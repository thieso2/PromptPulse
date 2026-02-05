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

    /// Filtered messages for display (delegates to AppState cache)
    private var displayedMessages: [Message] {
        state.displayedMessages
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
                    Text(Formatters.dateTimeFormatter.string(from: startTime))
                        .font(settings.captionFont)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                MarkdownExporter.export(session: session)
            }) {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Export as Markdown")

            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
    }

    private var filterToolbar: some View {
        VStack(spacing: 6) {
            // Search bar for messages
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Search messages...", text: Binding(
                    get: { state.messageSearchQuery },
                    set: { newValue in
                        state.messageSearchQuery = newValue
                        state.updateDisplayedMessages()
                    }
                ))
                .textFieldStyle(.plain)
                .font(settings.captionFont)

                if !state.messageSearchQuery.isEmpty {
                    Button(action: {
                        state.messageSearchQuery = ""
                        state.updateDisplayedMessages()
                    }) {
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

            // Filter row
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
                    Label("\(Formatters.tokens(usage.inputTokens)) in", systemImage: "arrow.down.circle")
                    Label("\(Formatters.tokens(usage.outputTokens)) out", systemImage: "arrow.up.circle")

                    if usage.cacheReadTokens > 0 {
                        Label("\(Formatters.tokens(usage.cacheReadTokens)) cached", systemImage: "memorychip")
                    }
                }
                .font(settings.captionFont)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Cost estimate (model-aware)
            if settings.showCostEstimate {
                let cost = CostCalculator.calculateForSession(session)
                Text(CostCalculator.format(cost: cost))
                    .font(settings.captionFont)
                    .foregroundColor(.green)
            }

            // Duration
            if let duration = session.duration {
                Text(Formatters.duration(duration))
                    .font(settings.captionFont)
                    .foregroundColor(.secondary)
            }
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
    @State private var showCopied = false

    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 8) {
                // Role icon
                Image(systemName: message.role.icon)
                    .font(settings.captionFont)
                    .foregroundColor(message.role.color)
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
                            Text(Formatters.timeFormatter.string(from: timestamp))
                                .foregroundColor(.secondary)
                        }

                        if showTokenStats {
                            let usage = message.usage
                            if usage.totalTokens > 0 {
                                Text(Formatters.tokens(usage.totalTokens))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if showModelBadge, let model = message.model {
                            ModelBadge(model: model, compact: true)
                        }
                    }
                    .font(.caption2)

                    // Tool calls (collapsed)
                    toolCallsSummary
                }

                Spacer()

                // Copy button (shown on hover)
                if isHovered {
                    Button(action: copyToClipboard) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundColor(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy message text")
                }

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

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.textContent, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopied = false
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.25)
        } else if isHovered {
            return Color.accentColor.opacity(0.1)
        }
        return message.role.color.opacity(0.1)
    }

    private var toolCallCount: Int {
        message.content.reduce(0) { count, block in
            if case .toolUse = block { return count + 1 }
            return count
        }
    }

    @ViewBuilder
    private var toolCallsSummary: some View {
        let count = toolCallCount
        if count > 0 {
            HStack(spacing: 4) {
                Image(systemName: "wrench.and.screwdriver")
                Text("\(count) tool call\(count == 1 ? "" : "s")")
            }
            .font(.caption2)
            .foregroundColor(.orange)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(4)
        }
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
                        Label("\(Formatters.tokens(interactionUsage.inputTokens)) in", systemImage: "arrow.down.circle")
                        Label("\(Formatters.tokens(interactionUsage.outputTokens)) out", systemImage: "arrow.up.circle")
                    }
                    .font(settings.captionFont)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if settings.showCostEstimate {
                    let cost = CostCalculator.calculatePerMessage(messages: promptWithResponses)
                    Text(CostCalculator.format(cost: cost))
                        .font(settings.captionFont)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
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
                Image(systemName: message.role.icon)
                    .foregroundColor(message.role.color)
                Text(message.role.displayName)
                    .font(settings.bodyFont.weight(.semibold))

                Spacer()

                if showModelBadge, let model = message.model {
                    ModelBadge(model: model)
                }

                if let timestamp = message.timestamp {
                    Text(Formatters.timeFormatter.string(from: timestamp))
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
                    Label("\(Formatters.tokens(message.usage.inputTokens)) in", systemImage: "arrow.down.circle")
                    Label("\(Formatters.tokens(message.usage.outputTokens)) out", systemImage: "arrow.up.circle")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(message.role.color.opacity(0.1))
        .cornerRadius(8)
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
