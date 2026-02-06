import Sparkle
import SwiftUI

/// Settings window view
struct SettingsView: View {
    @Bindable var settings = AppSettings.shared
    @ObservedObject private var checkForUpdatesVM: CheckForUpdatesViewModel

    init() {
        let updater = AppDelegate.shared!.updater
        _checkForUpdatesVM = ObservedObject(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }

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

            updatesTab
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 400, height: 320)
    }

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Theme section
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.headline)
                Picker("", selection: $settings.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Font Size section
            VStack(alignment: .leading, spacing: 8) {
                Text("Font Size")
                    .font(.headline)
                Picker("", selection: $settings.fontSize) {
                    ForEach(FontSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

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
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding(20)
    }

    private var displayTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Layout section
            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.headline)
                Toggle("Compact Mode", isOn: $settings.compactMode)
            }

            // Message Information section
            VStack(alignment: .leading, spacing: 8) {
                Text("Message Information")
                    .font(.headline)
                Toggle("Show Token Stats", isOn: $settings.showTokenStats)
                Toggle("Show Model Badge", isOn: $settings.showModelBadge)
                Toggle("Show Cost Estimate", isOn: $settings.showCostEstimate)
            }

            // Window section
            VStack(alignment: .leading, spacing: 8) {
                Text("Window Size")
                    .font(.headline)
                HStack {
                    Text("Width")
                    TextField("", value: Binding(
                        get: { Int(settings.windowWidth) },
                        set: { settings.windowWidth = CGFloat($0) }
                    ), format: .number)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)

                    Spacer().frame(width: 20)

                    Text("Height")
                    TextField("", value: Binding(
                        get: { Int(settings.windowHeight) },
                        set: { settings.windowHeight = CGFloat($0) }
                    ), format: .number)
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    Text("px")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private var updatesTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Software Updates")
                    .font(.headline)

                CheckForUpdatesView(viewModel: checkForUpdatesVM)

                if let updater = AppDelegate.shared?.updater {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                }
            }

            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    SettingsView()
}
