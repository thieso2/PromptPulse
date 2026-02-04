import Testing
import Foundation
@testable import PromptWatchData
@testable import PromptWatchDomain

@Suite("SessionParser Tests")
struct SessionParserTests {
    @Test("Parse user message from JSONL")
    func testParseUserMessage() throws {
        let jsonl = """
        {"type":"user","message":{"id":"msg_1","role":"user","content":"Hello"}}
        """

        let parser = SessionParser()
        let lines = [Data(jsonl.utf8)]
        let messages = parser.parseLines(lines)

        #expect(messages.count == 1)
        #expect(messages[0].role == .user)
        #expect(messages[0].textContent == "Hello")
    }

    @Test("Parse assistant message with usage")
    func testParseAssistantMessageWithUsage() throws {
        let jsonl = """
        {"type":"assistant","message":{"id":"msg_2","role":"assistant","content":"Hi there!","usage":{"input_tokens":100,"output_tokens":50}}}
        """

        let parser = SessionParser()
        let lines = [Data(jsonl.utf8)]
        let messages = parser.parseLines(lines)

        #expect(messages.count == 1)
        #expect(messages[0].role == .assistant)
        #expect(messages[0].usage.inputTokens == 100)
        #expect(messages[0].usage.outputTokens == 50)
    }

    @Test("Parse multiple messages")
    func testParseMultipleMessages() throws {
        let jsonl = [
            """
            {"type":"user","message":{"id":"1","role":"user","content":"Hello"}}
            """,
            """
            {"type":"assistant","message":{"id":"2","role":"assistant","content":"Hi"}}
            """,
            """
            {"type":"user","message":{"id":"3","role":"user","content":"Bye"}}
            """
        ]

        let parser = SessionParser()
        let lines = jsonl.map { Data($0.utf8) }
        let messages = parser.parseLines(lines)

        #expect(messages.count == 3)
        #expect(messages[0].role == .user)
        #expect(messages[1].role == .assistant)
        #expect(messages[2].role == .user)
    }

    @Test("Skip progress messages")
    func testSkipProgressMessages() throws {
        let jsonl = [
            """
            {"type":"user","message":{"id":"1","role":"user","content":"Hello"}}
            """,
            """
            {"type":"progress","content":"Processing..."}
            """,
            """
            {"type":"assistant","message":{"id":"2","role":"assistant","content":"Done"}}
            """
        ]

        let parser = SessionParser()
        let lines = jsonl.map { Data($0.utf8) }
        let messages = parser.parseLines(lines)

        // Progress messages should be skipped
        #expect(messages.count == 2)
    }

    @Test("Parse content array with text blocks")
    func testParseContentArray() throws {
        let jsonl = """
        {"type":"assistant","message":{"id":"1","role":"assistant","content":[{"type":"text","text":"Hello"},{"type":"text","text":"World"}]}}
        """

        let parser = SessionParser()
        let lines = [Data(jsonl.utf8)]
        let messages = parser.parseLines(lines)

        #expect(messages.count == 1)
        #expect(messages[0].content.count == 2)
    }

    @Test("Parse tool use content block")
    func testParseToolUse() throws {
        let jsonl = """
        {"type":"assistant","message":{"id":"1","role":"assistant","content":[{"type":"tool_use","id":"tool_1","name":"read_file","input":{"path":"test.txt"}}]}}
        """

        let parser = SessionParser()
        let lines = [Data(jsonl.utf8)]
        let messages = parser.parseLines(lines)

        #expect(messages.count == 1)
        #expect(messages[0].content.count == 1)

        if case .toolUse(let id, let name, _) = messages[0].content[0] {
            #expect(id == "tool_1")
            #expect(name == "read_file")
        } else {
            Issue.record("Expected tool_use content block")
        }
    }

    @Test("Parse tool result content block")
    func testParseToolResult() throws {
        let jsonl = """
        {"type":"user","message":{"id":"1","role":"user","content":[{"type":"tool_result","tool_use_id":"tool_1","content":"File contents here","is_error":false}]}}
        """

        let parser = SessionParser()
        let lines = [Data(jsonl.utf8)]
        let messages = parser.parseLines(lines)

        #expect(messages.count == 1)

        if case .toolResult(let toolUseId, let content, let isError) = messages[0].content[0] {
            #expect(toolUseId == "tool_1")
            #expect(content == "File contents here")
            #expect(isError == false)
        } else {
            Issue.record("Expected tool_result content block")
        }
    }

    @Test("Handle malformed JSON gracefully")
    func testHandleMalformedJSON() {
        let jsonl = [
            "not valid json",
            """
            {"type":"user","message":{"id":"1","role":"user","content":"Valid"}}
            """,
            "{incomplete"
        ]

        let parser = SessionParser()
        let lines = jsonl.map { Data($0.utf8) }
        let messages = parser.parseLines(lines)

        // Should only parse the valid line
        #expect(messages.count == 1)
    }
}
