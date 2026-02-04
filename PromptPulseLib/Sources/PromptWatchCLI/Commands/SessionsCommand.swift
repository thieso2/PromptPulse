import ArgumentParser
import Foundation
import PromptWatchKit
import PromptWatchDomain

/// List sessions for a project directory
struct SessionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sessions",
        abstract: "List sessions for a project directory"
    )

    @Argument(help: "Project directory path")
    var directory: String = "."

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .shortAndLong, help: "Show all projects instead of a specific directory")
    var all: Bool = false

    @Option(name: .shortAndLong, help: "Limit number of sessions shown")
    var limit: Int?

    mutating func run() throws {
        let kit = PromptWatchKit.shared

        if all {
            listAllProjects(kit: kit)
        } else {
            listSessions(kit: kit)
        }
    }

    private func listAllProjects(kit: PromptWatchKit) {
        let projects = runBlocking {
            try await kit.getProjects()
        }

        if json {
            printProjectsJSON(projects)
        } else {
            printProjectsTable(projects)
        }
    }

    private func listSessions(kit: PromptWatchKit) {
        let projectPath = (directory as NSString).standardizingPath

        // If it's a relative path, expand it
        let fullPath: String
        if projectPath.hasPrefix("/") {
            fullPath = projectPath
        } else {
            fullPath = (FileManager.default.currentDirectoryPath as NSString)
                .appendingPathComponent(projectPath)
        }

        let sessions = runBlocking {
            try await kit.getSessions(forProject: fullPath)
        }

        let limitedSessions: [SessionSummary]
        if let limit = limit {
            limitedSessions = Array(sessions.prefix(limit))
        } else {
            limitedSessions = sessions
        }

        if json {
            printSessionsJSON(limitedSessions)
        } else {
            printSessionsTable(limitedSessions, projectPath: fullPath)
        }
    }

    private func printProjectsTable(_ projects: [ProjectDir]) {
        if projects.isEmpty {
            print("No projects found")
            print("Claude session data is stored in ~/.claude/projects/")
            return
        }

        // Use string interpolation instead of String(format:) with %s
        let header = "Project".padding(toLength: 30, withPad: " ", startingAt: 0) +
                     "  Sessions  Last Activity"
        print(header)
        print(String(repeating: "-", count: 80))

        for project in projects {
            let activity = project.lastActivity.map { formatRelativeTime($0) } ?? "never"
            let name = truncate(project.name, maxLength: 30).padding(toLength: 30, withPad: " ", startingAt: 0)
            let sessions = String(project.sessionCount).padding(toLength: 10, withPad: " ", startingAt: 0)
            print("\(name)  \(sessions)  \(activity)")
        }

        print("\nTotal: \(projects.count) project(s)")
    }

    private func printSessionsTable(_ sessions: [SessionSummary], projectPath: String) {
        print("Sessions for: \(projectPath)\n")

        if sessions.isEmpty {
            print("No sessions found for this project")
            return
        }

        // Use string interpolation instead of String(format:) with %s
        let header = "Session ID".padding(toLength: 12, withPad: " ", startingAt: 0) +
                     "  " + "Size".padding(toLength: 10, withPad: " ", startingAt: 0) +
                     "  Last Modified"
        print(header)
        print(String(repeating: "-", count: 60))

        for session in sessions {
            let date = session.lastModified.map { formatRelativeTime($0) } ?? "unknown"
            let sessionId = session.shortId.padding(toLength: 12, withPad: " ", startingAt: 0)
            let size = session.formattedFileSize.padding(toLength: 10, withPad: " ", startingAt: 0)
            print("\(sessionId)  \(size)  \(date)")
        }

        print("\nTotal: \(sessions.count) session(s)")
    }

    private func printProjectsJSON(_ projects: [ProjectDir]) {
        let data: [[String: Any]] = projects.map { project in
            [
                "encodedName": project.encodedName,
                "originalPath": project.originalPath,
                "sessionCount": project.sessionCount,
                "lastActivity": project.lastActivity?.iso8601String ?? NSNull()
            ]
        }

        printJSON(data)
    }

    private func printSessionsJSON(_ sessions: [SessionSummary]) {
        let data: [[String: Any]] = sessions.map { session in
            [
                "id": session.id,
                "filePath": session.filePath,
                "fileSize": session.fileSize,
                "lastModified": session.lastModified?.iso8601String ?? NSNull()
            ]
        }

        printJSON(data)
    }

    private func printJSON(_ data: Any) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func truncate(_ string: String, maxLength: Int) -> String {
        if string.count <= maxLength {
            return string
        }
        return String(string.prefix(maxLength - 3)) + "..."
    }
}

// Date extension for ISO8601 string
extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}
