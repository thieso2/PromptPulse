import Foundation

/// Claude API pricing constants
/// Based on Claude API pricing (per 1M tokens)
public struct Pricing: Sendable {
    /// Input tokens: $3 per 1M tokens
    public let inputPerMillion: Decimal

    /// Output tokens: $15 per 1M tokens
    public let outputPerMillion: Decimal

    /// Cache read tokens: $0.30 per 1M tokens
    public let cacheReadPerMillion: Decimal

    /// Cache creation tokens: $3.75 per 1M tokens
    public let cacheCreationPerMillion: Decimal

    public init(
        inputPerMillion: Decimal = 3.0,
        outputPerMillion: Decimal = 15.0,
        cacheReadPerMillion: Decimal = 0.30,
        cacheCreationPerMillion: Decimal = 3.75
    ) {
        self.inputPerMillion = inputPerMillion
        self.outputPerMillion = outputPerMillion
        self.cacheReadPerMillion = cacheReadPerMillion
        self.cacheCreationPerMillion = cacheCreationPerMillion
    }

    /// Default Claude 3.5 Sonnet pricing
    public static let sonnet = Pricing(
        inputPerMillion: 3.0,
        outputPerMillion: 15.0,
        cacheReadPerMillion: 0.30,
        cacheCreationPerMillion: 3.75
    )

    /// Claude 3 Opus pricing
    public static let opus = Pricing(
        inputPerMillion: 15.0,
        outputPerMillion: 75.0,
        cacheReadPerMillion: 1.50,
        cacheCreationPerMillion: 18.75
    )

    /// Claude 3 Haiku pricing
    public static let haiku = Pricing(
        inputPerMillion: 0.25,
        outputPerMillion: 1.25,
        cacheReadPerMillion: 0.03,
        cacheCreationPerMillion: 0.30
    )

    /// Default pricing (Sonnet)
    public static let `default` = sonnet

    /// Resolve pricing tier from a model identifier string
    public static func forModel(_ model: String?) -> Pricing {
        guard let model = model?.lowercased() else { return .default }
        if model.contains("opus") { return .opus }
        if model.contains("haiku") { return .haiku }
        return .sonnet
    }
}
