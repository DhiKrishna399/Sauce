import { AgentMailClient } from "agentmail";
import { logger } from "./logger";
import {
  AgentMailConfig,
  EmailIntent,
  EmailSendResult,
  EmailMessage,
} from "./types";

// In-memory store for mock emails (for testing)
const mockEmailStore: Map<string, EmailSendResult & { email: EmailIntent }> = new Map();

export class AgentMailWrapper {
  private client: AgentMailClient | null;
  private inboxId: string | null;
  private mockMode: boolean;

  constructor(config: AgentMailConfig) {
    this.inboxId = config.inboxId || null;
    this.mockMode = config.mockMode;

    if (this.mockMode) {
      this.client = null;
      logger.info("AgentMail client initialized in MOCK mode");
    } else {
      this.client = new AgentMailClient({
        apiKey: config.apiKey,
      });
      logger.info("AgentMail client initialized", { 
        hasApiKey: !!config.apiKey, 
        hasInboxId: !!this.inboxId 
      });
    }
  }

  async ensureInbox(): Promise<string> {
    if (this.inboxId) {
      return this.inboxId;
    }

    if (this.mockMode) {
      this.inboxId = "inbox_mock_" + Date.now().toString(36);
      logger.info("[MOCK] Created mock inbox", { inboxId: this.inboxId });
      return this.inboxId;
    }

    if (!this.client) {
      throw new Error("AgentMail client not initialized");
    }

    const inbox = await this.client.inboxes.create({
      clientId: "guidebot-inbox-v1",
    });
    
    this.inboxId = inbox.inboxId;
    logger.info("Created new AgentMail inbox", { inboxId: this.inboxId });
    
    return this.inboxId;
  }

  async sendEmail(email: EmailIntent, requestId?: string): Promise<EmailSendResult> {
    if (this.mockMode) {
      return this.mockSendEmail(email, requestId);
    }

    const inboxId = await this.ensureInbox();

    if (!this.client) {
      throw new Error("AgentMail client not initialized");
    }

    logger.info("Sending email", { 
      requestId, 
      to: email.recipientEmail,
      subject: email.subject.substring(0, 50),
      purpose: email.purpose,
    });

    try {
      const result = await this.client.inboxes.messages.send(inboxId, {
        to: email.recipientEmail,
        subject: email.subject,
        text: email.body,
        html: email.htmlBody,
      });

      logger.info("Email sent successfully", { 
        requestId, 
        messageId: result.messageId,
        to: email.recipientEmail,
      });

      return {
        messageId: result.messageId,
        status: "sent",
        timestamp: new Date().toISOString(),
        recipientEmail: email.recipientEmail,
        subject: email.subject,
      };
    } catch (error) {
      logger.error("Failed to send email", error, { requestId });
      throw error;
    }
  }

  async sendConfirmationEmail(
    recipientEmail: string,
    reservationDetails: {
      restaurantName: string;
      date: string;
      time: string;
      partySize: number;
      guestName: string;
    },
    requestId?: string
  ): Promise<EmailSendResult> {
    const email: EmailIntent = {
      recipientEmail,
      subject: `Reservation Confirmed at ${reservationDetails.restaurantName}`,
      body: this.buildConfirmationText(reservationDetails),
      htmlBody: this.buildConfirmationHtml(reservationDetails),
      purpose: "confirmation",
    };

    return this.sendEmail(email, requestId);
  }

  async sendInquiryEmail(
    recipientEmail: string,
    businessName: string,
    inquiryMessage: string,
    senderName: string,
    requestId?: string
  ): Promise<EmailSendResult> {
    const email: EmailIntent = {
      recipientEmail,
      subject: `Inquiry about ${businessName}`,
      body: `Hello,\n\n${inquiryMessage}\n\nBest regards,\n${senderName}`,
      htmlBody: `<p>Hello,</p><p>${inquiryMessage}</p><p>Best regards,<br>${senderName}</p>`,
      purpose: "inquiry",
    };

    return this.sendEmail(email, requestId);
  }

  async sendFollowUpEmail(
    recipientEmail: string,
    context: string,
    message: string,
    senderName: string,
    requestId?: string
  ): Promise<EmailSendResult> {
    const email: EmailIntent = {
      recipientEmail,
      subject: `Follow-up: ${context}`,
      body: `Hello,\n\n${message}\n\nBest regards,\n${senderName}`,
      htmlBody: `<p>Hello,</p><p>${message}</p><p>Best regards,<br>${senderName}</p>`,
      purpose: "follow_up",
    };

    return this.sendEmail(email, requestId);
  }

