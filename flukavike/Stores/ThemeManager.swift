//
//  ThemeManager.swift
//  Theme system with extensive customization options
//

import SwiftUI
import Observation

@Observable
class ThemeManager {
    var currentTheme: AppTheme = .system
    var accentColor: AccentColor = .blueberry
    
    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case oled = "OLED Dark"
        
        var id: String { rawValue }
    }
    
    enum AccentColor: String, CaseIterable, Identifiable {
        case blueberry = "Blueberry"
        case strawberry = "Strawberry"
        case orange = "Orange"
        case banana = "Banana"
        case green = "Green"
        case mint = "Mint"
        case teal = "Teal"
        case grape = "Grape"
        case pink = "Pink"
        case platinum = "Platinum"
        
        var id: String { rawValue }
        
        var color: Color {
            switch self {
            case .blueberry: return Color(red: 0, green: 0.48, blue: 1)
            case .strawberry: return Color(red: 1, green: 0.23, blue: 0.19)
            case .orange: return Color(red: 1, green: 0.58, blue: 0)
            case .banana: return Color(red: 1, green: 0.8, blue: 0)
            case .green: return Color(red: 0.2, green: 0.78, blue: 0.35)
            case .mint: return Color(red: 0, green: 0.78, blue: 0.75)
            case .teal: return Color(red: 0.19, green: 0.69, blue: 0.78)
            case .grape: return Color(red: 0.69, green: 0.32, blue: 0.87)
            case .pink: return Color(red: 1, green: 0.18, blue: 0.33)
            case .platinum: return Color(red: 0.56, green: 0.56, blue: 0.58)
            }
        }
        
        var uiColor: UIColor {
            UIColor(color)
        }
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark, .oled: return .dark
        }
    }
    
    // MARK: - Dynamic Colors
    
    func backgroundPrimary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .oled:
            return .black
        case .dark:
            return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
        }
    }
    
    func backgroundSecondary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .oled:
            return Color(white: 0.04)
        case .dark:
            return Color(red: 0.17, green: 0.17, blue: 0.18)
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.17, green: 0.17, blue: 0.18) : Color(red: 0.95, green: 0.95, blue: 0.97)
        }
    }
    
    func backgroundTertiary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .oled:
            return Color(white: 0.08)
        case .dark:
            return Color(red: 0.23, green: 0.23, blue: 0.24)
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.23, green: 0.23, blue: 0.24) : Color(red: 0.9, green: 0.9, blue: 0.92)
        }
    }
    
    func textPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }
    
    func textSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.6) : Color(white: 0.42)
    }
    
    func textTertiary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.39) : Color(white: 0.61)
    }
    
    func separator(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.9)
    }
}

// MARK: - App State
@Observable
class AppState {
    var currentUser: User?
    var selectedServer: Server?
    var selectedChannel: Channel?
    var isShowingSettings: Bool = false
    var unreadNotifications: Int = 0
    var connectionStatus: ConnectionStatus = .disconnected
    
    var isAuthenticated: Bool {
        WebAuthService.shared.isAuthenticated
    }
    
    enum ConnectionStatus {
        case connected, connecting, disconnected, error(String)
    }
}
