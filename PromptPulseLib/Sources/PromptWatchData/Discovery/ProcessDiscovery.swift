import Foundation
import PromptWatchDomain
import PromptWatchPlatform

/// Service for discovering running Claude CLI processes
public struct ProcessDiscovery: Sendable {
    private let metricsCollector: ProcessMetricsCollector
    private let workDirResolver: WorkingDirectoryResolver

    public init(
        metricsCollector: ProcessMetricsCollector = ProcessMetricsCollector(),
        workDirResolver: WorkingDirectoryResolver = WorkingDirectoryResolver()
    ) {
        self.metricsCollector = metricsCollector
        self.workDirResolver = workDirResolver
    }

    /// Find all running Claude CLI processes
    public func findClaudeProcesses(includeHelpers: Bool = false) async throws -> [ClaudeProcess] {
        // Get all PIDs
        let allPIDs = try DarwinSyscalls.listAllPIDs()

        // First pass: find all Claude processes and their parents
        var claudeCandidates: [(pid: Int32, name: String, parentPID: Int32?, taskInfo: DarwinSyscalls.TaskAllInfo?)] = []
        var claudePIDs: Set<Int32> = []

        for pid in allPIDs {
            guard let processName = try? DarwinSyscalls.getProcessName(pid: pid) else {
                continue
            }

            // Check if this is a Claude process (main or child)
            let isClaudeProcess = processName == "claude" || processName.contains("claude-code")

            if isClaudeProcess {
                let taskInfo = try? DarwinSyscalls.getTaskInfo(pid: pid)
                claudeCandidates.append((pid: pid, name: processName, parentPID: taskInfo?.parentPID, taskInfo: taskInfo))
                claudePIDs.insert(pid)
            }
        }

        // Second pass: identify main processes vs helpers
        // A helper is a Claude process whose parent is also a Claude process
        var claudeProcesses: [ClaudeProcess] = []

        for candidate in claudeCandidates {
            let isChildOfClaude = candidate.parentPID.map { claudePIDs.contains($0) } ?? false

            if isChildOfClaude {
                // This is a helper process (child of another Claude process)
                if includeHelpers {
                    let process = ClaudeProcess(
                        id: candidate.pid,
                        name: candidate.name,
                        workingDirectory: nil,
                        cpuPercent: 0,
                        memoryMB: candidate.taskInfo?.residentMemoryMB ?? 0,
                        parentPID: candidate.parentPID,
                        startTime: candidate.taskInfo?.startTime,
                        isHelper: true
                    )
                    claudeProcesses.append(process)
                }
            } else {
                // This is a main Claude process
                let workDir = workDirResolver.resolve(pid: candidate.pid)
                let process = ClaudeProcess(
                    id: candidate.pid,
                    name: candidate.name,
                    workingDirectory: workDir,
                    cpuPercent: 0,  // Will be updated by metrics collector
                    memoryMB: candidate.taskInfo?.residentMemoryMB ?? 0,
                    parentPID: candidate.parentPID,
                    startTime: candidate.taskInfo?.startTime,
                    isHelper: false
                )
                claudeProcesses.append(process)
            }
        }

        // Collect metrics for all found processes
        let pids = claudeProcesses.map(\.id)
        let metrics = await metricsCollector.collect(pids: pids)

        // Update processes with metrics
        return claudeProcesses.map { process in
            if let m = metrics[process.id] {
                return process.withMetrics(cpu: m.cpuPercent, memory: m.memoryMB)
            }
            return process
        }
    }

    /// Check if a specific process is still running
    public func isRunning(pid: Int32) -> Bool {
        (try? DarwinSyscalls.getProcessName(pid: pid)) != nil
    }

    /// Get details for a specific process
    public func getProcess(pid: Int32) async throws -> ClaudeProcess? {
        guard let name = try? DarwinSyscalls.getProcessName(pid: pid) else {
            return nil
        }

        let workDir = workDirResolver.resolve(pid: pid)
        let taskInfo = try? DarwinSyscalls.getTaskInfo(pid: pid)
        let metrics = try? await metricsCollector.collect(pid: pid)

        return ClaudeProcess(
            id: pid,
            name: name,
            workingDirectory: workDir,
            cpuPercent: metrics?.cpuPercent ?? 0,
            memoryMB: metrics?.memoryMB ?? taskInfo?.residentMemoryMB ?? 0,
            parentPID: taskInfo?.parentPID,
            startTime: taskInfo?.startTime,
            isHelper: false
        )
    }
}
