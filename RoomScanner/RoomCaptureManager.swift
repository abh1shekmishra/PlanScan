/*
 RoomCaptureManager.swift
 Purpose: High-level manager for room scanning operations using iOS 16+ RoomPlan.
 
 Created: December 2025
 */

import Foundation
import SwiftUI
import Combine
import RoomPlan
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
        errorMessage = nil
        scanProgress = 0.0
        scanStartTime = Date()
        
        isScanning = true
        statusMessage = "Point camera at room. Move slowly around all walls..."
            // Start voice guidance
            voiceGuidance.startScanning()
        
        
        // Start the RoomPlan session when the capture view registers its session
        if let session = captureSession {
            let configuration = RoomCaptureSession.Configuration()
            session.run(configuration: configuration)
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
        errorMessage = error.localizedDescription
        
        // Only stop scanning if it's a critical error
        if error.localizedDescription.lowercased().contains("user cancelled") {
            isScanning = false
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
                id: wallId,
                height: dimensions.y,
                thickness: 0.15, // Standard wall thickness
                length: dimensions.x,
                position: position,
                normal: normal
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
                id: "door-\(idx + 1)",
                type: "door",
                width: dimensions.x,
                height: dimensions.y,
                position: position
            )
            openings.append(opening)
        }
        
        for (idx, window) in capturedRoom.windows.enumerated() {
            let dimensions = window.dimensions
            let transform = window.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            let opening = OpeningSummary(
                id: "window-\(idx + 1)",
                type: "window",
                width: dimensions.x,
                height: dimensions.y,
                position: position
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

struct WallSummary: Identifiable, Codable {
    let id: String
    let height: Float
    let thickness: Float?
    let length: Float?
    let position: simd_float3
    let normal: simd_float3
    
    enum CodingKeys: String, CodingKey {
        case id, height, thickness, length, position, normal
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(thickness, forKey: .thickness)
        try container.encodeIfPresent(length, forKey: .length)
        try container.encode([position.x, position.y, position.z], forKey: .position)
        try container.encode([normal.x, normal.y, normal.z], forKey: .normal)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        height = try container.decode(Float.self, forKey: .height)
        thickness = try container.decodeIfPresent(Float.self, forKey: .thickness)
        length = try container.decodeIfPresent(Float.self, forKey: .length)
        
        let posArray = try container.decode([Float].self, forKey: .position)
        position = simd_float3(posArray[0], posArray[1], posArray[2])
        
        let normalArray = try container.decode([Float].self, forKey: .normal)
        normal = simd_float3(normalArray[0], normalArray[1], normalArray[2])
    }
    
    init(id: String, height: Float, thickness: Float?, length: Float?, position: simd_float3, normal: simd_float3) {
        self.id = id
        self.height = height
        self.thickness = thickness
        self.length = length
        self.position = position
        self.normal = normal
    }
}

struct OpeningSummary: Identifiable, Codable {
    let id: String
    let type: String
    let width: Float
    let height: Float
    let position: simd_float3
    
    enum CodingKeys: String, CodingKey {
        case id, type, width, height, position
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode([position.x, position.y, position.z], forKey: .position)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        width = try container.decode(Float.self, forKey: .width)
        height = try container.decode(Float.self, forKey: .height)
        
        let posArray = try container.decode([Float].self, forKey: .position)
        position = simd_float3(posArray[0], posArray[1], posArray[2])
    }
    
    init(id: String, type: String, width: Float, height: Float, position: simd_float3) {
        self.id = id
        self.type = type
        self.width = width
        self.height = height
        self.position = position
    }
}
