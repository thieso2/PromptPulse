import Foundation

/// Filter criteria for messages
public struct MessageFilter: Sendable, Equatable {
    /// Filter by message role
    public var roles: Set<MessageRole>?

    /// Filter by text content (case-insensitive contains)
    public var textContains: String?

    /// Include tool-related content blocks
    public var includeTools: Bool

    /// Include thinking blocks
    public var includeThinking: Bool

    /// Minimum token count
    public var minTokens: Int?

    /// Maximum token count
    public var maxTokens: Int?

    public init(
        roles: Set<MessageRole>? = nil,
        textContains: String? = nil,
        includeTools: Bool = true,
        includeThinking: Bool = true,
        minTokens: Int? = nil,
        maxTokens: Int? = nil
    ) {
        self.roles = roles
        self.textContains = textContains
        self.includeTools = includeTools
        self.includeThinking = includeThinking
        self.minTokens = minTokens
        self.maxTokens = maxTokens
    }

    /// Default filter that includes everything
    public static let all = MessageFilter()

    /// Filter for user messages only
    public static let userOnly = MessageFilter(roles: [.user])

    /// Filter for assistant messages only
    public static let assistantOnly = MessageFilter(roles: [.assistant])

    /// Filter for conversation (user + assistant) without system messages
    public static let conversation = MessageFilter(roles: [.user, .assistant])

    /// Check if a message matches the filter criteria
    public func matches(_ message: Message) -> Bool {
        // Check role filter
        if let roles = roles, !roles.contains(message.role) {
            return false
        }

        // Check text content filter
        if let searchText = textContains?.lowercased(), !searchText.isEmpty {
            let text = message.textContent.lowercased()
            if !text.contains(searchText) {
                return false
            }
        }

        // Check token count filters
        let tokens = message.usage.totalTokens
        if let min = minTokens, tokens < min {
            return false
        }
        if let max = maxTokens, tokens > max {
            return false
        }

        return true
    }

    /// Filter an array of messages
    public func filter(_ messages: [Message]) -> [Message] {
        messages.filter { matches($0) }
    }

    /// Filter content blocks based on settings
    public func filterContent(_ blocks: [ContentBlock]) -> [ContentBlock] {
        blocks.filter { block in
            switch block {
            case .toolUse, .toolResult:
                return includeTools
            case .thinking:
                return includeThinking
            default:
                return true
            }
        }
    }
}

// MARK: - Builder Pattern

extension MessageFilter {
    /// Create a new filter with role constraint
    public func withRoles(_ roles: Set<MessageRole>) -> MessageFilter {
        var copy = self
        copy.roles = roles
        return copy
    }

    /// Create a new filter with text search
    public func withTextContaining(_ text: String) -> MessageFilter {
        var copy = self
        copy.textContains = text
        return copy
    }

    /// Create a new filter including/excluding tools
    public func withTools(_ include: Bool) -> MessageFilter {
        var copy = self
        copy.includeTools = include
        return copy
    }

    /// Create a new filter including/excluding thinking
    public func withThinking(_ include: Bool) -> MessageFilter {
        var copy = self
        copy.includeThinking = include
        return copy
    }

    /// Create a new filter with token range
    public func withTokenRange(min: Int? = nil, max: Int? = nil) -> MessageFilter {
        var copy = self
        copy.minTokens = min
        copy.maxTokens = max
        return copy
    }
}
