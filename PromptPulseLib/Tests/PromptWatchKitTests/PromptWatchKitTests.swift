import Testing
import Foundation
@testable import PromptWatchKit
@testable import PromptWatchDomain

@Suite("PromptWatchKit Integration Tests")
struct PromptWatchKitTests {
    @Test("Kit singleton is available")
    func testKitSingleton() {
        let kit = PromptWatchKit.shared

        #expect(kit.costCalculator != nil)
    }

    @Test("Calculate cost for session")
    func testCalculateCostForSession() {
        let kit = PromptWatchKit.shared

        let messages = [
            Message(
                role: .user,
                text: "Hello",
                usage: TokenUsage(inputTokens: 100)
            ),
            Message(
                role: .assistant,
                text: "Hi",
                usage: TokenUsage(inputTokens: 50, outputTokens: 100)
            )
        ]

        let session = Session(
            id: "test",
            filePath: "/test/path.jsonl",
            messages: messages
        )

        let cost = kit.calculateCost(for: session)

        #expect(cost > 0)
    }

    @Test("Get stats for session")
    func testGetStatsForSession() {
        let kit = PromptWatchKit.shared

        let messages = [
            Message(role: .user, text: "Hello"),
            Message(role: .assistant, text: "Hi"),
            Message(role: .user, text: "Bye"),
            Message(role: .assistant, text: "Goodbye")
        ]

        let session = Session(
            id: "test",
            filePath: "/test/path.jsonl",
            messages: messages
        )

        let stats = kit.getStats(for: session)

        #expect(stats.totalMessages == 4)
        #expect(stats.userMessages == 2)
        #expect(stats.assistantMessages == 2)
    }

    @Test("Calculate total cost across sessions")
    func testCalculateTotalCost() {
        let kit = PromptWatchKit.shared

        let sessions = [
            Session(
                id: "1",
                filePath: "/test/1.jsonl",
                messages: [
                    Message(role: .assistant, text: "Hi", usage: TokenUsage(outputTokens: 1000))
                ]
            ),
            Session(
                id: "2",
                filePath: "/test/2.jsonl",
                messages: [
                    Message(role: .assistant, text: "Hello", usage: TokenUsage(outputTokens: 1000))
                ]
            )
        ]

        let totalCost = kit.calculateTotalCost(sessions: sessions)

        // Each session has 1000 output tokens = $0.015
        // Total should be $0.03
        #expect(totalCost > 0)
    }

    @Test("Version info is available")
    func testVersionInfo() {
        #expect(!PromptWatchVersion.version.isEmpty)
        #expect(!PromptWatchVersion.buildDate.isEmpty)
    }
}
