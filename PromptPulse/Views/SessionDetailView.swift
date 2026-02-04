import SwiftUI
import PromptWatchKit

/// Detail view showing session messages
struct SessionDetailView: View {
    let session: Session
    let isLoading: Bool
    let onBack: () -> Void
    let onReveal: () -> Void
    var state: AppState  // Use shared state for keyboard navigation

    @Bindable private var settings = AppSettings.shared

    /// Cached date formatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Filtered messages based on toggle
    private var displayedMessages: [Message] {
        if state.showOnlyUserPrompts {
            return session.messages.filter { $0.role == .user }
        }
        return session.messages
    }

    /// Get the model used in this session
    private var sessionModel: String? {
        session.messages.first(where: { $0.model != nil })?.model
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Filter toolbar
            filterToolbar
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Messages list or expanded prompt view
            if let promptId = state.expandedPromptId {
                PromptDetailView(
                    session: session,
                    promptId: promptId,
                    onBack: { state.expandedPromptId = nil }
                )
            } else {
                messagesList
            }

            Divider()

            // Stats footer
            statsFooter
                .padding(.horizontal)
                .padding(.vertical, 8)
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
                HStack(spacing: 6) {
                    Text("\(session.messages.count) messages")
                        .font(settings.headlineFont)

                    if settings.showModelBadge, let model = sessionModel {
                        ModelBadge(model: model)
                    }
                }

                if let startTime = session.startTime {
                    Text(formattedDate(startTime))
                        .font(settings.captionFont)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
    }

    private var filterToolbar: some View {
        HStack {
            Button(action: {
                state.toggleUserPromptsFilter()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: state.showOnlyUserPrompts ? "checkmark.square.fill" : "square")
                        .foregroundColor(state.showOnlyUserPrompts ? .accentColor : .secondary)
                    Image(systemName: "person.fill")
                    Text("User Prompts Only")
                }
                .font(settings.captionFont)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(displayedMessages.count) shown")
                .font(settings.captionFont)
                .foregroundColor(.secondary)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: settings.compactMode ? 4 : 8) {
                    if isLoading {
                        loadingView
                    } else if displayedMessages.isEmpty {
                        emptyView
                    } else {
                        ForEach(Array(displayedMessages.enumerated()), id: \.element.id) { index, message in
                            MessageRowView(
                                message: message,
                                isSelected: index == state.messageSelectedIndex,
                                showTokenStats: settings.showTokenStats,
                                showModelBadge: settings.showModelBadge,
                                isUserPromptsMode: state.showOnlyUserPrompts,
                                onSelect: {
                                    state.messageSelectedIndex = index
                                    if state.showOnlyUserPrompts && message.role == .user {
                                        state.expandedPromptId = message.id
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: state.messageSelectedIndex) { _, newIndex in
                if newIndex < displayedMessages.count {
                    withAnimation {
                        proxy.scrollTo(displayedMessages[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading messages...")
                .font(settings.captionFont)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("No messages found")
                .font(settings.captionFont)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var statsFooter: some View {
        HStack {
            // Token stats
            if settings.showTokenStats {
                let usage = session.totalUsage
                HStack(spacing: 8) {
                    Label("\(formatTokens(usage.inputTokens)) in", systemImage: "arrow.down.circle")
                    Label("\(formatTokens(usage.outputTokens)) out", systemImage: "arrow.up.circle")

                    if usage.cacheReadTokens > 0 {
                        Label("\(formatTokens(usage.cacheReadTokens)) cached", systemImage: "memorychip")
                    }
                }
                .font(settings.captionFont)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Cost estimate
            if settings.showCostEstimate {
                let cost = CostCalculator.shared.calculate(usage: session.totalUsage)
                Text(CostCalculator.format(cost: cost))
                    .font(settings.captionFont)
                    .foregroundColor(.green)
            }

            // Duration
            if let duration = session.duration {
                Text(formattedDuration(duration))
                    .font(settings.captionFont)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Formatting

    private func formattedDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

// MARK: - Message Row View

struct MessageRowView: View {
    let message: Message
    var isSelected: Bool = false
    var showTokenStats: Bool = true
    var showModelBadge: Bool = true
    var isUserPromptsMode: Bool = false
    let onSelect: () -> Void

    @State private var isHovered = false

    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                // Role icon
                Image(systemName: roleIcon)
                    .font(settings.captionFont)
                    .foregroundColor(roleColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    // Message content
                    Text(message.textContent)
                        .font(settings.bodyFont)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .lineLimit(isUserPromptsMode ? 3 : nil)

                    // Metadata row
                    HStack(spacing: 8) {
                        if let timestamp = message.timestamp {
                            Text(formattedTime(timestamp))
                                .foregroundColor(.secondary)
                        }

                        if showTokenStats {
                            let usage = message.usage
                            if usage.totalTokens > 0 {
                                Text(formatTokens(usage.totalTokens))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if showModelBadge, let model = message.model {
                            ModelBadge(model: model, compact: true)
                        }
                    }
                    .font(.caption2)

                    // Tool calls (collapsed)
                    if hasToolCalls {
                        toolCallsSummary
                    }
                }

                Spacer()

                // Drill-down indicator for user prompts
                if isUserPromptsMode && message.role == .user {
                    Image(systemName: "chevron.right")
                        .font(settings.captionFont)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, settings.compactMode ? 4 : 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(rowBackground)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var roleIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .system: return "gear"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .purple
        case .system: return .gray
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.25)
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        }

        switch message.role {
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color.purple.opacity(0.1)
        case .system: return Color.gray.opacity(0.1)
        }
    }

    private var hasToolCalls: Bool {
        message.content.contains { block in
            if case .toolUse = block { return true }
            return false
        }
    }

    private var toolCallsSummary: some View {
        let toolCount = message.content.filter { block in
            if case .toolUse = block { return true }
            return false
        }.count

        return HStack(spacing: 4) {
            Image(systemName: "wrench.and.screwdriver")
            Text("\(toolCount) tool call\(toolCount == 1 ? "" : "s")")
        }
        .font(.caption2)
        .foregroundColor(.orange)
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(4)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count) tok"
    }
}

// MARK: - Model Badge

struct ModelBadge: View {
    let model: String
    var compact: Bool = false

    private var shortName: String {
        if model.contains("opus") {
            return "Opus"
        }
        if model.contains("sonnet") {
            return "Sonnet"
        }
        if model.contains("haiku") {
            return "Haiku"
        }
        if let lastComponent = model.split(separator: "-").last {
            return String(lastComponent)
        }
        return model
    }

    private var badgeColor: Color {
        if model.contains("opus") {
            return .purple
        }
        if model.contains("sonnet") {
            return .blue
        }
        if model.contains("haiku") {
            return .green
        }
        return .secondary
    }

    var body: some View {
        Text(shortName)
            .font(compact ? .caption2 : .caption)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, compact ? 1 : 2)
            .background(badgeColor.opacity(0.2))
            .foregroundColor(badgeColor)
            .cornerRadius(4)
    }
}

// MARK: - Prompt Detail View

/// Shows a user prompt and all subsequent agent work until the next user message
struct PromptDetailView: View {
    let session: Session
    let promptId: String
    let onBack: () -> Void

    @Bindable private var settings = AppSettings.shared

    /// Get the user message and all subsequent messages until the next user message
    private var promptWithResponses: [Message] {
        guard let startIndex = session.messages.firstIndex(where: { $0.id == promptId }) else {
            return []
        }

        var messages: [Message] = [session.messages[startIndex]]

        for i in (startIndex + 1)..<session.messages.count {
            let msg = session.messages[i]
            if msg.role == .user {
                break
            }
            messages.append(msg)
        }

        return messages
    }

    /// Total tokens for this interaction
    private var interactionUsage: TokenUsage {
        promptWithResponses.reduce(.zero) { $0 + $1.usage }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back to prompts")
                    }
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("\(promptWithResponses.count) messages")
                    .font(settings.captionFont)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: settings.compactMode ? 4 : 8) {
                    ForEach(promptWithResponses) { message in
                        ExpandedMessageView(
                            message: message,
                            showTokenStats: settings.showTokenStats,
                            showModelBadge: settings.showModelBadge
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Stats for this interaction
            HStack {
                if settings.showTokenStats {
                    HStack(spacing: 8) {
                        Label("\(formatTokens(interactionUsage.inputTokens)) in", systemImage: "arrow.down.circle")
                        Label("\(formatTokens(interactionUsage.outputTokens)) out", systemImage: "arrow.up.circle")
                    }
                    .font(settings.captionFont)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if settings.showCostEstimate {
                    let cost = CostCalculator.shared.calculate(usage: interactionUsage)
                    Text(CostCalculator.format(cost: cost))
                        .font(settings.captionFont)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - Expanded Message View

/// Full message view with all content blocks
struct ExpandedMessageView: View {
    let message: Message
    var showTokenStats: Bool = true
    var showModelBadge: Bool = true

    @Bindable private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: roleIcon)
                    .foregroundColor(roleColor)
                Text(roleName)
                    .font(settings.bodyFont.weight(.semibold))

                Spacer()

                if showModelBadge, let model = message.model {
                    ModelBadge(model: model)
                }

                if let timestamp = message.timestamp {
                    Text(formattedTime(timestamp))
                        .font(settings.captionFont)
                        .foregroundColor(.secondary)
                }
            }

            // Content blocks
            ForEach(Array(message.content.enumerated()), id: \.offset) { _, block in
                ContentBlockView(block: block)
            }

            // Token stats
            if showTokenStats && message.usage.totalTokens > 0 {
                HStack(spacing: 8) {
                    Label("\(message.usage.inputTokens) in", systemImage: "arrow.down.circle")
                    Label("\(message.usage.outputTokens) out", systemImage: "arrow.up.circle")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
    }

    private var roleIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .system: return "gear"
        }
    }

    private var roleName: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "Claude"
        case .system: return "System"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .purple
        case .system: return .gray
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color.purple.opacity(0.1)
        case .system: return Color.gray.opacity(0.1)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private func formattedTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
}

// MARK: - Content Block View

struct ContentBlockView: View {
    let block: ContentBlock

    @Bindable private var settings = AppSettings.shared

    var body: some View {
        switch block {
        case .text(let text):
            Text(text)
                .font(settings.bodyFont)
                .textSelection(.enabled)

        case .thinking(let text):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "brain")
                    Text("Thinking")
                        .fontWeight(.medium)
                }
                .font(settings.captionFont)
                .foregroundColor(.orange)

                Text(text)
                    .font(settings.bodyFont)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)

        case .toolUse(let id, let name, let input):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver")
                    Text(name)
                        .fontWeight(.medium)
                }
                .font(settings.captionFont)
                .foregroundColor(.orange)

                if !input.isEmpty {
                    Text(input)
                        .font(.system(settings.compactMode ? .caption2 : .caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(10)
                }

                Text("ID: \(id.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)

        case .toolResult(let toolUseId, let content, let isError):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isError ? "xmark.circle" : "checkmark.circle")
                    Text("Result")
                        .fontWeight(.medium)
                }
                .font(settings.captionFont)
                .foregroundColor(isError ? .red : .green)

                Text(content)
                    .font(.system(settings.compactMode ? .caption2 : .caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(20)

                Text("Tool: \(toolUseId.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(8)
            .background((isError ? Color.red : Color.green).opacity(0.1))
            .cornerRadius(6)

        case .image(let mediaType, _):
            HStack(spacing: 4) {
                Image(systemName: "photo")
                Text("Image (\(mediaType))")
            }
            .font(settings.captionFont)
            .foregroundColor(.secondary)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
    }
}
