import Foundation
import PromptWatchDomain

/// Thread-safe repository for managing session data with caching
public actor SessionRepository {
    private let discovery: SessionDiscovery
    private let parser: SessionParser

    /// Cache of parsed sessions keyed by file path
    private var sessionCache: [String: CachedSession] = [:]

    /// Cache entry with expiration
    private struct CachedSession {
        let session: Session
        let loadedAt: Date
        let fileModDate: Date?
    }

    /// Maximum age before cache entry is considered stale
    private let cacheMaxAge: TimeInterval

    public init(
        discovery: SessionDiscovery = SessionDiscovery(),
        parser: SessionParser = SessionParser(),
        cacheMaxAge: TimeInterval = 60.0
    ) {
        self.discovery = discovery
        self.parser = parser
        self.cacheMaxAge = cacheMaxAge
    }

    // MARK: - Session Loading

    /// Load a session by file path (async, runs parsing on background thread)
    public func loadSession(filePath: String) async throws -> Session {
        // Check cache first (fast path)
        if let cached = sessionCache[filePath], !isCacheStale(cached, filePath: filePath) {
            return cached.session
        }

        // Parse session on background thread to avoid blocking UI
        let parser = self.parser
        let session = try await Task.detached(priority: .userInitiated) {
            try parser.parseSession(filePath: filePath)
        }.value

        // Cache it
        let fileModDate = try? FileManager.default
            .attributesOfItem(atPath: filePath)[.modificationDate] as? Date

        sessionCache[filePath] = CachedSession(
            session: session,
            loadedAt: Date(),
            fileModDate: fileModDate
        )

        return session
    }

    /// Load a session synchronously (for internal use)
    private func loadSessionSync(filePath: String) throws -> Session {
        // Check cache
        if let cached = sessionCache[filePath], !isCacheStale(cached, filePath: filePath) {
            return cached.session
        }

        // Parse session
        let session = try parser.parseSession(filePath: filePath)

        // Cache it
        let fileModDate = try? FileManager.default
            .attributesOfItem(atPath: filePath)[.modificationDate] as? Date

        sessionCache[filePath] = CachedSession(
            session: session,
            loadedAt: Date(),
            fileModDate: fileModDate
        )

        return session
    }

    /// Load a session by ID within a project
    public func loadSession(sessionId: String, projectPath: String) async throws -> Session? {
        let sessions = try discovery.findSessions(forProjectPath: projectPath)

        guard let summary = sessions.first(where: { $0.id == sessionId }) else {
            return nil
        }

        return try await loadSession(filePath: summary.filePath)
    }

    // MARK: - Session Listing

    /// Get session summaries for a project
    public func getSessions(forProjectPath projectPath: String) throws -> [SessionSummary] {
        try discovery.findSessions(forProjectPath: projectPath)
    }

    /// Get session summaries for an encoded project directory
    public func getSessions(forEncodedDir encodedName: String) throws -> [SessionSummary] {
        try discovery.findSessions(inEncodedDir: encodedName)
    }

    /// Get all project directories
    public func getProjects() throws -> [ProjectDir] {
        try discovery.findAllProjects()
    }

    // MARK: - Cache Management

    /// Clear the session cache
    public func clearCache() {
        sessionCache.removeAll()
    }

    /// Remove a specific session from cache
    public func invalidate(filePath: String) {
        sessionCache.removeValue(forKey: filePath)
    }

    /// Remove stale entries from cache
    public func pruneCache() {
        let now = Date()
        sessionCache = sessionCache.filter { _, cached in
            now.timeIntervalSince(cached.loadedAt) < cacheMaxAge
        }
    }

    /// Check if a cache entry is stale
    private func isCacheStale(_ cached: CachedSession, filePath: String) -> Bool {
        // Check age
        if Date().timeIntervalSince(cached.loadedAt) > cacheMaxAge {
            return true
        }

        // Check if file was modified
        if let cachedModDate = cached.fileModDate {
            let currentModDate = try? FileManager.default
                .attributesOfItem(atPath: filePath)[.modificationDate] as? Date
            if let current = currentModDate, current > cachedModDate {
                return true
            }
        }

        return false
    }

    // MARK: - Preloading

    /// Preload sessions for a project in background
    public func preloadSessions(forProjectPath projectPath: String, limit: Int = 10) async {
        guard let sessions = try? discovery.findSessions(forProjectPath: projectPath) else {
            return
        }

        for summary in sessions.prefix(limit) {
            _ = try? await loadSession(filePath: summary.filePath)
        }
    }
}

// MARK: - Convenience Extensions

extension SessionRepository {
    /// Get the most recent session for a project
    public func getMostRecentSession(forProjectPath projectPath: String) async throws -> Session? {
        let sessions = try discovery.findSessions(forProjectPath: projectPath)

        guard let mostRecent = sessions.first else {
            return nil
        }

        return try await loadSession(filePath: mostRecent.filePath)
    }

    /// Search sessions by message content
    public func searchSessions(
        forProjectPath projectPath: String,
        query: String
    ) async throws -> [(session: SessionSummary, matchCount: Int)] {
        let sessions = try discovery.findSessions(forProjectPath: projectPath)
        var results: [(SessionSummary, Int)] = []

        for summary in sessions {
            if let session = try? await loadSession(filePath: summary.filePath) {
                let matches = session.messages.filter { message in
                    message.textContent.localizedCaseInsensitiveContains(query)
                }
                if !matches.isEmpty {
                    results.append((summary, matches.count))
                }
            }
        }

        return results.sorted { $0.1 > $1.1 }
    }
}
