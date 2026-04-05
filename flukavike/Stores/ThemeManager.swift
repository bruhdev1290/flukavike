//
//  ThemeManager.swift
//  Discord-style theme system
//

import SwiftUI
import Observation

@Observable
class ThemeManager {
    var currentTheme: AppTheme = .dark
    var accentColor: AccentColor = .indigo
    
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
        case indigo = "Indigo"
        
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
            case .indigo: return Color(red: 0.35, green: 0.35, blue: 0.9)
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
    
    // MARK: - Dynamic Colors (Discord-style)
    
    // Main background - very dark gray/almost black
    func backgroundPrimary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .oled:
            return .black
        case .dark:
            return Color(red: 0.06, green: 0.06, blue: 0.07) // #0F0F10
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.07) : .white
        }
    }
    
    // Secondary background - slightly lighter
    func backgroundSecondary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .oled:
            return Color(white: 0.04)
        case .dark:
            return Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1F
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color(red: 0.95, green: 0.95, blue: 0.97)
        }
    }
    
    // Tertiary background - input fields, etc
    func backgroundTertiary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .oled:
            return Color(white: 0.08)
        case .dark:
            return Color(red: 0.18, green: 0.18, blue: 0.19) // #2D2D30
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.18, green: 0.18, blue: 0.19) : Color(red: 0.9, green: 0.9, blue: 0.92)
        }
    }
    
    // Primary text - white in dark mode
    func textPrimary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }
    
    // Secondary text - gray
    func textSecondary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.71) : Color(white: 0.42)
    }
    
    // Tertiary text - darker gray
    func textTertiary(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.5) : Color(white: 0.61)
    }
    
    // Separator/divider
    func separator(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.9)
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
    var unreadMessages: Int = 0
    var connectionStatus: ConnectionStatus = .disconnected
    // ⚠️ WARNING — DO NOT REMOVE OR RENAME THIS PROPERTY.
    // Fluxer delivers channel data via the WebSocket Gateway READY event, not the REST API.
    // This property is populated by FluxerApp.onReady and consumed by HomeView.loadChannels.
    // See README "Critical: Channel Loading Architecture" for full details.
    var gatewayGuilds: [Server] = []
    
    var isAuthenticated: Bool {
        WebAuthService.shared.isAuthenticated
    }
    
    enum ConnectionStatus {
        case connected, connecting, disconnected, error(String)
    }
}
