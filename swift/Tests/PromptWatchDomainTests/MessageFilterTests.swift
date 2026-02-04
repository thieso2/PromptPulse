import Testing
import Foundation
@testable import PromptWatchDomain

@Suite("MessageFilter Tests")
struct MessageFilterTests {
    @Test("Default filter matches all messages")
    func testDefaultFilterMatchesAll() {
        let filter = MessageFilter.all

        let userMsg = Message(role: .user, text: "Hello")
        let assistantMsg = Message(role: .assistant, text: "Hi there")
        let systemMsg = Message(role: .system, text: "System message")

        #expect(filter.matches(userMsg))
        #expect(filter.matches(assistantMsg))
        #expect(filter.matches(systemMsg))
    }

    @Test("Role filter works correctly")
    func testRoleFilter() {
        let userFilter = MessageFilter.userOnly
        let assistantFilter = MessageFilter.assistantOnly

        let userMsg = Message(role: .user, text: "Hello")
        let assistantMsg = Message(role: .assistant, text: "Hi there")

        #expect(userFilter.matches(userMsg))
        #expect(!userFilter.matches(assistantMsg))

        #expect(!assistantFilter.matches(userMsg))
        #expect(assistantFilter.matches(assistantMsg))
    }

    @Test("Text contains filter works")
    func testTextContainsFilter() {
        let filter = MessageFilter(textContains: "hello")

        let matchingMsg = Message(role: .user, text: "Hello world")
        let nonMatchingMsg = Message(role: .user, text: "Goodbye")

        #expect(filter.matches(matchingMsg))
        #expect(!filter.matches(nonMatchingMsg))
    }

    @Test("Text contains filter is case insensitive")
    func testTextContainsCaseInsensitive() {
        let filter = MessageFilter(textContains: "HELLO")

        let msg = Message(role: .user, text: "hello world")

        #expect(filter.matches(msg))
    }

    @Test("Builder pattern works")
    func testBuilderPattern() {
        let filter = MessageFilter.all
            .withRoles([.user, .assistant])
            .withTextContaining("test")
            .withTokenRange(min: 10, max: 1000)

        #expect(filter.roles == [.user, .assistant])
        #expect(filter.textContains == "test")
        #expect(filter.minTokens == 10)
        #expect(filter.maxTokens == 1000)
    }

    @Test("Filter array of messages")
    func testFilterArray() {
        let messages = [
            Message(role: .user, text: "Hello"),
            Message(role: .assistant, text: "Hi"),
            Message(role: .user, text: "Bye"),
            Message(role: .system, text: "System")
        ]

        let filter = MessageFilter.userOnly
        let filtered = filter.filter(messages)

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.role == .user })
    }

    @Test("Conversation filter excludes system messages")
    func testConversationFilter() {
        let filter = MessageFilter.conversation

        let userMsg = Message(role: .user, text: "Hello")
        let assistantMsg = Message(role: .assistant, text: "Hi")
        let systemMsg = Message(role: .system, text: "System")

        #expect(filter.matches(userMsg))
        #expect(filter.matches(assistantMsg))
        #expect(!filter.matches(systemMsg))
    }
}
