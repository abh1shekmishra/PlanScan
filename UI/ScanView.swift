/*
 ScanView.swift
 Purpose: SwiftUI wrapper for RoomPlan's RoomCaptureViewController.
 Provides the scanning interface with camera feed and real-time guidance.
 
 Key Features:
 - UIViewControllerRepresentable wrapper for RoomCaptureViewController
 - Real-time scan progress display
 - Stop scan button
 - Instruction display
 - Fallback to ARView for ARKit mode
 
 Created: December 2025
 */

import SwiftUI
import RoomPlan
import ARKit
import RealityKit

/// SwiftUI view that wraps the RoomPlan capture experience
struct ScanView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    @State private var showingStopAlert = false
    @State private var currentInstruction: String = "Move your device slowly to scan the room"
    @State private var scanDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Camera/AR view
            if manager.supportsRoomPlan {
                RoomCaptureViewWrapper(instruction: $currentInstruction)
                    .edgesIgnoringSafeArea(.all)
            } else {
                ARScanViewWrapper()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Overlay UI
            VStack {
                // Top bar with instructions
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.white)
                        Text(currentInstruction)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    
                    HStack {
                        Text("Scan Duration: \(formatDuration(scanDuration))")
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        if !manager.supportsRoomPlan {
                            Text("Fallback Mode")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(4)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color.black.opacity(0.4))
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 16) {
                    // Progress indicator
                    if manager.scanProgress > 0 {
                        ProgressView(value: manager.scanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(maxWidth: 300)
                        
                        Text("\(Int(manager.scanProgress * 100))% Complete")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    
                    // Stop button
                    Button(action: {
                        showingStopAlert = true
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Scan")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: 300)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .alert("Stop Scanning?", isPresented: $showingStopAlert) {
            Button("Continue Scanning", role: .cancel) { }
            Button("Stop & Process", role: .destructive) {
                stopScanning()
            }
        } message: {
            Text("Are you sure you want to stop? Make sure you've scanned all walls and the floor.")
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            scanDuration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func stopScanning() {
        print("🛑 stopScanning called - telling manager to stop")
        manager.stopScan()
        stopTimer()
        print("✋ Scan stop initiated - waiting for RoomPlan callbacks...")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - RoomPlan Wrapper (iOS 16+)

@available(iOS 16.0, *)
struct RoomCaptureViewWrapper: UIViewRepresentable {
    @EnvironmentObject var manager: RoomCaptureManager
    @Binding var instruction: String
    
    func makeUIView(context: Context) -> RoomCaptureView {
        let captureView = RoomCaptureView(frame: .zero)
        
        // Configure the capture view
        captureView.delegate = context.coordinator
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        
        // Store reference in coordinator so we can call stop later
        context.coordinator.captureView = captureView
        
        // Set up the stop callback in the manager
        manager.onStopRoomCapture = {
            print("📡 onStopRoomCapture callback fired")
            context.coordinator.stopCaptureSession()
        }
        
        return captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @objc(RoomCaptureViewWrapperCoordinator)
    class Coordinator: NSObject, RoomCaptureViewDelegate {
        var parent: RoomCaptureViewWrapper
        var captureView: RoomCaptureView?
        
        init(_ parent: RoomCaptureViewWrapper) {
            self.parent = parent
            super.init()
        }
        
        // NSCoding requirements (not actually used, but required by compiler)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func encode(with coder: NSCoder) {
            // Not used
        }
        
        nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            // This is called when RoomPlan has finished processing and is asking permission to present results
            print("🎯 shouldPresent called - processing room data")
            print("   Error: \(error?.localizedDescription ?? "none")")
            print("   RoomData type: \(type(of: roomDataForProcessing))")
            
            if let error = error {
                print("❌ Error in capture: \(error.localizedDescription)")
                Task { @MainActor in
                    self.parent.manager.errorMessage = error.localizedDescription
                }
                return false
            }
            
            // Return true to let RoomPlan present the result view
            // But we'll handle the actual data in didPresent
            print("✅ Allowing RoomPlan to present results")
            return true
        }
        
        nonisolated func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            // This is the key callback - we get the final CapturedRoom here
            print("✅ didPresent called!")
            print("   Walls: \(processedResult.walls.count)")
            print("   Doors: \(processedResult.doors.count)")
            print("   Windows: \(processedResult.windows.count)")
            
            // Immediately process the result
            Task { @MainActor in
                print("🔄 Processing captured room...")
                self.parent.manager.handleRoomPlanCaptureComplete(processedResult)
                print("✨ Handed off to manager")
            }
        }
        
        /// Call this to stop the capture session and trigger processing
        func stopCaptureSession() {
            print("🛑 Stopping capture session from Coordinator")
            captureView?.captureSession.stop()
        }
        
        nonisolated func captureView(_ captureView: RoomCaptureView, didProvide instruction: RoomCaptureSession.Instruction) {
            // Update instruction text
            DispatchQueue.main.async {
                self.parent.instruction = instruction.localizedDescription
            }
        }
    }
}

// MARK: - Fallback ARKit Wrapper

struct ARScanViewWrapper: UIViewRepresentable {
    @EnvironmentObject var manager: RoomCaptureManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        
        arView.session.delegate = context.coordinator
        arView.session.run(configuration)
        
        // Enable plane detection visualization
        arView.debugOptions = [.showSceneUnderstanding]
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let manager: RoomCaptureManager
        
        init(manager: RoomCaptureManager) {
            self.manager = manager
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    Task { @MainActor in
                        manager.addMeshAnchor(meshAnchor)
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let meshAnchor = anchor as? ARMeshAnchor {
                    // Update existing mesh anchor
                    // For now, we just add it again (could optimize to replace)
                    Task { @MainActor in
                        manager.addMeshAnchor(meshAnchor)
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("❌ AR Session failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extension for Instruction Description

@available(iOS 16.0, *)
extension RoomCaptureSession.Instruction {
    var description: String {
        switch self {
        case .moveCloseToWall:
            return "Move closer to the wall"
        case .moveAwayFromWall:
            return "Move away from the wall"
        case .slowDown:
            return "Move more slowly"
        case .turnOnLight:
            return "Turn on more lights for better scanning"
        case .normal:
            return "Continue scanning the room"
        case .lowTexture:
            return "Low texture detected - move to a more detailed area"
        @unknown default:
            return "Follow on-screen guidance"
        }
    }
}

// MARK: - Preview

#Preview {
    ScanView()
        .environmentObject(RoomCaptureManager())
}
