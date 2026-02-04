import Foundation
import AppKit
import PromptWatchKit

/// Origin of session detail view for back navigation
enum SessionDetailOrigin: Equatable {
    case project(ProjectDir)
    case process(ClaudeProcess)
}

/// Navigation state for the popover
enum NavigationState: Equatable {
    case projects
    case sessions(project: ProjectDir)
    case processSessions(process: ClaudeProcess)
    case loadingSession(origin: SessionDetailOrigin)
    case sessionDetail(session: Session, origin: SessionDetailOrigin)
}

/// Main application state using @Observable pattern
@Observable
@MainActor
final class AppState {
    // MARK: - Navigation State

    var navigationState: NavigationState = .projects

    // MARK: - Data State

    var projects: [ProjectDir] = []
    var sessions: [SessionSummary] = []
    var processes: [ClaudeProcess] = []
    var loadedSession: Session?

    // MARK: - Loading State

    var isLoading = false
    var isLoadingSessions = false
    var isLoadingSession = false
    var error: Error?
    var lastRefresh: Date?

    // MARK: - Selection State (for keyboard navigation)

    var selectedIndex: Int = 0

    // MARK: - Message View State

    var messageSelectedIndex: Int = 0
    var showOnlyUserPrompts: Bool = false
    var expandedPromptId: String? = nil

    /// Toggle user prompts filter
    func toggleUserPromptsFilter() {
        showOnlyUserPrompts.toggle()
        messageSelectedIndex = 0
    }

    // MARK: - Private

    private let kit = PromptWatchKit.shared
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30.0

    // MARK: - Computed Properties

    /// Number of active Claude processes
    var activeProcessCount: Int {
        processes.count
    }

    /// Whether any Claude processes are running
    var hasActiveProcesses: Bool {
        !processes.isEmpty
    }

    /// Total CPU usage across all processes
    var totalCPU: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    /// Total memory usage across all processes (in MB)
    var totalMemoryMB: Double {
        processes.reduce(0) { $0 + $1.memoryMB }
    }

    /// Currently selected project
    var selectedProject: ProjectDir? {
        if case .sessions(let project) = navigationState {
            return project
        }
        if case .sessionDetail(_, let origin) = navigationState {
            if case .project(let project) = origin {
                return project
            }
        }
        return nil
    }

    /// Currently selected process
    var selectedProcess: ClaudeProcess? {
        if case .processSessions(let process) = navigationState {
            return process
        }
        if case .sessionDetail(_, let origin) = navigationState {
            if case .process(let process) = origin {
                return process
            }
        }
        return nil
    }

    // MARK: - Public Methods

