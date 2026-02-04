import XCTest
import PromptWatchKit
@testable import PromptPulse

final class PromptPulseTests: XCTestCase {

    func testTokenUsageZero() {
        let usage = TokenUsage.zero
        XCTAssertEqual(usage.inputTokens, 0)
        XCTAssertEqual(usage.outputTokens, 0)
        XCTAssertEqual(usage.totalTokens, 0)
    }

    func testTokenUsageAddition() {
        let usage1 = TokenUsage(
            inputTokens: 100,
            outputTokens: 50,
            cacheReadTokens: 10,
            cacheCreationTokens: 5
        )

        let usage2 = TokenUsage(
            inputTokens: 200,
            outputTokens: 100,
            cacheReadTokens: 20,
            cacheCreationTokens: 10
        )

        let total = usage1 + usage2

        XCTAssertEqual(total.inputTokens, 300)
        XCTAssertEqual(total.outputTokens, 150)
        XCTAssertEqual(total.cacheReadTokens, 30)
        XCTAssertEqual(total.cacheCreationTokens, 15)
    }

    func testClaudeProcessBasicProperties() {
        let process = ClaudeProcess(
            id: 12345,
            name: "claude",
            workingDirectory: "/Users/test/Projects/myproject",
            cpuPercent: 45.7,
            memoryMB: 256.5,
            parentPID: 1234,
            startTime: Date(),
            isHelper: false
        )

        XCTAssertEqual(process.id, 12345)
        XCTAssertEqual(process.name, "claude")
        XCTAssertEqual(process.workingDirectory, "/Users/test/Projects/myproject")
        XCTAssertFalse(process.isHelper)
    }

    func testProjectDirEncoding() {
        let encoded = ProjectDir.encode(path: "/Users/test/Projects/myapp")
        // Leading "/" becomes "-", so result starts with "-"
        XCTAssertEqual(encoded, "-Users-test-Projects-myapp")
        XCTAssertFalse(encoded.contains("/"))
    }

    func testProjectDirDecoding() {
        let encoded = "-Users-test-Projects-myapp"
        let decoded = ProjectDir.decode(encodedName: encoded)
        // The decode function returns the full path with leading "/"
        XCTAssertEqual(decoded, "/Users/test/Projects/myapp")
    }

    func testSessionSummaryShortId() {
        let summary = SessionSummary(
            id: "12345678-abcd-efgh-ijkl-mnopqrstuvwx",
            filePath: "/path/to/session.jsonl",
            projectPath: "/Users/test/project",
            lastModified: Date(),
            fileSize: 1024
        )

        XCTAssertEqual(summary.shortId, "12345678")
    }

    func testMessageTextContent() {
        let message = Message(
            role: .user,
            text: "Hello, world!"
        )

        XCTAssertEqual(message.textContent, "Hello, world!")
        XCTAssertEqual(message.role, .user)
    }

    func testMessagePreview() {
        let longText = String(repeating: "a", count: 150)
        let message = Message(
            role: .assistant,
            text: longText
        )

        XCTAssertTrue(message.preview.count <= 103) // 100 chars + "..."
        XCTAssertTrue(message.preview.hasSuffix("..."))
    }
}
