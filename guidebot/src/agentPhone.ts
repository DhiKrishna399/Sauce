import {
  AgentPhoneConfig,
  AgentPhoneAgent,
  AgentPhoneCall,
  CreateCallRequest,
  CallTranscript,
  ReservationIntent,
  PersonalMessageIntent,
} from "./types";
import { logger } from "./logger";

const AGENTPHONE_BASE_URL = "https://api.agentphone.ai/v1";

// In-memory store for mock calls (for testing)
const mockCallStore: Map<string, AgentPhoneCall & { transcripts: CallTranscript[] }> = new Map();

export class AgentPhoneClient {
  private apiKey: string;
  private agentId: string | null;
  private mockMode: boolean;

  constructor(config: AgentPhoneConfig) {
    this.apiKey = config.apiKey;
    this.agentId = config.agentId || null;
    this.mockMode = config.mockMode;

    if (this.mockMode) {
      logger.info("AgentPhone client initialized in MOCK mode");
    } else {
      logger.info("AgentPhone client initialized", { hasApiKey: !!this.apiKey, hasAgentId: !!this.agentId });
    }
  }

  private async request<T>(method: string, path: string, body?: any): Promise<T> {
    const url = `${AGENTPHONE_BASE_URL}${path}`;
    
    logger.debug(`AgentPhone API: ${method} ${path}`, { body: body ? "..." : undefined });
    
    const response = await fetch(url, {
      method,
      headers: {
        "Authorization": `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`AgentPhone API error (${response.status}): ${error}`);
    }

    return response.json() as Promise<T>;
  }

  async getOrCreateAgent(): Promise<AgentPhoneAgent> {
    if (this.mockMode) {
      return this.mockGetOrCreateAgent();
    }

    if (this.agentId) {
      return this.request<AgentPhoneAgent>("GET", `/agents/${this.agentId}`);
    }

    const agent = await this.request<AgentPhoneAgent>("POST", "/agents", {
      name: "Reservation Assistant",
      description: "AI assistant that makes restaurant reservations on behalf of users",
      voiceMode: "hosted",
      modelTier: "balanced",
      voice: "eleven_turbo_v2",
    });

    this.agentId = agent.id;
    logger.info("Created new AgentPhone agent", { agentId: agent.id });
    
    return agent;
  }

  async initiateReservationCall(reservation: ReservationIntent, requestId?: string): Promise<AgentPhoneCall> {
    if (this.mockMode) {
      return this.mockInitiateCall(reservation, requestId);
    }

    if (!this.agentId) {
      await this.getOrCreateAgent();
    }

    const systemPrompt = this.buildReservationPrompt(reservation);

    const callRequest: CreateCallRequest = {
      agentId: this.agentId!,
      toNumber: reservation.phoneNumber,
      initialGreeting: `Hi, I'm calling to make a reservation for ${reservation.partySize} ${reservation.partySize === 1 ? 'person' : 'people'} for ${reservation.time} on ${reservation.date}.`,
      systemPrompt,
      variables: {
        restaurant_name: reservation.restaurantName,
        party_size: String(reservation.partySize),
        date: reservation.date,
        time: reservation.time,
        guest_name: reservation.guestName,
        special_requests: reservation.specialRequests || "none",
      },
    };

    logger.info("Initiating reservation call", { 
      requestId, 
      restaurant: reservation.restaurantName,
      phone: reservation.phoneNumber.substring(0, 6) + "****" 
    });

    return this.request<AgentPhoneCall>("POST", "/calls", callRequest);
  }

  async initiatePersonalCall(message: PersonalMessageIntent, requestId?: string): Promise<AgentPhoneCall> {
    if (this.mockMode) {
      return this.mockInitiatePersonalCall(message, requestId);
    }

    if (!this.agentId) {
      await this.getOrCreateAgent();
    }

    const systemPrompt = this.buildPersonalMessagePrompt(message);
    const recipientName = message.recipientName || "there";

    const callRequest: CreateCallRequest = {
      agentId: this.agentId!,
      toNumber: message.phoneNumber,
      initialGreeting: `Hi ${recipientName}, I'm calling on behalf of ${message.senderName} with a message for you.`,
      systemPrompt,
      variables: {
        recipient_name: message.recipientName || "Friend",
        sender_name: message.senderName,
        message: message.message,
        is_urgent: message.isUrgent ? "yes" : "no",
      },
    };

    logger.info("Initiating personal call", { 
      requestId, 
      recipient: message.recipientName || "Unknown",
      phone: message.phoneNumber.substring(0, 6) + "****" 
    });

    return this.request<AgentPhoneCall>("POST", "/calls", callRequest);
  }

  async getCallStatus(callId: string): Promise<AgentPhoneCall> {
    if (this.mockMode) {
      return this.mockGetCallStatus(callId);
    }

    return this.request<AgentPhoneCall>("GET", `/calls/${callId}`);
  }

  async getCallTranscript(callId: string): Promise<CallTranscript[]> {
    if (this.mockMode) {
      return this.mockGetCallTranscript(callId);
    }

    const response = await this.request<{ transcripts: CallTranscript[] }>("GET", `/calls/${callId}/transcript`);
    return response.transcripts || [];
  }

  private buildReservationPrompt(reservation: ReservationIntent): string {
    return `You are making a restaurant reservation on behalf of a customer. Be polite, professional, and efficient.

RESERVATION DETAILS:
- Restaurant: ${reservation.restaurantName}
- Party Size: ${reservation.partySize} ${reservation.partySize === 1 ? 'person' : 'people'}
- Date: ${reservation.date}
- Time: ${reservation.time}
- Guest Name: ${reservation.guestName}
${reservation.specialRequests ? `- Special Requests: ${reservation.specialRequests}` : ''}

CONVERSATION GUIDELINES:
1. Greet politely and state you're calling to make a dinner reservation
2. Provide the date, time, and party size clearly
3. Give the guest name when asked: "${reservation.guestName}"
4. If they ask for a phone number, say the guest will call back if needed
5. Confirm all reservation details before ending the call
6. Thank them and say goodbye

IF THE REQUESTED TIME IS UNAVAILABLE:
- Ask what times ARE available on that date
- Accept a time within 1 hour of the requested time if offered
- If nothing works, politely thank them and end the call

IMPORTANT:
- Keep responses brief and natural, like a real phone call
- Don't over-explain or be overly formal
- If they're fully booked, accept it gracefully
- End the call politely once the reservation is confirmed or declined`;
  }

  private buildPersonalMessagePrompt(message: PersonalMessageIntent): string {
    const recipientName = message.recipientName || "there";
    return `You are delivering a personal message on behalf of someone. Be warm, friendly, and natural.

MESSAGE DETAILS:
- From: ${message.senderName}
- To: ${recipientName}
- Message: "${message.message}"
${message.isUrgent ? '- URGENT: This is time-sensitive!' : ''}

CONVERSATION FLOW:
1. Greet them warmly: "Hi ${recipientName}, this is an AI assistant calling on behalf of ${message.senderName}."
2. Check if it's a good time: "Is this a good time to pass along a quick message?"
3. If yes, deliver the message clearly and naturally
4. Ask if they'd like to send a reply: "Would you like me to pass any message back to ${message.senderName}?"
5. If they have a reply, acknowledge it: "Got it, I'll make sure ${message.senderName} gets that."
6. End warmly: "Thanks! Have a great day!"

IF YOU REACH VOICEMAIL:
- Leave a clear message: "Hi ${recipientName}, this is a message from ${message.senderName}: ${message.message}. ${message.senderName} asked me to pass this along. Have a great day!"

IF THEY SEEM CONFUSED OR SKEPTICAL:
- Reassure them: "I understand this might seem unusual. I'm an AI assistant that ${message.senderName} uses to deliver messages. The message is: ${message.message}"
- Offer verification: "You can reach ${message.senderName} directly if you'd like to confirm."

IMPORTANT:
- Be conversational, not robotic
- Keep it brief - respect their time
- If they're busy, offer to call back later
- Always be polite even if they're dismissive`;
  }

  // ==================== MOCK METHODS ====================

  private mockGetOrCreateAgent(): AgentPhoneAgent {
    const mockAgent: AgentPhoneAgent = {
      id: "agt_mock_" + Date.now().toString(36),
      name: "Reservation Assistant (Mock)",
      voiceMode: "hosted",
      voice: "eleven_turbo_v2",
      createdAt: new Date().toISOString(),
      numbers: [
        { id: "num_mock_001", phoneNumber: "+15550001234", status: "active" }
      ],
    };
    
    this.agentId = mockAgent.id;
    logger.info("[MOCK] Created mock agent", { agentId: mockAgent.id });
    
    return mockAgent;
  }

  private mockInitiateCall(reservation: ReservationIntent, requestId?: string): AgentPhoneCall {
    const callId = "call_mock_" + Date.now().toString(36);
    
    const mockCall: AgentPhoneCall & { transcripts: CallTranscript[] } = {
      id: callId,
      agentId: this.agentId || "agt_mock",
      toNumber: reservation.phoneNumber,
      fromNumber: "+15550001234",
      status: "queued",
      direction: "outbound",
      startedAt: new Date().toISOString(),
      transcripts: [],
    };

    mockCallStore.set(callId, mockCall);
    
    logger.info("[MOCK] Initiated mock call", { 
      requestId, 
      callId, 
      restaurant: reservation.restaurantName 
    });

    // Simulate call progression
    this.simulateCallProgression(callId, reservation);

    return mockCall;
  }

  private mockInitiatePersonalCall(message: PersonalMessageIntent, requestId?: string): AgentPhoneCall {
    const callId = "call_mock_" + Date.now().toString(36);
    
    const mockCall: AgentPhoneCall & { transcripts: CallTranscript[] } = {
      id: callId,
      agentId: this.agentId || "agt_mock",
      toNumber: message.phoneNumber,
      fromNumber: "+15550001234",
      status: "queued",
      direction: "outbound",
      startedAt: new Date().toISOString(),
      transcripts: [],
    };

    mockCallStore.set(callId, mockCall);
    
    logger.info("[MOCK] Initiated personal call", { 
      requestId, 
      callId, 
      recipient: message.recipientName || "Unknown"
    });

    // Simulate personal call progression
    this.simulatePersonalCallProgression(callId, message);

    return mockCall;
  }

  private async simulatePersonalCallProgression(callId: string, message: PersonalMessageIntent): Promise<void> {
    const call = mockCallStore.get(callId);
    if (!call) return;

    setTimeout(() => { call.status = "ringing"; }, 1000);
    setTimeout(() => { call.status = "in-progress"; }, 3000);

    setTimeout(() => {
      const recipientName = message.recipientName || "Friend";
      call.transcripts = [
        { role: "agent", content: `Hi ${recipientName}, I'm calling on behalf of ${message.senderName} with a message for you.`, createdAt: new Date().toISOString() },
        { role: "user", content: "Oh, okay. What's the message?", createdAt: new Date(Date.now() + 3000).toISOString() },
        { role: "agent", content: `${message.senderName} wanted me to tell you: "${message.message}"`, createdAt: new Date(Date.now() + 6000).toISOString() },
        { role: "user", content: "Got it, thanks for letting me know!", createdAt: new Date(Date.now() + 9000).toISOString() },
        { role: "agent", content: `Would you like me to pass any message back to ${message.senderName}?`, createdAt: new Date(Date.now() + 11000).toISOString() },
        { role: "user", content: "Just tell them I said thanks and I'll call them later.", createdAt: new Date(Date.now() + 14000).toISOString() },
        { role: "agent", content: `I'll pass that along. Have a great day!`, createdAt: new Date(Date.now() + 16000).toISOString() },
      ];
      call.status = "completed";
      call.endedAt = new Date().toISOString();
      call.durationSeconds = 25;
      
      logger.info("[MOCK] Personal call completed", { callId });
    }, 5000);
  }

  private async simulateCallProgression(callId: string, reservation: ReservationIntent): Promise<void> {
    const call = mockCallStore.get(callId);
    if (!call) return;

    // After 1 second: ringing
    setTimeout(() => {
      call.status = "ringing";
      logger.debug("[MOCK] Call status: ringing", { callId });
    }, 1000);

    // After 3 seconds: in-progress
    setTimeout(() => {
      call.status = "in-progress";
      logger.debug("[MOCK] Call status: in-progress", { callId });
    }, 3000);

    // After 5 seconds: add transcript and complete
    setTimeout(() => {
      const success = Math.random() > 0.2; // 80% success rate

      call.transcripts = this.generateMockTranscript(reservation, success);
      call.status = success ? "completed" : "completed";
      call.endedAt = new Date().toISOString();
      call.durationSeconds = 45 + Math.floor(Math.random() * 30);
      
      logger.info("[MOCK] Call completed", { 
        callId, 
        success, 
        duration: call.durationSeconds 
      });
    }, 5000);
  }

  private generateMockTranscript(reservation: ReservationIntent, success: boolean): CallTranscript[] {
    const now = new Date();
    
    if (success) {
      return [
        { role: "agent", content: `Hi, I'm calling to make a reservation for ${reservation.partySize} people for ${reservation.time} on ${reservation.date}.`, createdAt: now.toISOString() },
        { role: "user", content: "Sure, let me check... Yes, we have availability at that time. May I have a name for the reservation?", createdAt: new Date(now.getTime() + 5000).toISOString() },
        { role: "agent", content: `The name is ${reservation.guestName}.`, createdAt: new Date(now.getTime() + 8000).toISOString() },
        { role: "user", content: `Perfect. So that's ${reservation.partySize} guests at ${reservation.time} on ${reservation.date} for ${reservation.guestName}. You're all set!`, createdAt: new Date(now.getTime() + 12000).toISOString() },
        { role: "agent", content: "Thank you so much! Have a great day.", createdAt: new Date(now.getTime() + 15000).toISOString() },
        { role: "user", content: "You too, goodbye!", createdAt: new Date(now.getTime() + 18000).toISOString() },
      ];
    } else {
      return [
        { role: "agent", content: `Hi, I'm calling to make a reservation for ${reservation.partySize} people for ${reservation.time} on ${reservation.date}.`, createdAt: now.toISOString() },
        { role: "user", content: "I'm sorry, we're fully booked at that time. Would 8:30 work instead?", createdAt: new Date(now.getTime() + 5000).toISOString() },
        { role: "agent", content: "Unfortunately that's a bit too late for us. Thank you anyway for checking.", createdAt: new Date(now.getTime() + 8000).toISOString() },
        { role: "user", content: "No problem. Feel free to call back if your plans change!", createdAt: new Date(now.getTime() + 11000).toISOString() },
        { role: "agent", content: "Will do. Have a good day!", createdAt: new Date(now.getTime() + 14000).toISOString() },
      ];
    }
  }

  private mockGetCallStatus(callId: string): AgentPhoneCall {
    const call = mockCallStore.get(callId);
    if (!call) {
      throw new Error(`Mock call not found: ${callId}`);
    }
    return call;
  }

  private mockGetCallTranscript(callId: string): CallTranscript[] {
    const call = mockCallStore.get(callId);
    if (!call) {
      throw new Error(`Mock call not found: ${callId}`);
    }
    return call.transcripts;
  }

  // Utility to analyze call outcome from transcript
  analyzeCallOutcome(transcripts: CallTranscript[], callType: 'reservation' | 'personal' = 'reservation'): { 
    success: boolean; 
    message: string; 
    confirmationDetails?: string;
    recipientReply?: string;
  } {
    const fullText = transcripts.map(t => t.content.toLowerCase()).join(" ");
    
    // Extract the recipient's reply - look for their responses after the message was delivered
    const recipientReply = this.extractRecipientReply(transcripts, callType);
    
    if (callType === 'personal') {
      // For personal calls, check if the message was delivered
      const deliveredIndicators = [
        "got it",
        "thanks",
        "thank you",
        "okay",
        "ok",
        "i'll",
        "i will",
        "sure",
        "understood",
        "message",
      ];
      
      const failedIndicators = [
        "wrong number",
        "don't know",
        "who is this",
        "stop calling",
      ];
      
      const wasDelivered = deliveredIndicators.some(phrase => fullText.includes(phrase));
      const failed = failedIndicators.some(phrase => fullText.includes(phrase));
      
      if (wasDelivered && !failed) {
        // Check if they had a reply
        const hasReply = recipientReply && recipientReply.length > 0;
        return {
          success: true,
          message: hasReply ? "Message delivered! They sent a reply." : "Message delivered successfully!",
          confirmationDetails: transcripts.find(t => t.role === "user")?.content,
          recipientReply,
        };
      } else if (failed) {
        return {
          success: false,
          message: "Could not deliver the message.",
          recipientReply,
        };
      } else {
        // For personal calls, if it completed, assume success
        return {
          success: true,
          message: "Call completed - message delivered.",
          recipientReply,
        };
      }
    }
    
    // Reservation call analysis
    const successIndicators = [
      "you're all set",
      "reservation confirmed",
      "we have you down",
      "see you then",
      "booked",
      "confirmed for",
    ];
    
    const failureIndicators = [
      "fully booked",
      "no availability",
      "sorry, we can't",
      "unfortunately",
      "not available",
    ];

    const isSuccess = successIndicators.some(phrase => fullText.includes(phrase));
    const isFailure = failureIndicators.some(phrase => fullText.includes(phrase));

    if (isSuccess && !isFailure) {
      return {
        success: true,
        message: "Reservation confirmed!",
        confirmationDetails: transcripts.find(t => 
          t.role === "user" && 
          (t.content.toLowerCase().includes("set") || t.content.toLowerCase().includes("confirmed"))
        )?.content,
        recipientReply,
      };
    } else if (isFailure) {
      return {
        success: false,
        message: "Could not complete reservation - restaurant was unavailable at the requested time.",
        recipientReply,
      };
    } else {
      return {
        success: false,
        message: "Call completed but reservation status is unclear. Please call directly to confirm.",
        recipientReply,
      };
    }
  }

  // Extract the meaningful reply from the recipient
  private extractRecipientReply(transcripts: CallTranscript[], callType: 'reservation' | 'personal'): string | undefined {
    if (transcripts.length === 0) return undefined;

    // Get all user (recipient) messages
    const userMessages = transcripts.filter(t => t.role === "user");
    if (userMessages.length === 0) return undefined;

    if (callType === 'personal') {
      // For personal calls, look for a reply message after the agent asks about passing a message back
      // Find the index where agent asks about reply
      const agentAsksReplyIndex = transcripts.findIndex(t => 
        t.role === "agent" && 
        (t.content.toLowerCase().includes("pass any message") || 
         t.content.toLowerCase().includes("like me to tell") ||
         t.content.toLowerCase().includes("want me to pass") ||
         t.content.toLowerCase().includes("message back"))
      );

      if (agentAsksReplyIndex !== -1) {
        // Get user messages after the agent asks about a reply
        const replyMessages = transcripts
          .slice(agentAsksReplyIndex + 1)
          .filter(t => t.role === "user")
          .map(t => t.content);
        
        if (replyMessages.length > 0) {
          return replyMessages.join(" ");
        }
      }

      // Fallback: return the last substantive user message (not just "okay" or "bye")
      const substantiveReplies = userMessages.filter(t => {
        const content = t.content.toLowerCase();
        const trivialResponses = ["okay", "ok", "bye", "goodbye", "thanks", "thank you", "yes", "no", "sure"];
        return !trivialResponses.includes(content.trim());
      });

      if (substantiveReplies.length > 0) {
        return substantiveReplies[substantiveReplies.length - 1].content;
      }
    } else {
      // For reservation calls, extract key info from restaurant's response
      const confirmationMessage = userMessages.find(t => {
        const content = t.content.toLowerCase();
        return content.includes("all set") || 
               content.includes("confirmed") || 
               content.includes("reservation") ||
               content.includes("booked");
      });

      if (confirmationMessage) {
        return confirmationMessage.content;
      }

      // Return the last substantive message from the restaurant
      const lastSubstantive = userMessages
        .filter(t => t.content.length > 20)
        .pop();
      
      return lastSubstantive?.content;
    }

    return undefined;
  }
}

// Singleton instance
let agentPhoneClient: AgentPhoneClient | null = null;

export function getAgentPhoneClient(): AgentPhoneClient {
  if (!agentPhoneClient) {
    agentPhoneClient = new AgentPhoneClient({
      apiKey: process.env.AGENTPHONE_API_KEY || "",
      agentId: process.env.AGENTPHONE_AGENT_ID,
      mockMode: process.env.AGENTPHONE_MOCK === "true" || !process.env.AGENTPHONE_API_KEY,
    });
  }
  return agentPhoneClient;
}
