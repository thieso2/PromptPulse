import Foundation
import PromptWatchDomain
import PromptWatchPlatform
import PromptWatchData

// MARK: - Re-exports

// Domain types
@_exported import PromptWatchDomain

// MARK: - Main API

/// Main entry point for PromptWatch functionality
public struct PromptWatchKit: Sendable {
    public static let shared = PromptWatchKit()

    public let processRepository: ProcessRepository
    public let sessionRepository: SessionRepository
    public let costCalculator: CostCalculator

    public init(
        processRepository: ProcessRepository = ProcessRepository(),
        sessionRepository: SessionRepository = SessionRepository(),
        costCalculator: CostCalculator = .shared
    ) {
        self.processRepository = processRepository
        self.sessionRepository = sessionRepository
        self.costCalculator = costCalculator
    }

    // MARK: - Process Operations

    /// Get all running Claude processes
    public func getProcesses(includeHelpers: Bool = false) async throws -> [ClaudeProcess] {
        await processRepository.setIncludeHelpers(includeHelpers)
        return try await processRepository.refresh()
    }

    /// Start monitoring processes with periodic updates
    public func monitorProcesses(
        interval: Duration = .seconds(1)
    ) async -> AsyncThrowingStream<[ClaudeProcess], Error> {
        await processRepository.startRefreshing(interval: interval)
    }

    // MARK: - Session Operations

    /// Get all project directories
    public func getProjects() async throws -> [ProjectDir] {
        try await sessionRepository.getProjects()
    }

    /// Get sessions for a project path
    public func getSessions(forProject path: String) async throws -> [SessionSummary] {
        try await sessionRepository.getSessions(forProjectPath: path)
    }

    /// Load a full session with messages
    public func loadSession(filePath: String) async throws -> Session {
        print("[PromptWatchKit] loadSession START")
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await sessionRepository.loadSession(filePath: filePath)
        print("[PromptWatchKit] loadSession DONE (\(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms)")
        return result
    }

    /// Load a session by ID within a project
    public func loadSession(sessionId: String, projectPath: String) async throws -> Session? {
        try await sessionRepository.loadSession(sessionId: sessionId, projectPath: projectPath)
    }

    // MARK: - Analytics

    /// Calculate cost for a session
    public func calculateCost(for session: Session) -> Decimal {
        costCalculator.calculate(usage: session.totalUsage)
    }

    /// Get statistics for a session
    public func getStats(for session: Session) -> SessionStats {
        SessionStats.from(session: session, using: costCalculator)
    }

    /// Calculate total cost across sessions
    public func calculateTotalCost(sessions: [Session]) -> Decimal {
        sessions.reduce(0) { $0 + calculateCost(for: $1) }
    }
}

// MARK: - Convenience Functions

/// Find running Claude processes
public func findClaudeProcesses(includeHelpers: Bool = false) async throws -> [ClaudeProcess] {
    try await PromptWatchKit.shared.getProcesses(includeHelpers: includeHelpers)
}

/// Get all Claude project directories
public func findProjects() async throws -> [ProjectDir] {
    try await PromptWatchKit.shared.getProjects()
}

/// Get sessions for a project
public func findSessions(forProject path: String) async throws -> [SessionSummary] {
    try await PromptWatchKit.shared.getSessions(forProject: path)
}

/// Load a session file
public func loadSession(filePath: String) async throws -> Session {
    try await PromptWatchKit.shared.loadSession(filePath: filePath)
}

/// Calculate session cost
public func calculateCost(for session: Session) -> Decimal {
    PromptWatchKit.shared.calculateCost(for: session)
}

// MARK: - Version Info

public enum PromptWatchVersion {
    public static let version = "1.0.0"
    public static let buildDate = "2025-01-01"
}
