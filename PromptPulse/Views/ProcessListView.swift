import SwiftUI
import PromptWatchKit

/// List of running Claude processes
struct ProcessListView: View {
    let processes: [ClaudeProcess]
    let onSelect: (ClaudeProcess) -> Void
    var selectedIndex: Int = -1
    var indexOffset: Int = 0  // Offset for selection when combined with other lists

    private var totalCPU: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    private var totalMemory: Double {
        processes.reduce(0) { $0 + $1.memoryMB }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.green)
                Text("Running Processes")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()

                // Totals
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "cpu")
                            .font(.caption2)
                        Text(Formatters.cpu(totalCPU))
                            .font(.caption)
                    }
                    .foregroundColor(cpuColor(for: totalCPU))

                    HStack(spacing: 2) {
                        Image(systemName: "memorychip")
                            .font(.caption2)
                        Text(Formatters.memory(totalMemory))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                Text("\(processes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Process list
            ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                ProcessRowView(
                    process: process,
                    isSelected: (indexOffset + index) == selectedIndex,
                    onSelect: { onSelect(process) }
                )
            }
        }
    }

}

/// Single process row
struct ProcessRowView: View {
    let process: ClaudeProcess
    var isSelected: Bool = false
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    // Project name and helper badge
                    HStack {
                        Text(projectName)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)

                        if process.isHelper {
                            Text("Helper")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }

                    // Working directory
                    Text(shortWorkingDir)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Metrics
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 8) {
                        // CPU
                        HStack(spacing: 2) {
                            Image(systemName: "cpu")
                                .font(.caption2)
                            Text(Formatters.cpu(process.cpuPercent))
                                .font(.caption)
                        }
                        .foregroundColor(cpuColor(for: process.cpuPercent))

                        // Memory
                        HStack(spacing: 2) {
                            Image(systemName: "memorychip")
                                .font(.caption2)
                            Text(Formatters.memory(process.memoryMB))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Uptime
                    if let startTime = process.startTime {
                        Text(Formatters.uptime(from: startTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            return Color.accentColor.opacity(0.15)
        }
        return Color(NSColor.controlBackgroundColor).opacity(0.5)
    }

    private var projectName: String {
        guard let dir = process.workingDirectory else { return process.name }
        let url = URL(fileURLWithPath: dir)
        return url.lastPathComponent
    }

    private var shortWorkingDir: String {
        guard let dir = process.workingDirectory else { return "unknown" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) {
            return "~" + dir.dropFirst(home.count)
        }
        return dir
    }

}
