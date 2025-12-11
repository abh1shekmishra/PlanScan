/*
 ModelExporter.swift
 Purpose: Export captured room data to JSON.

 Created: December 2025
 */

import Foundation
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
    
    // MARK: - Utility Functions
    
    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private static func saveToDocuments(data: Data, filename: String) throws -> URL {
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
    
    static func listExportedFiles() throws -> [URL] {
        let fileManager = FileManager.default
        let docsURL = getDocumentsDirectory()
        return try fileManager.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)
    }
    
    static func deleteExportedFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    static func getFileSize(url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.size] as? Int64
    }
    
    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
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
    
    private static func getIOSVersion() -> String {
        UIDevice.current.systemVersion
    }
}

// MARK: - Data Structures for Export

struct ExportData: Codable {
    let project: String
    let timestamp: String
    let device: String
    let iosVersion: String
    let rooms: [CapturedRoomSummary]
}
