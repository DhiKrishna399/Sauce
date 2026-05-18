import { GoogleGenerativeAI, Part } from "@google/generative-ai";
import { GuideResponse } from "./types";
import { extractJsonFromText } from "./utils";
import { logger } from "./logger";

// Initialize Gemini SDK
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export async function generateGuide(
  imageBase64: string,
  query: string,
  appContext?: string,
  requestId?: string
): Promise<GuideResponse> {
  const ctx = { requestId };
  
  try {
    logger.debug("Initializing Gemini model", { ...ctx, model: "gemini-2.5-flash" });
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const systemInstruction = `You are a helpful UI guide assistant. Your job is to analyze screenshots and answer questions about what's on screen.

IMPORTANT: Determine the type of question:
1. **"howto" questions** - User wants to DO something (e.g., "How do I change settings?", "Where do I click to save?", "Help me navigate to X"). These need step-by-step instructions.
2. **"informational" questions** - User wants to KNOW something about what's visible (e.g., "What item is cheapest?", "What's the total?", "How many items are in my cart?", "What does this button do?"). These just need a direct answer, NO steps needed.

For "howto" questions:
- Provide numbered steps with clear instructions
- CRITICAL: Include a highlight for EACH step showing exactly where to click/look
- Each highlight MUST have a label like "Step 1", "Step 2", etc. to match the step number
- Use pixel coordinates from the screenshot image (x, y measured from top-left)
- Estimate the approximate bounding box around the UI element

For "informational" questions:
- Provide a direct, helpful answer in the explanation
- Leave steps array EMPTY []
- Only include highlights if pointing to something helps the answer

Always respond with valid JSON matching this exact structure:
{
  "answerType": "howto" or "informational",
  "explanation": "Your answer or explanation here",
  "steps": [
    { "step": 1, "instruction": "Click the X button", "elementDescription": "Blue button labeled 'X' in top right" }
  ],
  "highlights": [
    { "type": "box", "x": 1200, "y": 50, "width": 80, "height": 40, "label": "Step 1", "color": "#FF6B6B" },
    { "type": "box", "x": 300, "y": 200, "width": 150, "height": 50, "label": "Step 2", "color": "#4ECDC4" }
  ]
}

HIGHLIGHT RULES:
- Use "box" type for buttons, menu items, input fields (most common)
- Use "circle" type for icons, small buttons, or circular elements
- x, y coordinates are the TOP-LEFT corner of the bounding box (in image pixels)
- width, height define the size of the highlight box
- For circle type, use "radius" instead of width/height, and x,y is the CENTER
- label MUST be "Step N" where N matches the step number
- color is optional but recommended for visual distinction

For informational questions, steps should be an empty array: "steps": []

DO NOT include any markdown formatting like \`\`\`json around the response. Return ONLY raw JSON.`;

    const prompt = `User Question: "${query}"
${appContext ? `App Context: ${appContext}` : ""}

Please analyze the screenshot and provide step-by-step guidance. Respond ONLY with raw valid JSON.`;

    const imagePart: Part = {
      inlineData: {
        data: imageBase64,
        mimeType: "image/png"
      }
    };

    logger.debug("Sending request to Gemini Vision API", { 
      ...ctx, 
      queryLength: query.length,
      imageSize: `${Math.round(imageBase64.length / 1024)}KB`,
      hasAppContext: !!appContext 
    });
    
    const apiStartTime = Date.now();
    const result = await model.generateContent([systemInstruction, prompt, imagePart]);
    const apiDuration = Date.now() - apiStartTime;
    
    const responseText = result.response.text();
    logger.debug("Received response from Gemini", { 
      ...ctx, 
      responseLength: responseText.length,
      apiDuration 
    });

    // Parse the JSON response
    try {
      const parsed = extractJsonFromText(responseText) || JSON.parse(responseText);
      
      const answerType = parsed.answerType || (parsed.steps?.length > 0 ? "howto" : "informational");
      
      logger.debug("Successfully parsed Gemini response", { 
        ...ctx,
        answerType,
        hasExplanation: !!parsed.explanation,
        stepsCount: parsed.steps?.length || 0,
        highlightsCount: parsed.highlights?.length || 0
      });

      return {
        mode: "guide",
        answerType,
        explanation: parsed.explanation || "Here's what I found",
        steps: parsed.steps || [],
        highlights: parsed.highlights || [],
      };
    } catch (parseError) {
      logger.error("Failed to parse Gemini response as JSON", parseError, ctx);
      logger.debug("Raw response was", { ...ctx, rawResponse: responseText.substring(0, 500) });
      
      return {
        mode: "guide",
        answerType: "informational",
        explanation: "Unable to parse guidance. Please try again.",
        steps: [],
        highlights: [],
      };
    }
  } catch (error) {
    logger.error("Gemini API call failed", error, ctx);
    
    // Add more context for specific error types
    if (error instanceof Error) {
      if (error.message.includes("API key")) {
        logger.error("API Key issue detected - check GEMINI_API_KEY environment variable", null, ctx);
      } else if (error.message.includes("quota")) {
        logger.error("API quota exceeded", null, ctx);
      } else if (error.message.includes("timeout") || error.message.includes("ETIMEDOUT")) {
        logger.error("API request timed out", null, ctx);
      }
    }
    
    throw error;
  }
}
