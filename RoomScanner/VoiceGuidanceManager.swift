/*
 VoiceGuidanceManager.swift
 Purpose: Provide real-time voice guidance during room scanning
 
 Created: December 2025
 */

import Foundation
import AVFoundation 
import Combine

/// Manages voice guidance and feedback during scanning
@MainActor
class VoiceGuidanceManager: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var currentGuidance: String = ""
    
    private lazy var synthesizer: AVSpeechSynthesizer = {
        let synth = AVSpeechSynthesizer()
        return synth
    }()
    private var lastAnnouncementTime: Date?
    private var announcementQueue: [String] = []
    private let minimumAnnouncementInterval: TimeInterval = 3.0 // Seconds between announcements
    
    // Scanning state tracking
    private var scanStartTime: Date?
    private var lastCoveragePercentage: Int = 0
    private var hasAnnouncedStart = false
    private var isSpeaking = false
    private var isAudioSessionConfigured = false
    private var hasAnnouncedMidpoint = false
    private var hasWarned25Percent = false
    
    // MARK: - Initialization
    
    init() {
        // Defer audio session configuration until first use
    }
    
    private func configureAudioSession() {
        guard !isAudioSessionConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            isAudioSessionConfigured = true
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
    }
    
    // MARK: - Scan Lifecycle
    
    func startScanning() {
        guard isEnabled else { return }
        
        scanStartTime = Date()
        hasAnnouncedStart = false
        hasAnnouncedMidpoint = false
        hasWarned25Percent = false
        lastCoveragePercentage = 0
        
        // Welcome message
        speak("Scan started. Move slowly around the room. Point your camera at all walls and corners.")
    }
    
    func stopScanning() {
        guard isEnabled else { return }
        
        speak("Scan stopped. Processing your room data.")
        reset()
    }
    
    func scanCompleted(wallCount: Int, openingCount: Int) {
        guard isEnabled else { return }
        
        let message: String
        if wallCount >= 4 {
            message = "Excellent scan! Detected \(wallCount) walls and \(openingCount) openings. Scan complete."
        } else if wallCount >= 3 {
            message = "Scan complete. Detected \(wallCount) walls. You may want to re-scan for better coverage."
        } else {
            message = "Scan complete. Only \(wallCount) walls detected. Consider re-scanning the room."
        }
        
        speak(message)
        reset()
    }
    
    // MARK: - Real-time Guidance
    
    func updateCoverage(percentage: Int) {
        guard isEnabled else { return }
        
        // Announce progress milestones
        if percentage >= 25 && !hasWarned25Percent {
            speak("25 percent complete. Keep moving around the room.")
            hasWarned25Percent = true
        } else if percentage >= 50 && !hasAnnouncedMidpoint {
            speak("Halfway there. Continue scanning all walls.")
            hasAnnouncedMidpoint = true
        } else if percentage >= 75 && lastCoveragePercentage < 75 {
            speak("75 percent done. Almost finished.")
        }
        
        lastCoveragePercentage = percentage
    }
    
    func guideScanningBehavior(motion: ScanningMotion) {
        guard isEnabled, canAnnounce() else { return }
        
        let message: String
        switch motion {
        case .tooFast:
            message = "Slow down. Move the camera more slowly for better accuracy."
        case .tooStill:
            message = "Keep moving. Scan around the walls continuously."
        case .missingCorner:
            message = "Missing corner. Make sure to scan all corners of the room."
        case .goodPace:
            return // No need to announce when things are going well
        case .lowLight:
            message = "Low light detected. Turn on more lights for better scanning."
        case .coverageGap:
            message = "Coverage gap detected. Scan that area again."
        }
        
        speak(message)
    }
    
    func announceWallDetection(wallNumber: Int) {
        guard isEnabled, wallNumber <= 4, canAnnounce() else { return } // Reduced to prevent spam
        
        if wallNumber == 1 {
            speak("First wall detected. Continue around the room.")
        } else if wallNumber == 4 {
            speak("Four walls detected. Good coverage so far.")
        }
    }
    
    func warnIncompleteScan(missingArea: String) {
        guard isEnabled, canAnnounce() else { return }
        
        speak("Incomplete scan. \(missingArea). Please scan that area.")
    }
    
    // MARK: - Quality Feedback
    
    func announceQualityIssue(issue: QualityIssue) {
        guard isEnabled, canAnnounce() else { return }
        
        let message: String
        switch issue {
        case .poorCoverage:
            message = "Coverage is low. Make sure to scan all walls."
        case .unstableMovement:
            message = "Keep the device steady. Move smoothly."
        case .missingWalls:
            message = "Not enough walls detected. Scan the entire room."
        case .goodQuality:
            return
        }
        
        speak(message)
    }
    
    // MARK: - Time-based Reminders
    
    func checkScanDuration() {
        guard isEnabled, let startTime = scanStartTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Remind if scan is taking too long
        if duration > 120 && !hasAnnouncedMidpoint { // 2 minutes
            speak("Take your time. A thorough scan produces better results.")
        } else if duration > 300 { // 5 minutes
            speak("Long scan detected. You can stop when ready.")
        }
    }
    
    // MARK: - Tip of the Day
    
    func provideScanningTip() {
        guard isEnabled, canAnnounce() else { return }
        
        let tips = [
            "Pro tip: Hold your device at waist height for best results.",
            "Tip: Scan slowly for more accurate measurements.",
            "Remember: Include all corners and doorways in your scan.",
            "Pro tip: Good lighting improves scan quality.",
            "Tip: Keep the camera perpendicular to walls."
        ]
        
        if let randomTip = tips.randomElement() {
            speak(randomTip)
        }
    }
    
    // MARK: - Speech Synthesis
    
    private func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        
        // Configure audio session on first use
        if !isAudioSessionConfigured {
            configureAudioSession()
        }
        
        // Update current guidance text for UI
        currentGuidance = text
        
        // Stop any ongoing speech to prevent queue buildup
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5 // Slightly slower for clarity
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        // Cache voice lookup
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // Speak
        isSpeaking = true
        synthesizer.speak(utterance)
        
        // Reset speaking flag after estimated duration
        let estimatedDuration = TimeInterval(text.count) * 0.05 + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) { [weak self] in
            self?.isSpeaking = false
        }
        
        // Update last announcement time
        lastAnnouncementTime = Date()
        
        print("🗣️ Voice: \(text)")
    }
    
    private func canAnnounce() -> Bool {
        guard let lastTime = lastAnnouncementTime else { return true }
        return Date().timeIntervalSince(lastTime) >= minimumAnnouncementInterval
    }
    
    private func reset() {
        scanStartTime = nil
        lastCoveragePercentage = 0
        hasAnnouncedStart = false
        hasAnnouncedMidpoint = false
        hasWarned25Percent = false
    }
    
    // MARK: - Toggle
    
    func toggleVoiceGuidance() {
        isEnabled.toggle()
        
        if isEnabled {
            speak("Voice guidance enabled.")
        }
    }
}

// MARK: - Supporting Types

enum ScanningMotion {
    case tooFast
    case tooStill
    case missingCorner
    case goodPace
    case lowLight
    case coverageGap
}

enum QualityIssue {
    case poorCoverage
    case unstableMovement
    case missingWalls
    case goodQuality
}
