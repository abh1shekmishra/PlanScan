/*
 ModelExporter.swift
 Purpose: Export captured room data to various formats (JSON, USDZ).
 Handles file I/O, format conversion, and sharing capabilities.
 
 Key Features:
 - Export to JSON with detailed measurements
 - Export to USDZ (via RoomPlan)
 - Save to app documents directory
 - Generate shareable file URLs
 
 Created: December 2025
 */

import Foundation
import RoomPlan
import UniformTypeIdentifiers
import simd
import UIKit

/// Handles exporting of room scan data to various formats
struct ModelExporter {
    
    // MARK: - JSON Export
    
    /// Export captured rooms to JSON format
    static func exportJSON(rooms: [CapturedRoomSummary]) throws -> URL {
        print("💾 Exporting \(rooms.count) room(s) to JSON")
        
        // Create export data structure
        let exportData = ExportData(
            project: "RoomScanner",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            device: getDeviceModel(),
            iosVersion: getIOSVersion(),
            rooms: rooms
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(exportData)
        
        // Save to documents directory
        let filename = "RoomScan_\(dateString()).json"
        let fileURL = try saveToDocuments(data: jsonData, filename: filename)
        
        print("✅ JSON exported to: \(fileURL.path)")
        return fileURL
    }
    
    /// Export single room to JSON
    static func exportJSON(room: CapturedRoomSummary) throws -> URL {
        return try exportJSON(rooms: [room])
    }
    
    // MARK: - USDZ Export
    
    /// Export room to USDZ format (requires RoomPlan CapturedRoom)
    @available(iOS 16.0, *)
    static func exportUSDZ(capturedRoom: CapturedRoom) async throws -> URL {
        print("💾 Exporting room to USDZ")
        
        let filename = "RoomScan_\(dateString()).usdz"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        // Use RoomPlan's built-in USDZ export
        try await capturedRoom.export(to: fileURL, exportOptions: .model)
        
        print("✅ USDZ exported to: \(fileURL.path)")
        return fileURL
    }
    
    /// Export room to USDZ with parametric option
    @available(iOS 17.0, *)
    static func exportParametricUSDZ(capturedRoom: CapturedRoom) async throws -> URL {
        print("💾 Exporting room to parametric USDZ")
        
        let filename = "RoomScan_Parametric_\(dateString()).usdz"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        // Use parametric export option (iOS 17+)
        try await capturedRoom.export(to: fileURL, exportOptions: .parametric)
        
        print("✅ Parametric USDZ exported to: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Floor Plan Export
    
    /// Export room to floor plan image (PNG or JPEG)
    @available(iOS 16.0, *)
    static func exportFloorPlan(capturedRoom: CapturedRoom, format: FloorPlanFormat = .png) async -> URL? {
        print("🎨 Exporting room to floor plan (\(format))")
        
        guard let floorPlanImage = FloorPlanGenerator.generateFloorPlan(from: capturedRoom) else {
            print("❌ Failed to generate floor plan image")
            return nil
        }
        
        let fileURL = FloorPlanGenerator.saveFloorPlan(floorPlanImage, format: format == .png ? .png : .jpeg)
        
        if let url = fileURL {
            print("✅ Floor plan exported to: \(url.path)")
        }
        
        return fileURL
    }
    
    enum FloorPlanFormat: String {
        case png = "PNG"
        case jpeg = "JPEG"
    }
    
    // MARK: - CSV Export
    
    /// Export wall measurements to CSV format
    static func exportCSV(rooms: [CapturedRoomSummary]) throws -> URL {
        print("💾 Exporting room measurements to CSV")
        
        var csvContent = "Room ID,Wall ID,Height (m),Thickness (m),Length (m),Position X,Position Y,Position Z,Normal X,Normal Y,Normal Z\n"
        
        for room in rooms {
            for wall in room.walls {
                let line = [
                    room.roomId,
                    wall.id,
                    String(format: "%.3f", wall.height),
                    String(format: "%.3f", wall.thickness ?? 0),
                    String(format: "%.3f", wall.length ?? 0),
                    String(format: "%.3f", wall.position.x),
                    String(format: "%.3f", wall.position.y),
                    String(format: "%.3f", wall.position.z),
                    String(format: "%.3f", wall.normal.x),
                    String(format: "%.3f", wall.normal.y),
                    String(format: "%.3f", wall.normal.z)
                ].joined(separator: ",")
                
                csvContent += line + "\n"
            }
        }
        
        let data = csvContent.data(using: .utf8)!
        let filename = "RoomMeasurements_\(dateString()).csv"
        let fileURL = try saveToDocuments(data: data, filename: filename)
        
        print("✅ CSV exported to: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - File Management
    
    /// Get the documents directory
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Save data to documents directory
    private static func saveToDocuments(data: Data, filename: String) throws -> URL {
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
    
    /// List all exported files
    static func listExportedFiles() throws -> [URL] {
        let documentsURL = getDocumentsDirectory()
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil
        )
        
        // Filter for our exported files
        return fileURLs.filter { url in
            let filename = url.lastPathComponent
            return filename.hasPrefix("RoomScan") || filename.hasPrefix("RoomMeasurements")
        }
    }
    
    /// Delete an exported file
    static func deleteExportedFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
        print("🗑️ Deleted file: \(url.lastPathComponent)")
    }
    
    /// Get file size
    static func getFileSize(url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            print("⚠️ Could not get file size: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get current date string for filenames
    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    /// Get device model string
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    /// Get iOS version string
    private static func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    // MARK: - Import
    
    /// Import room data from JSON file
    static func importJSON(from url: URL) throws -> [CapturedRoomSummary] {
        print("📥 Importing JSON from: \(url.path)")
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportData = try decoder.decode(ExportData.self, from: data)
        
        print("✅ Imported \(exportData.rooms.count) room(s)")
        return exportData.rooms
    }
}

// MARK: - Export Data Model

/// Complete export data structure for JSON
struct ExportData: Codable {
    let project: String
    let timestamp: String
    let device: String
    let iosVersion: String
    let rooms: [CapturedRoomSummary]
    
    enum CodingKeys: String, CodingKey {
        case project, timestamp, device, iosVersion = "ios_version", rooms
    }
}

// MARK: - Share Extensions

extension ModelExporter {
    /// Create share items for activity view controller
    static func createShareItems(for url: URL) -> [Any] {
        var items: [Any] = [url]
        
        // Add text description
        let filename = url.lastPathComponent
        let fileExtension = url.pathExtension.uppercased()
        let description = "RoomScanner Export - \(fileExtension) file: \(filename)"
        items.append(description)
        
        return items
    }
    
    /// Get UTType for file
    static func getUTType(for url: URL) -> UTType? {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "json":
            return .json
        case "usdz":
            return .usdz
        case "csv":
            return .commaSeparatedText
        default:
            return nil
        }
    }
}

// MARK: - Sample Data (for DEBUG mode)

#if DEBUG
extension ModelExporter {
    /// Generate sample data for testing without device
    static func generateSampleData() -> [CapturedRoomSummary] {
        let wall1 = WallSummary(
            id: "wall-1",
            height: 2.7,
            thickness: 0.15,
            length: 4.5,
            position: simd_float3(0, 1.35, -2.25),
            normal: simd_float3(0, 0, 1)
        )
        
        let wall2 = WallSummary(
            id: "wall-2",
            height: 2.7,
            thickness: 0.15,
            length: 3.6,
            position: simd_float3(2.25, 1.35, 0),
            normal: simd_float3(-1, 0, 0)
        )
        
        let wall3 = WallSummary(
            id: "wall-3",
            height: 2.7,
            thickness: 0.15,
            length: 4.5,
            position: simd_float3(0, 1.35, 2.25),
            normal: simd_float3(0, 0, -1)
        )
        
        let wall4 = WallSummary(
            id: "wall-4",
            height: 2.7,
            thickness: 0.15,
            length: 3.6,
            position: simd_float3(-2.25, 1.35, 0),
            normal: simd_float3(1, 0, 0)
        )
        
        let door = OpeningSummary(
            id: "door-1",
            type: "door",
            width: 0.9,
            height: 2.1,
            position: simd_float3(-2.25, 1.05, 1.0)
        )
        
        let window = OpeningSummary(
            id: "window-1",
            type: "window",
            width: 1.2,
            height: 1.5,
            position: simd_float3(2.25, 1.8, 0)
        )
        
        let room = CapturedRoomSummary(
            roomId: "room-sample",
            floorArea: 16.2,
            walls: [wall1, wall2, wall3, wall4],
            openings: [door, window]
        )
        
        return [room]
    }
}
#endif
