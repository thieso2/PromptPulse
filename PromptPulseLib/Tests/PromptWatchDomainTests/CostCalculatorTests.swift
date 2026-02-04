import Testing
import Foundation
@testable import PromptWatchDomain

@Suite("CostCalculator Tests")
struct CostCalculatorTests {
    @Test("Calculate cost for zero usage")
    func testZeroUsage() {
        let calculator = CostCalculator()
        let usage = TokenUsage()
        let cost = calculator.calculate(usage: usage)

        #expect(cost == 0)
    }

    @Test("Calculate cost for input tokens only")
    func testInputTokensOnly() {
        let calculator = CostCalculator()
        let usage = TokenUsage(inputTokens: 1_000_000)
        let cost = calculator.calculate(usage: usage)

        // $3 per 1M input tokens
        #expect(cost == 3.0)
    }

    @Test("Calculate cost for output tokens only")
    func testOutputTokensOnly() {
        let calculator = CostCalculator()
        let usage = TokenUsage(outputTokens: 1_000_000)
        let cost = calculator.calculate(usage: usage)

        // $15 per 1M output tokens
        #expect(cost == 15.0)
    }

    @Test("Calculate cost for cache read tokens")
    func testCacheReadTokens() {
        let calculator = CostCalculator()
        let usage = TokenUsage(cacheReadTokens: 1_000_000)
        let cost = calculator.calculate(usage: usage)

        // $0.30 per 1M cache read tokens
        #expect(cost == 0.30)
    }

    @Test("Calculate cost for cache creation tokens")
    func testCacheCreationTokens() {
        let calculator = CostCalculator()
        let usage = TokenUsage(cacheCreationTokens: 1_000_000)
        let cost = calculator.calculate(usage: usage)

        // $3.75 per 1M cache creation tokens
        #expect(cost == 3.75)
    }

    @Test("Calculate cost for mixed usage")
    func testMixedUsage() {
        let calculator = CostCalculator()
        let usage = TokenUsage(
            inputTokens: 500_000,
            outputTokens: 100_000,
            cacheReadTokens: 200_000,
            cacheCreationTokens: 50_000
        )
        let cost = calculator.calculate(usage: usage)

        // 0.5M * $3 + 0.1M * $15 + 0.2M * $0.30 + 0.05M * $3.75
        // = $1.50 + $1.50 + $0.06 + $0.1875 = $3.2475
        let expected: Decimal = 1.50 + 1.50 + 0.06 + 0.1875
        #expect(cost == expected)
    }

    @Test("Format cost as currency string")
    func testFormatCost() {
        let formatted = CostCalculator.format(cost: 3.2475)
        // Format varies by locale, but should contain the digits
        #expect(formatted.contains("3") && formatted.contains("2") && formatted.contains("4") && formatted.contains("7") && formatted.contains("5"))
    }

    @Test("Opus pricing is more expensive")
    func testOpusPricing() {
        let sonnetCalc = CostCalculator(pricing: .sonnet)
        let opusCalc = CostCalculator(pricing: .opus)

        let usage = TokenUsage(inputTokens: 1_000_000)

        let sonnetCost = sonnetCalc.calculate(usage: usage)
        let opusCost = opusCalc.calculate(usage: usage)

        #expect(opusCost > sonnetCost)
        #expect(opusCost == 15.0)  // $15 per 1M for Opus
        #expect(sonnetCost == 3.0)  // $3 per 1M for Sonnet
    }
}
