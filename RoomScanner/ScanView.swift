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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            scanDuration += 0.1
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

#Preview {
    if #available(iOS 16.0, *) {
        ScanView()
            .environmentObject(RoomCaptureManager())
    }
}
