import SwiftUI
import PromptWatchKit

/// List of sessions for a project
struct SessionListView: View {
    let project: ProjectDir
    let sessions: [SessionSummary]
    let isLoading: Bool
    let onSelect: (SessionSummary) -> Void
    let onReveal: (SessionSummary) -> Void
    let onBack: () -> Void
    var selectedIndex: Int = -1

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            headerView
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

    private var headerView: some View {
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
                Text(project.name)
                    .font(.headline)
                Text("\(sessions.count) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

/// Single session summary row
struct SessionSummaryRowView: View {
    let session: SessionSummary
    var isSelected: Bool = false
    let onSelect: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Main content - clickable to drill down
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.shortId)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)

                        HStack(spacing: 6) {
                            if let lastModified = session.lastModified {
                                Text(timeAgo(from: lastModified))
                                    .foregroundColor(.secondary)
                            }

                            Text(session.formattedFileSize)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption2)
                    }

                    Spacer()

                    // Chevron to indicate drill-down
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Reveal in Finder button
            Button(action: onReveal) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(rowBackground)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.25)
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        }
        return Color.clear
    }

    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        }
        if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}
