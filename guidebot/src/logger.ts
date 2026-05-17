type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR";

interface LogContext {
  requestId?: string;
  endpoint?: string;
  method?: string;
  duration?: number;
  [key: string]: any;
}

const LOG_COLORS = {
  DEBUG: "\x1b[36m",  // Cyan
  INFO: "\x1b[32m",   // Green
  WARN: "\x1b[33m",   // Yellow
  ERROR: "\x1b[31m",  // Red
  RESET: "\x1b[0m",
};

class Logger {
  private formatTimestamp(): string {
    return new Date().toISOString();
  }

  private formatContext(context?: LogContext): string {
    if (!context || Object.keys(context).length === 0) return "";
    
    const parts: string[] = [];
    if (context.requestId) parts.push(`reqId=${context.requestId}`);
    if (context.endpoint) parts.push(`endpoint=${context.endpoint}`);
    if (context.method) parts.push(`method=${context.method}`);
    if (context.duration !== undefined) parts.push(`duration=${context.duration}ms`);
    
    const otherKeys = Object.keys(context).filter(
      k => !["requestId", "endpoint", "method", "duration"].includes(k)
    );
    for (const key of otherKeys) {
      const value = context[key];
      if (typeof value === "object") {
        parts.push(`${key}=${JSON.stringify(value)}`);
      } else {
        parts.push(`${key}=${value}`);
      }
    }
    
    return parts.length > 0 ? ` [${parts.join(" | ")}]` : "";
  }

  private log(level: LogLevel, message: string, context?: LogContext): void {
    const color = LOG_COLORS[level];
    const reset = LOG_COLORS.RESET;
    const timestamp = this.formatTimestamp();
    const contextStr = this.formatContext(context);
    
    console.log(`${color}[${timestamp}] [${level}]${reset} ${message}${contextStr}`);
  }

  debug(message: string, context?: LogContext): void {
    if (process.env.NODE_ENV === "development" || process.env.DEBUG === "true") {
      this.log("DEBUG", message, context);
    }
  }

  info(message: string, context?: LogContext): void {
    this.log("INFO", message, context);
  }

  warn(message: string, context?: LogContext): void {
    this.log("WARN", message, context);
  }

  error(message: string, error?: Error | unknown, context?: LogContext): void {
    this.log("ERROR", message, context);
    if (error) {
      if (error instanceof Error) {
        console.error(`  └─ ${error.name}: ${error.message}`);
        if (error.stack && process.env.NODE_ENV === "development") {
          console.error(`  └─ Stack: ${error.stack.split("\n").slice(1, 4).join("\n       ")}`);
        }
      } else {
        console.error(`  └─ ${String(error)}`);
      }
    }
  }

  request(method: string, endpoint: string, requestId: string, body?: any): void {
    const context: LogContext = { requestId, endpoint, method };
    if (body?.query) context.query = body.query;
    if (body?.mode) context.mode = body.mode;
    if (body?.imageBase64) context.imageSize = `${Math.round(body.imageBase64.length / 1024)}KB`;
    this.info("Incoming request", context);
  }

  response(requestId: string, statusCode: number, duration: number): void {
    const level = statusCode >= 400 ? "WARN" : "INFO";
    this.log(level, `Response sent`, { requestId, statusCode, duration });
  }

  apiCall(service: string, operation: string, requestId?: string): void {
    this.debug(`External API call: ${service}`, { operation, requestId });
  }

  apiResponse(service: string, success: boolean, duration: number, requestId?: string): void {
    const level = success ? "DEBUG" : "ERROR";
    this.log(level, `External API response: ${service}`, { success, duration, requestId });
  }
}

export const logger = new Logger();

export function generateRequestId(): string {
  return `req_${Date.now().toString(36)}_${Math.random().toString(36).substring(2, 8)}`;
}
