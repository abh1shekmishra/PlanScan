// This patch removes duplicate definitions of WallSummary and OpeningSummary
// while keeping the CapturedRoomSummary using shared types.

/*
 RoomCaptureManager.swift
 Purpose: High-level manager for room scanning operations using iOS 16+ RoomPlan.
 
 Created: December 2025
 */

import Foundation  
import SwiftUI
import Combine
#if canImport(RoomPlan)
import RoomPlan
#endif
import simd

/// Main manager class for room capture operations
@MainActor
@available(iOS 16.0, *)
class RoomCaptureManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isScanning = false
    @Published var capturedRooms: [CapturedRoomSummary] = []
    @Published var scanProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    
    // Store the original CapturedRoom for USDZ export
    var lastCapturedRoom: CapturedRoom?
        // Voice guidance
        let voiceGuidance = VoiceGuidanceManager()
    @Published var importedModelPresented: Bool = false
    @Published var importedModelURL: URL?
    
    
    // MARK: - Private Properties
    
    private(set) var captureSession: RoomCaptureSession?
    private(set) var sessionIsRunning: Bool = false
    private var scanStartTime: Date?
    
    // MARK: - Initialization
    
    init() {
        print("🚀 RoomCaptureManager initialized")
    }
    
    // MARK: - Scan Control
    
    /// Start a new room scan
    func startScan() {
        // Thread-safe state check
        guard !isScanning else {
            print("⚠️ Scan already in progress")
            return
        }
        
        print("🚀 Starting RoomPlan scan")
        
        // Check RoomPlan support
        guard RoomCaptureSession.isSupported else {
            errorMessage = "RoomPlan is not supported on this device. Requires iPhone 12 Pro or later with LiDAR."
            return
        }
        
        // Clear previous data
        capturedRooms.removeAll()
        lastCapturedRoom = nil
        errorMessage = nil
        scanProgress = 0.0
        scanStartTime = Date()
        
        // Set scanning flag FIRST to signal to the UI that we need the capture view
        isScanning = true
        statusMessage = "Point camera at room. Move slowly around all walls..."
        
        // Start voice guidance
        voiceGuidance.startScanning()
        
        // Try to start session immediately if available
        // If not available yet, the RoomCaptureViewWrapper will start it in updateUIView
        if let session = captureSession, !sessionIsRunning {
            let configuration = RoomCaptureSession.Configuration()
            do {
                try session.run(configuration: configuration)
                sessionIsRunning = true
                print("✅ RoomPlan session started immediately")
            } catch {
                print("⚠️ Failed to start session immediately: \(error)")
                // The wrapper will try again in updateUIView
            }
        } else if captureSession == nil {
            print("⏳ RoomCaptureView not yet ready - will start session when available")
        }
        
        print("✅ RoomPlan scan initiated")
    }
    
    /// Stop the current scan
    func stopScan() {
        guard isScanning else { 
            print("⚠️ No active scan to stop")
            return 
        }
        
        print("🛑 Stopping scan")
        
        captureSession?.stop()
        sessionIsRunning = false
        isScanning = false
        statusMessage = "Processing scan..."
        
            // Stop voice guidance
            voiceGuidance.stopScanning()
        
        print("✅ Scan stopped")
    }
    
    /// Reset session for a new scan (used by rescan button)
    func resetForNewScan() {
        print("🔄 Resetting for new scan")
        
        // Ensure we're on main thread for state changes
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.resetForNewScan()
            }
            return
        }
        
        
        // Stop any active session
        captureSession?.stop()
        
        // Clear session references and state
        captureSession = nil
        sessionIsRunning = false
        
        // Clear captured data
        capturedRooms.removeAll()
        lastCapturedRoom = nil
        errorMessage = nil
        scanProgress = 0.0
        
        print("✅ Reset complete, ready for new scan")
    }
    
    /// Handle completion of RoomPlan capture
    @available(iOS 16.0, *)
    func handleRoomCaptureComplete(_ capturedRoom: CapturedRoom) {
        guard !capturedRoom.walls.isEmpty else {
            print("⚠️ Captured room has no walls")
            errorMessage = "Scan failed: No walls detected"
            isScanning = false
            return
        }
        
        print("✅ RoomPlan capture complete")
        
        self.lastCapturedRoom = capturedRoom
        
        // Convert to summary format
        var summary = convertRoomToSummary(capturedRoom)
        
        // Calculate quality report
        summary.calculateQuality()
        
        capturedRooms.append(summary)
        
        statusMessage = "Scan complete! \(capturedRooms.count) room(s) captured."
        
        // Delay setting isScanning to false to ensure UI updates properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isScanning = false
        }
        
        print("✅ Room processed: \(summary.walls.count) walls, \(summary.openings.count) openings")
        if let report = summary.qualityReport {
            print("📊 Quality Score: \(report.qualityScore)/100 (\(report.overallQuality.description))")
        }

        // Announce completion with voice
        voiceGuidance.scanCompleted(wallCount: summary.walls.count, openingCount: summary.openings.count)
    }
    
    /// Handle RoomPlan capture error
    func handleRoomCaptureError(_ error: Error) {
        print("❌ Capture error: \(error.localizedDescription)")
        
        let errorDesc = error.localizedDescription.lowercased()
        
        // For world tracking failures, keep scanning flag on to allow retry
        if errorDesc.contains("world tracking") {
            print("⚠️ World tracking failed - allowing user to retry without stopping scan")
            statusMessage = "Tracking lost. Adjust lighting or position and try again..."
            // Don't clear isScanning - user can retry
            return
        }
        
        // For other errors, stop the scan
        isScanning = false
        
        if errorDesc.contains("user cancelled") {
            statusMessage = "Scan cancelled"
        } else {
            statusMessage = "Scan failed"
        }
    }

    /// Register the capture session owned by the RoomCaptureView and start it if scanning is active
    func registerCaptureSession(_ session: RoomCaptureSession) {
        captureSession = session

        if isScanning {
            let configuration = RoomCaptureSession.Configuration()
            session.run(configuration: configuration)
            sessionIsRunning = true
        }
    }

    /// Track whether the capture session is currently running
    func setSessionRunning(_ running: Bool) {
        sessionIsRunning = running
    }
    
    // MARK: - Conversion
    
    @available(iOS 16.0, *)
    private func convertRoomToSummary(_ capturedRoom: CapturedRoom) -> CapturedRoomSummary {
        let roomId = "room-\(UUID().uuidString.prefix(8))"
        
        // Convert walls
        var walls: [WallSummary] = []
        for (idx, wall) in capturedRoom.walls.enumerated() {
            let wallId = "wall-\(idx + 1)"
            let dimensions = wall.dimensions
            let transform = wall.transform
            
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let normal = simd_normalize(simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
            
            let wallSummary = WallSummary(
                length: dimensions.x,
                height: dimensions.y,
                thickness: 0.15, // Standard wall thickness
                normal: normal,
                start: position - simd_float3(dimensions.x / 2, 0, 0),
                end: position + simd_float3(dimensions.x / 2, 0, 0),
                position: position
            )
            walls.append(wallSummary)
        }
        
        // Convert openings (doors and windows)
        var openings: [OpeningSummary] = []
        
        for (idx, door) in capturedRoom.doors.enumerated() {
            let dimensions = door.dimensions
            let transform = door.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            let opening = OpeningSummary(
                width: dimensions.x,
                height: dimensions.y,
                position: position,
                type: "door"
            )
            openings.append(opening)
        }
        
        for (idx, window) in capturedRoom.windows.enumerated() {
            let dimensions = window.dimensions
            let transform = window.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            let opening = OpeningSummary(
                width: dimensions.x,
                height: dimensions.y,
                position: position,
                type: "window"
            )
            openings.append(opening)
        }
        
        // Estimate floor area
        let floorArea = estimateFloorArea(from: walls)
        
        return CapturedRoomSummary(
            roomId: roomId,
            floorArea: floorArea,
            walls: walls,
            openings: openings
        )
    }
    
    private func estimateFloorArea(from walls: [WallSummary]) -> Float {
        guard walls.count >= 2 else { return 0.0 }
        
        let lengths = walls.compactMap { $0.length }
        guard lengths.count >= 2 else { return 0.0 }
        
        let sortedLengths = lengths.sorted(by: >)
        
        // Guard against array access
        guard sortedLengths.count >= 2 else { return 0.0 }
        
        return sortedLengths[0] * sortedLengths[1]
    }
    
    // MARK: - Export Functions
    
    func exportToJSON() -> URL? {
        do {
            print("💾 Exporting JSON...")
            let url = try ModelExporter.exportJSON(rooms: capturedRooms)
            print("✅ JSON exported to: \(url.path)")
            return url
        } catch {
            print("❌ JSON export failed: \(error)")
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    @available(iOS 16.0, *)
    func exportToUSDZ() async -> URL? {
        guard let lastRoom = lastCapturedRoom else {
            errorMessage = "No room data available for USDZ export"
            return nil
        }
        
        do {
            print("💾 Exporting USDZ...")
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "PlanScan_\(dateString()).usdz"
            let fileURL = documentsURL.appendingPathComponent(fileName)
            
            try await lastRoom.export(to: fileURL, exportOptions: .model)
            print("✅ USDZ exported to: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ USDZ export failed: \(error)")
            errorMessage = "USDZ export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    private func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - Floor Plan Export

    @available(iOS 16.0, *)
    func exportToFloorPlan() -> URL? {
        guard let lastSummary = capturedRooms.last else {
            errorMessage = "No room data available for floor plan"
            return nil
        }

        do {
            return try ModelExporter.exportFloorPlan(room: lastSummary, format: .png)
        } catch {
            print("❌ Floor plan export failed: \(error)")
            errorMessage = "Floor plan export failed: \(error.localizedDescription)"
            return nil
        }
    }
}

// MARK: - Imported model presentation
@available(iOS 16.0, *)
extension RoomCaptureManager {
    func presentImportedModel(url: URL) {
        // Retain URL and flag presentation; UI will decide how to render
        importedModelURL = url
        importedModelPresented = true
        print("📁 Imported model URL: \(url.path)")
    }
}

// MARK: - Data Models

struct CapturedRoomSummary: Identifiable, Codable {
    let id = UUID()
    let roomId: String
    let floorArea: Float
    let walls: [WallSummary]
    let openings: [OpeningSummary]
    var qualityReport: ScanQualityReport?
    
    enum CodingKeys: String, CodingKey {
        case roomId, floorArea, walls, openings
    }
    
    init(roomId: String, floorArea: Float, walls: [WallSummary], openings: [OpeningSummary]) {
        self.roomId = roomId
        self.floorArea = floorArea
        self.walls = walls
        self.openings = openings
        // Quality report will be calculated after initialization
        self.qualityReport = nil
    }
    
    mutating func calculateQuality() {
        self.qualityReport = ScanQualityAnalyzer.analyzeScanQuality(room: self)
    }
}

// WallSummary and OpeningSummary definitions should remain intact.
