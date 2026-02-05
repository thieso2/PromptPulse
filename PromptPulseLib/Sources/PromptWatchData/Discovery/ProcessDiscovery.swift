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
        print("[DEBUG] Total PIDs from sysctl: \(allPIDs.count)")

        // First pass: find all Claude processes and their parents
        var claudeCandidates: [(pid: Int32, name: String, parentPID: Int32?, taskInfo: DarwinSyscalls.TaskAllInfo?)] = []
        var claudePIDs: Set<Int32> = []
        var procNameFailures = 0
        var checkedCount = 0

        for pid in allPIDs {
            do {
                let processName = try DarwinSyscalls.getProcessName(pid: pid)
                checkedCount += 1

                // Check if this is a Claude process (main or child)
                // The native binary installed via install.sh resolves to a versioned path
                // like ~/.local/share/claude/versions/2.1.32, so proc_name returns "2.1.32".
                // Fall back to proc_pidpath to check the full executable path.
                var isClaudeProcess = processName == "claude" || processName.contains("claude-code")
                if !isClaudeProcess,
                   let path = try? DarwinSyscalls.getProcessPath(pid: pid),
                   path.contains("/claude/versions/") {
                    isClaudeProcess = true
                }

                // Log processes that might be Claude-related (for debugging)
                let lowerName = processName.lowercased()
                if isClaudeProcess || lowerName.contains("claude") || lowerName.contains("node") || lowerName.contains("npm") {
                    print("[DEBUG] PID \(pid): name='\(processName)' -> isClaudeProcess=\(isClaudeProcess)")
                }

                if isClaudeProcess {
                    let taskInfo = try? DarwinSyscalls.getTaskInfo(pid: pid)
                    print("[DEBUG] ✓ Found Claude process: PID=\(pid) name='\(processName)' ppid=\(taskInfo?.parentPID ?? -1)")
                    claudeCandidates.append((pid: pid, name: processName, parentPID: taskInfo?.parentPID, taskInfo: taskInfo))
                    claudePIDs.insert(pid)
                }
            } catch {
                procNameFailures += 1
                // Only log first few failures to avoid spam
                if procNameFailures <= 5 {
                    print("[DEBUG] ✗ proc_name failed for PID \(pid): \(error.localizedDescription)")
                }
            }
        }

        print("[DEBUG] proc_name succeeded: \(checkedCount), failed: \(procNameFailures)")
        print("[DEBUG] Claude candidates found: \(claudeCandidates.count)")

        // Second pass: identify main processes vs helpers
        // A helper is a Claude process whose parent is also a Claude process
        var claudeProcesses: [ClaudeProcess] = []
        var mainCount = 0
        var helperCount = 0

        print("[DEBUG] Classifying \(claudeCandidates.count) candidates (claudePIDs: \(claudePIDs.sorted()))")

        for candidate in claudeCandidates {
            let isChildOfClaude = candidate.parentPID.map { claudePIDs.contains($0) } ?? false
            print("[DEBUG]   PID \(candidate.pid): ppid=\(candidate.parentPID ?? -1) -> isHelper=\(isChildOfClaude)")

            if isChildOfClaude {
                helperCount += 1
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
                mainCount += 1
                let workDir = workDirResolver.resolve(pid: candidate.pid)
                print("[DEBUG]   → Main process PID \(candidate.pid) workDir='\(workDir ?? "nil")'")
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

        print("[DEBUG] Classification complete: main=\(mainCount), helpers=\(helperCount)")
        print("[DEBUG] Returning \(claudeProcesses.count) processes (includeHelpers=\(includeHelpers))")

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
