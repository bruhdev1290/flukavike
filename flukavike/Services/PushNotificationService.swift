//
//  PushNotificationService.swift
//  Push notification handling for Flukavike
//

import SwiftUI
import UserNotifications
import UIKit

@Observable
class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    
    var deviceToken: String?
    var isRegistered: Bool = false
    var unreadCount: Int = 0
    
    // Call notification handlers
    var onIncomingCall: ((CallNotification) -> Void)?
    var onCallEnded: ((String) -> Void)?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Registration
    
    func requestAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]
        
        let granted = try await center.requestAuthorization(options: options)
        
        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        
        return granted
    }
    
    func registerDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        self.isRegistered = true
        
        // Token is registered with the server via AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
    }
    
    // MARK: - Notification Handling

    func handleIncomingNotification(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "INCOMING_CALL":
            if let callData = userInfo["call"] as? [String: Any] {
                guard let call = CallNotification(from: callData) else { return }
                onIncomingCall?(call)
            }

        case "CALL_ENDED":
            if let callId = userInfo["call_id"] as? String {
                onCallEnded?(callId)
            }

        case "MESSAGE_MENTION":
            let channelId = userInfo["channel_id"] as? String
            let serverId  = userInfo["server_id"]  as? String
            let title     = (userInfo["title"]   as? String) ?? "New Mention"
            let body      = (userInfo["body"]    as? String) ?? ""
            scheduleLocalNotification(title: title, body: body,
                                      channelId: channelId, serverId: serverId,
                                      type: "MESSAGE_MENTION")
            incrementBadge()

        case "DIRECT_MESSAGE":
            let channelId = userInfo["channel_id"] as? String
            let title     = (userInfo["title"] as? String) ?? "New Message"
            let body      = (userInfo["body"]  as? String) ?? ""
            scheduleLocalNotification(title: title, body: body,
                                      channelId: channelId, serverId: nil,
                                      type: "DIRECT_MESSAGE")
            incrementBadge()

        default:
            break
        }
    }

    // MARK: - Local Notifications

    func scheduleLocalNotification(
        title: String,
        body: String,
        channelId: String? = nil,
        serverId: String? = nil,
        type: String = "MESSAGE"
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var info: [String: String] = ["type": type]
        if let c = channelId { info["channel_id"] = c }
        if let s = serverId  { info["server_id"]  = s }
        content.userInfo = info

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    // MARK: - Badge

    func incrementBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = delivered.count + 1
                }
            }
        }
    }

    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationService: UNUserNotificationCenterDelegate {
    
    // Handle foreground notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Check if it's a call notification
        if let type = userInfo["type"] as? String, type == "INCOMING_CALL" {
            // Don't show banner for calls, CallKit will handle it
            completionHandler([])
            return
        }
        
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleIncomingNotification(userInfo)
        completionHandler()
    }
    
    // Open app settings
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        // Navigate to notification settings
    }
}

// MARK: - Call Notification Model
struct CallNotification {
    let id: String
    let channelId: String
    let guildId: String?
    let caller: CallerInfo
    let type: CallType
    let startedAt: Date
    
    enum CallType: String {
        case voice
        case video
        case screenShare
    }
    
    struct CallerInfo {
        let id: String
        let username: String
        let displayName: String?
        let avatarUrl: String?
    }
    
    init?(from dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let channelId = dict["channel_id"] as? String,
              let callerDict = dict["caller"] as? [String: Any],
              let callerId = callerDict["id"] as? String,
              let callerUsername = callerDict["username"] as? String,
              let typeString = dict["type"] as? String,
              let type = CallType(rawValue: typeString) else {
            return nil
        }
        
        self.id = id
        self.channelId = channelId
        self.guildId = dict["guild_id"] as? String
        self.caller = CallerInfo(
            id: callerId,
            username: callerUsername,
            displayName: callerDict["global_name"] as? String,
            avatarUrl: callerDict["avatar"] as? String
        )
        self.type = type
        self.startedAt = Date()
    }
}
