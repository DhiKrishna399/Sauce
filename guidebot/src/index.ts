import dotenv from "dotenv";
// Load environment variables FIRST, before any other imports that depend on them
dotenv.config();

import express, { Request, Response, NextFunction } from "express";
import cors from "cors";
import { generateGuide } from "./guideAgent";
import { AnalyzeRequest, ActionIntentResponse } from "./types";
import { logger, generateRequestId } from "./logger";

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
      logger.info("Action mode requested (not fully implemented)", { requestId });
      const actionResponse: ActionIntentResponse = {
        mode: "action",
        type: "pending_confirmation",
        intent: "book_reservation",
        details: { task: "Analyzing request..." },
        requiresConfirmation: true,
        message: "Action mode not yet fully implemented. Please use guide mode.",
      };
      return res.json({ ...actionResponse, requestId });
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

// 404 handler
app.use((req: Request, res: Response) => {
  const requestId = (req as any).requestId || generateRequestId();
  logger.warn("Endpoint not found", { requestId, path: req.path, method: req.method });
  res.status(404).json({ error: "Endpoint not found", requestId });
});

// Startup
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info("=".repeat(50));
  logger.info("GuideBot backend starting up");
  logger.info(`Server listening on http://localhost:${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || "development"}`);
  logger.info(`API Key configured: ${process.env.GEMINI_API_KEY ? "Yes" : "NO - MISSING!"}`);
  logger.info("Endpoints:");
  logger.info("  POST /analyze - Guide or Action mode");
  logger.info("  GET  /health  - Health check");
  logger.info("=".repeat(50));
});
