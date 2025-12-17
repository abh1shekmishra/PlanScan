import SwiftUI
import Foundation
#if canImport(RoomPlan) 
import RoomPlan
#endif

/// Wrapper for RoomCaptureView (iOS 16+)
@available(iOS 16.0, *) 
struct RoomCaptureViewWrapper: UIViewRepresentable {
    @EnvironmentObject var manager: RoomCaptureManager
    
    func makeUIView(context: Context) -> RoomCaptureView {
        let captureView = RoomCaptureView(frame: .zero)
        captureView.delegate = context.coordinator

        // Use the view's built-in session so delegates stay consistent
        if let session = captureView.captureSession {
            session.delegate = context.coordinator
            manager.registerCaptureSession(session)
            print("✅ RoomCaptureSession registered")
            
            // If a scan was already requested, start immediately
            if manager.isScanning && !manager.sessionIsRunning {
                let configuration = RoomCaptureSession.Configuration()
                do {
                    try session.run(configuration: configuration)
                    manager.setSessionRunning(true)
                    print("✅ Session started in makeUIView")
                } catch {
                    print("❌ Failed to start session in makeUIView: \(error)")
                    manager.errorMessage = "Failed to start scan: \(error.localizedDescription)"
                    manager.isScanning = false
                }
            }
        } else {
            print("❌ Failed to get RoomCaptureSession from RoomCaptureView")
            manager.errorMessage = "Failed to initialize camera. Try restarting the app."
        }

        return captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        guard let session = manager.captureSession else { return }

        // Ensure delegate is current
        if session.delegate !== context.coordinator {
            session.delegate = context.coordinator
        }

        // Start the session when scanning is requested
        // This handles the case where the view was created before startScan() was called
        if manager.isScanning && !manager.sessionIsRunning {
            let configuration = RoomCaptureSession.Configuration()
            do {
                try session.run(configuration: configuration)
                manager.setSessionRunning(true)
                print("✅ Session started in updateUIView")
            } catch {
                print("❌ Failed to start session in updateUIView: \(error)")
                manager.errorMessage = "Failed to start scan: \(error.localizedDescription)"
                manager.isScanning = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    @objc(RoomCaptureViewWrapperCoordinator)
    class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
        let manager: RoomCaptureManager
        private var lastCapturedRoom: CapturedRoom?
        private var lastUpdateTime: Date?
        private var lastAnnouncedWallCount: Int = 0
        private let updateThrottle: TimeInterval = 2.0 // Throttle updates to every 2 seconds
        
        init(manager: RoomCaptureManager) {
            self.manager = manager
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func encode(with coder: NSCoder) {
            // Not needed for this use case
        }
        
        func roomCaptureView(_ view: RoomCaptureView, didPresent room: CapturedRoom) {
            print("✅ Room capture complete")
            lastCapturedRoom = room
            Task { @MainActor in
                manager.handleRoomCaptureComplete(room)
            }
        }
        
        func roomCaptureView(_ view: RoomCaptureView, shouldPresent roomData: CapturedRoomData, error: Error?) -> Bool {
            print("🎯 shouldPresent called")
            
            if let error = error {
                // Only log non-critical errors; don't stop scanning
                print("⚠️ Warning during scan: \(error.localizedDescription)")
                // Return true to allow the user to continue scanning
                return true
            }
            
            return true
        }

        func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
            // Keep a reference to the latest room so we can use it on completion
            lastCapturedRoom = room
            
            // Throttle updates to reduce performance impact
            let now = Date()
            if let lastTime = lastUpdateTime, now.timeIntervalSince(lastTime) < updateThrottle {
                return
            }
            lastUpdateTime = now
            
            // Provide real-time voice guidance (throttled)
            Task { @MainActor in
                let wallCount = room.walls.count
                
                // Only announce if wall count changed significantly
                if wallCount != self.lastAnnouncedWallCount && wallCount > 0 {
                    self.manager.voiceGuidance.announceWallDetection(wallNumber: wallCount)
                    self.lastAnnouncedWallCount = wallCount
                }
                
                // Estimate coverage based on wall count (rough heuristic)
                let estimatedCoverage = min(100, wallCount * 20)
                self.manager.voiceGuidance.updateCoverage(percentage: estimatedCoverage)
            }
        }

        func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
            if let error = error {
                print("❌ Session error: \(error.localizedDescription)")
                
                // Map common RoomPlan errors to user-friendly messages with recovery steps
                let userMessage: String
                let errorLower = error.localizedDescription.lowercased()
                
                if errorLower.contains("world tracking") {
                    userMessage = "Scan failed: Lost spatial tracking. Point camera at well-lit area with visible features (walls, furniture, etc). Hold steady for 2-3 seconds, then move slowly."
                } else if errorLower.contains("no features") || errorLower.contains("insufficient") {
                    userMessage = "Scan failed: Room has too few visual features. Improve lighting and show more details (furniture, posters, patterns) to the camera."
                } else if errorLower.contains("timeout") {
                    userMessage = "Scan failed: Took too long or lost tracking. Start with a smaller room or try in brighter conditions."
                } else if errorLower.contains("camera") || errorLower.contains("permission") {
                    userMessage = "Camera access denied or unavailable. Check privacy settings and restart the app."
                } else if errorLower.contains("user cancelled") {
                    userMessage = "Scan cancelled."
                } else {
                    userMessage = "Scan failed: \(error.localizedDescription)\n\nTips: Ensure good lighting, show camera details (furniture, walls), and move slowly."
                }
                
                Task { @MainActor in
                    manager.handleRoomCaptureError(error)
                    manager.errorMessage = userMessage
                    // Don't auto-stop for world tracking - user should retry
                    if !errorLower.contains("world tracking") {
                        manager.isScanning = false
                    }
                }
                return
            }

            if let room = lastCapturedRoom {
                print("✅ Session didEndWith room from last update")
                Task { @MainActor in
                    manager.handleRoomCaptureComplete(room)
                }
            } else {
                print("⚠️ Session ended without room data")
                Task { @MainActor in
                    manager.errorMessage = "Scan ended without capturing room data. Try again with better lighting and visible features."
                    manager.isScanning = false
                }
            }
        }
    }
}


