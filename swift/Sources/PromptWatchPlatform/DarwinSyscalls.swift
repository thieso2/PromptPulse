import Darwin
import Foundation

// Constants that may not be available in Swift Darwin module
private let PROC_PIDPATHINFO_MAXSIZE: Int32 = 4096

/// Mach timebase info for converting Mach absolute time to nanoseconds
private let machTimebaseInfo: mach_timebase_info_data_t = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return info
}()

/// Convert Mach absolute time to nanoseconds
private func machTimeToNanoseconds(_ machTime: UInt64) -> UInt64 {
    return machTime * UInt64(machTimebaseInfo.numer) / UInt64(machTimebaseInfo.denom)
}

/// Low-level Darwin syscall wrappers for process introspection
public enum DarwinSyscalls {
    // MARK: - Process ID Listing

    /// Get all process IDs on the system using sysctl
    /// Note: Uses sysctl KERN_PROC_ALL instead of proc_listallpids because
    /// proc_listallpids returns an incomplete list on some macOS versions
    public static func listAllPIDs() throws -> [Int32] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0

        // First call to get the required buffer size
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else {
            throw DarwinError.syscallFailed("sysctl(size)", errno: errno)
        }

        guard size > 0 else {
            throw DarwinError.emptyResult("process list")
        }

        // Allocate buffer with some extra room for new processes
        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count + 16)
        var actualSize = procs.count * MemoryLayout<kinfo_proc>.stride

        // Second call to get the actual data
        guard sysctl(&mib, 4, &procs, &actualSize, nil, 0) == 0 else {
            throw DarwinError.syscallFailed("sysctl(data)", errno: errno)
        }

        // Extract PIDs from kinfo_proc structures
        let actualCount = actualSize / MemoryLayout<kinfo_proc>.stride
        return procs.prefix(actualCount)
            .map { Int32($0.kp_proc.p_pid) }
            .filter { $0 > 0 }
    }

    // MARK: - Process Name

    /// Get the name of a process by PID
    public static func getProcessName(pid: Int32) throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let result = proc_name(pid, &buffer, UInt32(buffer.count))

        guard result > 0 else {
            throw DarwinError.syscallFailed("proc_name", errno: errno)
        }

        // Convert CChar buffer to String, truncating at null terminator
        let length = buffer.firstIndex(of: 0) ?? buffer.count
        return String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Get the full executable path of a process
    public static func getProcessPath(pid: Int32) throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(PROC_PIDPATHINFO_MAXSIZE))
        let result = proc_pidpath(pid, &buffer, UInt32(buffer.count))

        guard result > 0 else {
            throw DarwinError.syscallFailed("proc_pidpath", errno: errno)
        }

        // Convert CChar buffer to String, truncating at null terminator
        let length = buffer.firstIndex(of: 0) ?? buffer.count
        return String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    // MARK: - Task Info (CPU, Memory)

    /// Task info structure for all process info
    public struct TaskAllInfo: Sendable {
        public let cpuUsage: Double
        public let residentMemoryBytes: UInt64
        public let virtualMemoryBytes: UInt64
        public let startTime: Date?
        public let parentPID: Int32

        public var residentMemoryMB: Double {
            Double(residentMemoryBytes) / (1024 * 1024)
        }
    }

    /// Get task info for a process (CPU, memory usage)
    public static func getTaskInfo(pid: Int32) throws -> TaskAllInfo {
        var info = proc_taskallinfo()
        let size = MemoryLayout<proc_taskallinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, Int32(size))

        guard result == size else {
            throw DarwinError.syscallFailed("proc_pidinfo(TASKALLINFO)", errno: errno)
        }

        // Calculate CPU usage (cumulative seconds)
        // ptinfo.pti_total_user and pti_total_system are in Mach absolute time units
        // Convert to nanoseconds using the system timebase, then to seconds
        let userTimeNs = machTimeToNanoseconds(info.ptinfo.pti_total_user)
        let systemTimeNs = machTimeToNanoseconds(info.ptinfo.pti_total_system)
        let totalTimeNs = Double(userTimeNs + systemTimeNs)

        // Convert nanoseconds to seconds (cumulative CPU time)
        // For instantaneous percentage, sample twice and compute delta
        let cpuUsage = totalTimeNs / 1_000_000_000.0

        // Memory info
        let residentMemory = info.ptinfo.pti_resident_size
        let virtualMemory = info.ptinfo.pti_virtual_size

        // Start time
        let startSec = info.pbsd.pbi_start_tvsec
        let startTime: Date? = startSec > 0 ? Date(timeIntervalSince1970: TimeInterval(startSec)) : nil

        // Parent PID
        let ppid = info.pbsd.pbi_ppid

        return TaskAllInfo(
            cpuUsage: cpuUsage,
            residentMemoryBytes: residentMemory,
            virtualMemoryBytes: virtualMemory,
            startTime: startTime,
            parentPID: Int32(ppid)
        )
    }

    // MARK: - Working Directory (VNODEPATHINFO)

    /// Get the current working directory of a process
    public static func getWorkingDirectory(pid: Int32) throws -> String {
        var vnodeInfo = proc_vnodepathinfo()
        let size = MemoryLayout<proc_vnodepathinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vnodeInfo, Int32(size))

        guard result == size else {
            throw DarwinError.syscallFailed("proc_pidinfo(VNODEPATHINFO)", errno: errno)
        }

        // Extract the current working directory path using withUnsafeBytes
        let cwd = withUnsafeBytes(of: vnodeInfo.pvi_cdir.vip_path) { buffer in
            guard let baseAddress = buffer.baseAddress else { return "" }
            return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
        }

        if cwd.isEmpty {
            throw DarwinError.emptyResult("working directory")
        }

        return cwd
    }

    // MARK: - BSD Info

    /// BSD process info
    public struct BSDInfo: Sendable {
        public let pid: Int32
        public let ppid: Int32
        public let uid: UInt32
        public let gid: UInt32
        public let status: UInt32
        public let name: String
    }

    /// Get BSD info for a process
    public static func getBSDInfo(pid: Int32) throws -> BSDInfo {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))

        guard result == size else {
            throw DarwinError.syscallFailed("proc_pidinfo(BSDINFO)", errno: errno)
        }

        let name = withUnsafeBytes(of: info.pbi_name) { buffer in
            guard let baseAddress = buffer.baseAddress else { return "" }
            return String(cString: baseAddress.assumingMemoryBound(to: CChar.self))
        }

        return BSDInfo(
            pid: Int32(info.pbi_pid),
            ppid: Int32(info.pbi_ppid),
            uid: info.pbi_uid,
            gid: info.pbi_gid,
            status: info.pbi_status,
            name: name
        )
    }
}

// MARK: - Errors

/// Errors from Darwin syscalls
public enum DarwinError: Error, LocalizedError {
    case syscallFailed(String, errno: Int32)
    case emptyResult(String)
    case processNotFound(Int32)

    public var errorDescription: String? {
        switch self {
        case .syscallFailed(let syscall, let err):
            let message = String(cString: strerror(err))
            return "\(syscall) failed: \(message) (errno: \(err))"
        case .emptyResult(let what):
            return "Empty result for \(what)"
        case .processNotFound(let pid):
            return "Process not found: \(pid)"
        }
    }
}
