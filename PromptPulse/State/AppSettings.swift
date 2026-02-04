import Foundation
import SwiftUI

/// App settings stored in UserDefaults with proper observation
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Stored Properties (observed by @Observable)

    var fontSize: FontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "fontSize") }
    }

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }

    var compactMode: Bool {
        didSet { UserDefaults.standard.set(compactMode, forKey: "compactMode") }
    }

    var showTokenStats: Bool {
        didSet { UserDefaults.standard.set(showTokenStats, forKey: "showTokenStats") }
    }

    var showModelBadge: Bool {
        didSet { UserDefaults.standard.set(showModelBadge, forKey: "showModelBadge") }
    }

    var showCostEstimate: Bool {
        didSet { UserDefaults.standard.set(showCostEstimate, forKey: "showCostEstimate") }
    }

    var windowWidth: CGFloat {
        didSet { UserDefaults.standard.set(Double(windowWidth), forKey: "windowWidth") }
    }

    var windowHeight: CGFloat {
        didSet { UserDefaults.standard.set(Double(windowHeight), forKey: "windowHeight") }
    }

    // MARK: - Computed Fonts

    var bodyFont: Font {
        switch fontSize {
        case .small: return .system(size: 11)
        case .medium: return .system(size: 13)
        case .large: return .system(size: 15)
        }
    }

    var captionFont: Font {
        switch fontSize {
        case .small: return .system(size: 9)
        case .medium: return .system(size: 11)
        case .large: return .system(size: 13)
        }
    }

    var headlineFont: Font {
        switch fontSize {
        case .small: return .system(size: 12, weight: .semibold)
        case .medium: return .system(size: 14, weight: .semibold)
        case .large: return .system(size: 16, weight: .semibold)
        }
    }

    // MARK: - Init (load from UserDefaults)

    private init() {
        // Load saved values from UserDefaults
        self.fontSize = FontSize(rawValue: UserDefaults.standard.string(forKey: "fontSize") ?? "") ?? .medium
        self.theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "") ?? .system
        self.compactMode = UserDefaults.standard.bool(forKey: "compactMode")
        self.showTokenStats = UserDefaults.standard.object(forKey: "showTokenStats") as? Bool ?? true
        self.showModelBadge = UserDefaults.standard.object(forKey: "showModelBadge") as? Bool ?? true
        self.showCostEstimate = UserDefaults.standard.object(forKey: "showCostEstimate") as? Bool ?? true

        let savedWidth = UserDefaults.standard.double(forKey: "windowWidth")
        self.windowWidth = savedWidth > 0 ? CGFloat(savedWidth) : 400

        let savedHeight = UserDefaults.standard.double(forKey: "windowHeight")
        self.windowHeight = savedHeight > 0 ? CGFloat(savedHeight) : 500
    }
}

// MARK: - Settings Enums

enum FontSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
