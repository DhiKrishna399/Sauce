// Request and Response types for Sauce API

export interface AnalyzeRequest {
  imageBase64: string;
  query: string;
  mode: 'guide' | 'action';
  context?: {
    appName?: string;
    pageUrl?: string;
  };
}

// Guide Mode Response
export interface GuideResponse {
  mode: 'guide';
  answerType: 'howto' | 'informational';  // howto = needs steps, informational = direct answer
  explanation: string;
  steps: GuideStep[];
  highlights: Highlight[];
}

export interface GuideStep {
  step: number;
  instruction: string;
  elementDescription: string;
}

export interface Highlight {
  type: 'circle' | 'arrow' | 'box';
  x: number;
  y: number;
  radius?: number;
  width?: number;
  height?: number;
  toX?: number;
  toY?: number;
  label: string;
  color?: string;
}

// Action Mode Response
export interface ActionIntentResponse {
  mode: 'action';
  type: 'parsed_intent' | 'executed' | 'pending_confirmation' | 'error';
  intent?: string; // book_reservation, schedule_appointment, etc
  details?: Record<string, any>;
  requiresConfirmation?: boolean;
  message?: string;
  status?: 'success' | 'failed';
  callId?: string;
}

export interface ActionExecutionRequest {
  intent: string;
  details: Record<string, any>;
  phoneNumber?: string;
  taskDescription: string;
}

export interface ActionExecutionResponse {
  mode: 'action';
  type: 'executed';
  status: 'success' | 'failed';
  message: string;
  callId?: string;
  confirmationNumber?: string;
}
