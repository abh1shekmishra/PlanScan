/*
 FloorPlanGenerator.swift
 Purpose: Generate 2D floor plan images from captured room data.
 Renders a top-down view with walls, doors, windows, and scale markings.
 
 Key Responsibilities:
 - Convert 3D room data to 2D floor plan
 - Render walls, doors, windows, openings
 - Add scale and dimension markings
 - Export to PNG/JPEG
 
 Created: December 2025
 */

import Foundation
import UIKit
import RoomPlan

@available(iOS 16.0, *)
class FloorPlanGenerator {
    
    // MARK: - Constants
    private static let pixelsPerMeter: CGFloat = 100
    private static let wallThickness: CGFloat = 8
    private static let doorWidth: CGFloat = 2
    private static let windowWidth: CGFloat = 1.5
    
    // MARK: - Color Scheme
    private static let backgroundColor = UIColor.white
    private static let wallColor = UIColor.darkGray
    private static let doorColor = UIColor.blue
    private static let windowColor = UIColor.cyan
    private static let openingColor = UIColor.orange
    private static let gridColor = UIColor.lightGray
    private static let textColor = UIColor.black
    
    // MARK: - Floor Plan Generation
    
    /// Generate a floor plan image from a captured room
    static func generateFloorPlan(from capturedRoom: CapturedRoom, size: CGSize = CGSize(width: 1200, height: 1200)) -> UIImage? {
        print("📐 Generating floor plan from captured room")
        print("   Walls: \(capturedRoom.walls.count)")
        print("   Doors: \(capturedRoom.doors.count)")
        print("   Windows: \(capturedRoom.windows.count)")
        
        // Calculate room bounds
        let bounds = calculateRoomBounds(from: capturedRoom)
        print("   Room bounds: \(bounds)")
        
        // Create image context
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to create graphics context")
            return nil
        }
        
        // Draw background
        backgroundColor.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        
        // Calculate transformation from world space to image space
        let transform = calculateTransform(from: bounds, to: size)
        
        // Draw grid
        drawGrid(context: context, size: size, transform: transform, bounds: bounds)
        
        // Draw walls
        drawWalls(context: context, walls: capturedRoom.walls, transform: transform)
        
        // Draw doors
        drawDoors(context: context, doors: capturedRoom.doors, transform: transform)
        
        // Draw windows
        drawWindows(context: context, windows: capturedRoom.windows, transform: transform)
        
        // Draw openings
        drawOpenings(context: context, openings: capturedRoom.openings, transform: transform)
        
        // Draw scale and dimensions
        drawScale(context: context, size: size, transform: transform, bounds: bounds)
        
        // Get the image
        let floorPlan = UIGraphicsGetImageFromCurrentImageContext()
        print("✅ Floor plan generated successfully")
        
