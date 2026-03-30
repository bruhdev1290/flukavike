//
//  AudioRecorderService.swift
//  Voice message recording using AVAudioRecorder
//

import Foundation
import AVFoundation

@Observable
class AudioRecorderService: NSObject {
    static let shared = AudioRecorderService()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession: AVAudioSession?
    
    var isRecording: Bool = false
    var recordingDuration: TimeInterval = 0
    var currentRecordingURL: URL?
    
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // Minimum recording duration (0.5 seconds)
    let minimumDuration: TimeInterval = 0.5
    // Maximum recording duration (5 minutes)
    let maximumDuration: TimeInterval = 300
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - Permissions
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    var hasPermission: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    // MARK: - Recording
    
    func startRecording() async throws -> Bool {
        // Check permission
        if !hasPermission {
            let granted = await requestPermission()
            guard granted else {
                throw AudioRecorderError.permissionDenied
            }
        }
        
        // Stop any existing playback
        AudioPlayerService.shared.stop()
        
        // Activate audio session
        do {
            try recordingSession?.setActive(true)
        } catch {
            throw AudioRecorderError.sessionSetupFailed(error)
        }
        
        // Create recording URL
        let recordingName = "voice_message_\(UUID().uuidString).m4a"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingURL = documentsPath.appendingPathComponent(recordingName)
        currentRecordingURL = recordingURL
        
        // Configure recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard audioRecorder?.record() == true else {
                throw AudioRecorderError.recordingFailed
            }
            
            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0
            
            // Start duration timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateRecordingDuration()
            }
            
            return true
        } catch {
            throw AudioRecorderError.recordingFailed
        }
    }
    
    func stopRecording() -> VoiceMessageRecording? {
        guard isRecording, let recorder = audioRecorder else { return nil }
        
        recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        
        let finalDuration = recordingDuration
        
        // Only return if meets minimum duration
        guard finalDuration >= minimumDuration else {
            cleanup()
            return nil
        }
        
        // Generate waveform data (simplified)
        let waveform = generateWaveform()
        
        return VoiceMessageRecording(
            url: currentRecordingURL,
            duration: finalDuration,
            waveform: waveform
        )
    }
    
    func cancelRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        recordingDuration = 0
        cleanup()
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
        
        // Auto-stop at maximum duration
        if recordingDuration >= maximumDuration {
            _ = stopRecording()
        }
    }
    
    private func generateWaveform() -> [UInt8] {
        // Simplified waveform generation
        // In a real app, you'd analyze the audio file to generate accurate waveform data
        // For now, return random data as placeholder
        return (0..<100).map { _ in UInt8.random(in: 10...100) }
    }
    
    func cleanup() {
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
        recordingDuration = 0
        
        do {
            try recordingSession?.setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    func deleteRecording(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            cleanup()
        }
    }
}

// MARK: - Errors
enum AudioRecorderError: Error {
    case permissionDenied
    case sessionSetupFailed(Error)
    case recordingFailed
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record voice messages."
        case .sessionSetupFailed(let error):
            return "Failed to set up audio session: \(error.localizedDescription)"
        case .recordingFailed:
            return "Failed to start recording. Please try again."
        }
    }
}

// MARK: - Recording Model
struct VoiceMessageRecording {
    let url: URL?
    let duration: TimeInterval
    let waveform: [UInt8]
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}