  async getInboxMessages(limit: number = 10, requestId?: string): Promise<EmailMessage[]> {
    if (this.mockMode) {
      return this.mockGetInboxMessages(limit);
    }

    const inboxId = await this.ensureInbox();

    if (!this.client) {
      throw new Error("AgentMail client not initialized");
    }

    logger.info("Fetching inbox messages", { requestId, inboxId, limit });

    const response = await this.client.inboxes.messages.list(inboxId, { limit });
    
    return response.messages.map(msg => {
      // Handle 'to' field which can be string or object
      let toAddress = "";
      if (typeof msg.to === "string") {
        toAddress = msg.to;
      } else if (msg.to && typeof msg.to === "object") {
        toAddress = (msg.to as any).email || (msg.to as any).address || JSON.stringify(msg.to);
      }
      
      return {
        messageId: msg.messageId,
        from: msg.from || "",
        to: toAddress,
        subject: msg.subject || "",
        text: (msg as any).extractedText || (msg as any).text || (msg as any).body || "",
        html: (msg as any).extractedHtml || (msg as any).html,
        receivedAt: String(msg.createdAt || new Date().toISOString()),
      };
    });
  }

  private buildConfirmationText(details: {
    restaurantName: string;
    date: string;
    time: string;
    partySize: number;
    guestName: string;
  }): string {
    return `Hello ${details.guestName},

Your reservation has been confirmed!

Restaurant: ${details.restaurantName}
Date: ${details.date}
Time: ${details.time}
Party Size: ${details.partySize} ${details.partySize === 1 ? 'guest' : 'guests'}

We look forward to seeing you!

If you need to make any changes, please contact the restaurant directly.

Best regards,
Guidebot Assistant`;
  }

  private buildConfirmationHtml(details: {
    restaurantName: string;
    date: string;
    time: string;
    partySize: number;
    guestName: string;
  }): string {
    return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #4F46E5; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
    .content { background: #f9fafb; padding: 20px; border-radius: 0 0 8px 8px; }
    .details { background: white; padding: 15px; border-radius: 8px; margin: 15px 0; }
    .detail-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
    .detail-row:last-child { border-bottom: none; }
    .label { color: #666; }
    .value { font-weight: 600; }
    .footer { text-align: center; color: #888; font-size: 12px; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0;">Reservation Confirmed!</h1>
    </div>
    <div class="content">
      <p>Hello ${details.guestName},</p>
      <p>Great news! Your reservation has been confirmed.</p>
      
      <div class="details">
        <div class="detail-row">
          <span class="label">Restaurant</span>
          <span class="value">${details.restaurantName}</span>
        </div>
        <div class="detail-row">
          <span class="label">Date</span>
          <span class="value">${details.date}</span>
        </div>
        <div class="detail-row">
          <span class="label">Time</span>
          <span class="value">${details.time}</span>
        </div>
        <div class="detail-row">
          <span class="label">Party Size</span>
          <span class="value">${details.partySize} ${details.partySize === 1 ? 'guest' : 'guests'}</span>
        </div>
      </div>
      
      <p>We look forward to seeing you!</p>
      <p style="color: #666; font-size: 14px;">If you need to make any changes, please contact the restaurant directly.</p>
      
      <div class="footer">
        <p>Sent by Guidebot Assistant</p>
      </div>
    </div>
  </div>
</body>
</html>`;
  }

  // ==================== MOCK METHODS ====================

  private mockSendEmail(email: EmailIntent, requestId?: string): EmailSendResult {
    const messageId = "msg_mock_" + Date.now().toString(36);
    
    const result: EmailSendResult = {
      messageId,
      status: "sent",
      timestamp: new Date().toISOString(),
      recipientEmail: email.recipientEmail,
      subject: email.subject,
    };

    mockEmailStore.set(messageId, { ...result, email });
    
    logger.info("[MOCK] Email sent", { 
      requestId, 
      messageId, 
      to: email.recipientEmail,
      subject: email.subject.substring(0, 50),
    });

    return result;
  }

  private mockGetInboxMessages(limit: number): EmailMessage[] {
    const messages: EmailMessage[] = [
      {
        messageId: "msg_mock_sample1",
        from: "restaurant@example.com",
        to: "guidebot@agentmail.to",
        subject: "Re: Reservation Inquiry",
        text: "Thank you for reaching out! We'd be happy to accommodate your party.",
        receivedAt: new Date(Date.now() - 3600000).toISOString(),
      },
    ];
    
    return messages.slice(0, limit);
  }
}

// Singleton instance
let agentMailClient: AgentMailWrapper | null = null;

export function getAgentMailClient(): AgentMailWrapper {
  if (!agentMailClient) {
    agentMailClient = new AgentMailWrapper({
      apiKey: process.env.AGENTMAIL_API_KEY || "",
      inboxId: process.env.AGENTMAIL_INBOX_ID,
      mockMode: process.env.AGENTMAIL_MOCK === "true" || !process.env.AGENTMAIL_API_KEY,
    });
  }
  return agentMailClient;
}
