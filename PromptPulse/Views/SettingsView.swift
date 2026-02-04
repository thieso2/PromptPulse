import SwiftUI

/// Settings window view
struct SettingsView: View {
    @Bindable var settings = AppSettings.shared

    var body: some View {
        TabView {
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            displayTab
                .tabItem {
                    Label("Display", systemImage: "text.alignleft")
                }
        }
        .frame(width: 400, height: 300)
        .padding()
    }

    private var appearanceTab: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Font Size") {
                Picker("Font Size", selection: $settings.fontSize) {
                    ForEach(FontSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                // Preview
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(settings.headlineFont)
                    Text("This is how body text will appear in the app.")
                        .font(settings.bodyFont)
                    Text("Caption and metadata text")
                        .font(settings.captionFont)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
    }

    private var displayTab: some View {
        Form {
            Section("Layout") {
                Toggle("Compact Mode", isOn: $settings.compactMode)
                    .help("Reduce spacing between elements")
            }

            Section("Message Information") {
                Toggle("Show Token Stats", isOn: $settings.showTokenStats)
                    .help("Display token counts on messages")

                Toggle("Show Model Badge", isOn: $settings.showModelBadge)
                    .help("Display which model generated each response")

                Toggle("Show Cost Estimate", isOn: $settings.showCostEstimate)
                    .help("Display estimated API cost")
            }

            Section("Window") {
                HStack {
                    Text("Default Width")
                    Spacer()
                    TextField("Width", value: Binding(
                        get: { Int(settings.windowWidth) },
                        set: { settings.windowWidth = CGFloat($0) }
                    ), format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Default Height")
                    Spacer()
                    TextField("Height", value: Binding(
                        get: { Int(settings.windowHeight) },
                        set: { settings.windowHeight = CGFloat($0) }
                    ), format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
