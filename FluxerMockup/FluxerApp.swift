//
//  FluxerApp.swift
//  Fluxer Mobile Client
//

import SwiftUI
import UserNotifications

@main
struct FluxerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Services
    @State private var apiService = APIService.shared
    @State private var webSocketService = WebSocketService.shared
    @State private var callService = FluxerCallService.shared
    @State private var pushService = PushNotificationService.shared
    
    // State
    @State private var themeManager = ThemeManager()
    @State private var appState = AppState()
    
    // View State
    @State private var showIncomingCall = false
    @State private var showActiveCall = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    authenticatedView
                } else {
                    OnboardingView()
                }
            }
            .environment(themeManager)
            .environment(appState)
            .environment(apiService)
            .environment(webSocketService)
            .preferredColorScheme(themeManager.colorScheme)
            .onAppear {
                initializeServices()
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
        
        // Connect to gateway if authenticated
        if let token = appState.authToken {
            webSocketService.connect(token: token)
            apiService.setAuthToken(token)
        }
    }
    
    private func setupWebSocketHandlers() {
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
            let call = FluxerCall(
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

// MARK: - App State Extension
extension AppState {
    var authToken: String? {
        // Get from Keychain
        // For mockup, return a placeholder
        return "mock_token"
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environment(ThemeManager())
        .environment(AppState())
        .environment(APIService.shared)
        .environment(WebSocketService.shared)
}

// MARK: - Content View
struct ContentView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}
