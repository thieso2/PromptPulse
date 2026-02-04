import Foundation
import SwiftUI

/// App settings stored in UserDefaults
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Font Settings

    var fontSize: FontSize {
        get { FontSize(rawValue: UserDefaults.standard.string(forKey: "fontSize") ?? "medium") ?? .medium }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "fontSize") }
    }

    // MARK: - Theme Settings

    var theme: AppTheme {
        get { AppTheme(rawValue: UserDefaults.standard.string(forKey: "theme") ?? "system") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme") }
    }

    // MARK: - Layout Settings

    var compactMode: Bool {
        get { UserDefaults.standard.bool(forKey: "compactMode") }
        set { UserDefaults.standard.set(newValue, forKey: "compactMode") }
    }

    var showTokenStats: Bool {
        get { UserDefaults.standard.object(forKey: "showTokenStats") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showTokenStats") }
    }

    var showModelBadge: Bool {
        get { UserDefaults.standard.object(forKey: "showModelBadge") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showModelBadge") }
    }

    var showCostEstimate: Bool {
        get { UserDefaults.standard.object(forKey: "showCostEstimate") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showCostEstimate") }
    }

    // MARK: - Window Settings

    var windowWidth: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "windowWidth").nonZeroOr(400)) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "windowWidth") }
    }

    var windowHeight: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: "windowHeight").nonZeroOr(500)) }
        set { UserDefaults.standard.set(Double(newValue), forKey: "windowHeight") }
    }

    // MARK: - Computed Font

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

    private init() {}
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

// MARK: - Helpers

private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        self == 0 ? defaultValue : self
    }
}
