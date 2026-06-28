//
//  ThemeManager.swift
//  Discord-style theme system
//

import SwiftUI
import Observation

@Observable
class ThemeManager {
    static let shared = ThemeManager()
    
    var currentTheme: AppTheme = .dark {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: "theme") }
    }
    var accentColor: AccentColor = .indigo {
        didSet { UserDefaults.standard.set(accentColor.rawValue, forKey: "accentColor") }
    }
    /// Boosts text/separator contrast for improved legibility (Accessibility).
    var increaseContrast: Bool = false {
        didSet { UserDefaults.standard.set(increaseContrast, forKey: "increaseContrast") }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "theme"),
           let theme = AppTheme(rawValue: saved) {
            currentTheme = theme
        }
        if let saved = UserDefaults.standard.string(forKey: "accentColor"),
           let accent = AccentColor(rawValue: saved) {
            accentColor = accent
        }
        if UserDefaults.standard.object(forKey: "increaseContrast") != nil {
            increaseContrast = UserDefaults.standard.bool(forKey: "increaseContrast")
        }
    }

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
        case oled = "OLED Dark"
        case sandstone = "Sandstone"
        case ocean = "Ocean"
        case forest = "Forest"
        case solarized = "Solarized"

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
        case .dark, .oled, .ocean, .forest: return .dark
        case .sandstone, .solarized: return .light
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
        case .ocean:
            return Color(red: 0.04, green: 0.06, blue: 0.12) // deep navy
        case .forest:
            return Color(red: 0.05, green: 0.08, blue: 0.05) // deep green-black
        case .sandstone:
            return Color(red: 0.93, green: 0.88, blue: 0.78) // warm sandy beige
        case .solarized:
            return Color(red: 0.99, green: 0.96, blue: 0.89) // #FDF6E3 base3
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
        case .ocean:
            return Color(red: 0.07, green: 0.10, blue: 0.18)
        case .forest:
            return Color(red: 0.08, green: 0.12, blue: 0.07)
        case .sandstone:
            return Color(red: 0.88, green: 0.82, blue: 0.70)
        case .solarized:
            return Color(red: 0.97, green: 0.94, blue: 0.86) // #EEE8D5 base2
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
        case .ocean:
            return Color(red: 0.10, green: 0.14, blue: 0.24)
        case .forest:
            return Color(red: 0.12, green: 0.17, blue: 0.10)
        case .sandstone:
            return Color(red: 0.82, green: 0.75, blue: 0.62)
        case .solarized:
            return Color(red: 0.93, green: 0.90, blue: 0.83) // #EEE8D5-ish darker
        case .system, .light:
            return colorScheme == .dark ? Color(red: 0.18, green: 0.18, blue: 0.19) : Color(red: 0.9, green: 0.9, blue: 0.92)
        }
    }

    // Primary text - white in dark mode
    func textPrimary(_ colorScheme: ColorScheme) -> Color {
        switch currentTheme {
        case .solarized:
            return Color(red: 0.40, green: 0.48, blue: 0.47) // #586E75 base01
        default:
            return colorScheme == .dark ? .white : .black
        }
    }

    // Secondary text - gray
    func textSecondary(_ colorScheme: ColorScheme) -> Color {
        if increaseContrast {
            return colorScheme == .dark ? Color(white: 0.88) : Color(white: 0.30)
        }
        switch currentTheme {
        case .solarized:
            return Color(red: 0.55, green: 0.63, blue: 0.62) // #657B83 base00
        default:
            return colorScheme == .dark ? Color(white: 0.71) : Color(white: 0.42)
        }
    }

    // Tertiary text - darker gray
    func textTertiary(_ colorScheme: ColorScheme) -> Color {
        if increaseContrast {
            return colorScheme == .dark ? Color(white: 0.80) : Color(white: 0.38)
        }
        return colorScheme == .dark ? Color(white: 0.6) : Color(white: 0.5)
    }

    // Separator/divider
    func separator(_ colorScheme: ColorScheme) -> Color {
        if increaseContrast {
            return colorScheme == .dark ? Color(white: 0.28) : Color(white: 0.78)
        }
        return colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.9)
    }
}

// MARK: - App State
@Observable
class AppState {
    var currentUser: User?
    var selectedServer: Server?
    var selectedChannel: Channel?
    var isShowingSettings: Bool = false
    var isQuickSwitcherPresented: Bool = false
    var notifications: [AppNotification] = []
    var unreadNotifications: Int = 0
    var unreadMessages: Int = 0
    /// Set by the push/deep-link handler to trigger navigation to a specific channel.
    var pendingChannelNavigation: ChannelNavigation? = nil
    /// Set by deep-link / Siri handlers to trigger navigation to a specific DM.
    var pendingDMNavigation: DMNavigation? = nil

    struct ChannelNavigation: Equatable {
        let serverId: String
        let channelId: String
    }

    struct DMNavigation: Equatable {
        let channelId: String
        let userId: String?
    }

    // MARK: - DM List
    var dmChannels: [DMChannelResponse] = []

    func upsertDM(_ channel: DMChannelResponse) {
        if let index = dmChannels.firstIndex(where: { $0.id == channel.id }) {
            dmChannels[index] = channel
        } else {
            dmChannels.insert(channel, at: 0)
        }
    }

    func removeDM(id: String) {
        dmChannels.removeAll { $0.id == id }
    }

    func dmChannel(for id: String) -> DMChannelResponse? {
        dmChannels.first { $0.id == id }
    }

    func dmChannel(withRecipient userId: String) -> DMChannelResponse? {
        dmChannels.first { $0.recipients.contains { $0.id == userId } }
    }
    var connectionStatus: ConnectionStatus = .disconnected
    // ⚠️ WARNING — DO NOT REMOVE OR RENAME THIS PROPERTY.
    // Fluxer delivers channel data via the WebSocket Gateway READY event, not the REST API.
    // This property is populated by FluxerApp.onReady and consumed by HomeView.loadChannels.
    // See README "Critical: Channel Loading Architecture" for full details.
    var gatewayGuilds: [Server] = []

    /// Servers loaded via REST API — have correct names. Populated by HomeView.loadServers().
    var restServers: [Server] = []

    /// Best-effort server name for a given server ID: uses REST name if available, else gateway.
    func serverName(for serverId: String) -> String {
        if let s = restServers.first(where: { $0.id == serverId }), s.name != "Unknown Server" {
            return s.name
        }
        return gatewayGuilds.first(where: { $0.id == serverId })?.name ?? ""
    }

    // MARK: - Server Rail Layout State
    // Stored in AppState so it survives tab switches and view recreation.
    var railServers: [Server] = []
    var railSelectedServer: Server?
    var railChannels: [Channel] = []
    
    var isAuthenticated: Bool {
        WebAuthService.shared.isAuthenticated
    }
    
    enum ConnectionStatus {
        case connected, connecting, disconnected, error(String)
    }
}
