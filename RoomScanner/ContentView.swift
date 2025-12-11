//
//  ContentView.swift
//  RoomScanner
//
//  Created by Abhishek trezi on 10/12/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    @State private var showingResults = false
    
    var body: some View {
        ZStack {
            Group {
                if manager.isScanning {
                    ScanView()
                        .edgesIgnoringSafeArea(.all)
                } else if !manager.capturedRooms.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 40))
                                VStack(alignment: .leading) {
                                    Text("Scan Complete")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("\(manager.capturedRooms.count) room(s) captured")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            
                            ForEach(manager.capturedRooms) { room in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Room: \(room.roomId)")
                                        .font(.headline)
                                    
                                    HStack {
                                        Text("Floor Area")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "%.2f m²", room.floorArea))
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("Walls")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(room.walls.count) walls")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            VStack(spacing: 12) {
                                Button(action: exportJSON) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("Export JSON")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: resetScan) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("New Scan")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                        .padding()
                    }
                } else {
                    WelcomeView(onStartScan: {
                        print("🚀 Start scan button tapped")
                        manager.startScan()
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Error overlay
            if let error = manager.errorMessage {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text("Error")
                                .fontWeight(.bold)
                            Spacer()
                            Button(action: { manager.errorMessage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        Text(error)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
    }
    
    private func exportJSON() {
        print("📝 Exporting JSON...")
        do {
            let url = try ModelExporter.exportJSON(rooms: manager.capturedRooms)
            print("✅ JSON exported to: \(url.path)")
        } catch {
            print("❌ JSON export failed: \(error)")
            manager.errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
    
    private func resetScan() {
        print("🔄 Starting new scan...")
        manager.capturedRooms.removeAll()
        manager.startScan()
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onStartScan: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "ruler.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("RoomScanner")
                .font(.system(size: 32, weight: .bold))
            
            Text("Scan and measure indoor spaces using LiDAR")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "ruler", text: "Measure wall heights")
                FeatureRow(icon: "square.grid.3x3", text: "Compute floor area")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: onStartScan) {
                HStack(spacing: 10) {
                    Image(systemName: "scanner.fill")
                    Text("Start Scan")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .padding(.horizontal, 40)
            
            Text("Requires iPhone with LiDAR (iPhone 12 Pro or later)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Results View
@available(iOS 16.0, *)
struct ResultsView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    let rooms: [CapturedRoomSummary]
    @Binding var showingExportOptions: Bool
    @Binding var exportedURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 40))
                    VStack(alignment: .leading) {
                        Text("Scan Complete")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(rooms.count) room(s) captured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                
                ForEach(rooms) { room in
                    RoomCard(room: room)
                }
                
                VStack(spacing: 12) {
                    Button(action: exportJSON) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Export JSON")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
    
    private func exportJSON() {
        do {
            let url = try ModelExporter.exportJSON(rooms: rooms)
            exportedURL = url
            showingExportOptions = true
        } catch {
            print("Error exporting JSON: \(error)")
        }
    }
}

struct RoomCard: View {
    let room: CapturedRoomSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room: \(room.roomId)")
                .font(.headline)
            
            HStack {
                Text("Floor Area")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f m²", room.floorArea))
                    .fontWeight(.semibold)
            }
            
            Text("Walls (\(room.walls.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Share Sheet
@available(iOS 16.0, *)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    if #available(iOS 16.0, *) {
        ContentView()
            .environmentObject(RoomCaptureManager())
    }
}

