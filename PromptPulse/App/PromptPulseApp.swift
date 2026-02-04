import SwiftUI

@main
struct PromptPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window
        Settings {
            SettingsView()
        }
    }
}
