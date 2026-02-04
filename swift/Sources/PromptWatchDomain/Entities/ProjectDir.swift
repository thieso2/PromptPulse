import Foundation

/// A project directory that contains Claude sessions
public struct ProjectDir: Identifiable, Sendable, Equatable, Hashable {
    /// The encoded directory name in ~/.claude/projects/
    public let encodedName: String

    /// The original project path on disk
    public let originalPath: String

    /// Number of sessions in this project
    public let sessionCount: Int

    /// Most recent session timestamp
    public let lastActivity: Date?

    public var id: String { encodedName }

    public init(
        encodedName: String,
        originalPath: String,
        sessionCount: Int = 0,
        lastActivity: Date? = nil
    ) {
        self.encodedName = encodedName
        self.originalPath = originalPath
        self.sessionCount = sessionCount
        self.lastActivity = lastActivity
    }

    /// The project name (last path component)
    public var name: String {
        (originalPath as NSString).lastPathComponent
    }

    /// Path to the project sessions directory
    public var sessionsDirectoryPath: String {
        let claudeDir = ("~/.claude/projects" as NSString).expandingTildeInPath
        return (claudeDir as NSString).appendingPathComponent(encodedName)
    }

    /// Encode a project path to the format used by Claude CLI
    /// Replaces "/" with "-" (the leading "/" becomes the leading "-")
    public static func encode(path: String) -> String {
        let normalized = (path as NSString).standardizingPath
        // The leading "/" becomes "-", so no need to prepend
        return normalized.replacingOccurrences(of: "/", with: "-")
    }

    /// Decode an encoded project path back to original
    public static func decode(encodedName: String) -> String {
        guard encodedName.hasPrefix("-") else { return encodedName }
        // Replace all "-" with "/" - the leading "-" becomes the leading "/"
        return encodedName.replacingOccurrences(of: "-", with: "/")
    }
}

extension ProjectDir: CustomStringConvertible {
    public var description: String {
        "ProjectDir(\(name), sessions: \(sessionCount))"
    }
}
