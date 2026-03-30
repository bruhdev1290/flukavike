//
//  IntentHandler.swift
//  Fluxer Intent Extension - Siri integration
//

import Intents

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        if intent is INSendMessageIntent {
            return SendMessageIntentHandler()
        } else if intent is INStartCallIntent {
            return StartCallIntentHandler()
        } else if intent is INSearchForMessagesIntent {
            return SearchForMessagesIntentHandler()
        } else if intent is INSetMessageAttributeIntent {
            return SetMessageAttributeIntentHandler()
        }
        return self
    }
}

// MARK: - Send Message Handler
class SendMessageIntentHandler: NSObject, INSendMessageIntentHandling {
    
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INSendMessageRecipientResolutionResult]) -> Void) {
        guard let recipients = intent.recipients, !recipients.isEmpty else {
            completion([.needsValue()])
            return
        }
        
        // Resolve recipient names to actual users from cache
        let results = recipients.map { recipient -> INSendMessageRecipientResolutionResult in
            if let user = SharedUserCache.shared.findUser(matching: recipient.displayName) {
                let person = INPerson(
                    personHandle: INPersonHandle(value: user.id, type: .unknown),
                    nameComponents: nil,
                    displayName: user.displayName ?? user.username,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: user.id
                )
                return .success(with: person)
            }
            return .unsupported()
        }
        
        completion(results)
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let content = intent.content, !content.isEmpty else {
            completion(.needsValue())
            return
        }
        completion(.success(with: content))
    }
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Check authentication via shared keychain
        guard SharedAuthService.shared.isAuthenticated else {
            let userActivity = NSUserActivity(activityType: "com.fluxer.siri.openApp")
            userActivity.userInfo = ["action": "login"]
            completion(INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity))
            return
        }
        completion(INSendMessageIntentResponse(code: .ready, userActivity: nil))
    }
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        guard let recipient = intent.recipients?.first,
              let recipientId = recipient.customIdentifier,
              let content = intent.content else {
            completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Task {
            do {
                // Find or create DM channel
                let channelId = try await SharedAPIService.shared.findOrCreateDMChannel(with: recipientId)
                
                // Send the message
                let message = try await SharedAPIService.shared.sendMessage(
                    channelId: channelId,
                    content: content
                )
                
                // Create success response with message info
                let response = INSendMessageIntentResponse(code: .success, userActivity: nil)
                response.sentMessage = INMessage(
                    identifier: message.id,
                    content: content,
                    dateSent: Date(),
                    sender: nil,
                    recipients: intent.recipients
                )
                completion(response)
                
            } catch {
                completion(INSendMessageIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Start Call Handler
class StartCallIntentHandler: NSObject, INStartCallIntentHandling {
    
    func resolveContacts(for intent: INStartCallIntent, with completion: @escaping ([INStartCallContactResolutionResult]) -> Void) {
        guard let contacts = intent.contacts, !contacts.isEmpty else {
            completion([.needsValue()])
            return
        }
        
        let results = contacts.map { contact -> INStartCallContactResolutionResult in
            if let user = SharedUserCache.shared.findUser(matching: contact.displayName) {
                let person = INPerson(
                    personHandle: INPersonHandle(value: user.id, type: .unknown),
                    nameComponents: nil,
                    displayName: user.displayName ?? user.username,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: user.id
                )
                return .success(with: person)
            }
            return .unsupported()
        }
        
        completion(results)
    }
    
    func resolveCallCapability(for intent: INStartCallIntent, with completion: @escaping (INStartCallCapabilityResolutionResult) -> Void) {
        // Support both audio and video calls
        let capability = intent.callCapability
        completion(.success(with: capability))
    }
    
    func confirm(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        guard SharedAuthService.shared.isAuthenticated else {
            let userActivity = NSUserActivity(activityType: "com.fluxer.siri.openApp")
            completion(INSendMessageIntentResponse(code: .failureRequiringAppLaunch, userActivity: userActivity))
            return
        }
        completion(INStartCallIntentResponse(code: .ready, userActivity: nil))
    }
    
    func handle(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        guard let contact = intent.contacts?.first,
              let contactId = contact.customIdentifier else {
            completion(INStartCallIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Open app to start the call (calls require UI)
        let userActivity = NSUserActivity(activityType: "com.fluxer.startCall")
        userActivity.userInfo = [
            "recipientId": contactId,
            "recipientName": contact.displayName,
            "callType": intent.callCapability == .videoCall ? "video" : "voice"
        ]
        
        let response = INStartCallIntentResponse(code: .continueInApp, userActivity: userActivity)
        completion(response)
    }
}

// MARK: - Search Messages Handler
class SearchForMessagesIntentHandler: NSObject, INSearchForMessagesIntentHandling {
    
    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        Task {
            do {
                // Search messages via API
                let messages = try await SharedAPIService.shared.searchMessages(
                    searchTerm: intent.searchTerms?.first,
                    sender: intent.senders?.first?.displayName,
                    date: intent.dateTime?.date
                )
                
                // Convert to INMessage objects
                let inMessages = messages.map { msg -> INMessage in
                    let sender = INPerson(
                        personHandle: INPersonHandle(value: msg.author.id, type: .unknown),
                        nameComponents: nil,
                        displayName: msg.author.displayName ?? msg.author.username,
                        image: nil,
                        contactIdentifier: nil,
                        customIdentifier: msg.author.id
                    )
                    
                    return INMessage(
                        identifier: msg.id,
                        content: msg.content,
                        dateSent: msg.timestamp,
                        sender: sender,
                        recipients: nil
                    )
                }
                
                let response = INSearchForMessagesIntentResponse(code: .success, userActivity: nil)
                response.messages = inMessages
                completion(response)
                
            } catch {
                completion(INSearchForMessagesIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Set Message Attribute Handler (Read/Flag)
class SetMessageAttributeIntentHandler: NSObject, INSetMessageAttributeIntentHandling {
    
    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        guard let messageId = intent.identifiers?.first else {
            completion(INSetMessageAttributeIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        Task {
            do {
                switch intent.attribute {
                case .read:
                    try await SharedAPIService.shared.markMessageAsRead(messageId: messageId)
                case .flagged:
                    // Pin or flag the message
                    try await SharedAPIService.shared.flagMessage(messageId: messageId)
                case .unread:
                    try await SharedAPIService.shared.markMessageAsUnread(messageId: messageId)
                case .unflagged:
                    try await SharedAPIService.shared.unflagMessage(messageId: messageId)
                @unknown default:
                    break
                }
                
                completion(INSetMessageAttributeIntentResponse(code: .success, userActivity: nil))
            } catch {
                completion(INSetMessageAttributeIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}

// MARK: - Shared Services (Simplified for Extension)
// In a real app, these would share code with the main app via a framework

class SharedAuthService {
    static let shared = SharedAuthService()
    
    var isAuthenticated: Bool {
        // Read from shared keychain group
        KeychainTokenStore.getToken() != nil
    }
}

class SharedUserCache {
    static let shared = SharedUserCache()
    
    // In a real app, this would use shared App Group container
    func findUser(matching name: String) -> SharedUser? {
        // Simplified - would search cached users
        return nil
    }
}

struct SharedUser {
    let id: String
    let username: String
    let displayName: String?
}

class SharedAPIService {
    static let shared = SharedAPIService()
    
    private let baseURL = "https://api.fluxer.app/v1"
    
    func findOrCreateDMChannel(with userId: String) async throws -> String {
        // POST /users/@me/channels
        return ""
    }
    
    func sendMessage(channelId: String, content: String) async throws -> SharedMessage {
        // POST /channels/{id}/messages
        return SharedMessage(
            id: UUID().uuidString,
            content: content,
            timestamp: Date(),
            author: SharedUser(id: "", username: "", displayName: nil)
        )
    }
    
    func searchMessages(searchTerm: String?, sender: String?, date: Date?) async throws -> [SharedMessage] {
        return []
    }
    
    func markMessageAsRead(messageId: String) async throws {}
    func markMessageAsUnread(messageId: String) async throws {}
    func flagMessage(messageId: String) async throws {}
    func unflagMessage(messageId: String) async throws {}
}

struct SharedMessage {
    let id: String
    let content: String
    let timestamp: Date
    let author: SharedUser
}
