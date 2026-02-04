import Foundation

/// Service for resolving working directories of processes
public struct WorkingDirectoryResolver: Sendable {
    public init() {}

    /// Get the working directory for a process
    public func resolve(pid: Int32) -> String? {
        do {
            return try DarwinSyscalls.getWorkingDirectory(pid: pid)
        } catch {
            return nil
        }
    }

    /// Get working directories for multiple processes
    public func resolve(pids: [Int32]) -> [Int32: String] {
        var results: [Int32: String] = [:]

        for pid in pids {
            if let dir = resolve(pid: pid) {
                results[pid] = dir
            }
        }

        return results
    }
}

/// Validation of process-directory associations
public struct SessionValidator: Sendable {
    public init() {}

    /// Check if a Claude process is associated with a specific project directory
    public func validate(process pid: Int32, projectPath: String) -> Bool {
        guard let workDir = WorkingDirectoryResolver().resolve(pid: pid) else {
            return false
        }

        // Normalize paths for comparison
        let normalizedWorkDir = (workDir as NSString).standardizingPath
        let normalizedProject = (projectPath as NSString).standardizingPath

        // Check if the working directory is the project or a subdirectory
        return normalizedWorkDir.hasPrefix(normalizedProject) ||
               normalizedProject.hasPrefix(normalizedWorkDir)
    }

    /// Find which project directory a process is associated with
    public func findProjectPath(for pid: Int32, in knownProjects: [String]) -> String? {
        guard let workDir = WorkingDirectoryResolver().resolve(pid: pid) else {
            return nil
        }

        let normalizedWorkDir = (workDir as NSString).standardizingPath

        // Find the best matching project (most specific path)
        var bestMatch: (path: String, depth: Int)?

        for project in knownProjects {
            let normalizedProject = (project as NSString).standardizingPath

            if normalizedWorkDir.hasPrefix(normalizedProject) {
                let depth = normalizedProject.components(separatedBy: "/").count
                if bestMatch == nil || depth > bestMatch!.depth {
                    bestMatch = (normalizedProject, depth)
                }
            }
        }

        return bestMatch?.path
    }
}
