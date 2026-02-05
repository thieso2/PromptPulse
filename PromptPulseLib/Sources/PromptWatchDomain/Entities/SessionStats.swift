import Foundation

/// Computed statistics for a session
public struct SessionStats: Sendable, Equatable {
    public let totalMessages: Int
    public let userMessages: Int
    public let assistantMessages: Int
    public let toolCalls: Int
    public let totalUsage: TokenUsage
    public let estimatedCost: Decimal
    public let duration: TimeInterval?

    public init(
        totalMessages: Int = 0,
        userMessages: Int = 0,
        assistantMessages: Int = 0,
        toolCalls: Int = 0,
        totalUsage: TokenUsage = .zero,
        estimatedCost: Decimal = 0,
        duration: TimeInterval? = nil
    ) {
        self.totalMessages = totalMessages
        self.userMessages = userMessages
        self.assistantMessages = assistantMessages
        self.toolCalls = toolCalls
        self.totalUsage = totalUsage
        self.estimatedCost = estimatedCost
        self.duration = duration
    }

    /// Calculate stats from a session (uses model-aware per-message pricing)
    public static func from(session: Session, using calculator: CostCalculator) -> SessionStats {
        var toolCalls = 0

        for message in session.messages {
            for content in message.content {
                if case .toolUse = content {
                    toolCalls += 1
                }
            }
        }

        let totalUsage = session.totalUsage
        let cost = CostCalculator.calculateForSession(session)

        return SessionStats(
            totalMessages: session.messages.count,
            userMessages: session.userMessageCount,
            assistantMessages: session.assistantMessageCount,
            toolCalls: toolCalls,
            totalUsage: totalUsage,
            estimatedCost: cost,
            duration: session.duration
        )
    }

    /// Formatted duration string
    public var formattedDuration: String? {
        guard let duration = duration else { return nil }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Formatted cost string
    public var formattedCost: String {
        CostCalculator.format(cost: estimatedCost)
    }
}
