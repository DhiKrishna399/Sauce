import { GoogleGenerativeAI, Part } from "@google/generative-ai";
import { 
  ExtractedBusinessInfo, 
  ParsedUserIntent, 
  ReservationIntent,
  PersonalMessageIntent,
  ActionIntentResponse 
} from "./types";
import { extractJsonFromText } from "./utils";
import { logger } from "./logger";
import { getAgentPhoneClient } from "./agentPhone";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

// Phone number regex patterns
const PHONE_PATTERNS = [
  /\+1?\d{10,11}/g,                           // +1234567890 or +11234567890
  /\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g,    // (123) 456-7890, 123-456-7890, 123.456.7890
];

export async function analyzeActionIntent(
  imageBase64: string,
  query: string,
  context?: string,
  requestId?: string
): Promise<ActionIntentResponse> {
  const ctx = { requestId };
  
  try {
    // Check if this is a personal call (phone number in query)
    const phoneInQuery = extractPhoneFromQuery(query);
    if (phoneInQuery) {
      logger.info("Detected personal call intent", { ...ctx, phone: phoneInQuery.substring(0, 6) + "****" });
      return handlePersonalCall(query, phoneInQuery, requestId);
    }

    // Otherwise, try to extract from screenshot (business call)
    logger.info("Extracting business info from screenshot", ctx);
    const businessInfo = await extractBusinessInfo(imageBase64, requestId);
    
    if (!businessInfo.phoneNumber) {
      logger.warn("No phone number found in screenshot", ctx);
      return {
        mode: "action",
        type: "error",
        message: "Could not find a phone number on the screen. Please make sure the restaurant's phone number is visible, or include a phone number in your request.",
        details: { extractedInfo: businessInfo },
      };
    }

    // Parse user's intent from query
    logger.info("Parsing user intent from query", ctx);
    const userIntent = await parseUserIntent(query, businessInfo, requestId);
    
    if (userIntent.action !== "reservation") {
      return {
        mode: "action",
        type: "error",
        message: `I can only help with reservations right now. You asked about: "${userIntent.action}"`,
        details: { parsedIntent: userIntent },
      };
    }

    // Build reservation intent
    const reservation: ReservationIntent = {
      restaurantName: businessInfo.businessName,
      phoneNumber: formatPhoneNumber(businessInfo.phoneNumber),
      partySize: userIntent.partySize || 2,
      date: userIntent.date || getTodayOrTomorrow(),
      time: userIntent.time || "7:00 PM",
      guestName: userIntent.guestName || "Guest",
      specialRequests: userIntent.specialRequests,
    };

    logger.info("Built reservation intent", { ...ctx, reservation: { 
      restaurant: reservation.restaurantName,
      partySize: reservation.partySize,
      date: reservation.date,
      time: reservation.time,
    }});

    // Initiate the call
    const client = getAgentPhoneClient();
    const call = await client.initiateReservationCall(reservation, requestId);

    return {
      mode: "action",
      type: "executed",
      intent: "book_reservation",
      status: "success",
      callId: call.id,
      message: `Calling ${reservation.restaurantName} to make a reservation for ${reservation.partySize} at ${reservation.time} on ${reservation.date}...`,
      details: {
        reservation,
        callStatus: call.status,
      },
    };

  } catch (error) {
    logger.error("Action analysis failed", error, ctx);
    return {
      mode: "action",
      type: "error",
      message: error instanceof Error ? error.message : "An unexpected error occurred",
    };
  }
}

function extractPhoneFromQuery(query: string): string | null {
  for (const pattern of PHONE_PATTERNS) {
    const match = query.match(pattern);
    if (match) {
      return formatPhoneNumber(match[0]);
    }
  }
  return null;
}

