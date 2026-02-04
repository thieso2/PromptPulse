import ArgumentParser
import Foundation
import PromptWatchKit
import PromptWatchDomain

/// Inspect a session file
struct InspectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inspect",
        abstract: "Inspect a Claude session file"
    )

    @Argument(help: "Path to the session JSONL file")
    var file: String

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .shortAndLong, help: "Show only summary statistics")
    var summary: Bool = false

    @Option(name: .shortAndLong, help: "Filter messages by role (user, assistant, system)")
    var role: String?

    @Option(name: .shortAndLong, help: "Show specific message by index (1-based)")
    var message: Int?

    @Flag(name: .shortAndLong, help: "Show cost breakdown")
    var cost: Bool = false

    mutating func run() throws {
        let kit = PromptWatchKit.shared

        // Resolve file path
        let filePath: String
        if file.hasPrefix("/") {
            filePath = file
        } else {
            filePath = (FileManager.default.currentDirectoryPath as NSString)
                .appendingPathComponent(file)
        }

        // Check file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw ValidationError("File not found: \(filePath)")
        }

        // Load session synchronously
        let session = runBlocking {
            try await kit.loadSession(filePath: filePath)
        }
        let stats = kit.getStats(for: session)

        // Handle different output modes
        if let messageIndex = message {
            try showMessage(session: session, index: messageIndex)
        } else if summary {
            if json {
                printSummaryJSON(session: session, stats: stats)
            } else {
                printSummary(session: session, stats: stats)
            }
        } else if cost {
            printCostBreakdown(session: session, stats: stats)
        } else if json {
            printFullJSON(session: session, stats: stats)
        } else {
            printFull(session: session, stats: stats)
        }
    }

    private func showMessage(session: Session, index: Int) throws {
        guard index >= 1, index <= session.messages.count else {
            throw ValidationError("Message index out of range. Valid range: 1-\(session.messages.count)")
        }

        let message = session.messages[index - 1]

        print("Message #\(index)")
        print("Role: \(message.role.rawValue)")
        if let timestamp = message.timestamp {
            print("Time: \(formatDateTime(timestamp))")
        }
        print("Tokens: \(message.usage.totalTokens)")
        if let model = message.model {
            print("Model: \(model)")
        }
        print("\n--- Content ---\n")

        for block in message.content {
            printContentBlock(block)
        }
    }

    private func printContentBlock(_ block: ContentBlock) {
        switch block {
        case .text(let text):
            print(text)
            print()

        case .toolUse(let id, let name, let input):
            print("🔧 Tool Use: \(name)")
            print("   ID: \(id)")
            print("   Input: \(input)")
            print()

        case .toolResult(let toolUseId, let content, let isError):
            let status = isError ? "❌ Error" : "✅ Result"
            print("\(status) for tool: \(toolUseId)")
            print(content)
            print()

        case .thinking(let text):
            print("💭 Thinking:")
            print(text)
            print()

        case .image(let mediaType, let data):
            print("🖼️ Image (\(mediaType), \(data.count) bytes)")
            print()
        }
    }

    private func printSummary(session: Session, stats: SessionStats) {
        print("Session: \(session.shortId)")
        print("File: \(session.filePath)")
        if let date = session.lastModified {
            print("Last Modified: \(formatDateTime(date))")
        }
        print()
        print("Messages: \(stats.totalMessages)")
        print("  User: \(stats.userMessages)")
        print("  Assistant: \(stats.assistantMessages)")
        print("  Tool Calls: \(stats.toolCalls)")
        print()
        print("Tokens:")
        print("  Input: \(formatTokens(stats.totalUsage.inputTokens))")
        print("  Output: \(formatTokens(stats.totalUsage.outputTokens))")
        print("  Cache Read: \(formatTokens(stats.totalUsage.cacheReadTokens))")
        print("  Cache Create: \(formatTokens(stats.totalUsage.cacheCreationTokens))")
        print("  Total: \(formatTokens(stats.totalUsage.totalTokens))")
        print()
        print("Estimated Cost: \(stats.formattedCost)")
        if let duration = stats.formattedDuration {
            print("Duration: \(duration)")
        }
    }

    private func printFull(session: Session, stats: SessionStats) {
        printSummary(session: session, stats: stats)
        print("\n--- Messages ---\n")

        var filteredMessages = session.messages
        if let roleFilter = role {
            filteredMessages = session.messages.filter {
                $0.role.rawValue.lowercased() == roleFilter.lowercased()
            }
        }

        for (index, message) in filteredMessages.enumerated() {
            let roleIcon: String
            switch message.role {
            case .user: roleIcon = "👤"
            case .assistant: roleIcon = "🤖"
            case .system: roleIcon = "⚙️"
            }

            let tokens = formatTokens(message.usage.totalTokens)
            print("#\(index + 1) \(roleIcon) \(message.role.rawValue) [\(tokens) tokens]")

            let preview = message.preview.replacingOccurrences(of: "\n", with: " ")
            if preview.count > 100 {
                print("   \(String(preview.prefix(100)))...")
            } else {
                print("   \(preview)")
            }
            print()
        }
    }

    private func printCostBreakdown(session: Session, stats: SessionStats) {
        print("Cost Breakdown for Session: \(session.shortId)\n")

        let inputCost = Decimal(stats.totalUsage.inputTokens) / 1_000_000 * 3.0
        let outputCost = Decimal(stats.totalUsage.outputTokens) / 1_000_000 * 15.0
        let cacheReadCost = Decimal(stats.totalUsage.cacheReadTokens) / 1_000_000 * 0.30
        let cacheCreateCost = Decimal(stats.totalUsage.cacheCreationTokens) / 1_000_000 * 3.75

        // Use string interpolation and padding instead of String(format:) with %s
        let categoryCol = "Category".padding(toLength: 20, withPad: " ", startingAt: 0)
        let tokensCol = "Tokens".padding(toLength: 12, withPad: " ", startingAt: 0)
        let rateCol = "Rate/1M".padding(toLength: 10, withPad: " ", startingAt: 0)
        let costCol = "Cost".padding(toLength: 12, withPad: " ", startingAt: 0)
        print("\(categoryCol)  \(tokensCol)  \(rateCol)  \(costCol)")
        print(String(repeating: "-", count: 60))

        printCostRow("Input", formatTokens(stats.totalUsage.inputTokens), "$3.00", formatCost(inputCost))
        printCostRow("Output", formatTokens(stats.totalUsage.outputTokens), "$15.00", formatCost(outputCost))
        printCostRow("Cache Read", formatTokens(stats.totalUsage.cacheReadTokens), "$0.30", formatCost(cacheReadCost))
        printCostRow("Cache Create", formatTokens(stats.totalUsage.cacheCreationTokens), "$3.75", formatCost(cacheCreateCost))
        print(String(repeating: "-", count: 60))
        printCostRow("TOTAL", formatTokens(stats.totalUsage.totalTokens), "", stats.formattedCost)
    }

    private func printCostRow(_ category: String, _ tokens: String, _ rate: String, _ cost: String) {
        let categoryCol = category.padding(toLength: 20, withPad: " ", startingAt: 0)
        let tokensCol = tokens.padding(toLength: 12, withPad: " ", startingAt: 0)
        let rateCol = rate.padding(toLength: 10, withPad: " ", startingAt: 0)
        let costCol = cost.padding(toLength: 12, withPad: " ", startingAt: 0)
        print("\(categoryCol)  \(tokensCol)  \(rateCol)  \(costCol)")
    }

    private func printSummaryJSON(session: Session, stats: SessionStats) {
        let data: [String: Any] = [
            "sessionId": session.id,
            "filePath": session.filePath,
            "lastModified": session.lastModified?.iso8601String ?? NSNull(),
            "messages": [
                "total": stats.totalMessages,
                "user": stats.userMessages,
                "assistant": stats.assistantMessages,
                "toolCalls": stats.toolCalls
            ],
            "tokens": [
                "input": stats.totalUsage.inputTokens,
                "output": stats.totalUsage.outputTokens,
                "cacheRead": stats.totalUsage.cacheReadTokens,
                "cacheCreate": stats.totalUsage.cacheCreationTokens,
                "total": stats.totalUsage.totalTokens
            ],
            "estimatedCostUSD": NSDecimalNumber(decimal: stats.estimatedCost).doubleValue
        ]

        printJSON(data)
    }

    private func printFullJSON(session: Session, stats: SessionStats) {
        let messagesData: [[String: Any]] = session.messages.map { message in
            [
                "id": message.id,
                "role": message.role.rawValue,
                "timestamp": message.timestamp?.iso8601String ?? NSNull(),
                "tokens": [
                    "input": message.usage.inputTokens,
                    "output": message.usage.outputTokens,
                    "total": message.usage.totalTokens
                ],
                "preview": message.preview
            ]
        }

        let data: [String: Any] = [
            "sessionId": session.id,
            "filePath": session.filePath,
            "lastModified": session.lastModified?.iso8601String ?? NSNull(),
            "stats": [
                "totalMessages": stats.totalMessages,
                "userMessages": stats.userMessages,
                "assistantMessages": stats.assistantMessages,
                "toolCalls": stats.toolCalls,
                "totalTokens": stats.totalUsage.totalTokens,
                "estimatedCostUSD": NSDecimalNumber(decimal: stats.estimatedCost).doubleValue
            ],
            "messages": messagesData
        ]

        printJSON(data)
    }

    private func printJSON(_ data: Any) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTokens(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 1_000_000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        }
    }

    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: cost as NSDecimalNumber) ?? "$0.0000"
    }
}
