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

// AgentPhone Types
export interface AgentPhoneConfig {
  apiKey: string;
  agentId?: string;
  mockMode: boolean;
}

export interface CreateAgentRequest {
  name: string;
  description?: string;
  voiceMode: 'webhook' | 'hosted';
  systemPrompt?: string;
  beginMessage?: string;
  voice?: string;
  modelTier?: 'turbo' | 'balanced' | 'max';
}

export interface AgentPhoneAgent {
  id: string;
  name: string;
  voiceMode: 'webhook' | 'hosted';
  systemPrompt?: string;
  voice: string;
  createdAt: string;
  numbers?: { id: string; phoneNumber: string; status: string }[];
}

export interface CreateCallRequest {
  agentId: string;
  toNumber: string;
  initialGreeting?: string;
  systemPrompt?: string;
  variables?: Record<string, string>;
}

export interface AgentPhoneCall {
  id: string;
  agentId: string;
  toNumber: string;
  fromNumber?: string;
  status: 'queued' | 'ringing' | 'in-progress' | 'completed' | 'failed' | 'no-answer';
  direction: 'inbound' | 'outbound' | 'web';
  startedAt?: string;
  endedAt?: string;
  durationSeconds?: number;
}

export interface CallTranscript {
  role: 'user' | 'agent';
  content: string;
  createdAt: string;
}

export interface WebhookEvent {
  event: 'agent.message' | 'agent.call_ended';
  callId: string;
  agentId: string;
  data: {
    transcript?: string;
    status?: string;
    durationSeconds?: number;
    transcripts?: CallTranscript[];
  };
}

// Reservation-specific types
export interface ReservationIntent {
  restaurantName: string;
  phoneNumber: string;
  partySize: number;
  date: string;
  time: string;
  guestName: string;
  specialRequests?: string;
}

export interface ExtractedBusinessInfo {
  businessName: string;
  phoneNumber: string | null;
  address?: string;
  hours?: string;
  cuisine?: string;
  priceRange?: string;
}

export interface ParsedUserIntent {
  action: 'reservation' | 'inquiry' | 'personal_call' | 'email' | 'unknown';
  partySize?: number;
  date?: string;
  time?: string;
  guestName?: string;
  specialRequests?: string;
  emailRecipient?: string;
  emailSubject?: string;
  emailBody?: string;
  rawQuery: string;
}

// Personal call/message types
export interface PersonalMessageIntent {
  phoneNumber: string;
  recipientName?: string;
  message: string;
  isUrgent: boolean;
  senderName: string;
}

// AgentMail Types
export interface AgentMailConfig {
  apiKey: string;
  inboxId?: string;
  mockMode: boolean;
}

export interface EmailIntent {
  recipientEmail: string;
  subject: string;
  body: string;
  htmlBody?: string;
  purpose: 'confirmation' | 'inquiry' | 'follow_up' | 'general';
}

export interface EmailSendResult {
  messageId: string;
  status: 'sent' | 'failed' | 'queued';
  timestamp: string;
  recipientEmail: string;
  subject: string;
  errorMessage?: string;
}

export interface EmailMessage {
  messageId: string;
  from: string;
  to: string;
  subject: string;
  text: string;
  html?: string;
  receivedAt: string;
}

export interface ExtractedEmailInfo {
  businessName: string;
  emailAddress: string | null;
  phoneNumber?: string | null;
}

export interface EmailActionResponse {
  mode: 'action';
  type: 'email_sent' | 'email_pending' | 'error';
  intent: 'send_email';
  status: 'success' | 'failed';
  messageId?: string;
  message: string;
  details?: {
    recipientEmail: string;
    subject: string;
    purpose: string;
  };
}

export interface AgentMailWebhookEvent {
  event: 'message.received' | 'message.sent' | 'message.delivered' | 'message.bounced';
  inboxId: string;
  messageId: string;
  data: {
    from?: string;
    to?: string;
    subject?: string;
    text?: string;
    timestamp?: string;
  };
}
