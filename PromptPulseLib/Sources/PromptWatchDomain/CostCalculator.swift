import Foundation

/// Calculator for estimating Claude API costs from token usage
public struct CostCalculator: Sendable {
    public let pricing: Pricing

    public init(pricing: Pricing = .default) {
        self.pricing = pricing
    }

    /// Calculate cost from token usage
    public func calculate(usage: TokenUsage) -> Decimal {
        let million: Decimal = 1_000_000

        let inputCost = Decimal(usage.inputTokens) / million * pricing.inputPerMillion
        let outputCost = Decimal(usage.outputTokens) / million * pricing.outputPerMillion
        let cacheReadCost = Decimal(usage.cacheReadTokens) / million * pricing.cacheReadPerMillion
        let cacheCreationCost = Decimal(usage.cacheCreationTokens) / million * pricing.cacheCreationPerMillion

        return inputCost + outputCost + cacheReadCost + cacheCreationCost
    }

    /// Calculate cost from individual token counts
    public func calculate(
        inputTokens: Int,
        outputTokens: Int,
        cacheReadTokens: Int = 0,
        cacheCreationTokens: Int = 0
    ) -> Decimal {
        let usage = TokenUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens
        )
        return calculate(usage: usage)
    }

    /// Cached currency formatter for cost display
    private static let costFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    /// Format a cost as a currency string
    public static func format(cost: Decimal) -> String {
        costFormatter.string(from: cost as NSDecimalNumber) ?? "$0.0000"
    }
}

extension CostCalculator {
    /// Shared default calculator instance
    public static let shared = CostCalculator()

    /// Calculate cost for a single message using its model-specific pricing
    public static func calculateForMessage(_ message: Message) -> Decimal {
        let pricing = Pricing.forModel(message.model)
        let calculator = CostCalculator(pricing: pricing)
        return calculator.calculate(usage: message.usage)
    }

    /// Calculate total cost across messages using per-message model-aware pricing
    public static func calculatePerMessage(messages: [Message]) -> Decimal {
        messages.reduce(Decimal.zero) { total, message in
            total + calculateForMessage(message)
        }
    }

    /// Calculate total cost for a session using per-message model-aware pricing
    public static func calculateForSession(_ session: Session) -> Decimal {
        calculatePerMessage(messages: session.messages)
    }
}
