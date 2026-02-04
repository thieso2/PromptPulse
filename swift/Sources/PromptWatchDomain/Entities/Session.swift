import Foundation

/// A Claude CLI session with conversation history
public struct Session: Identifiable, Sendable, Equatable {
    public let id: String
    public let filePath: String
    public let projectPath: String?
    public let startTime: Date?
    public let lastModified: Date?
    public let messages: [Message]

    public init(
        id: String,
        filePath: String,
        projectPath: String? = nil,
        startTime: Date? = nil,
        lastModified: Date? = nil,
        messages: [Message] = []
    ) {
        self.id = id
        self.filePath = filePath
        self.projectPath = projectPath
        self.startTime = startTime
        self.lastModified = lastModified
        self.messages = messages
    }

    /// Returns the session with messages loaded
    public func withMessages(_ messages: [Message]) -> Session {
        Session(
            id: id,
            filePath: filePath,
            projectPath: projectPath,
            startTime: startTime,
            lastModified: lastModified,
            messages: messages
        )
    }

    /// Total token usage across all messages
    public var totalUsage: TokenUsage {
        messages.reduce(.zero) { $0 + $1.usage }
    }

    /// Number of user messages
    public var userMessageCount: Int {
        messages.filter { $0.role == .user }.count
    }

    /// Number of assistant messages
    public var assistantMessageCount: Int {
        messages.filter { $0.role == .assistant }.count
    }

    /// Duration of the session
    public var duration: TimeInterval? {
        guard let start = startTime, let end = lastModified else { return nil }
        return end.timeIntervalSince(start)
    }

    /// Short session ID (first 8 characters of UUID)
    public var shortId: String {
        if id.count > 8 {
            return String(id.prefix(8))
        }
        return id
    }
}

/// Session metadata from sessions-index.json
public struct SessionMetadata: Sendable, Codable {
    public let id: String
    public let originalPath: String?
    public let lastModified: Date?
    public let summary: String?

    public init(
        id: String,
        originalPath: String? = nil,
        lastModified: Date? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.originalPath = originalPath
        self.lastModified = lastModified
        self.summary = summary
    }

    enum CodingKeys: String, CodingKey {
        case id
        case originalPath
        case lastModified
        case summary
    }
}

/// Summary of a session without full message history
public struct SessionSummary: Identifiable, Sendable, Equatable {
    public let id: String
    public let filePath: String
    public let projectPath: String?
    public let lastModified: Date?
    public let fileSize: Int64

    public init(
        id: String,
        filePath: String,
        projectPath: String? = nil,
        lastModified: Date? = nil,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.filePath = filePath
        self.projectPath = projectPath
        self.lastModified = lastModified
        self.fileSize = fileSize
    }

    /// Short session ID
    public var shortId: String {
        if id.count > 8 {
            return String(id.prefix(8))
        }
        return id
    }

    /// Human-readable file size
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
