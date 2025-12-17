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
import simd

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
    
    // MARK: - Floor Plan Generation (from CapturedRoomSummary)
    
    /// Generate a floor plan image from room summary data
    static func generateFloorPlan(from roomSummary: CapturedRoomSummary, size: CGSize = CGSize(width: 1200, height: 1200)) -> UIImage? {
        // Guard against empty data
        guard !roomSummary.walls.isEmpty else {
            print("⚠️ Cannot generate floor plan: no walls detected")
            return nil
        }
        
        print("📐 Generating floor plan from room summary")
        print("   Walls: \(roomSummary.walls.count)")
        print("   Openings: \(roomSummary.openings.count)")
        
        // Calculate dominant wall angle for alignment
        let alignmentAngle = calculateDominantWallAngle(from: roomSummary)
        print("   Alignment angle: \(alignmentAngle * 180 / Float.pi)°")
        
        // Rotate walls and openings to align with grid
        let rotatedWalls = roomSummary.walls.map { wall in
            WallSummary(
                id: wall.id,
                length: wall.length,
                height: wall.height,
                thickness: wall.thickness,
                normal: rotatePoint(wall.normal, angle: -alignmentAngle),
                start: rotatePoint(wall.start, angle: -alignmentAngle),
                end: rotatePoint(wall.end, angle: -alignmentAngle),
                position: rotatePoint(wall.position, angle: -alignmentAngle)
            )
        }
        
        let rotatedOpenings = roomSummary.openings.map { opening in
            OpeningSummary(
                id: opening.id,
                width: opening.width,
                height: opening.height,
                position: rotatePoint(opening.position, angle: -alignmentAngle),
                type: opening.type
            )
        }
        
        // Create rotated room summary
        let rotatedRoom = CapturedRoomSummary(
            roomId: roomSummary.roomId,
            floorArea: roomSummary.floorArea,
            walls: rotatedWalls,
            openings: rotatedOpenings
        )
        
        // Calculate room bounds from rotated walls
        let bounds = calculateRoomBounds(from: rotatedRoom)
        print("   Room bounds: \(bounds)")
        
        // Create image context with explicit scale for better performance
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
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
        drawWalls(context: context, walls: rotatedWalls, transform: transform)
        
        // Draw openings (doors and windows)
        drawOpenings(context: context, openings: rotatedOpenings, transform: transform)
        
        // Draw wall dimension annotations
        drawWallDimensions(context: context, walls: rotatedWalls, transform: transform)
        
        // Draw scale and dimensions
        drawScale(context: context, size: size, transform: transform, bounds: bounds)

        // Draw title and north arrow for standard floor-plan look
        drawTitle(context: context, size: size, roomId: roomSummary.roomId)
        drawNorthArrow(context: context, size: size)
        
        // Get the image
        let floorPlan = UIGraphicsGetImageFromCurrentImageContext()
        print("✅ Floor plan generated successfully")
        
        return floorPlan
    }
    
    // MARK: - Helper Functions
    
    /// Calculate the dominant wall angle to align the floor plan with room orientation
    private static func calculateDominantWallAngle(from roomSummary: CapturedRoomSummary) -> Float {
        guard !roomSummary.walls.isEmpty else { return 0 }
        
        // Collect all wall tangent angles
        let up = simd_float3(0, 1, 0)
        var angles: [Float] = []
        
        for wall in roomSummary.walls {
            let normal = simd_normalize(wall.normal)
            let tangent = simd_normalize(simd_cross(up, normal))
            
            if simd_length(tangent) > 1e-3 {
                // Get angle in range [-pi, pi]
                var angle = atan2(tangent.x, tangent.z)
                
                // Normalize to [0, pi/2] by taking modulo with respect to 90 degrees
                // This groups all parallel/perpendicular walls together
                angle = abs(angle)
                while angle > Float.pi / 2 {
                    angle -= Float.pi / 2
                }
                
                angles.append(angle)
            }
        }
        
        guard !angles.isEmpty else { return 0 }
        
        // Find the most common angle bucket (rounded to nearest 5 degrees)
        let bucketSize: Float = Float.pi / 36 // 5 degrees
        var buckets: [Int: Int] = [:] // bucket index -> count
        
        for angle in angles {
            let bucket = Int((angle / bucketSize).rounded())
            buckets[bucket, default: 0] += 1
        }
        
        // Get the most common bucket
        let dominantBucket = buckets.max(by: { $0.value < $1.value })?.key ?? 0
        let dominantAngle = Float(dominantBucket) * bucketSize
        
        print("   Dominant wall angle: \(dominantAngle * 180 / Float.pi)° (from \(angles.count) walls)")
        
        return dominantAngle
    }
    
    /// Rotate a point around the origin in the XZ plane
    private static func rotatePoint(_ point: simd_float3, angle: Float) -> simd_float3 {
        let cosA = cos(angle)
        let sinA = sin(angle)
        
        let x = point.x * cosA - point.z * sinA
        let z = point.x * sinA + point.z * cosA
        
        return simd_float3(x, point.y, z)
    }
    
    private static func calculateRoomBounds(from roomSummary: CapturedRoomSummary) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        var minX = Float.infinity
        var maxX = -Float.infinity
        var minZ = Float.infinity
        var maxZ = -Float.infinity
        let up = simd_float3(0, 1, 0)
        let defaultThickness: Float = 0.15

        // Get bounds from oriented wall rectangles
        for wall in roomSummary.walls {
            let length = wall.length
            let thickness = wall.thickness
            let normal = simd_normalize(wall.normal)
            // Tangent runs along the wall (perpendicular to normal, in the floor plane)
            var tangent = simd_normalize(simd_cross(up, normal))
            if simd_length(tangent) < 1e-3 {
                tangent = simd_float3(1, 0, 0) // fallback if normal is degenerate
            }

            let halfL = length / 2
            let halfT = thickness / 2
            let center = wall.position

            let corners: [simd_float3] = [
                center + tangent * halfL + normal * halfT,
                center + tangent * halfL - normal * halfT,
                center - tangent * halfL - normal * halfT,
                center - tangent * halfL + normal * halfT
            ]

            for c in corners {
                minX = min(minX, c.x)
                maxX = max(maxX, c.x)
                minZ = min(minZ, c.z)
                maxZ = max(maxZ, c.z)
            }
        }
        
        // If we don't have valid bounds, use defaults
        if minX.isInfinite || maxX.isInfinite || minZ.isInfinite || maxZ.isInfinite {
            return (0, 5, 0, 5)
        }
        
        // Add padding
        let padding: Float = 0.5
        minX -= padding
        maxX += padding
        minZ -= padding
        maxZ += padding
        
        return (minX, maxX, minZ, maxZ)
    }
    
    private static func calculateTransform(from bounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float), to size: CGSize) -> CGAffineTransform {
        // Guard against invalid bounds
        guard bounds.maxX > bounds.minX && bounds.maxZ > bounds.minZ else {
            return CGAffineTransform.identity
        }
        
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
        
        // Vertical lines (constant X, varying Z)
        var x = (bounds.minX / gridSpacing).rounded(.down) * gridSpacing
        while x <= bounds.maxX {
            let start = worldToImage(simd_float3(x, 0, bounds.minZ), transform: transform)
            let end = worldToImage(simd_float3(x, 0, bounds.maxZ), transform: transform)
            context.move(to: start)
            context.addLine(to: end)
            x += gridSpacing
        }
        
        // Horizontal lines (constant Z, varying X)
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
    
    private static func drawWalls(context: CGContext, walls: [WallSummary], transform: CGAffineTransform) {
        wallColor.setFill()
        let up = simd_float3(0, 1, 0)
        let defaultThickness: Float = 0.15
        
        for wall in walls {
            let position = wall.position
            let thickness = wall.thickness ?? defaultThickness
            let length = wall.length ?? 1.0
            let normal = simd_normalize(wall.normal)
            var tangent = simd_normalize(simd_cross(up, normal))
            if simd_length(tangent) < 1e-3 {
                tangent = simd_float3(1, 0, 0)
            }

            let halfT = thickness / 2
            let halfL = length / 2

            let c0 = position + tangent * halfL + normal * halfT
            let c1 = position + tangent * halfL - normal * halfT
            let c2 = position - tangent * halfL - normal * halfT
            let c3 = position - tangent * halfL + normal * halfT
            let corners = [c0, c1, c2, c3]
            
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
    
    private static func drawOpenings(context: CGContext, openings: [OpeningSummary], transform: CGAffineTransform) {
        for opening in openings {
            let position = opening.position
            
            // Draw opening as a simple marker dot instead of a line
            // Since we don't have reliable normal data for openings
            
            if opening.type == "door" {
                // Draw doors as blue circles
                doorColor.setFill()
            } else {
                // Draw windows as cyan circles
                windowColor.setFill()
            }
            
            let centerPoint = worldToImage(position, transform: transform)
            let radius: CGFloat = 8
            let rect = CGRect(x: centerPoint.x - radius, y: centerPoint.y - radius, width: radius * 2, height: radius * 2)
            context.fillEllipse(in: rect)
        }
        
        // Reset line dash for subsequent drawing
        context.setLineDash(phase: 0, lengths: [])
    }
    
    private static func drawWallDimensions(context: CGContext, walls: [WallSummary], transform: CGAffineTransform) {
        // Limit dimension annotations for performance
        let maxAnnotations = 8
        let wallsToAnnotate = walls.prefix(maxAnnotations)
        
        let up = simd_float3(0, 1, 0)
        let defaultThickness: Float = 0.15
        let offsetDistance: Float = 0.4 // Offset dimension line from wall
        
        for wall in wallsToAnnotate {
            let length = wall.length
            guard length > 0 else { continue }
            
            let position = wall.position
            let thickness = wall.thickness
            let normal = simd_normalize(wall.normal)
            var tangent = simd_normalize(simd_cross(up, normal))
            
            if simd_length(tangent) < 1e-3 {
                tangent = simd_float3(1, 0, 0)
            }
            
            // Calculate wall endpoints (center of the wall)
            let halfL = length / 2
            let start3D = position - tangent * halfL
            let end3D = position + tangent * halfL
            
            // Offset the dimension line outward from the wall
            let offsetStart = start3D + normal * offsetDistance
            let offsetEnd = end3D + normal * offsetDistance
            
            let startPt = worldToImage(offsetStart, transform: transform)
            let endPt = worldToImage(offsetEnd, transform: transform)
            
            // Draw dimension line
            context.saveGState()
            textColor.setStroke()
            context.setLineWidth(1)
            context.move(to: startPt)
            context.addLine(to: endPt)
            context.strokePath()
            
            // Draw end ticks
            let tickSize: CGFloat = 6
            let dx = endPt.x - startPt.x
            let dy = endPt.y - startPt.y
            let lineLength = sqrt(dx*dx + dy*dy)
            
            if lineLength > 1e-3 {
                let perpX = -dy / lineLength * tickSize
                let perpY = dx / lineLength * tickSize
                
                // Start tick
                context.move(to: CGPoint(x: startPt.x + perpX, y: startPt.y + perpY))
                context.addLine(to: CGPoint(x: startPt.x - perpX, y: startPt.y - perpY))
                
                // End tick
                context.move(to: CGPoint(x: endPt.x + perpX, y: endPt.y + perpY))
                context.addLine(to: CGPoint(x: endPt.x - perpX, y: endPt.y - perpY))
                context.strokePath()
            }
            
            // Draw length text
            let midPoint = CGPoint(x: (startPt.x + endPt.x) / 2, y: (startPt.y + endPt.y) / 2)
            let lengthText = String(format: "%.2fm", length)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: textColor,
                .backgroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
            
            let attributedString = NSAttributedString(string: lengthText, attributes: attributes)
            let textSize = attributedString.size()
            
            // Position text slightly offset from the line
            let textPoint = CGPoint(
                x: midPoint.x - textSize.width / 2,
                y: midPoint.y - textSize.height - 4
            )
            
            attributedString.draw(at: textPoint)
            context.restoreGState()
        }
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
        
        // Draw scale label (show both meters and feet)
        let scaleFeet = MeasurementHelper.toFeet(2.0)
        let scaleText = String(format: "2 m (%.2f ft)", scaleFeet)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: textColor
        ]
        let attributedString = NSAttributedString(string: scaleText, attributes: attributes)
        attributedString.draw(at: CGPoint(x: scaleBarX + scaleBarLength/2 - 15, y: scaleBarY + 15))
        
        // Draw room dimensions
        let roomWidth = bounds.maxX - bounds.minX
        let roomHeight = bounds.maxZ - bounds.minZ
        let dimensionsText = "\(MeasurementHelper.formatDistanceDual(roomWidth)) × \(MeasurementHelper.formatDistanceDual(roomHeight))"
        let dimAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: textColor
        ]
        let dimAttributedString = NSAttributedString(string: dimensionsText, attributes: dimAttributes)
        dimAttributedString.draw(at: CGPoint(x: size.width - 200, y: size.height - 40))
    }

    private static func drawTitle(context: CGContext, size: CGSize, roomId: String) {
        let title = "Floor Plan – \(roomId)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: textColor
        ]
        let attributedString = NSAttributedString(string: title, attributes: attributes)
        attributedString.draw(at: CGPoint(x: 20, y: 20))
    }

    private static func drawNorthArrow(context: CGContext, size: CGSize) {
        // Simple north arrow top-right
        let arrowCenter = CGPoint(x: size.width - 40, y: 60)
        let arrowSize: CGFloat = 20
        let path = UIBezierPath()
        path.move(to: CGPoint(x: arrowCenter.x, y: arrowCenter.y - arrowSize))
        path.addLine(to: CGPoint(x: arrowCenter.x - arrowSize * 0.6, y: arrowCenter.y + arrowSize * 0.6))
        path.addLine(to: CGPoint(x: arrowCenter.x + arrowSize * 0.6, y: arrowCenter.y + arrowSize * 0.6))
        path.close()
        wallColor.setFill()
        path.fill()

        let nAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: textColor
        ]
        let nString = NSAttributedString(string: "N", attributes: nAttributes)
        nString.draw(at: CGPoint(x: arrowCenter.x - 5, y: arrowCenter.y + arrowSize * 0.7))
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
