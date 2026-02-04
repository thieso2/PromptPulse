import Testing
import Foundation
@testable import PromptWatchPlatform

@Suite("DarwinSyscalls Tests")
struct DarwinSyscallsTests {
    @Test("List all PIDs returns non-empty array")
    func testListAllPIDs() throws {
        let pids = try DarwinSyscalls.listAllPIDs()

        #expect(!pids.isEmpty)
        #expect(pids.allSatisfy { $0 > 0 })
    }

    @Test("Get process name for current process")
    func testGetProcessName() throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let name = try DarwinSyscalls.getProcessName(pid: pid)

        #expect(!name.isEmpty)
    }

    @Test("Get task info for current process")
    func testGetTaskInfo() throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let info = try DarwinSyscalls.getTaskInfo(pid: pid)

        #expect(info.residentMemoryBytes > 0)
        #expect(info.parentPID > 0)
    }

    @Test("Get working directory for current process")
    func testGetWorkingDirectory() throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let workDir = try DarwinSyscalls.getWorkingDirectory(pid: pid)

        #expect(!workDir.isEmpty)
        // Should match the current directory
        let expectedDir = FileManager.default.currentDirectoryPath
        #expect(workDir == expectedDir)
    }

    @Test("Invalid PID throws error")
    func testInvalidPID() {
        let invalidPID: Int32 = -1

        #expect(throws: DarwinError.self) {
            _ = try DarwinSyscalls.getProcessName(pid: invalidPID)
        }
    }

    @Test("Non-existent PID throws error")
    func testNonExistentPID() {
        // Use a very high PID that's unlikely to exist
        let unlikelyPID: Int32 = 999999

        #expect(throws: DarwinError.self) {
            _ = try DarwinSyscalls.getProcessName(pid: unlikelyPID)
        }
    }

    @Test("BSD info returns valid data")
    func testGetBSDInfo() throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let info = try DarwinSyscalls.getBSDInfo(pid: pid)

        #expect(info.pid == pid)
        #expect(info.ppid > 0)
        #expect(!info.name.isEmpty)
    }

    @Test("Task info memory values are reasonable")
    func testTaskInfoMemoryValues() throws {
        let pid = ProcessInfo.processInfo.processIdentifier

        let info = try DarwinSyscalls.getTaskInfo(pid: pid)

        // Memory should be positive and reasonable for a test process
        #expect(info.residentMemoryMB > 0)
        #expect(info.residentMemoryMB < 10000)  // Less than 10GB
    }
}