        return floorPlan
    }
    
    // MARK: - Helper Functions
    
    private static func calculateRoomBounds(from capturedRoom: CapturedRoom) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX = Float.infinity
        var maxX = -Float.infinity
        var minZ = Float.infinity
        var maxZ = -Float.infinity
        
        // Get bounds from walls
        for wall in capturedRoom.walls {
            let transform = wall.transform
            let x = transform.columns.3.x
            let z = transform.columns.3.z
            
            minX = min(minX, x)
            maxX = max(maxX, x)
            minZ = min(minZ, z)
            maxZ = max(maxZ, z)
            
            // Account for wall dimensions
            let width = wall.dimensions.x
            minX = min(minX, x - width/2)
            maxX = max(maxX, x + width/2)
        }
        
        // Add padding
        let padding: Float = 1.0
        minX -= padding
        maxX += padding
        minZ -= padding
        maxZ += padding
        
        return (minX, maxX, minZ, maxZ)
    }
    
    private static func calculateTransform(from bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float), to size: CGSize) -> CGAffineTransform {
        let roomWidth = CGFloat(bounds.maxX - bounds.minX)
        let roomHeight = CGFloat(bounds.maxZ - bounds.minZ)
        
        let scaleX = (size.width * 0.9) / roomWidth
        let scaleY = (size.height * 0.9) / roomHeight
        let scale = min(scaleX, scaleY)
        
        let originX = (size.width - roomWidth * scale) / 2
        let originY = (size.height - roomHeight * scale) / 2
        
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: originX - CGFloat(bounds.minX) * scale, ty: originY - CGFloat(bounds.minZ) * scale)
    }
    
    private static func worldToImage(_ point: simd_float3, transform: CGAffineTransform) -> CGPoint {
        let worldPoint = CGPoint(x: CGFloat(point.x), y: CGFloat(point.z))
        return worldPoint.applying(transform)
    }
    
    private static func drawGrid(context: CGContext, size: CGSize, transform: CGAffineTransform, bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)) {
        gridColor.setStroke()
        context.setLineWidth(0.5)
        
        // Draw grid lines every 1 meter
        let gridSpacing: Float = 1.0
        
        var x = (bounds.minX / gridSpacing).rounded(.down) * gridSpacing
        while x <= bounds.maxX {
            let start = worldToImage(simd_float3(x, 0, bounds.minZ), transform: transform)
            let end = worldToImage(simd_float3(x, 0, bounds.maxZ), transform: transform)
            context.move(to: start)
            context.addLine(to: end)
            x += gridSpacing
        }
        
        var z = (bounds.minZ / gridSpacing).rounded(.down) * gridSpacing
        while z <= bounds.maxZ {
            let start = worldToImage(simd_float3(bounds.minX, 0, z), transform: transform)
            let end = worldToImage(simd_float3(bounds.maxX, 0, z), transform: transform)
            context.move(to: start)
            context.addLine(to: end)
            z += gridSpacing
        }
        
        context.strokePath()
    }
    
    private static func drawWalls(context: CGContext, walls: [Wall], transform: CGAffineTransform) {
        wallColor.setFill()
        
        for wall in walls {
            let transform3D = wall.transform
            let position = simd_float3(transform3D.columns.3.x, transform3D.columns.3.y, transform3D.columns.3.z)
            let width = wall.dimensions.x
            let length = wall.dimensions.z
            
            // Wall corners
            let halfWidth = width / 2
            let halfLength = length / 2
            
            let corners = [
                simd_float3(position.x - halfWidth, 0, position.z - halfLength),
                simd_float3(position.x + halfWidth, 0, position.z - halfLength),
                simd_float3(position.x + halfWidth, 0, position.z + halfLength),
                simd_float3(position.x - halfWidth, 0, position.z + halfLength)
            ]
            
            let path = UIBezierPath()
            let p0 = worldToImage(corners[0], transform: transform)
            path.move(to: p0)
            
            for i in 1..<corners.count {
                let p = worldToImage(corners[i], transform: transform)
                path.addLine(to: p)
            }
            path.close()
            
            path.fill()
        }
    }
    
    private static func drawDoors(context: CGContext, doors: [Door], transform: CGAffineTransform) {
        doorColor.setStroke()
        context.setLineWidth(3)
        
        for door in doors {
            let transform3D = door.transform
            let position = simd_float3(transform3D.columns.3.x, transform3D.columns.3.y, transform3D.columns.3.z)
            let width = door.dimensions.x
            
            let start = worldToImage(simd_float3(position.x - width/2, 0, position.z), transform: transform)
            let end = worldToImage(simd_float3(position.x + width/2, 0, position.z), transform: transform)
            
            context.move(to: start)
            context.addLine(to: end)
        }
        
        context.strokePath()
    }
    
    private static func drawWindows(context: CGContext, windows: [Window], transform: CGAffineTransform) {
        windowColor.setStroke()
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [5, 5])
        
        for window in windows {
            let transform3D = window.transform
            let position = simd_float3(transform3D.columns.3.x, transform3D.columns.3.y, transform3D.columns.3.z)
            let width = window.dimensions.x
            
            let start = worldToImage(simd_float3(position.x - width/2, 0, position.z), transform: transform)
            let end = worldToImage(simd_float3(position.x + width/2, 0, position.z), transform: transform)
            
            context.move(to: start)
            context.addLine(to: end)
        }
        
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }
    
    private static func drawOpenings(context: CGContext, openings: [Opening], transform: CGAffineTransform) {
        openingColor.setStroke()
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [3, 3])
        
        for opening in openings {
            let transform3D = opening.transform
            let position = simd_float3(transform3D.columns.3.x, transform3D.columns.3.y, transform3D.columns.3.z)
            let width = opening.dimensions.x
            
            let start = worldToImage(simd_float3(position.x - width/2, 0, position.z), transform: transform)
            let end = worldToImage(simd_float3(position.x + width/2, 0, position.z), transform: transform)
            
            context.move(to: start)
            context.addLine(to: end)
        }
        
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
    }
    
    private static func drawScale(context: CGContext, size: CGSize, transform: CGAffineTransform, bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)) {
        // Draw scale bar at bottom
        let scaleBarLength: CGFloat = 2 * abs(transform.a) // 2 meters in pixels
        let scaleBarX: CGFloat = 50
        let scaleBarY: CGFloat = size.height - 80
        
        // Draw scale bar line
        wallColor.setStroke()
        context.setLineWidth(2)
        context.move(to: CGPoint(x: scaleBarX, y: scaleBarY))
        context.addLine(to: CGPoint(x: scaleBarX + scaleBarLength, y: scaleBarY))
        context.strokePath()
        
        // Draw scale ticks
        context.move(to: CGPoint(x: scaleBarX, y: scaleBarY - 5))
        context.addLine(to: CGPoint(x: scaleBarX, y: scaleBarY + 5))
        context.move(to: CGPoint(x: scaleBarX + scaleBarLength, y: scaleBarY - 5))
        context.addLine(to: CGPoint(x: scaleBarX + scaleBarLength, y: scaleBarY + 5))
        context.strokePath()
        
        // Draw scale label
        let scaleText = "2m"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: textColor
        ]
        let attributedString = NSAttributedString(string: scaleText, attributes: attributes)
        attributedString.draw(at: CGPoint(x: scaleBarX + scaleBarLength/2 - 15, y: scaleBarY + 15))
        
        // Draw room dimensions
        let roomWidth = bounds.maxX - bounds.minX
        let roomHeight = bounds.maxZ - bounds.minZ
        let dimensionsText = String(format: "%.2f m × %.2f m", roomWidth, roomHeight)
        let dimAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: textColor
        ]
        let dimAttributedString = NSAttributedString(string: dimensionsText, attributes: dimAttributes)
        dimAttributedString.draw(at: CGPoint(x: size.width - 200, y: size.height - 40))
    }
    
    // MARK: - Export to File
    
    /// Save floor plan image to Documents directory
    static func saveFloorPlan(_ image: UIImage, format: ImageFormat = .png) -> URL? {
        let fileName: String
        let data: Data?
        
        switch format {
        case .png:
            fileName = "FloorPlan_\(dateString()).png"
            data = image.pngData()
        case .jpeg:
            fileName = "FloorPlan_\(dateString()).jpg"
            data = image.jpegData(compressionQuality: 0.9)
        }
        
        guard let imageData = data else {
            print("❌ Failed to get image data")
            return nil
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            print("✅ Floor plan saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("❌ Failed to save floor plan: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    enum ImageFormat {
        case png
        case jpeg
    }
}
