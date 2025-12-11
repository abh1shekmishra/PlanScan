/*
 RoomCaptureDelegate.swift
 Purpose: Delegate implementation for RoomPlan RoomCaptureSession callbacks.
 Handles capture session lifecycle events and data processing.
 
 Key Responsibilities:
 - Receive callbacks when scanning starts, updates, or completes
 - Extract parametric data from CapturedRoom
 - Handle errors during capture
 - Bridge RoomPlan events to the manager
 
 Created: December 2025
 */

import Foundation
import RoomPlan
import ARKit

/// Delegate for handling RoomPlan capture session events
@available(iOS 16.0, *)
class RoomCaptureDelegate: NSObject, RoomCaptureSessionDelegate {
    
    // MARK: - Properties
    
    /// Store the last captured room from updates
    private var lastCapturedRoom: CapturedRoom?
    
    // MARK: - Callbacks
    
    /// Called when capture completes successfully with final room data
    var onCaptureComplete: ((CapturedRoom?) -> Void)?
    
    /// Called when capture updates with intermediate data
    var onCaptureUpdate: ((CapturedRoom?) -> Void)?
    
    /// Called when an error occurs during capture
    var onError: ((Error) -> Void)?
    
    /// Called when capture instructions should be displayed
    var onInstruction: ((RoomCaptureSession.Instruction) -> Void)?
    
    // MARK: - RoomCaptureSessionDelegate Methods
    
    /// Called when the capture session provides updated room data
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        print("📊 Capture session updated - Walls: \(room.walls.count), Doors: \(room.doors.count), Windows: \(room.windows.count)")
        
        // Store the latest room
        lastCapturedRoom = room
        
        // Pass intermediate data to callback
        onCaptureUpdate?(room)
    }
    
    /// Called when the capture session ends (either by user or system)
    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        print("🏁 Capture session ended with data: \(data)")
        
        if let error = error {
            print("❌ Capture ended with error: \(error.localizedDescription)")
            onError?(error)
            return
        }
        
        print("📦 CapturedRoomData received - checking for room...")
        
        // Try using the last captured room first, fall back to data if needed
        Task { @MainActor in
            // First check if we have a room from didUpdate
            if let capturedRoom = lastCapturedRoom {
                print("✅ Using lastCapturedRoom - Walls: \(capturedRoom.walls.count), Doors: \(capturedRoom.doors.count)")
                onCaptureComplete?(capturedRoom)
                return
            }
            
            // If no room from didUpdate, try to extract from data
            // CapturedRoomData might have a way to get the room
            print("⚠️ No lastCapturedRoom, trying to use data directly")
            print("   Data type: \(type(of: data))")
            
            // For now, fire callback with nil to trigger error handling
            print("❌ Unable to extract room from data")
            onCaptureComplete?(nil)
        }
    }
    
    /// Called when the session provides user instructions
    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        print("💡 Capture instruction: \(instruction)")
        onInstruction?(instruction)
    }
    
    /// Called when the capture session starts
    func captureSession(_ session: RoomCaptureSession, didStartWith configuration: RoomCaptureSession.Configuration) {
        print("🎬 Capture session started with configuration")
    }
    
    // MARK: - Helper Methods
    
    /// Export the captured room to a USDZ file
    func exportToUSDZ(room: CapturedRoom, to url: URL) async throws {
        print("💾 Exporting room to USDZ at \(url.path)")
        
        do {
            // Use RoomPlan's built-in USDZ export
            try await room.export(to: url, exportOptions: .model)
            print("✅ Successfully exported to USDZ")
        } catch {
            print("❌ Failed to export USDZ: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get detailed statistics about the captured room
    func getRoomStatistics(from room: CapturedRoom) -> RoomStatistics {
        let stats = RoomStatistics(
            wallCount: room.walls.count,
            doorCount: room.doors.count,
            windowCount: room.windows.count,
            objectCount: room.objects.count,
            surfaceCount: 0 // Surfaces not exposed in RoomPlan API
        )
        
        print("📈 Room statistics: \(stats)")
        return stats
    }
}

// MARK: - Supporting Types

/// Statistics about a captured room
struct RoomStatistics {
    let wallCount: Int
    let doorCount: Int
    let windowCount: Int
    let objectCount: Int
    let surfaceCount: Int
    
    var totalElements: Int {
        wallCount + doorCount + windowCount + objectCount + surfaceCount
    }
}

// MARK: - Instruction Extension
// Note: We extend with a custom method instead of conforming to CustomStringConvertible
// to avoid conflicts with potential future Apple implementations

@available(iOS 16.0, *)
extension RoomCaptureSession.Instruction {
    var localizedDescription: String {
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
            return "Continue scanning"
        case .lowTexture:
            return "This area has low texture - try moving to a more detailed area"
        @unknown default:
            return "Follow on-screen guidance"
        }
    }
}
