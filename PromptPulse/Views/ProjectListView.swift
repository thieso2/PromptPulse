import SwiftUI
import PromptWatchKit

/// List of projects with session counts
struct ProjectListView: View {
    let projects: [ProjectDir]
    let onSelect: (ProjectDir) -> Void
    let onReveal: (ProjectDir) -> Void
    var selectedIndex: Int = -1
    var indexOffset: Int = 0  // Offset for selection when combined with other lists

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text("Projects")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(projects.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Project list
            if projects.isEmpty {
                Text("No projects found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                    ProjectRowView(
                        project: project,
                        isSelected: (indexOffset + index) == selectedIndex,
                        onSelect: { onSelect(project) },
                        onReveal: { onReveal(project) }
                    )
                }
            }
        }
    }
}

/// Single project row
struct ProjectRowView: View {
    let project: ProjectDir
    var isSelected: Bool = false
    let onSelect: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Main content - clickable to drill down
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.system(.body, design: .default))
                            .lineLimit(1)
                            .foregroundColor(.primary)

                        HStack(spacing: 6) {
                            Text("\(project.sessionCount) sessions")
                                .foregroundColor(.secondary)

                            if let lastActivity = project.lastActivity {
                                Text(timeAgo(from: lastActivity))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.caption2)
                    }

                    Spacer()

                    // Chevron to indicate drill-down
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Reveal in Finder button
            Button(action: onReveal) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Open in Finder")
        }
        .background(rowBackground)
        .cornerRadius(6)
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
