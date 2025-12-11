/*
 RoomCaptureManager.swift
 Purpose: High-level manager for room scanning operations.
 Handles RoomPlan capture session or ARKit fallback for devices without RoomPlan support.
 
 Key Responsibilities:
 - Start/stop scanning sessions
 - Check device capabilities (RoomPlan vs ARKit fallback)
 - Manage captured room data
 - Bridge between RoomPlan APIs and app state
 
 Created: December 2025
 */

import Foundation
import SwiftUI
import Combine
import RoomPlan
import ARKit

/// Main manager class for room capture operations
@MainActor
class RoomCaptureManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Indicates whether a scan is currently in progress
    @Published var isScanning = false
    
    /// Array of captured room summaries from completed scans
    @Published var capturedRooms: [CapturedRoomSummary] = []
    
    /// Store the original CapturedRoom from RoomPlan for USDZ export
    var lastCapturedRoomData: CapturedRoom?
    
    /// Current scan progress (0.0 to 1.0)
    @Published var scanProgress: Double = 0.0
    
    /// Status message for user feedback
    @Published var statusMessage: String = ""
    
    /// Error message if something goes wrong
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// RoomPlan capture session (iOS 16+)
    private var captureSession: RoomCaptureSession?
    
    /// Delegate for RoomPlan callbacks
    private var captureDelegate: RoomCaptureDelegate?
    
    /// ARKit session for fallback mode
    private var arSession: ARSession?
    
    /// Reference to the RoomCapture view's coordinator (to stop the session)
    var roomCaptureCoordinator: RoomCaptureViewWrapper.Coordinator?
    
    /// Callback to stop the RoomCapture session
    var onStopRoomCapture: (() -> Void)?
    
    /// Whether device supports RoomPlan
    private(set) var supportsRoomPlan: Bool = false
    
    /// Collected AR mesh anchors (fallback mode)
    private var collectedMeshAnchors: [ARMeshAnchor] = []
    
    /// Start time of current scan
    private var scanStartTime: Date?
    
    // MARK: - Initialization
    
    init() {
        checkDeviceCapabilities()
    }
    
    // MARK: - Device Capabilities
    
    /// Check if device supports RoomPlan or needs ARKit fallback
    private func checkDeviceCapabilities() {
        if #available(iOS 16.0, *) {
            supportsRoomPlan = RoomCaptureSession.isSupported
            print("📱 Device capabilities - RoomPlan supported: \(supportsRoomPlan)")
        } else {
            supportsRoomPlan = false
            print("📱 Device capabilities - iOS version too old for RoomPlan")
        }
        
        // Check LiDAR availability
        let hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        print("📱 Device capabilities - LiDAR available: \(hasLiDAR)")
        
        if !supportsRoomPlan && !hasLiDAR {
            errorMessage = "This device does not support room scanning. Requires iPhone 12 Pro or later with LiDAR."
        }
    }
    
    // MARK: - Scan Control
    
    /// Start a new room scan
    func startScan() {
        print("🚀 Starting scan - RoomPlan mode: \(supportsRoomPlan)")
        
        guard !isScanning else {
            print("⚠️ Scan already in progress")
            return
        }
        
        // Clear previous data
        capturedRooms.removeAll()
        errorMessage = nil
        scanProgress = 0.0
        scanStartTime = Date()
        
        if supportsRoomPlan {
            startRoomPlanScan()
        } else {
            startARKitFallbackScan()
        }
        
        isScanning = true
    }
    
    /// Stop the current scan
    func stopScan() {
        print("🛑 Stopping scan")
        
        guard isScanning else { return }
        
        if supportsRoomPlan {
            stopRoomPlanScan()
        } else {
            stopARKitFallbackScan()
        }
        
        isScanning = false
    }
    
    // MARK: - RoomPlan Implementation
    
    private func startRoomPlanScan() {
        guard #available(iOS 16.0, *) else { return }
        
        print("📸 Starting RoomPlan capture session (via ScanView)")
        statusMessage = "Point camera at room. Move slowly to scan walls and floor."
        
        // NOTE: The actual RoomCaptureSession is created by ScanView's RoomCaptureViewWrapper
        // We just need to be ready to receive the captured data when it arrives
        // The delegate will be called when stopScan() is invoked
    }
    
    private func stopRoomPlanScan() {
        guard #available(iOS 16.0, *) else { return }
        
        print("🛑 Stopping RoomPlan session via callback")
        statusMessage = "Processing scan data..."
        
        // Call the callback to stop the RoomCaptureView's session
        onStopRoomCapture?()
        print("📞 Sent stop signal to RoomCaptureView")
    }
    
    /// Handle when RoomPlan capture completes with a final room
    func handleRoomPlanCaptureComplete(_ capturedRoom: CapturedRoom?) {
        print("📦 handleRoomPlanCaptureComplete called with capturedRoom: \(capturedRoom != nil)")
        guard let capturedRoom = capturedRoom else {
            print("❌ No captured room data available")
            errorMessage = "Failed to capture room data"
            return
        }
        
        print("✅ RoomPlan capture complete")
        
        // Store the original CapturedRoom for USDZ export
        self.lastCapturedRoomData = capturedRoom
        print("💾 Stored original CapturedRoom for export")
        
        // Process captured room into our summary format
        let summary = processRoomPlanData(capturedRoom)
        print("📊 Processed summary - Walls: \(summary.walls.count), Openings: \(summary.openings.count)")
        capturedRooms.append(summary)
        
        statusMessage = "Scan complete! \(capturedRooms.count) room(s) captured."
        print("✨ Status updated - Total rooms: \(capturedRooms.count)")
    }
    
    private func processRoomPlanData(_ capturedRoom: CapturedRoom) -> CapturedRoomSummary {
        guard #available(iOS 16.0, *) else {
            return CapturedRoomSummary(roomId: "error", floorArea: 0, walls: [], openings: [])
        }
        
        print("🔄 Processing RoomPlan data...")
        
        let roomId = "room-\(UUID().uuidString.prefix(8))"
        
        // Extract walls
        var walls: [WallSummary] = []
        for (index, wall) in capturedRoom.walls.enumerated() {
            let wallId = "wall-\(index + 1)"
            
            // Get dimensions from wall
            let dimensions = wall.dimensions
            let height = dimensions.y // Wall height in meters
            let length = dimensions.x // Wall length in meters
            
            // Wall thickness - RoomPlan doesn't directly provide this
            // We estimate it or use a standard value
            let thickness: Float = 0.15 // Standard 15cm wall thickness
            
            // Get transform to extract position and normal
            let transform = wall.transform
            let position = simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Wall normal is typically the Z-axis of the transform
            let normal = simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
            
            let wallSummary = WallSummary(
                id: wallId,
                height: height,
                thickness: thickness,
                length: length,
                position: position,
                normal: simd_normalize(normal)
            )
            
            walls.append(wallSummary)
        }
        
        // Extract openings (doors and windows)
        var openings: [OpeningSummary] = []
        
        for door in capturedRoom.doors {
            let dimensions = door.dimensions
            let position = simd_float3(door.transform.columns.3.x, door.transform.columns.3.y, door.transform.columns.3.z)
            
            let opening = OpeningSummary(
                id: "door-\(openings.count + 1)",
                type: "door",
                width: dimensions.x,
                height: dimensions.y,
                position: position
            )
            openings.append(opening)
        }
        
        for window in capturedRoom.windows {
            let dimensions = window.dimensions
            let position = simd_float3(window.transform.columns.3.x, window.transform.columns.3.y, window.transform.columns.3.z)
            
            let opening = OpeningSummary(
                id: "window-\(openings.count + 1)",
                type: "window",
                width: dimensions.x,
                height: dimensions.y,
                position: position
            )
            openings.append(opening)
        }
        
        // Calculate floor area from walls or use bounding box
        let floorArea = calculateFloorArea(from: walls)
        
        print("✅ Processed room: \(walls.count) walls, \(openings.count) openings, \(String(format: "%.2f", floorArea))m² floor area")
        
        return CapturedRoomSummary(
            roomId: roomId,
            floorArea: floorArea,
            walls: walls,
            openings: openings
        )
    }
    
    private func calculateFloorArea(from walls: [WallSummary]) -> Float {
        // Simple estimation: use wall lengths to estimate rectangular area
        // In a real app, you'd use the actual floor surface from RoomPlan
        guard walls.count >= 2 else { return 0 }
        
        let lengths = walls.compactMap { $0.length }
        guard lengths.count >= 2 else { return 0 }
        
        // Rough estimate using perpendicular walls
        let sortedLengths = lengths.sorted(by: >)
        return sortedLengths[0] * sortedLengths[1]
    }
    
    // MARK: - ARKit Fallback Implementation
    
    private func startARKitFallbackScan() {
        print("🔧 Starting ARKit fallback scan")
        statusMessage = "Fallback mode - Results may be less accurate. Move slowly around the room."
        
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
            errorMessage = "This device does not support scene reconstruction"
            isScanning = false
            return
        }
        
        let session = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.planeDetection = [.horizontal, .vertical]
        
        session.run(configuration)
        self.arSession = session
        
        // Start collecting mesh data
        collectedMeshAnchors.removeAll()
        
        print("✅ ARKit fallback session started")
    }
    
    private func stopARKitFallbackScan() {
        print("🛑 Stopping ARKit fallback session")
        
        arSession?.pause()
        
        // Process collected mesh data
        if !collectedMeshAnchors.isEmpty {
            processARKitMeshData()
        } else {
            errorMessage = "No mesh data collected. Try scanning again."
        }
        
        arSession = nil
    }
    
    private func processARKitMeshData() {
        print("🔄 Processing ARKit mesh data - \(collectedMeshAnchors.count) anchors")
        statusMessage = "Processing mesh data..."
        
        // Use MeshProcessor to extract measurements
        let planes = MeshProcessor.estimatePlanes(from: collectedMeshAnchors)
        
        guard !planes.isEmpty else {
            errorMessage = "Could not detect walls in scan. Try again."
            return
        }
        
        // Identify floor plane (lowest horizontal plane)
        let floorPlane = planes.first { $0.isHorizontal && $0.normal.y > 0 }
        
        // Identify wall planes (vertical planes)
        let wallPlanes = planes.filter { !$0.isHorizontal }
        
        var walls: [WallSummary] = []
        for (index, plane) in wallPlanes.enumerated() {
            let wallId = "wall-\(index + 1)"
            
            // Compute wall height
            let height = floorPlane.map { MeshProcessor.computeWallHeight(plane: plane, floorPlane: $0) } ?? 2.5
            
            // Compute wall thickness
            let thickness = MeshProcessor.computeWallThickness(plane: plane, allPlanes: planes)
            
            // Estimate length from plane bounds
            let length = plane.estimatedLength
            
            let wallSummary = WallSummary(
                id: wallId,
                height: height,
                thickness: thickness,
                length: length,
                position: plane.center,
                normal: plane.normal
            )
            
            walls.append(wallSummary)
        }
        
        // Estimate floor area
        let floorArea = floorPlane?.estimatedArea ?? 0
        
        let roomId = "room-\(UUID().uuidString.prefix(8))"
        let summary = CapturedRoomSummary(
            roomId: roomId,
            floorArea: floorArea,
            walls: walls,
            openings: [] // ARKit fallback doesn't detect openings
        )
        
        capturedRooms.append(summary)
        statusMessage = "Fallback scan complete!"
        
        print("✅ ARKit fallback processing complete")
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        print("❌ Capture error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        isScanning = false
    }
    
    // MARK: - Public API for ARSession Updates
    
    /// Call this from ARSessionDelegate to add mesh anchors (fallback mode)
    func addMeshAnchor(_ anchor: ARMeshAnchor) {
        collectedMeshAnchors.append(anchor)
        
        // Update progress based on collected data
        scanProgress = min(Double(collectedMeshAnchors.count) / 50.0, 1.0)
    }
}