async function handlePersonalCall(
  query: string,
  phoneNumber: string,
  requestId?: string
): Promise<ActionIntentResponse> {
  const ctx = { requestId };
  
  // Parse the personal message intent using Gemini
  const messageIntent = await parsePersonalMessageIntent(query, phoneNumber, requestId);
  
  logger.info("Parsed personal message intent", { 
    ...ctx, 
    recipient: messageIntent.recipientName,
    messagePreview: messageIntent.message.substring(0, 50) + "..."
  });

  // Initiate the personal call
  const client = getAgentPhoneClient();
  const call = await client.initiatePersonalCall(messageIntent, requestId);

  const recipientDisplay = messageIntent.recipientName || phoneNumber;
  
  return {
    mode: "action",
    type: "executed",
    intent: "personal_message",
    status: "success",
    callId: call.id,
    message: `Calling ${recipientDisplay} to deliver your message...`,
    details: {
      recipient: recipientDisplay,
      message: messageIntent.message,
      callStatus: call.status,
    },
  };
}

async function parsePersonalMessageIntent(
  query: string,
  phoneNumber: string,
  requestId?: string
): Promise<PersonalMessageIntent> {
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const systemPrompt = `You are parsing a user's request to call someone and deliver a message.

User's request: "${query}"
Phone number detected: ${phoneNumber}

Extract the following and return ONLY valid JSON:
{
  "recipientName": "name of person being called, or null if not mentioned",
  "message": "the actual message to deliver (reword naturally if needed)",
  "isUrgent": true or false,
  "senderName": "name of sender if mentioned, or 'your friend' as default"
}

EXAMPLES:
- "Call +15551234567 and tell them I'll be late" → {"recipientName": null, "message": "I'll be running late", "isUrgent": false, "senderName": "your friend"}
- "Call mom at 555-123-4567 and say I got the job!" → {"recipientName": "Mom", "message": "I got the job!", "isUrgent": false, "senderName": "your child"}
- "URGENT: Call John at +15559876543 - meeting moved to 3pm" → {"recipientName": "John", "message": "The meeting has been moved to 3pm", "isUrgent": true, "senderName": "your colleague"}
- "Leave a message for 555-0000 saying the package arrived" → {"recipientName": null, "message": "The package you were expecting has arrived", "isUrgent": false, "senderName": "your friend"}

Return raw JSON only.`;

  const result = await model.generateContent(systemPrompt);
  const responseText = result.response.text();
  
  logger.debug("Personal message parsing raw response", { requestId, response: responseText.substring(0, 200) });

  const parsed = extractJsonFromText(responseText) || JSON.parse(responseText);
  
  return {
    phoneNumber,
    recipientName: parsed.recipientName || undefined,
    message: parsed.message || "I wanted to reach out to you.",
    isUrgent: parsed.isUrgent || false,
    senderName: parsed.senderName || "your friend",
  };
}

async function extractBusinessInfo(imageBase64: string, requestId?: string): Promise<ExtractedBusinessInfo> {
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const systemPrompt = `You are analyzing a screenshot to extract business information. 
Look for a restaurant, cafe, or food establishment and extract:
- Business name
- Phone number (VERY IMPORTANT - look carefully for any phone numbers)
- Address if visible
- Hours if visible
- Cuisine type if apparent
- Price range if indicated

Return ONLY valid JSON with this exact structure:
{
  "businessName": "Restaurant Name",
  "phoneNumber": "+1234567890 or null if not found",
  "address": "123 Main St or null",
  "hours": "Open hours or null",
  "cuisine": "Italian/Mexican/etc or null",
  "priceRange": "$/$$/$$$/$$$$ or null"
}

IMPORTANT: 
- Look EVERYWHERE for phone numbers: header, footer, sidebar, contact section, "Call" buttons
- Phone numbers might be formatted like (415) 555-1234, 415.555.1234, or 415-555-1234
- Return raw JSON only, no markdown formatting`;

  const imagePart: Part = {
    inlineData: {
      data: imageBase64,
      mimeType: "image/png"
    }
  };

  const result = await model.generateContent([systemPrompt, imagePart]);
  const responseText = result.response.text();
  
  logger.debug("Business extraction raw response", { requestId, response: responseText.substring(0, 200) });

  const parsed = extractJsonFromText(responseText) || JSON.parse(responseText);
  
  return {
    businessName: parsed.businessName || "Unknown Restaurant",
    phoneNumber: parsed.phoneNumber || null,
    address: parsed.address,
    hours: parsed.hours,
    cuisine: parsed.cuisine,
    priceRange: parsed.priceRange,
  };
}

