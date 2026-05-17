import dotenv from "dotenv";
// Load environment variables FIRST, before any other imports that depend on them
dotenv.config();

import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import { generateGuide } from "./guideAgent";
import { analyzeActionIntent, getCallResult } from "./actionAgent";
import { AnalyzeRequest, ActionIntentResponse, WebhookEvent } from "./types";
import { logger, generateRequestId } from "./logger";
import { getAgentPhoneClient } from "./agentPhone";

const app = express();
app.use(cors());
app.use(express.json({ limit: "50mb" }));

// Request logging middleware
app.use((req: Request, res: Response, next: NextFunction) => {
  const requestId = generateRequestId();
  const startTime = Date.now();
  
  // Attach requestId to request for use in handlers
  (req as any).requestId = requestId;
  (req as any).startTime = startTime;
  
  // Log incoming request
  logger.request(req.method, req.path, requestId, req.body);
  
  // Log response when finished
  res.on("finish", () => {
    const duration = Date.now() - startTime;
    logger.response(requestId, res.statusCode, duration);
  });
  
  next();
});

// Health check endpoint
app.get("/health", (req: Request, res: Response) => {
  const requestId = (req as any).requestId;
  logger.debug("Health check requested", { requestId });
  res.json({ 
    status: "ok", 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + "MB"
  });
});

// Main analyze endpoint
app.post("/analyze", async (req: Request, res: Response) => {
  const requestId = (req as any).requestId;
  const startTime = (req as any).startTime;
  
  try {
    const { imageBase64, query, mode, context } = req.body as AnalyzeRequest;

    // Validate input
    if (!imageBase64 || !query || !mode) {
      logger.warn("Missing required fields in request", { requestId, hasImage: !!imageBase64, hasQuery: !!query, hasMode: !!mode });
      return res.status(400).json({
        error: "Missing required fields: imageBase64, query, mode",
        requestId,
      });
    }

    if (!["guide", "action"].includes(mode)) {
      logger.warn("Invalid mode specified", { requestId, mode });
      return res.status(400).json({ error: "Mode must be 'guide' or 'action'", requestId });
    }

    logger.info(`Processing ${mode.toUpperCase()} request`, { 
      requestId, 
      query: query.substring(0, 100),
      imageSize: `${Math.round(imageBase64.length / 1024)}KB`,
      appContext: context?.appName 
    });

    if (mode === "guide") {
      const apiStartTime = Date.now();
      logger.apiCall("Gemini", "generateContent", requestId);
      
      const response = await generateGuide(imageBase64, query, context?.appName, requestId);
      
      const apiDuration = Date.now() - apiStartTime;
      logger.apiResponse("Gemini", true, apiDuration, requestId);
      logger.info("Guide generated successfully", { 
        requestId, 
        stepsCount: response.steps?.length || 0,
        highlightsCount: response.highlights?.length || 0,
        totalDuration: Date.now() - startTime
      });
      
      return res.json({ ...response, requestId });
    } else if (mode === "action") {
      const apiStartTime = Date.now();
      logger.apiCall("ActionAgent", "analyzeActionIntent", requestId);
      
      const response = await analyzeActionIntent(imageBase64, query, context?.appName, requestId);
      
      const apiDuration = Date.now() - apiStartTime;
      logger.apiResponse("ActionAgent", response.type !== "error", apiDuration, requestId);
      logger.info("Action processed", { 
        requestId, 
        type: response.type,
        intent: response.intent,
        hasCallId: !!response.callId,
        totalDuration: Date.now() - startTime
      });
      
      return res.json({ ...response, requestId });
    }
  } catch (error) {
    const duration = Date.now() - startTime;
    logger.error("Request failed", error, { requestId, duration });
    
    // Extract useful error info
    const errorMessage = error instanceof Error ? error.message : String(error);
    const isApiError = errorMessage.includes("API") || errorMessage.includes("GoogleGenerativeAI");
    
    res.status(500).json({
      error: isApiError ? "AI service error" : "Internal server error",
      message: errorMessage,
      requestId,
    });
  }
});

// Get call status endpoint
app.get("/call/:callId", async (req: Request, res: Response) => {
  const requestId = (req as any).requestId;
  const callId = req.params.callId as string;
  
  try {
    logger.info("Fetching call status", { requestId, callId });
    const result = await getCallResult(callId, requestId);
    return res.json({ ...result, callId, requestId });
  } catch (error) {
    logger.error("Failed to get call status", error, { requestId, callId });
    const errorMessage = error instanceof Error ? error.message : String(error);
    return res.status(500).json({ error: errorMessage, callId, requestId });
  }
});

