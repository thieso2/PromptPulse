import SwiftUI
import PromptWatchKit

/// Main popover view containing all UI sections
struct PopoverView: View {
    var state: AppState
    @FocusState private var isFocused: Bool
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = state.error {
                ErrorBannerView(
                    message: error.localizedDescription,
                    onDismiss: { state.dismissError() },
                    onRetry: { Task { await state.refresh() } }
                )
            }

            switch state.navigationState {
            case .projects:
                mainContentView

            case .sessions(let project):
                SessionListView(
                    project: project,
                    sessions: state.sessions,
                    isLoading: state.isLoadingSessions,
                    onSelect: { summary in
                        Task {
                            await state.loadSession(summary, from: .project(project))
                        }
                    },
                    onReveal: { summary in
                        state.revealInFinder(summary)
                    },
                    onBack: {
                        state.back()
                    },
                    selectedIndex: state.selectedIndex
                )

            case .processSessions(let process):
                ProcessSessionsView(
                    process: process,
                    sessions: state.sessions,
                    isLoading: state.isLoadingSessions,
                    onSelect: { summary in
                        Task {
                            await state.loadSession(summary, from: .process(process))
                        }
                    },
                    onReveal: { summary in
                        state.revealInFinder(summary)
                    },
                    onBack: {
                        state.back()
                    },
                    selectedIndex: state.selectedIndex
                )

            case .loadingSession(let origin):
                SessionLoadingView(
                    origin: origin,
                    onBack: {
                        state.back()
                    }
                )

            case .sessionDetail(let session, _):
                SessionDetailView(
                    session: session,
                    isLoading: state.isLoadingSession,
                    onBack: {
                        state.back()
                    },
                    onReveal: {
                        state.revealInFinder(session)
                    },
                    state: state
                )
            }
        }
        .frame(width: settings.windowWidth)
        .background(Color(NSColor.windowBackgroundColor))
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            state.back()
            return .handled
        }
        .onKeyPress(keys: [.init("r")], phases: .down) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            Task { await state.refresh() }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: ",")) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            AppDelegate.shared?.openSettings()
            return .handled
        }
        .onKeyPress(.upArrow) {
            state.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            state.selectNext()
            return .handled
        }
        .onKeyPress(.return) {
            Task { await state.activateSelection() }
            return .handled
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header with stats
            StatsHeaderView(
                processCount: state.activeProcessCount,
                projectCount: state.projects.count,
                totalCPU: state.totalCPU,
                totalMemoryMB: state.totalMemoryMB,
                isLoading: state.isLoading
            )
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search bar
            SearchBarView(query: Binding(
                get: { state.searchQuery },
                set: { newValue in
                    state.searchQuery = newValue
                    state.selectedIndex = 0
                }
            ))
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Running processes section (hidden during search)
                    if !state.isSearching && !state.processes.isEmpty {
                        ProcessListView(
                            processes: state.processes,
                            onSelect: { process in
                                Task {
                                    await state.loadSessions(for: process)
                                }
                            },
                            selectedIndex: state.selectedIndex,
                            indexOffset: 0
                        )
                    }

                    // Projects section (filtered during search)
                    if !state.filteredProjects.isEmpty {
                        ProjectListView(
                            projects: state.filteredProjects,
                            onSelect: { project in
                                Task {
                                    await state.loadSessions(for: project)
                                }
                            },
                            onReveal: { project in
                                state.openInFinder(project)
                            },
                            selectedIndex: state.selectedIndex,
                            indexOffset: state.isSearching ? 0 : state.processes.count
                        )
                    }

                    // Empty state
                    if state.isSearching && state.filteredProjects.isEmpty {
                        noSearchResultsView
                    } else if state.processes.isEmpty && state.projects.isEmpty && !state.isLoading {
                        EmptyStateView()
                    }
                }
                .padding()
            }
            Divider()

            // Footer with actions
            FooterView(
                lastRefresh: state.lastRefresh,
                onRefresh: {
                    Task {
                        await state.refresh()
                    }
                },
                onQuit: { state.quit() }
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var noSearchResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("No projects matching \"\(state.searchQuery)\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Search bar for filtering projects
struct SearchBarView: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.caption)

            TextField("Search projects...", text: $query)
                .textFieldStyle(.plain)
                .font(.caption)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(6)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
    }
}

/// Sessions view for a running process
struct ProcessSessionsView: View {
    let process: ClaudeProcess
    let sessions: [SessionSummary]
    let isLoading: Bool
    let onSelect: (SessionSummary) -> Void
    let onReveal: (SessionSummary) -> Void
    let onBack: () -> Void
    var selectedIndex: Int = -1

    private var projectName: String {
        guard let dir = process.workingDirectory else { return process.name }
        return URL(fileURLWithPath: dir).lastPathComponent
    }

    private var shortWorkingDir: String {
        guard let dir = process.workingDirectory else { return "unknown" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) {
            return "~" + dir.dropFirst(home.count)
        }
        return dir
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(projectName)
                            .font(.headline)
                    }
                    Text(shortWorkingDir)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Sessions list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if isLoading {
                        loadingView
                    } else if sessions.isEmpty {
                        emptyView
                    } else {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            SessionSummaryRowView(
                                session: session,
                                isSelected: index == selectedIndex,
                                onSelect: { onSelect(session) },
                                onReveal: { onReveal(session) }
                            )
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading sessions...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("No sessions found")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }
}

/// Header showing status
struct StatsHeaderView: View {
    let processCount: Int
    let projectCount: Int
    var totalCPU: Double = 0
    var totalMemoryMB: Double = 0
    let isLoading: Bool

    var body: some View {
        HStack {
            // Status indicator
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(processCount > 0 ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(processCount > 0 ? "\(processCount) Active" : "No Active Sessions")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                HStack(spacing: 8) {
                    if projectCount > 0 {
                        Text("\(projectCount) projects")
                            .foregroundColor(.secondary)
                    }

                    if processCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text(Formatters.cpu(totalCPU))
                        }
                        .foregroundColor(cpuColor(for: totalCPU))

                        HStack(spacing: 4) {
                            Image(systemName: "memorychip")
                            Text(Formatters.memory(totalMemoryMB))
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .padding(.leading, 8)
            }
        }
    }

}

/// Empty state view
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No Claude Sessions")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Start a Claude Code session to see it here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Footer with refresh and quit buttons
struct FooterView: View {
    let lastRefresh: Date?
    let onRefresh: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack {
            if let lastRefresh = lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh (⌘R)")

            Button(action: {
                AppDelegate.shared?.openSettings()
            }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            .help("Settings (⌘,)")

            Button(action: onQuit) {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit PromptPulse")
        }
    }
}

/// Loading view shown while session is being parsed
struct SessionLoadingView: View {
    let origin: SessionDetailOrigin
    let onBack: () -> Void

    private var originName: String {
        switch origin {
        case .project(let project):
            return project.name
        case .process(let process):
            return process.workingDirectory.map { URL(fileURLWithPath: $0).lastPathComponent } ?? process.name
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(originName)
                    .font(.headline)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Loading indicator
            VStack(spacing: 16) {
                Spacer()

                ProgressView()
                    .scaleEffect(1.2)

                Text("Loading session...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Parsing messages")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 200)
    }
}

/// Dismissable error banner shown at the top of the popover
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()

            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderless)
            .help("Retry")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.85))
    }
}
