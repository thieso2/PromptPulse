import Foundation

/// Role of a message participant
public enum MessageRole: String, Sendable, Codable, Equatable {
    case user
    case assistant
    case system
}

/// Content block within a message
public enum ContentBlock: Sendable, Equatable {
    case text(String)
    case toolUse(id: String, name: String, input: String)
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case thinking(String)
    case image(mediaType: String, data: Data)

    public var textContent: String? {
        switch self {
        case .text(let text): return text
        case .thinking(let text): return text
        case .toolResult(_, let content, _): return content
        default: return nil
        }
    }

    public var isToolRelated: Bool {
        switch self {
        case .toolUse, .toolResult: return true
        default: return false
        }
    }
}

/// Token usage statistics
public struct TokenUsage: Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheCreationTokens: Int

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    public static let zero = TokenUsage()

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
            cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens
        )
    }
}

/// A single message in a Claude conversation
public struct Message: Identifiable, Sendable, Equatable {
    public let id: String
    public let role: MessageRole
    public let content: [ContentBlock]
    public let timestamp: Date?
    public let usage: TokenUsage
    public let model: String?
    public let stopReason: String?

    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: [ContentBlock],
        timestamp: Date? = nil,
        usage: TokenUsage = .zero,
        model: String? = nil,
        stopReason: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.usage = usage
        self.model = model
        self.stopReason = stopReason
    }

    /// Convenience initializer for simple text messages
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        text: String,
        timestamp: Date? = nil,
        usage: TokenUsage = .zero
    ) {
        self.init(
            id: id,
            role: role,
            content: [.text(text)],
            timestamp: timestamp,
            usage: usage
        )
    }

    /// Returns all text content concatenated
    public var textContent: String {
        content.compactMap(\.textContent).joined(separator: "\n")
    }

    /// Returns a preview of the message (first 100 chars)
    public var preview: String {
        let text = textContent
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(100)) + "..."
    }
}

/// Message type from JSONL entries
public enum MessageType: String, Sendable {
    case user
    case assistant
    case progress
    case system
    case result
    case summary
    case unknown
}
