//
//  FluxerApp.swift
//  Fluxer Mobile Client
//

import SwiftUI
import UserNotifications
import Intents

@main
struct FluxerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Services
    @State private var apiService = APIService.shared
    @State private var webSocketService = WebSocketService.shared
    @State private var callService = FlukavikeCallService.shared
    @State private var pushService = PushNotificationService.shared
    @State private var webAuthService = WebAuthService.shared
    
    // State
    @State private var themeManager = ThemeManager()
    @State private var appState = AppState()
    @State private var authService = AuthService.shared
    
    // View State
    @State private var showIncomingCall = false
    @State private var showActiveCall = false
    
    // Lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            Group {
                if webAuthService.isAuthenticated {
                    authenticatedView
                } else {
                    OnboardingView()
                }
            }
            .environment(themeManager)
            .environment(appState)
            .environment(apiService)
            .environment(webSocketService)
            .environment(webAuthService)
            .preferredColorScheme(themeManager.colorScheme)
            .onAppear {
                initializeServices()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }
    }
    
    // MARK: - Authenticated View
    private var authenticatedView: some View {
        ZStack {
            MainTabView()
            
            // Incoming call overlay
            if showIncomingCall {
                IncomingCallView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            
            // Active call overlay
            if showActiveCall {
                CallView()
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
    }
    
    // MARK: - Service Initialization
    private func initializeServices() {
        // Configure services
        callService.configure(apiService: apiService, webSocketService: webSocketService)
        
        // Setup WebSocket handlers
        setupWebSocketHandlers()
        
        // Setup Call handlers
        setupCallHandlers()
        
        // Setup Push notifications
        setupPushNotifications()
        
        // Try to migrate from legacy auth if needed
        Task {
            await webAuthService.migrateFromLegacyIfNeeded()
            
            // Connect to gateway if authenticated
            await MainActor.run {
                connectIfAuthenticated()
            }
        }
    }
    
    private func connectIfAuthenticated() {
        guard let session = WebAuthService.shared.currentSession else { return }
        
        // Discover endpoints if needed
        Task {
            if apiService.gatewayURL.isEmpty {
                try? await apiService.discoverInstance(WebAuthService.webInstanceHost)
            }
            
            await MainActor.run {
                let gatewayURL = apiService.gatewayURL
                if !gatewayURL.isEmpty {
                    webSocketService.setGatewayURL(gatewayURL)
                }
                webSocketService.connect(token: session.token)
                appState.currentUser = session.user
            }
        }
    }
    
    private func setupWebSocketHandlers() {
        webSocketService.onConnectionStateChange = { state in
            switch state {
            case .connected:
                appState.connectionStatus = .connected
            case .connecting, .identifying:
                appState.connectionStatus = .connecting
            case .reconnecting:
                appState.connectionStatus = .connecting
            case .disconnected:
                appState.connectionStatus = .disconnected
            case .error(let message):
                appState.connectionStatus = .error(message)
            }
        }
        
        webSocketService.onReady = { ready in
            appState.currentUser = ready.user
        }
        
        webSocketService.onMessageCreate = { message in
            // Handle new message - update UI, show notification if needed
            if message.channelId != appState.selectedChannel?.id {
                // Show local notification
                pushService.scheduleLocalNotification(
                    title: message.author.formattedName,
                    body: message.content
                )
            }
        }
        
        webSocketService.onNotification = { notification in
            // Handle push notification
            if notification.type == .incomingCall {
                // Call notification handled via CallService
            }
        }
    }
    
    private func setupCallHandlers() {
        // Incoming call from push notification
        pushService.onIncomingCall = { notification in
            // Convert to FluxerCall and handle
            let call = FlukavikeCall(
                id: notification.id,
                channelId: notification.channelId,
                guildId: notification.guildId,
                initiator: User(
                    id: notification.caller.id,
                    username: notification.caller.username,
                    displayName: notification.caller.displayName,
                    avatarUrl: notification.caller.avatarUrl,
                    bannerUrl: nil,
                    bio: nil,
                    status: .online,
                    customStatus: nil,
                    bot: false,
                    createdAt: Date()
                ),
                participants: [],
                type: notification.type == .video ? .video : .voice,
                status: .ringing,
                startedAt: Date(),
                endedAt: nil
            )
            
            DispatchQueue.main.async {
                callService.activeCall = call
                withAnimation {
                    showIncomingCall = true
                }
            }
        }
        
        // Call connected
        callService.onCallConnected = {
            withAnimation {
                showIncomingCall = false
                showActiveCall = true
            }
        }
        
        // Call ended
        callService.onCallEnded = {
            withAnimation {
                showIncomingCall = false
                showActiveCall = false
            }
        }
    }
    
    private func setupPushNotifications() {
        Task {
            do {
                let granted = try await pushService.requestAuthorization()
                print("Push notification permission: \(granted)")
            } catch {
                print("Failed to request push permission: \(error)")
            }
        }
    }
    
    // MARK: - Lifecycle Handling
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App came to foreground - reconnect WebSocket if authenticated
            if appState.isAuthenticated, !webSocketService.isConnected,
               let session = WebAuthService.shared.currentSession {
                webSocketService.connect(token: session.token)
            }
            
        case .background:
            // App went to background - keep WebSocket connected for push notifications
            break
            
        case .inactive:
            break
            
        @unknown default:
            break
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.registerDeviceToken(deviceToken)
        
        // Register with Fluxer API
        Task {
            try? await APIService.shared.registerDeviceToken(
                token: PushNotificationService.shared.deviceToken ?? "",
                platform: "ios"
            )
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        PushNotificationService.shared.handleIncomingNotification(userInfo)
        completionHandler(.newData)
    }
    
    // MARK: - URL Handling (Deep Links)
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return handleDeepLink(url: url)
    }
    
    // MARK: - User Activity (Siri/Handoff)
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Handle Siri intents that require the app
        if let intent = userActivity.interaction?.intent {
            return handleIntent(intent)
        }
        
        // Handle custom user activities
        switch userActivity.activityType {
        case "com.fluxer.startCall":
            if let userInfo = userActivity.userInfo {
                handleStartCallIntent(userInfo: userInfo)
            }
            return true
            
        case "com.fluxer.viewChannel":
            if let userInfo = userActivity.userInfo {
                handleViewChannelIntent(userInfo: userInfo)
            }
            return true
            
        case "com.fluxer.joinVoiceChannel":
            if let userInfo = userActivity.userInfo {
                handleJoinVoiceChannelIntent(userInfo: userInfo)
            }
            return true
            
        case "com.fluxer.siri.openApp":
            // Just open the app (e.g., for login)
            return true
            
        case NSUserActivityTypeBrowsingWeb:
            // Handle Universal Links
            if let url = userActivity.webpageURL {
                return handleDeepLink(url: url)
            }
            return false
            
        default:
            return false
        }
    }
    
    // MARK: - Intent Handlers
    
    private func handleIntent(_ intent: INIntent) -> Bool {
        switch intent {
        case is INStartCallIntent:
            if let callIntent = intent as? INStartCallIntent,
               let contact = callIntent.contacts?.first {
                handleStartCallIntent(userInfo: [
                    "recipientId": contact.customIdentifier ?? "",
                    "recipientName": contact.displayName,
                    "callType": callIntent.callCapability == .videoCall ? "video" : "voice"
                ])
            }
            return true
            
        case is INSendMessageIntent:
            // Message sent via extension, app just needs to show conversation
            if let messageIntent = intent as? INSendMessageIntent,
               let recipient = messageIntent.recipients?.first {
                handleViewConversationIntent(userInfo: [
                    "userId": recipient.customIdentifier ?? "",
                    "username": recipient.displayName
                ])
            }
            return true
            
        default:
            return false
        }
    }
    
    private func handleDeepLink(url: URL) -> Bool {
        guard url.scheme == "fluxer" else { return false }
        
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        switch pathComponents.first {
        case "channel":
            if pathComponents.count >= 3 {
                let serverId = pathComponents[1]
                let channelId = pathComponents[2]
                handleViewChannelIntent(userInfo: [
                    "serverId": serverId,
                    "channelId": channelId
                ])
            }
            return true
            
        case "user":
            if pathComponents.count >= 2 {
                let userId = pathComponents[1]
                handleViewConversationIntent(userInfo: [
                    "userId": userId
                ])
            }
            return true
            
        case "call":
            if pathComponents.count >= 2 {
                let userId = pathComponents[1]
                handleStartCallIntent(userInfo: [
                    "recipientId": userId,
                    "callType": url.queryParameters?["type"] ?? "voice"
                ])
            }
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Navigation Handlers
    
    private func handleStartCallIntent(userInfo: [AnyHashable: Any]) {
        // Post notification to be handled by the view layer
        NotificationCenter.default.post(
            name: .init("StartCallIntent"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
    
    private func handleViewChannelIntent(userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .init("ViewChannelIntent"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
    
    private func handleViewConversationIntent(userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .init("ViewConversationIntent"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
    
    private func handleJoinVoiceChannelIntent(userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .init("JoinVoiceChannelIntent"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Don't show banner for calls - CallKit handles it
        if let type = userInfo["type"] as? String, type == "INCOMING_CALL" {
            completionHandler([])
            return
        }
        
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        PushNotificationService.shared.handleIncomingNotification(userInfo)
        completionHandler()
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environment(ThemeManager())
        .environment(AppState())
        .environment(AuthService.shared)
        .environment(WebAuthService.shared)
        .environment(APIService.shared)
        .environment(WebSocketService.shared)
}

// MARK: - Content View
struct ContentView: View {
    @Environment(WebAuthService.self) private var webAuthService
    
    var body: some View {
        Group {
            if webAuthService.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

// MARK: - URL Handling Extension
extension AppDelegate {
    func handleWebAuthCallback(url: URL) -> Bool {
        // The WebAuthService handles the callback internally via ASWebAuthenticationSession
        // This is just for additional deep link handling if needed
        return false
    }
}

// MARK: - URL Extensions
extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }
        return params
    }
}
