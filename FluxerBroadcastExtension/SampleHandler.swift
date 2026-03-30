//
//  SampleHandler.swift
//  Broadcast extension for screen sharing
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let serverURL = URL(string: "wss://sfu.fluxer.app/screen-share")!
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // User has requested to start the broadcast
        // Setup WebSocket connection to SFU
        
        let request = URLRequest(url: serverURL)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Send start screen share signal to main app
        let notification = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            notification,
            CFNotificationName("com.fluxer.app.screenshare.started" as CFString),
            nil,
            nil,
            true
        )
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast
        webSocketTask?.send(.string("{\"type\":\"pause\"}")) { _ in }
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast
        webSocketTask?.send(.string("{\"type\":\"resume\"}")) { _ in }
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        
        // Send stop signal to main app
        let notification = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            notification,
            CFNotificationName("com.fluxer.app.screenshare.stopped" as CFString),
            nil,
            nil,
            true
        )
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            // Handle video sample buffer
            // Compress and send via WebRTC/WebSocket
            if let data = encodeVideoSampleBuffer(sampleBuffer) {
                sendVideoData(data)
            }
            
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer from app
            break
            
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer from mic
            break
            
        @unknown default:
            break
        }
    }
    
    private func encodeVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Data? {
        // Convert CMSampleBuffer to encoded video data (H.264)
        // This is a placeholder - actual implementation needs VideoToolbox encoding
        return nil
    }
    
    private func sendVideoData(_ data: Data) {
        // Send encoded video frame to SFU
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print("Failed to send video data: \(error)")
            }
        }
    }
}
