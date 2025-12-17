import Foundation
import SwiftUI
#if canImport(RoomPlan)
import RoomPlan
#endif

/// ScanView displays the RoomPlan capture interface
@available(iOS 16.0, *)
struct ScanView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    @State private var showStopConfirm = false
    @State private var scanDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // RoomCaptureView (full screen behind everything)
            if #available(iOS 16.0, *) {
                RoomCaptureViewWrapper()
                    .ignoresSafeArea()
            }
            
            // Top Status Bar with safe area padding
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                    .frame(height: 0)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scanning Room")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(manager.statusMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                            Text(formatTime(scanDuration))
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0)
            }
            
            // Voice Guidance Floating Indicator (top-right, above buttons)
            VStack(alignment: .trailing, spacing: 0) {
                HStack {
                    Spacer()
                    if !manager.voiceGuidance.currentGuidance.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: manager.voiceGuidance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                            Text(manager.voiceGuidance.currentGuidance)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.85))
                        .cornerRadius(6)
                        .padding(.top, 50)
                        .padding(.trailing, 12)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            
            // Bottom Control Buttons - positioned above safe area
            VStack(alignment: .leading, spacing: 12) {
                // Voice toggle circular button (left side, small)
                Button(action: { manager.voiceGuidance.toggleVoiceGuidance() }) {
                    Image(systemName: manager.voiceGuidance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(manager.voiceGuidance.isEnabled ? Color.blue : Color.gray)
                        .clipShape(Circle())
                }
                
                // Show error with retry option if available
                if let errorMsg = manager.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.yellow)
                            Text("Error")
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: { manager.errorMessage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(3)
                        
                        // Retry button for world tracking failures
                        if errorMsg.lowercased().contains("tracking") {
                            Button(action: {
                                manager.errorMessage = nil
                                manager.statusMessage = "Retrying... Point at well-lit area with visible features..."
                                manager.isScanning = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry Scan")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                }
                
                // Stop scan button
                Button(action: { showStopConfirm = true }) {
                    HStack {
                        Image(systemName: "stop.circle.fill")
                        Text("Stop Scan")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .alert("Stop Scanning?", isPresented: $showStopConfirm) {
            Button("Continue", role: .cancel) { }
            Button("Stop & Process", role: .destructive) {
                manager.stopScan()
            }
        } message: {
            Text("Make sure you've scanned all walls and the floor before stopping.")
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        // Reduce timer frequency for better performance
        // Note: Timer will be invalidated in onDisappear, so self is safe
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            scanDuration += 1.0

            // Periodic voice guidance check (every 30 seconds)
            if Int(scanDuration) % 30 == 0 {
                Task {
                    await MainActor.run {
                        self.manager.voiceGuidance.checkScanDuration()
                    }
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
