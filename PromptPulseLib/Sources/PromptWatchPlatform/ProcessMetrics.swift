import Foundation

/// Process metrics snapshot
public struct ProcessMetrics: Sendable {
    public let cpuPercent: Double
    public let memoryMB: Double
    public let timestamp: Date

    public init(cpuPercent: Double, memoryMB: Double, timestamp: Date = Date()) {
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.timestamp = timestamp
    }
}

/// Service for collecting process metrics with delta-based CPU calculation
public actor ProcessMetricsCollector {
    /// Stored previous readings for CPU delta calculation
    private var previousReadings: [Int32: (timestamp: Date, cpuTime: Double)] = [:]

    /// Interval between samples for CPU percentage calculation
    private let sampleInterval: TimeInterval

    public init(sampleInterval: TimeInterval = 1.0) {
        self.sampleInterval = sampleInterval
    }

    /// Collect metrics for a single process
    public func collect(pid: Int32) async throws -> ProcessMetrics {
        let taskInfo = try DarwinSyscalls.getTaskInfo(pid: pid)
        let now = Date()

        // Calculate CPU usage
        let cpuPercent: Double
        let currentCPUTime = taskInfo.cpuUsage  // This is cumulative seconds

        if let previous = previousReadings[pid] {
            let timeDelta = now.timeIntervalSince(previous.timestamp)
            if timeDelta > 0 {
                let cpuDelta = currentCPUTime - previous.cpuTime
                cpuPercent = (cpuDelta / timeDelta) * 100.0
            } else {
                cpuPercent = 0.0
            }
        } else {
            // First reading, can't compute delta
            cpuPercent = 0.0
        }

        // Store current reading for next delta
        previousReadings[pid] = (timestamp: now, cpuTime: currentCPUTime)

        return ProcessMetrics(
            cpuPercent: max(0, min(cpuPercent, 100.0 * Double(ProcessInfo.processInfo.processorCount))),
            memoryMB: taskInfo.residentMemoryMB,
            timestamp: now
        )
    }

    /// Collect metrics for multiple processes
    public func collect(pids: [Int32]) async -> [Int32: ProcessMetrics] {
        var results: [Int32: ProcessMetrics] = [:]

        for pid in pids {
            if let metrics = try? await collect(pid: pid) {
                results[pid] = metrics
            }
        }

        return results
    }

    /// Clean up readings for processes that no longer exist
    public func cleanup(validPIDs: Set<Int32>) {
        previousReadings = previousReadings.filter { validPIDs.contains($0.key) }
    }
}
