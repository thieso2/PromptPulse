import SwiftUI
import AppKit
import PromptWatchKit

// MARK: - Shared Formatting Utilities

enum Formatters {
    /// Format token count as compact string (e.g., "1.2K", "3.4M")
    static func tokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }

    /// Format a time interval as compact duration (e.g., "2h 15m", "3m 42s")
    static func duration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    /// Format uptime from a start date to now
    static func uptime(from startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Format CPU percentage
    static func cpu(_ percent: Double) -> String {
        if percent > 99.9 { return ">99%" }
        return String(format: "%.1f%%", percent)
    }

    /// Format memory in MB
    static func memory(_ megabytes: Double) -> String {
        if megabytes > 1024 {
            return String(format: "%.1fG", megabytes / 1024)
        }
        return String(format: "%.0fM", megabytes)
    }

    /// Cached date formatter for short date + time
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Cached date formatter for time only
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Message Role Styling

extension MessageRole {
    var icon: String {
        switch self {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .system: return "gear"
        }
    }

    var color: Color {
        switch self {
        case .user: return .blue
        case .assistant: return .purple
        case .system: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .user: return "You"
        case .assistant: return "Claude"
        case .system: return "System"
        }
    }
}

// MARK: - CPU Load Color

extension View {
    func cpuColor(for percent: Double) -> Color {
        if percent >= 50 { return .red }
        if percent >= 20 { return .orange }
        if percent >= 5 { return .yellow }
        return .secondary
    }
}

// MARK: - Markdown Export

@MainActor
enum MarkdownExporter {
    /// Export a session to markdown via NSSavePanel
    static func export(session: Session) {
        let markdown = render(session: session)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.nameFieldStringValue = "session-\(session.shortId).md"
        panel.title = "Export Session"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Render a session as a markdown string
    static func render(session: Session) -> String {
        var lines: [String] = []

        // Header
        lines.append("# Claude Session \(session.shortId)")
        lines.append("")

        if let start = session.startTime {
            lines.append("**Date:** \(Formatters.dateTimeFormatter.string(from: start))")
        }
        if let duration = session.duration {
            lines.append("**Duration:** \(Formatters.duration(duration))")
        }

        let usage = session.totalUsage
        if usage.totalTokens > 0 {
            lines.append("**Tokens:** \(Formatters.tokens(usage.inputTokens)) in / \(Formatters.tokens(usage.outputTokens)) out")
        }

        let cost = CostCalculator.calculateForSession(session)
        if cost > 0 {
            lines.append("**Cost:** \(CostCalculator.format(cost: cost))")
        }

        lines.append("")
        lines.append("---")
        lines.append("")

        // Messages
        for message in session.messages {
            let role = message.role.displayName
            let timestamp = message.timestamp.map { Formatters.timeFormatter.string(from: $0) } ?? ""
            let header = timestamp.isEmpty ? "## \(role)" : "## \(role) (\(timestamp))"
            lines.append(header)
            lines.append("")

            for block in message.content {
                switch block {
                case .text(let text):
                    lines.append(text)
                    lines.append("")

                case .thinking(let text):
                    lines.append("<details>")
                    lines.append("<summary>Thinking</summary>")
                    lines.append("")
                    lines.append(text)
                    lines.append("")
                    lines.append("</details>")
                    lines.append("")

                case .toolUse(_, let name, let input):
                    lines.append("**Tool:** `\(name)`")
                    if !input.isEmpty {
                        lines.append("```")
                        lines.append(input)
                        lines.append("```")
                    }
                    lines.append("")

                case .toolResult(_, let content, let isError):
                    let label = isError ? "Error" : "Result"
                    lines.append("**\(label):**")
                    lines.append("```")
                    lines.append(content)
                    lines.append("```")
                    lines.append("")

                case .image(let mediaType, _):
                    lines.append("*[Image: \(mediaType)]*")
                    lines.append("")
                }
            }

            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
