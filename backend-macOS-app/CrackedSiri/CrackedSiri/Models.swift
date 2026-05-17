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
    
    enum CodingKeys: String, CodingKey {
        case mode, type, intent, requiresConfirmation, message, status, callId
    }
}

// MARK: - Call Status Response
struct CallStatusResponse: Codable {
    let callId: String
    let status: String
    let message: String
    let success: Bool?
    let transcript: String?
}
