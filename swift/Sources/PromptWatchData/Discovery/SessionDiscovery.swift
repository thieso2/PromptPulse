import Foundation
import PromptWatchDomain

/// Service for discovering Claude session files
public struct SessionDiscovery: Sendable {
    /// Base path for Claude projects: ~/.claude/projects/
    private let claudeProjectsPath: String

    public init(claudeProjectsPath: String? = nil) {
        if let path = claudeProjectsPath {
            self.claudeProjectsPath = path
        } else {
            self.claudeProjectsPath = ("~/.claude/projects" as NSString).expandingTildeInPath
        }
    }

    /// Find all sessions for a project directory
    public func findSessions(forProjectPath projectPath: String) throws -> [SessionSummary] {
        let encodedName = ProjectDir.encode(path: projectPath)
        let projectDir = (claudeProjectsPath as NSString).appendingPathComponent(encodedName)

        return try findSessionsInDirectory(projectDir, projectPath: projectPath)
    }

    /// Find all sessions in an encoded project directory
    public func findSessions(inEncodedDir encodedName: String) throws -> [SessionSummary] {
        let projectDir = (claudeProjectsPath as NSString).appendingPathComponent(encodedName)
        let projectPath = ProjectDir.decode(encodedName: encodedName)

        return try findSessionsInDirectory(projectDir, projectPath: projectPath)
    }

    /// Find sessions in a specific directory
    private func findSessionsInDirectory(_ dir: String, projectPath: String?) throws -> [SessionSummary] {
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir) else {
            return []
        }

        let contents = try fm.contentsOfDirectory(atPath: dir)
        var sessions: [SessionSummary] = []

        for filename in contents {
            guard filename.hasSuffix(".jsonl") else { continue }

            let filePath = (dir as NSString).appendingPathComponent(filename)
            let sessionId = (filename as NSString).deletingPathExtension

            // Get file attributes
            let attrs = try? fm.attributesOfItem(atPath: filePath)
            let modDate = attrs?[.modificationDate] as? Date
            let fileSize = (attrs?[.size] as? Int64) ?? 0

            let summary = SessionSummary(
                id: sessionId,
                filePath: filePath,
                projectPath: projectPath,
                lastModified: modDate,
                fileSize: fileSize
            )
            sessions.append(summary)
        }

        // Sort by last modified, newest first
        return sessions.sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
    }

    /// Find all project directories with sessions
    public func findAllProjects() throws -> [ProjectDir] {
        let fm = FileManager.default

        guard fm.fileExists(atPath: claudeProjectsPath) else {
            return []
        }

        let contents = try fm.contentsOfDirectory(atPath: claudeProjectsPath)
        var projects: [ProjectDir] = []

        for dirname in contents {
            guard dirname.hasPrefix("-") else { continue }

            let projectDir = (claudeProjectsPath as NSString).appendingPathComponent(dirname)

            // Check if it's a directory
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            // Count sessions and find latest
            let sessions = try? findSessionsInDirectory(projectDir, projectPath: nil)
            let sessionCount = sessions?.count ?? 0
            let lastActivity = sessions?.first?.lastModified

            let originalPath = ProjectDir.decode(encodedName: dirname)

            let project = ProjectDir(
                encodedName: dirname,
                originalPath: originalPath,
                sessionCount: sessionCount,
                lastActivity: lastActivity
            )
            projects.append(project)
        }

        // Sort by last activity, most recent first
        return projects.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    /// Read session index metadata if available
    public func readSessionIndex(forProjectPath projectPath: String) throws -> [SessionMetadata] {
        let encodedName = ProjectDir.encode(path: projectPath)
        let projectDir = (claudeProjectsPath as NSString).appendingPathComponent(encodedName)
        let indexPath = (projectDir as NSString).appendingPathComponent("sessions-index.json")

        guard FileManager.default.fileExists(atPath: indexPath) else {
            return []
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // The index might be an array or a dictionary
        if let array = try? decoder.decode([SessionMetadata].self, from: data) {
            return array
        }

        if let dict = try? decoder.decode([String: SessionMetadata].self, from: data) {
            return Array(dict.values)
        }

        return []
    }
}
