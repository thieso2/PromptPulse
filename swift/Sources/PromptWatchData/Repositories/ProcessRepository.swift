import Foundation
import PromptWatchDomain
import PromptWatchPlatform

/// Thread-safe repository for managing Claude process state
public actor ProcessRepository {
    private let discovery: ProcessDiscovery
    private var processes: [ClaudeProcess] = []
    private var lastUpdate: Date?
    private var includeHelpers: Bool = false

    public init(discovery: ProcessDiscovery = ProcessDiscovery()) {
        self.discovery = discovery
    }

    /// Configure whether to include helper processes
    public func setIncludeHelpers(_ include: Bool) {
        self.includeHelpers = include
    }

    /// Refresh the process list
    public func refresh() async throws -> [ClaudeProcess] {
        processes = try await discovery.findClaudeProcesses(includeHelpers: includeHelpers)
        lastUpdate = Date()
        return processes
    }

    /// Get the current process list without refreshing
    public func getProcesses() -> [ClaudeProcess] {
        processes
    }

    /// Get a specific process by PID
    public func getProcess(pid: Int32) -> ClaudeProcess? {
        processes.first { $0.id == pid }
    }

    /// Get processes for a specific working directory
    public func getProcesses(forWorkDir workDir: String) -> [ClaudeProcess] {
        let normalized = (workDir as NSString).standardizingPath
        return processes.filter { process in
            guard let dir = process.workingDirectory else { return false }
            return (dir as NSString).standardizingPath.hasPrefix(normalized)
        }
    }

    /// Get the time since last update
    public func timeSinceLastUpdate() -> TimeInterval? {
        guard let last = lastUpdate else { return nil }
        return Date().timeIntervalSince(last)
    }

    /// Check if a refresh is needed based on interval
    public func needsRefresh(interval: TimeInterval) -> Bool {
        guard let elapsed = timeSinceLastUpdate() else { return true }
        return elapsed >= interval
    }

    /// Start a continuous refresh stream
    public func startRefreshing(
        interval: Duration
    ) -> AsyncThrowingStream<[ClaudeProcess], Error> {
        AsyncThrowingStream { continuation in
            Task {
                while !Task.isCancelled {
                    do {
                        let result = try await self.refresh()
                        continuation.yield(result)
                        try await Task.sleep(for: interval)
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
                continuation.finish()
            }
        }
    }
}

// MARK: - Convenience Extensions

extension ProcessRepository {
    /// Get summary statistics
    public func getStats() -> ProcessStats {
        let mainProcesses = processes.filter { !$0.isHelper }
        let helpers = processes.filter { $0.isHelper }

        return ProcessStats(
            totalProcesses: processes.count,
            mainProcesses: mainProcesses.count,
            helperProcesses: helpers.count,
            totalCPU: processes.reduce(0) { $0 + $1.cpuPercent },
            totalMemoryMB: processes.reduce(0) { $0 + $1.memoryMB }
        )
    }
}

/// Statistics about Claude processes
public struct ProcessStats: Sendable {
    public let totalProcesses: Int
    public let mainProcesses: Int
    public let helperProcesses: Int
    public let totalCPU: Double
    public let totalMemoryMB: Double

    public init(
        totalProcesses: Int,
        mainProcesses: Int,
        helperProcesses: Int,
        totalCPU: Double,
        totalMemoryMB: Double
    ) {
        self.totalProcesses = totalProcesses
        self.mainProcesses = mainProcesses
        self.helperProcesses = helperProcesses
        self.totalCPU = totalCPU
        self.totalMemoryMB = totalMemoryMB
    }
}