    /// Refresh all data
    func refresh() async {
        isLoading = true
        error = nil

        defer {
            isLoading = false
            lastRefresh = Date()
        }

        do {
            async let projectsTask = kit.getProjects()
            async let processesTask = kit.getProcesses(includeHelpers: false)

            let (fetchedProjects, fetchedProcesses) = try await (projectsTask, processesTask)

            // Sort projects by last activity
            projects = fetchedProjects.sorted {
                ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast)
            }
            processes = fetchedProcesses

            updateStatusIcon()

        } catch {
            self.error = error
            logMessage("Refresh error: \(error.localizedDescription)")
        }
    }

    /// Load sessions for a specific project
    func loadSessions(for project: ProjectDir) async {
        navigationState = .sessions(project: project)
        isLoadingSessions = true
        sessions = []

        defer {
            isLoadingSessions = false
        }

        do {
            let fetchedSessions = try await kit.getSessions(forProject: project.originalPath)
            // Sort by last modified
            sessions = fetchedSessions.sorted {
                ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast)
            }
        } catch {
            self.error = error
            logMessage("Load sessions error: \(error.localizedDescription)")
        }
    }

    /// Load sessions for a running process (by working directory)
    func loadSessions(for process: ClaudeProcess) async {
        guard let workDir = process.workingDirectory else {
            logMessage("Process has no working directory")
            return
        }

        navigationState = .processSessions(process: process)
        isLoadingSessions = true
        sessions = []

        defer {
            isLoadingSessions = false
        }

        do {
            let fetchedSessions = try await kit.getSessions(forProject: workDir)
            // Sort by last modified
            sessions = fetchedSessions.sorted {
                ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast)
            }
        } catch {
            self.error = error
            logMessage("Load sessions for process error: \(error.localizedDescription)")
        }
    }

    /// Load a full session with messages
    func loadSession(_ summary: SessionSummary, from origin: SessionDetailOrigin) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        logMessage("loadSession START: \(summary.filePath)")

        // Navigate to loading state immediately for responsive UI
        navigationState = .loadingSession(origin: origin)
        isLoadingSession = true
        loadedSession = nil
        logMessage("loadSession: nav state set, yielding... (\(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms)")

        // Yield to let UI update before heavy work
        await Task.yield()
        logMessage("loadSession: after yield (\(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms)")

        do {
            logMessage("loadSession: calling kit.loadSession...")
            let session = try await kit.loadSession(filePath: summary.filePath)
            logMessage("loadSession: kit returned (\(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms), \(session.messages.count) messages")
            loadedSession = session
            navigationState = .sessionDetail(session: session, origin: origin)
            logMessage("loadSession: nav updated (\(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms)")
        } catch {
            self.error = error
            logMessage("Load session error: \(error.localizedDescription)")
            // Navigate back on error
            back()
        }

        isLoadingSession = false
        logMessage("loadSession DONE (\(Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms)")
    }

    /// Navigate back
    func back() {
        switch navigationState {
        case .projects:
            break // Already at root
        case .sessions:
            navigationState = .projects
            sessions = []
            selectedIndex = 0
        case .processSessions:
            navigationState = .projects
            sessions = []
            selectedIndex = 0
        case .loadingSession(let origin):
            loadedSession = nil
            selectedIndex = 0
            switch origin {
            case .project(let project):
                navigationState = .sessions(project: project)
            case .process(let process):
                navigationState = .processSessions(process: process)
            }
        case .sessionDetail(_, let origin):
            // If viewing expanded prompt, collapse it first
            if expandedPromptId != nil {
                expandedPromptId = nil
                return
            }
            // Otherwise go back to session list
            loadedSession = nil
            selectedIndex = 0
            messageSelectedIndex = 0
            showOnlyUserPrompts = false
            expandedPromptId = nil
            switch origin {
            case .project(let project):
                navigationState = .sessions(project: project)
            case .process(let process):
                navigationState = .processSessions(process: process)
            }
        }
    }

    // MARK: - Keyboard Navigation

    /// Filtered messages for display
    var displayedMessages: [Message] {
        guard case .sessionDetail(let session, _) = navigationState else { return [] }
        if showOnlyUserPrompts {
            return session.messages.filter { $0.role == .user }
        }
        return session.messages
    }

    /// Total number of selectable items in current view
    var selectableItemCount: Int {
        switch navigationState {
        case .projects:
            return processes.count + projects.count
        case .sessions, .processSessions:
            return sessions.count
        case .sessionDetail:
            return displayedMessages.count
        case .loadingSession:
            return 0
        }
    }

    /// Move selection up
    func selectPrevious() {
        if case .sessionDetail = navigationState {
            if displayedMessages.count > 0 {
                messageSelectedIndex = max(0, messageSelectedIndex - 1)
            }
        } else if selectableItemCount > 0 {
            selectedIndex = max(0, selectedIndex - 1)
        }
    }

    /// Move selection down
    func selectNext() {
        if case .sessionDetail = navigationState {
            if displayedMessages.count > 0 {
                messageSelectedIndex = min(displayedMessages.count - 1, messageSelectedIndex + 1)
            }
        } else if selectableItemCount > 0 {
            selectedIndex = min(selectableItemCount - 1, selectedIndex + 1)
        }
    }

    /// Activate current selection
    func activateSelection() async {
        switch navigationState {
        case .projects:
            // First processes, then projects
            if selectedIndex < processes.count {
                let process = processes[selectedIndex]
                await loadSessions(for: process)
            } else {
                let projectIndex = selectedIndex - processes.count
                if projectIndex < projects.count {
                    let project = projects[projectIndex]
                    await loadSessions(for: project)
                }
            }
        case .sessions(let project):
            if selectedIndex < sessions.count {
                let session = sessions[selectedIndex]
                await loadSession(session, from: .project(project))
            }
        case .processSessions(let process):
            if selectedIndex < sessions.count {
                let session = sessions[selectedIndex]
                await loadSession(session, from: .process(process))
            }
        case .sessionDetail:
            // In user prompts mode, drill down on selected message
            if showOnlyUserPrompts && messageSelectedIndex < displayedMessages.count {
                let message = displayedMessages[messageSelectedIndex]
                if message.role == .user {
                    expandedPromptId = message.id
                }
            }
        case .loadingSession:
            break
        }
    }

    /// Reveal session file in Finder
    func revealInFinder(_ session: Session) {
        NSWorkspace.shared.selectFile(session.filePath, inFileViewerRootedAtPath: "")
    }

    /// Reveal session summary file in Finder
    func revealInFinder(_ summary: SessionSummary) {
        NSWorkspace.shared.selectFile(summary.filePath, inFileViewerRootedAtPath: "")
    }

    /// Open project directory in Finder
    func openInFinder(_ project: ProjectDir) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.originalPath)
    }

    /// Start auto-refresh timer
    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    /// Stop auto-refresh timer
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Quit the application
    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private Methods

    private func updateStatusIcon() {
        AppDelegate.shared?.updateStatusIcon(
            hasActiveProcesses: hasActiveProcesses,
            totalCPU: totalCPU,
            totalMemoryMB: totalMemoryMB
        )
    }
}

/// Log to stdout with immediate flush
func logMessage(_ message: String) {
    let output = "[PromptPulse] \(message)\n"
    fputs(output, stdout)
    fflush(stdout)
}
