//
//  SiriDonationService.swift
//  Donate user actions to Siri for suggestions
//

import Foundation
import Intents

/// Service for donating user actions to Siri so it can suggest relevant shortcuts
class SiriDonationService {
    static let shared = SiriDonationService()
    
    private init() {}
    
    // MARK: - Message Intents
    
    /// Donate a send message intent after the user sends a message
    /// This helps Siri learn who the user frequently messages
    func donateSendMessage(to recipient: User, in channel: Channel? = nil) {
        guard #available(iOS 15.0, *) else { return }
        
        let intent = INSendMessageIntent(
            recipients: [createPerson(from: recipient)],
            outgoingMessageType: .outgoingMessageText,
            content: nil, // Don't include actual content for privacy
            speakableGroupName: channel.map { INSpeakableString(spokenPhrase: "#\($0.name)") },
            conversationIdentifier: channel?.id ?? recipient.id,
            serviceName: "Fluxer",
            sender: nil,
            attachments: nil
        )
        
        donate(intent: intent)
    }
    
    /// Donate a search messages intent
    func donateSearchMessages(query: String? = nil, inServer server: Server? = nil) {
        guard #available(iOS 15.0, *) else { return }
        
        let intent = INSearchForMessagesIntent(
            recipients: nil,
            senders: nil,
            searchTerms: query.map { [$0] },
            attributes: INMessageAttributeOptions(),
            dateTime: nil,
            identifiers: nil,
            notificationIdentifiers: nil,
            speakableGroupNames: server.map { [INSpeakableString(spokenPhrase: $0.name)] },
            conversationIdentifiers: nil
        )
        
        donate(intent: intent)
    }
    
    // MARK: - Call Intents
    
    /// Donate a start call intent after the user starts a call
    func donateStartCall(with recipient: User, isVideo: Bool = false) {
        guard #available(iOS 15.0, *) else { return }
        
        let intent = INStartCallIntent(
            audioRoute: .speakerphoneAudioRoute,
            destinationType: .normal,
            contacts: [createPerson(from: recipient)],
            recordTypeForRedialing: .outgoing,
            callCapability: isVideo ? .videoCall : .audioCall
        )
        
        donate(intent: intent)
    }
    
    // MARK: - Voice Channel Intents
    
    /// Donate joining a voice channel
    func donateJoinVoiceChannel(server: Server, channel: Channel) {
        // Note: JoinVoiceChannelIntent would need to be defined in the Intent Definition File
        // For now, we use a custom user activity
        let userActivity = NSUserActivity(activityType: "com.fluxer.joinVoiceChannel")
        userActivity.title = "Join \(channel.name) in \(server.name)"
        userActivity.userInfo = [
            "serverId": server.id,
            "serverName": server.name,
            "channelId": channel.id,
            "channelName": channel.name
        ]
        userActivity.isEligibleForPrediction = true
        userActivity.isEligibleForSearch = true
        
        userActivity.becomeCurrent()
    }
    
    // MARK: - Set Message Attribute
    
    /// Donate marking a message as read
    func donateMarkAsRead(message: Message) {
        guard #available(iOS 15.0, *) else { return }
        
        let intent = INSetMessageAttributeIntent(
            identifiers: [message.id],
            attribute: .read
        )
        
        donate(intent: intent)
    }
    
    // MARK: - Custom Activities
    
    /// Donate viewing a specific channel
    func donateViewChannel(_ channel: Channel, in server: Server) {
        let userActivity = NSUserActivity(activityType: "com.fluxer.viewChannel")
        userActivity.title = "View #\(channel.name)"
        userActivity.userInfo = [
            "channelId": channel.id,
            "channelName": channel.name,
            "serverId": server.id,
            "serverName": server.name
        ]
        userActivity.isEligibleForPrediction = true
        userActivity.isEligibleForSearch = true
        
        userActivity.becomeCurrent()
    }
    
    /// Donate viewing a user profile
    func donateViewProfile(user: User) {
        let userActivity = NSUserActivity(activityType: "com.fluxer.viewProfile")
        userActivity.title = "View \(user.displayName ?? user.username)'s Profile"
        userActivity.userInfo = [
            "userId": user.id,
            "username": user.username,
            "displayName": user.displayName as Any
        ]
        userActivity.isEligibleForPrediction = true
        userActivity.isEligibleForSearch = true
        
        userActivity.becomeCurrent()
    }
    
    // MARK: - Helpers
    
    private func createPerson(from user: User) -> INPerson {
        let handle = INPersonHandle(value: user.id, type: .unknown)
        return INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: user.displayName ?? user.username,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: user.id,
            isMe: false,
            suggestionType: .instantMessageAddress
        )
    }
    
    private func donate(intent: INIntent) {
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.groupIdentifier = "com.fluxer.mobile"
        
        interaction.donate { error in
            if let error = error {
                print("Failed to donate intent: \(error)")
            } else {
                print("Successfully donated intent: \(type(of: intent))")
            }
        }
    }
    
    // MARK: - Delete Donations
    
    /// Delete all donated intents for a specific user (e.g., when blocked)
    func deleteDonations(for user: User) {
        INInteraction.delete(with: user.id) { error in
            if let error = error {
                print("Failed to delete donations: \(error)")
            }
        }
    }
    
    /// Delete all donations (e.g., on logout)
    func deleteAllDonations() {
        INInteraction.deleteAll { error in
            if let error = error {
                print("Failed to delete all donations: \(error)")
            }
        }
    }
}

// MARK: - Voice Channel Intent (Custom)

/// Custom intent for joining voice channels
/// This would be defined in the Intent Definition File for full Siri support
@available(iOS 15.0, *) 
class JoinVoiceChannelIntent: INIntent {
    @NSManaged var server: String?
    @NSManaged var channel: String?
}

@available(iOS 15.0, *)
protocol JoinVoiceChannelIntentHandling {
    func handle(intent: JoinVoiceChannelIntent, completion: @escaping (JoinVoiceChannelIntentResponse) -> Void)
    func resolveServer(for intent: JoinVoiceChannelIntent, with completion: @escaping (INStringResolutionResult) -> Void)
    func resolveChannel(for intent: JoinVoiceChannelIntent, with completion: @escaping (INStringResolutionResult) -> Void)
}

@available(iOS 15.0, *)
class JoinVoiceChannelIntentResponse: INIntentResponse {
    @NSManaged var code: Int
    
    enum ResponseCode: Int {
        case unspecified = 0
        case ready = 1
        case success = 2
        case failure = 3
    }
    
    init(code: ResponseCode, userActivity: NSUserActivity?) {
        super.init()
        self.code = code.rawValue
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
