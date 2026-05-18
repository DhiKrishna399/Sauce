import Foundation

// MARK: - Request Types
struct AnalyzeRequest: Codable {
    let imageBase64: String
    let query: String
    let mode: String  // "guide" or "action"
    let context: Context?
}

struct Context: Codable {
    let appName: String?
    let pageUrl: String?
}

// MARK: - Response Types
struct GuideResponse: Codable {
    let mode: String
    let answerType: String?  // "howto" or "informational"
    let explanation: String
    let steps: [GuideStep]
    let highlights: [Highlight]
    
    var isHowTo: Bool {
        return answerType == "howto" || (answerType == nil && !steps.isEmpty)
    }
}

struct GuideStep: Codable, Identifiable {
    let step: Int
    let instruction: String
    let elementDescription: String
    
    var id: Int { step }
}

struct Highlight: Codable {
    let type: String  // "circle", "arrow", "box"
    let x: Int
    let y: Int
    let radius: Int?
    let width: Int?
    let height: Int?
    let toX: Int?
    let toY: Int?
    let label: String
    let color: String?
}

// MARK: - Action Response
struct ActionResponse: Codable {
    let mode: String
    let type: String
    let intent: String?
    let requiresConfirmation: Bool?
    let message: String?
    let status: String?
    let callId: String?
    let details: ActionDetails?
    
    enum CodingKeys: String, CodingKey {
        case mode, type, intent, requiresConfirmation, message, status, callId, details
    }
    
    var isEmailAction: Bool {
        return intent == "send_email"
    }
}

// MARK: - Action Details
struct ActionDetails: Codable {
    let messageId: String?
    let recipientEmail: String?
    let subject: String?
    let body: String?
    let purpose: String?
    let timestamp: String?
}

// MARK: - Call Status Response
struct CallStatusResponse: Codable {
    let callId: String
    let status: String
    let message: String
    let success: Bool?
    let transcript: String?
    let recipientReply: String?
    
    var hasReply: Bool {
        return recipientReply != nil && !recipientReply!.isEmpty
    }
}

// MARK: - Conversation History
struct ConversationItem: Identifiable {
    let id: UUID
    let query: String
    let timestamp: Date
    var guideResponse: GuideResponse?
    var actionResponse: ActionResponse?
    var callStatus: CallStatusResponse?
    var isLoading: Bool
    var errorMessage: String?
    
    init(query: String) {
        self.id = UUID()
        self.query = query
        self.timestamp = Date()
        self.guideResponse = nil
        self.actionResponse = nil
        self.callStatus = nil
        self.isLoading = true
        self.errorMessage = nil
    }
}