async function parseUserIntent(
  query: string, 
  businessInfo: ExtractedBusinessInfo,
  requestId?: string
): Promise<ParsedUserIntent> {
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const today = new Date();
  const todayStr = today.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });

  const systemPrompt = `You are parsing a user's request about a restaurant. Today is ${todayStr}.

User's request: "${query}"
Restaurant: ${businessInfo.businessName}

Determine what the user wants and extract details. Return ONLY valid JSON:
{
  "action": "reservation" or "inquiry" or "unknown",
  "partySize": number or null,
  "date": "formatted date like 'May 17, 2026' or null",
  "time": "formatted time like '7:00 PM' or null", 
  "guestName": "name if mentioned or null",
  "specialRequests": "any special requests or null",
  "rawQuery": "original query"
}

PARSING RULES:
- "tonight" or "today" = ${todayStr}
- "tomorrow" = the next day
- "for 2" or "party of 2" or "table for two" = partySize: 2
- "at 7" or "7pm" or "7:00" = time: "7:00 PM"
- If no time specified, default to "7:00 PM"
- If no party size specified, default to 2
- "book", "reserve", "make a reservation", "get a table" = action: "reservation"

Return raw JSON only.`;

  const result = await model.generateContent(systemPrompt);
  const responseText = result.response.text();
  
  logger.debug("Intent parsing raw response", { requestId, response: responseText.substring(0, 200) });

  const parsed = extractJsonFromText(responseText) || JSON.parse(responseText);
  
  return {
    action: parsed.action || "unknown",
    partySize: parsed.partySize,
    date: parsed.date,
    time: parsed.time,
    guestName: parsed.guestName,
    specialRequests: parsed.specialRequests,
    rawQuery: query,
  };
}

function formatPhoneNumber(phone: string): string {
  // Remove all non-numeric characters except +
  const cleaned = phone.replace(/[^\d+]/g, "");
  
  // If it doesn't start with +, assume US number
  if (!cleaned.startsWith("+")) {
    if (cleaned.length === 10) {
      return "+1" + cleaned;
    } else if (cleaned.length === 11 && cleaned.startsWith("1")) {
      return "+" + cleaned;
    }
  }
  
  return cleaned;
}

function getTodayOrTomorrow(): string {
  const now = new Date();
  const hour = now.getHours();
  
  // If it's after 8 PM, default to tomorrow
  const targetDate = hour >= 20 ? new Date(now.getTime() + 24 * 60 * 60 * 1000) : now;
  
  return targetDate.toLocaleDateString('en-US', { 
    weekday: 'long', 
    month: 'long', 
    day: 'numeric', 
    year: 'numeric' 
  });
}

// Get call status and analyze outcome
export async function getCallResult(callId: string, requestId?: string): Promise<{
  status: string;
  success?: boolean;
  message: string;
  transcript?: string;
}> {
  const client = getAgentPhoneClient();
  
  try {
    const call = await client.getCallStatus(callId);
    
    if (call.status === "completed") {
      const transcripts = await client.getCallTranscript(callId);
      
      // Detect call type from transcript content
      const fullText = transcripts.map(t => t.content.toLowerCase()).join(" ");
      const isReservation = fullText.includes("reservation") || 
                           fullText.includes("table for") || 
                           fullText.includes("party of") ||
                           fullText.includes("guests at");
      const callType = isReservation ? 'reservation' : 'personal';
      
      const outcome = client.analyzeCallOutcome(transcripts, callType);
      
      return {
        status: call.status,
        success: outcome.success,
        message: outcome.message,
        transcript: transcripts.map(t => `${t.role}: ${t.content}`).join("\n"),
      };
    }
    
    return {
      status: call.status,
      message: getStatusMessage(call.status),
    };
  } catch (error) {
    logger.error("Failed to get call result", error, { requestId, callId });
    throw error;
  }
}

function getStatusMessage(status: string): string {
  const messages: Record<string, string> = {
    "queued": "Call is queued...",
    "ringing": "Phone is ringing...",
    "in-progress": "Call in progress...",
    "completed": "Call completed",
    "failed": "Call failed to connect",
    "no-answer": "No answer",
  };
  return messages[status] || `Status: ${status}`;
}