// AgentPhone webhook endpoint
app.post("/webhook/agentphone", async (req: Request, res: Response) => {
  const requestId = (req as any).requestId;
  
  try {
    const event = req.body as WebhookEvent;
    logger.info("Received AgentPhone webhook", { 
      requestId, 
      event: event.event, 
      callId: event.callId 
    });

    if (event.event === "agent.call_ended") {
      const client = getAgentPhoneClient();
      const transcripts = event.data.transcripts || [];
      const outcome = client.analyzeCallOutcome(transcripts);
      
      logger.info("Call ended", { 
        requestId,
        callId: event.callId,
        success: outcome.success,
        duration: event.data.durationSeconds 
      });
      
      // TODO: Send push notification or store result for polling
      // For now, just log it
    }

    res.status(200).send("OK");
  } catch (error) {
    logger.error("Webhook processing failed", error, { requestId });
    res.status(500).send("Error processing webhook");
  }
});

// ==================== TEST ENDPOINTS ====================

// Test: Simulate a complete call flow (for local testing without AgentPhone)
app.post("/test/simulate-call", async (req: Request, res: Response) => {
  const requestId = (req as any).requestId;
  
  const { 
    restaurantName = "Test Restaurant",
    phoneNumber = "+15551234567",
    partySize = 2,
    date = "Tonight",
    time = "7:00 PM",
    success = true
  } = req.body;

  logger.info("[TEST] Simulating call", { requestId, restaurantName, success });

  // Generate mock call ID
  const callId = "call_test_" + Date.now().toString(36);

  // Simulate async call completion
  setTimeout(() => {
    logger.info("[TEST] Simulated call completed", { requestId, callId, success });
  }, 3000);

  return res.json({
    mode: "action",
    type: "executed",
    intent: "book_reservation",
    status: "success",
    callId,
    message: `[TEST MODE] Simulating call to ${restaurantName} for ${partySize} at ${time} on ${date}...`,
    details: {
      restaurantName,
      phoneNumber,
      partySize,
      date,
      time,
      testMode: true,
      simulatedSuccess: success,
    },
    requestId,
  });
});

// Test: Get mock status with progression
app.get("/test/call-status/:callId", async (req: Request, res: Response) => {
  const requestId = (req as any).requestId;
  const callId = req.params.callId as string;
  
  // Parse timestamp from call ID to simulate progression
  const callTimestamp = parseInt(callId.replace("call_test_", ""), 36);
  const elapsed = Date.now() - callTimestamp;
  
  let status: string;
  let message: string;
  let transcript: string | undefined;
  let success: boolean | undefined;

  if (elapsed < 2000) {
    status = "queued";
    message = "Call is queued...";
  } else if (elapsed < 4000) {
    status = "ringing";
    message = "Phone is ringing...";
  } else if (elapsed < 8000) {
    status = "in-progress";
    message = "Call in progress...";
  } else {
    status = "completed";
    success = true;
    message = "Reservation confirmed!";
    transcript = [
      "Agent: Hi, I'm calling to make a reservation for 2 people for 7:00 PM tonight.",
      "Restaurant: Sure, let me check... Yes, we have availability. Name for the reservation?",
      "Agent: The name is Guest.",
      "Restaurant: Perfect, you're all set for 2 at 7 PM. See you then!",
      "Agent: Thank you! Goodbye.",
    ].join("\n");
  }

  return res.json({
    callId,
    status,
    message,
    success,
    transcript,
    elapsedMs: elapsed,
    requestId,
  });
});

// 404 handler
app.use((req: Request, res: Response) => {
  const requestId = (req as any).requestId || generateRequestId();
  logger.warn("Endpoint not found", { requestId, path: req.path, method: req.method });
  res.status(404).json({ error: "Endpoint not found", requestId });
});

// Startup
const PORT = process.env.PORT || 3000;
const isMockMode = process.env.AGENTPHONE_MOCK === "true" || !process.env.AGENTPHONE_API_KEY;

app.listen(PORT, () => {
  logger.info("=".repeat(50));
  logger.info("Sauce backend starting up");
  logger.info(`Server listening on http://localhost:${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || "development"}`);
  logger.info(`Gemini API Key: ${process.env.GEMINI_API_KEY ? "Configured" : "MISSING!"}`);
  logger.info(`AgentPhone: ${isMockMode ? "MOCK MODE (no API key)" : "Live mode"}`);
  logger.info("");
  logger.info("Endpoints:");
  logger.info("  POST /analyze        - Guide or Action mode");
  logger.info("  GET  /health         - Health check");
  logger.info("  GET  /call/:callId   - Get call status");
  logger.info("  POST /webhook/agentphone - AgentPhone webhooks");
  logger.info("");
  logger.info("Test Endpoints:");
  logger.info("  POST /test/simulate-call     - Simulate a call");
  logger.info("  GET  /test/call-status/:id   - Get simulated status");
  logger.info("=".repeat(50));
});
