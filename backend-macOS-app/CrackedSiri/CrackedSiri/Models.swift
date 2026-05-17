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
    let details: [String: AnyCodable]?
    let requiresConfirmation: Bool?
    let message: String?
    let status: String?
    let callId: String?
}

// Helper for nested JSON
enum AnyCodable: Codable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
