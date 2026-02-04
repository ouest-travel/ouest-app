import Foundation

enum ChatMessageType: String, Codable {
    case text
    case expense
    case summary
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let tripId: String
    let userId: String
    let content: String?
    let messageType: ChatMessageType
    let metadata: [String: AnyCodable]?
    let createdAt: Date

    // Optional joined data
    var profile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case userId = "user_id"
        case content
        case messageType = "message_type"
        case metadata
        case createdAt = "created_at"
        case profile = "profiles"
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    // Computed properties
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: createdAt)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(createdAt)
    }

    var dateFormatted: String {
        if isToday {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: createdAt)
    }

    // Extract expense metadata
    var expenseMetadata: ExpenseMessageMetadata? {
        guard messageType == .expense, let metadata = metadata else { return nil }
        return ExpenseMessageMetadata(
            expenseId: metadata["expenseId"]?.value as? String,
            title: metadata["title"]?.value as? String,
            amount: metadata["amount"]?.value as? Double
        )
    }
}

struct ExpenseMessageMetadata {
    let expenseId: String?
    let title: String?
    let amount: Double?
}

// MARK: - Create Message Request

struct CreateChatMessageRequest: Codable {
    let tripId: String
    let userId: String
    let content: String?
    let messageType: ChatMessageType
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case userId = "user_id"
        case content
        case messageType = "message_type"
        case metadata
    }
}

// MARK: - AnyCodable for JSON metadata

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality check for common types
        switch (lhs.value, rhs.value) {
        case (let l as String, let r as String): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Double, let r as Double): return l == r
        case (let l as Bool, let r as Bool): return l == r
        default: return false
        }
    }
}
