import SwiftUI
import RoomPlan

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
        }

        // If a scan was already requested, start immediately
        if manager.isScanning, let session = captureView.captureSession, !manager.sessionIsRunning {
            let configuration = RoomCaptureSession.Configuration()
            session.run(configuration: configuration)
            manager.setSessionRunning(true)
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
        if manager.isScanning, !manager.sessionIsRunning {
            let configuration = RoomCaptureSession.Configuration()
            session.run(configuration: configuration)
            manager.setSessionRunning(true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    @objc(RoomCaptureViewWrapperCoordinator)
    class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
        let manager: RoomCaptureManager
        private var lastCapturedRoom: CapturedRoom?
        
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
                print("❌ Error: \(error.localizedDescription)")
                Task { @MainActor in
                    manager.handleRoomCaptureError(error)
                }
                return false
            }
            
            return true
        }

        func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
            // Keep a reference to the latest room so we can use it on completion
            lastCapturedRoom = room
        }

        func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
            if let error = error {
                print("❌ Session error: \(error.localizedDescription)")
                Task { @MainActor in
                    manager.handleRoomCaptureError(error)
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
            }
        }
    }
}


