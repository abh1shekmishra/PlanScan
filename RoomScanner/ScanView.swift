import SwiftUI

/// ScanView displays the RoomPlan capture interface
@available(iOS 16.0, *)
struct ScanView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    @State private var showStopConfirm = false
    @State private var scanDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // RoomCaptureView
            if #available(iOS 16.0, *) {
                RoomCaptureViewWrapper()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Overlay UI
            VStack {
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
                .background(Color.black.opacity(0.6))
                
                Spacer()
                
                VStack(spacing: 12) {
                                        // Voice guidance indicator
                                        if !manager.voiceGuidance.currentGuidance.isEmpty {
                                            HStack {
                                                Image(systemName: manager.voiceGuidance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                                    .foregroundColor(.white)
                                                Text(manager.voiceGuidance.currentGuidance)
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.blue.opacity(0.8))
                                            .cornerRadius(8)
                                        }
                    
                                        // Voice guidance toggle
                                        Button(action: { manager.voiceGuidance.toggleVoiceGuidance() }) {
                                            HStack {
                                                Image(systemName: manager.voiceGuidance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                                Text(manager.voiceGuidance.isEnabled ? "Voice On" : "Voice Off")
                                                    .fontWeight(.medium)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(manager.voiceGuidance.isEnabled ? Color.blue : Color.gray)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                        }
                    
                    Button(action: { showStopConfirm = true }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Scan")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scanDuration += 1.0

            // Periodic voice guidance check (every 30 seconds)
            if Int(self.scanDuration) % 30 == 0 {
                self.manager.voiceGuidance.checkScanDuration()
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
