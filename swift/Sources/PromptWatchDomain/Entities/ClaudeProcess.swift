import Foundation

/// Represents a running Claude CLI process with its metrics
public struct ClaudeProcess: Identifiable, Sendable, Equatable, Hashable {
    public let id: Int32  // PID
    public let name: String
    public let workingDirectory: String?
    public let cpuPercent: Double
    public let memoryMB: Double
    public let parentPID: Int32?
    public let startTime: Date?
    public let isHelper: Bool

    public init(
        id: Int32,
        name: String,
        workingDirectory: String? = nil,
        cpuPercent: Double = 0.0,
        memoryMB: Double = 0.0,
        parentPID: Int32? = nil,
        startTime: Date? = nil,
        isHelper: Bool = false
    ) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.parentPID = parentPID
        self.startTime = startTime
        self.isHelper = isHelper
    }

    /// Returns a copy with updated metrics
    public func withMetrics(cpu: Double, memory: Double) -> ClaudeProcess {
        ClaudeProcess(
            id: id,
            name: name,
            workingDirectory: workingDirectory,
            cpuPercent: cpu,
            memoryMB: memory,
            parentPID: parentPID,
            startTime: startTime,
            isHelper: isHelper
        )
    }

    /// Returns a copy with updated working directory
    public func withWorkingDirectory(_ path: String?) -> ClaudeProcess {
        ClaudeProcess(
            id: id,
            name: name,
            workingDirectory: path,
            cpuPercent: cpuPercent,
            memoryMB: memoryMB,
            parentPID: parentPID,
            startTime: startTime,
            isHelper: isHelper
        )
    }
}

extension ClaudeProcess: CustomStringConvertible {
    public var description: String {
        let dir = workingDirectory ?? "unknown"
        return "ClaudeProcess(pid: \(id), cpu: \(String(format: "%.1f", cpuPercent))%, mem: \(String(format: "%.1f", memoryMB))MB, dir: \(dir))"
    }
}