// MARK: - Data Models

/// Summary of a captured room with measurements
struct CapturedRoomSummary: Identifiable, Codable {
    let id = UUID()
    let roomId: String
    let floorArea: Float // Square meters
    let walls: [WallSummary]
    let openings: [OpeningSummary]
    
    enum CodingKeys: String, CodingKey {
        case roomId, floorArea, walls, openings
    }
}

/// Summary of a wall with measurements
struct WallSummary: Identifiable, Codable {
    let id: String
    let height: Float // Meters
    let thickness: Float? // Meters
    let length: Float? // Meters
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

/// Summary of an opening (door or window)
struct OpeningSummary: Identifiable, Codable {
    let id: String
    let type: String // "door" or "window"
    let width: Float // Meters
    let height: Float // Meters
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

// MARK: - Export Functions

extension RoomCaptureManager {
    /// Export the last captured room to USDZ format
    func exportToUSDZ() async -> URL? {
        guard #available(iOS 16.0, *) else {
            print("❌ USDZ export requires iOS 16.0+")
            return nil
        }
        
        guard let capturedRoom = lastCapturedRoomData else {
            print("❌ No captured room available for export")
            errorMessage = "No room data available for export"
            return nil
        }
        
        do {
            print("💾 Starting USDZ export...")
            let url = try await ModelExporter.exportUSDZ(capturedRoom: capturedRoom)
            print("✅ USDZ exported successfully to: \(url.path)")
            return url
        } catch {
            print("❌ USDZ export failed: \(error.localizedDescription)")
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Export the captured rooms to JSON format
    func exportToJSON() -> URL? {
        do {
            print("💾 Starting JSON export...")
            let url = try ModelExporter.exportJSON(rooms: capturedRooms)
            print("✅ JSON exported successfully to: \(url.path)")
            return url
        } catch {
            print("❌ JSON export failed: \(error.localizedDescription)")
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Export the last captured room to floor plan image (PNG or JPEG)
    func exportToFloorPlan(format: ModelExporter.FloorPlanFormat = .png) async -> URL? {
        guard #available(iOS 16.0, *) else {
            print("❌ Floor plan export requires iOS 16.0+")
            return nil
        }
        
        guard let capturedRoom = lastCapturedRoomData else {
            print("❌ No captured room available for floor plan export")
            errorMessage = "No room data available for floor plan export"
            return nil
        }
        
        print("🎨 Starting floor plan export (\(format.rawValue))...")
        let url = await ModelExporter.exportFloorPlan(capturedRoom: capturedRoom, format: format)
        
        if let url = url {
            print("✅ Floor plan exported successfully to: \(url.path)")
        } else {
            errorMessage = "Floor plan export failed"
        }
        
        return url
    }
}
