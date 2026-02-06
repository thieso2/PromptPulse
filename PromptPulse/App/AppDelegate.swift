import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    let state = AppState()
    private var eventMonitor: Any?
    private var themeObservation: Any?

    /// Sparkle updater controller — initialized once at launch.
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    /// Convenience accessor for the underlying updater.
    var updater: SPUUpdater { updaterController.updater }

    private var settings: AppSettings { AppSettings.shared }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        logMessage("Starting up...")
        logMessage("Version: 0.2.0")
        logMessage("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        // Create status bar item
        logMessage("Creating menubar status item...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon(hasActiveProcesses: false)
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
            logMessage("Menubar icon installed")
        }

        // Create panel window (resizable)
        logMessage("Creating panel window...")
        createPanel()

        // Setup click-outside-to-close
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self = self, let panel = self.panel else { return }
                if panel.isVisible {
                    // Check if click is outside the panel
                    let clickLocation = event.locationInWindow
                    if event.window != panel {
                        self.closePanel()
                    }
                }
            }
        }

        // Initial data refresh
        logMessage("Performing initial data refresh...")
        Task {
            await state.refresh()
        }

        // Start auto-refresh timer
        logMessage("Starting auto-refresh timer (30s interval)...")
        state.startAutoRefresh()

        logMessage("Startup complete. Click the menubar icon to open.")
    }

    private func createPanel() {
        let contentView = PopoverView(state: state)
            .background(Color(NSColor.windowBackgroundColor))
        let hostingView = NSHostingView(rootView: contentView)

        // Create panel with standard window controls
        let panelRect = NSRect(x: 0, y: 0, width: settings.windowWidth, height: settings.windowHeight)
        panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel?.title = "PromptPulse"
        panel?.backgroundColor = NSColor.windowBackgroundColor
        panel?.contentView = hostingView
        panel?.titlebarAppearsTransparent = true
        panel?.titleVisibility = .hidden
        panel?.styleMask.insert(.fullSizeContentView)
        panel?.titlebarSeparatorStyle = .none
        panel?.isFloatingPanel = true
        panel?.level = .floating
        panel?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel?.isMovableByWindowBackground = true
        panel?.hidesOnDeactivate = false
        panel?.becomesKeyOnlyIfNeeded = true

        // Set min/max size
        panel?.minSize = NSSize(width: 350, height: 300)
        panel?.maxSize = NSSize(width: 1000, height: 1200)

        // Apply theme
        applyTheme()

        // Save size on resize
        panel?.delegate = self

        // Observe theme changes
        startThemeObservation()
    }

    private func applyTheme() {
        if let colorScheme = settings.theme.colorScheme {
            panel?.appearance = colorScheme == .dark
                ? NSAppearance(named: .darkAqua)
                : NSAppearance(named: .aqua)
            settingsWindow?.appearance = panel?.appearance
        } else {
            panel?.appearance = nil
            settingsWindow?.appearance = nil
        }
    }

    private func startThemeObservation() {
        observeTheme()
    }

    private func observeTheme() {
        themeObservation = withObservationTracking {
            _ = self.settings.theme
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.applyTheme()
                self?.observeTheme()
            }
        }
    }

    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            state.stopAutoRefresh()
        }
    }

    @objc private func togglePanel(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(for: sender)
        } else {
            if panel?.isVisible == true {
                closePanel()
            } else {
                showPanel()
            }
        }
    }

    private func showContextMenu(for button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshData), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit PromptPulse", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func refreshData() {
        Task {
            await state.refresh()
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingView = NSHostingView(rootView: settingsView)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "PromptPulse Settings"
            settingsWindow?.contentView = hostingView
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.level = .floating
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func showPanel() {
        guard let panel = panel, let button = statusItem?.button else { return }

        // Position panel below the status item
        let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
        let panelSize = panel.frame.size

        let x = buttonRect.midX - panelSize.width / 2
        let y = buttonRect.minY - panelSize.height - 5

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)

        // Refresh data when showing
        Task {
            await state.refresh()
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
    }

    /// Resize the panel (called from footer buttons)
    func resizePopover(width: CGFloat, height: CGFloat) {
        guard let panel = panel else { return }
        var frame = panel.frame
        frame.size = NSSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
    }

    /// Update the status bar icon based on active process state
    func updateStatusIcon(hasActiveProcesses: Bool, totalCPU: Double = 0, totalMemoryMB: Double = 0) {
        guard let button = statusItem?.button else { return }

        if hasActiveProcesses {
            let statusColor = systemLoadColor(cpu: totalCPU, memoryMB: totalMemoryMB)
            if let image = createStatusImage(color: statusColor) {
                button.image = image
            }
            let cpuText = totalCPU > 99.9 ? ">99%" : String(format: "%.0f%%", totalCPU)
            button.title = cpuText
            button.imagePosition = .imageLeading
        } else {
            if let image = createStatusImage(color: .systemGray) {
                button.image = image
            }
            button.title = ""
        }
    }

    private func systemLoadColor(cpu: Double, memoryMB: Double) -> NSColor {
        let cpuLevel = loadLevel(forCPU: cpu)
        let memLevel = loadLevel(forMemoryMB: memoryMB)
        let worstLevel = max(cpuLevel, memLevel)

        switch worstLevel {
        case 3: return .systemRed
        case 2: return .systemOrange
        case 1: return .systemYellow
        default: return .systemGreen
        }
    }

    private func loadLevel(forCPU cpu: Double) -> Int {
        if cpu >= 80 { return 3 }
        if cpu >= 50 { return 2 }
        if cpu >= 20 { return 1 }
        return 0
    }

    private func loadLevel(forMemoryMB mem: Double) -> Int {
        if mem >= 4096 { return 3 }
        if mem >= 2048 { return 2 }
        if mem >= 1024 { return 1 }
        return 0
    }

    private func createStatusImage(color: NSColor) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
                color.setFill()
                NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).fill()
                return true
            }

            let outerPath = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            rgbColor.withAlphaComponent(0.4).setFill()
            outerPath.fill()

            let innerRect = rect.insetBy(dx: 4, dy: 4)
            let innerPath = NSBezierPath(ovalIn: innerRect)
            rgbColor.setFill()
            innerPath.fill()

            return true
        }

        image.isTemplate = false
        return image
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            guard let panel = panel else { return }
            settings.windowWidth = panel.frame.width
            settings.windowHeight = panel.frame.height
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        // Panel is being closed, just hide it
    }
}
