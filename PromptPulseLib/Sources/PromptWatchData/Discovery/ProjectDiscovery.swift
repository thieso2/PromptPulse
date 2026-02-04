import Foundation
import PromptWatchDomain

/// Service for discovering and managing project directories
public struct ProjectDiscovery: Sendable {
    private let sessionDiscovery: SessionDiscovery

    public init(sessionDiscovery: SessionDiscovery = SessionDiscovery()) {
        self.sessionDiscovery = sessionDiscovery
    }

    /// Find all known project directories with Claude sessions
    public func findProjects() throws -> [ProjectDir] {
        try sessionDiscovery.findAllProjects()
    }

    /// Find project directory for a given path
    public func findProject(forPath path: String) throws -> ProjectDir? {
        let encodedName = ProjectDir.encode(path: path)
        let projects = try sessionDiscovery.findAllProjects()
        return projects.first { $0.encodedName == encodedName }
    }

    /// Get project directory by encoded name
    public func getProject(encodedName: String) throws -> ProjectDir? {
        let projects = try sessionDiscovery.findAllProjects()
        return projects.first { $0.encodedName == encodedName }
    }

    /// Find projects with active Claude processes
    public func findActiveProjects(
        processes: [ClaudeProcess]
    ) throws -> [(project: ProjectDir, processes: [ClaudeProcess])] {
        let allProjects = try sessionDiscovery.findAllProjects()

        var result: [(ProjectDir, [ClaudeProcess])] = []

        for project in allProjects {
            let matchingProcesses = processes.filter { process in
                guard let workDir = process.workingDirectory else { return false }
                let normalizedWorkDir = (workDir as NSString).standardizingPath
                let normalizedProject = (project.originalPath as NSString).standardizingPath
                return normalizedWorkDir.hasPrefix(normalizedProject)
            }

            if !matchingProcesses.isEmpty {
                result.append((project, matchingProcesses))
            }
        }

        return result
    }

    /// Suggest project path from a working directory
    public func suggestProjectPath(fromWorkDir workDir: String) -> String? {
        // Try to find git root
        let fm = FileManager.default
        var current = (workDir as NSString).standardizingPath

        while current != "/" {
            let gitDir = (current as NSString).appendingPathComponent(".git")
            if fm.fileExists(atPath: gitDir) {
                return current
            }
            current = (current as NSString).deletingLastPathComponent
        }

        // Fall back to the working directory itself
        return workDir
    }
}
