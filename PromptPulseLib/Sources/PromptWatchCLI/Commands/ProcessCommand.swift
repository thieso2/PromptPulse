import ArgumentParser
import Foundation
import PromptWatchKit
import PromptWatchDomain
import PromptWatchPlatform

/// List running Claude processes
struct ProcessCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "processes",
        abstract: "List running Claude CLI processes"
    )

    @Flag(name: .shortAndLong, help: "Show MCP helper processes")
    var showHelpers: Bool = false

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json: Bool = false

    @Flag(name: .shortAndLong, help: "Watch mode - continuously update")
    var watch: Bool = false

    @Option(name: .shortAndLong, help: "Refresh interval for watch mode (default: 1s)")
    var interval: String = "1s"

    @Option(name: .long, help: "Debug a specific PID (inspect syscall results)")
    var debugPid: Int32?

    mutating func run() throws {
        // Debug mode for specific PID
        if let pid = debugPid {
            DarwinSyscalls.debugPID(pid)
            return
        }

        let kit = PromptWatchKit.shared

        if watch {
            runWatchMode(kit: kit)
        } else {
            try runOnce(kit: kit)
        }
    }

    private func runOnce(kit: PromptWatchKit) throws {
        // Run async code synchronously
        let processes = runBlocking {
            try await kit.getProcesses(includeHelpers: showHelpers)
        }

        if json {
            printJSON(processes)
        } else {
            printTable(processes)
        }
    }

    private func runWatchMode(kit: PromptWatchKit) {
        let intervalSeconds = parseIntervalSeconds(interval)

        while true {
            // Clear screen
            print("\u{001B}[2J\u{001B}[H", terminator: "")

            let processes = runBlocking {
                try await kit.getProcesses(includeHelpers: showHelpers)
            }

            print("Claude Processes (refreshing every \(interval))")
            print("Press Ctrl+C to stop\n")

            printTable(processes)

            Thread.sleep(forTimeInterval: intervalSeconds)
        }
    }

    private func printTable(_ processes: [ClaudeProcess]) {
        if processes.isEmpty {
            print("No Claude processes running")
            return
        }

        // Header - use string interpolation instead of C-style format specifiers
        print("   PID      CPU      Memory  Working Directory")
        print(String(repeating: "-", count: 80))

        // Rows - avoid String(format:) with %s which doesn't work with Swift Strings
        for process in processes {
            let pid = String(process.id).padding(toLength: 6, withPad: " ", startingAt: 0)
            let cpu = String(format: "%.1f%%", process.cpuPercent).padding(toLength: 8, withPad: " ", startingAt: 0)
            let mem = formatMemory(process.memoryMB).padding(toLength: 10, withPad: " ", startingAt: 0)
            let dir = process.workingDirectory ?? "unknown"
            let helper = process.isHelper ? " [helper]" : ""

            print("\(pid)  \(cpu)  \(mem)  \(dir)\(helper)")
        }

        print("\nTotal: \(processes.count) process(es)")
    }

    private func printJSON(_ processes: [ClaudeProcess]) {
        let data: [[String: Any]] = processes.map { process in
            [
                "pid": process.id,
                "name": process.name,
                "workingDirectory": process.workingDirectory ?? NSNull(),
                "cpuPercent": process.cpuPercent,
                "memoryMB": process.memoryMB,
                "isHelper": process.isHelper
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb < 1 {
            return String(format: "%.0f KB", mb * 1024)
        } else if mb < 1024 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.2f GB", mb / 1024)
        }
    }

    private func parseIntervalSeconds(_ string: String) -> TimeInterval {
        let value = string.lowercased()
        if value.hasSuffix("ms"), let ms = Int(value.dropLast(2)) {
            return TimeInterval(ms) / 1000.0
        }
        if value.hasSuffix("s"), let s = Int(value.dropLast(1)) {
            return TimeInterval(s)
        }
        if let s = Int(value) {
            return TimeInterval(s)
        }
        return 1.0
    }
}

// MARK: - Async Helper

/// Run async code synchronously by blocking the current thread
func runBlocking<T: Sendable>(_ operation: @Sendable @escaping () async throws -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: Result<T, Error>!

    Task {
        do {
            let value = try await operation()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()

    switch result! {
    case .success(let value):
        return value
    case .failure(let error):
        fatalError("Async operation failed: \(error)")
    }
}
