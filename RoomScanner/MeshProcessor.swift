/*
 MeshProcessor.swift
 Purpose: Process ARKit mesh data for fallback mode when RoomPlan is unavailable.
 Implements plane detection, wall measurement extraction from raw mesh data.
 
 Key Features:
 - RANSAC-based plane detection from point clouds
 - Wall height calculation from floor plane
 - Wall thickness estimation from parallel planes
 - Distance calculations between walls
 
 Created: December 2025
 */

import Foundation
import ARKit
import simd
import Accelerate

/// Processor for ARKit mesh data - extracts measurements from raw LiDAR scans
struct MeshProcessor {
    
    // MARK: - Constants
    
    /// Threshold for considering planes as parallel (dot product of normals)
    private static let parallelThreshold: Float = 0.95
    
    /// Threshold for considering planes as perpendicular
    private static let perpendicularThreshold: Float = 0.1
    
    /// Minimum number of points required to fit a plane
    private static let minPointsForPlane = 100
    
    /// RANSAC iteration count
    private static let ransacIterations = 100
    
    /// Distance threshold for RANSAC inliers (meters)
    private static let ransacThreshold: Float = 0.05
    
    /// Threshold for vertical planes (dot product with up vector)
    private static let verticalThreshold: Float = 0.1
    
    // MARK: - Plane Detection
    
    /// Extract planes from ARMeshAnchors using RANSAC
    static func estimatePlanes(from meshAnchors: [ARMeshAnchor]) -> [DetectedPlane] {
        print("🔍 Estimating planes from \(meshAnchors.count) mesh anchors")
        
        guard !meshAnchors.isEmpty else { return [] }
        
        // Collect all vertices from mesh anchors
        var allVertices: [simd_float3] = []
        
        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices
            let transform = anchor.transform
            
            // Extract vertices and transform to world space
            let vertexCount = Int(vertices.count)
            let vertexBuffer = vertices.buffer.contents()
            let vertexStride = vertices.stride
            let vertexOffset = vertices.offset
            
            for i in 0..<vertexCount {
                let vertexPointer = vertexBuffer.advanced(by: vertexOffset + (i * vertexStride))
                let vertex = vertexPointer.assumingMemoryBound(to: simd_float3.self).pointee
                
                let worldVertex = simd_make_float3(
                    transform * simd_float4(vertex.x, vertex.y, vertex.z, 1.0)
                )
                allVertices.append(worldVertex)
            }
        }
        
        print("📊 Collected \(allVertices.count) vertices")
        
        // Detect multiple planes using iterative RANSAC
        var detectedPlanes: [DetectedPlane] = []
        var remainingVertices = allVertices
        
        // Find up to 10 planes (floor, ceiling, and walls)
        for iteration in 0..<10 {
            guard remainingVertices.count >= minPointsForPlane else { break }
            
            if let plane = detectSinglePlane(from: remainingVertices) {
                detectedPlanes.append(plane)
                
                // Remove inliers for this plane
                remainingVertices = remainingVertices.filter { vertex in
                    abs(MeasurementHelper.distanceFromPointToPlane(vertex, plane.plane)) > ransacThreshold * 2
                }
                
                print("✅ Plane \(iteration + 1): \(plane.isHorizontal ? "Horizontal" : "Vertical"), \(plane.points.count) points")
            } else {
                break
            }
        }
        
        print("🎯 Detected \(detectedPlanes.count) planes total")
        return detectedPlanes
    }
    
    /// Detect a single dominant plane using RANSAC
    private static func detectSinglePlane(from vertices: [simd_float3]) -> DetectedPlane? {
        guard vertices.count >= minPointsForPlane else { return nil }
        
        var bestPlane: Plane?
        var bestInlierCount = 0
        var bestInliers: [simd_float3] = []
        
        // RANSAC iterations
        for _ in 0..<ransacIterations {
            // Randomly select 3 points
            let indices = (0..<3).map { _ in Int.random(in: 0..<vertices.count) }
            let p1 = vertices[indices[0]]
            let p2 = vertices[indices[1]]
            let p3 = vertices[indices[2]]
            
            // Fit plane to these 3 points
            guard let plane = MeasurementHelper.planeFrom3Points(p1, p2, p3) else { continue }
            
            // Count inliers
            var inliers: [simd_float3] = []
            for vertex in vertices {
                let distance = abs(MeasurementHelper.distanceFromPointToPlane(vertex, plane))
                if distance < ransacThreshold {
                    inliers.append(vertex)
                }
            }
            
            // Update best plane if this one is better
            if inliers.count > bestInlierCount {
                bestInlierCount = inliers.count
                bestPlane = plane
                bestInliers = inliers
            }
        }
        
        guard let plane = bestPlane, bestInlierCount >= minPointsForPlane else { return nil }
        
        // Refine plane using all inliers
        let refinedPlane = MeasurementHelper.planeFromPoints(bestInliers) ?? plane
        
        // Determine if horizontal or vertical
        let upVector = simd_float3(0, 1, 0)
        let dotUp = abs(simd_dot(refinedPlane.normal, upVector))
        let isHorizontal = dotUp > (1.0 - verticalThreshold)
        
        return DetectedPlane(
            plane: refinedPlane,
            points: bestInliers,
            isHorizontal: isHorizontal
        )
    }
    
    // MARK: - Wall Measurements
    
    /// Compute wall height as distance from floor plane to top of wall
    static func computeWallHeight(plane: DetectedPlane, floorPlane: DetectedPlane) -> Float {
        guard !plane.isHorizontal else { return 0 }
        
        // Find the highest point in the wall plane
        let wallPoints = plane.points
        let maxY = wallPoints.map { $0.y }.max() ?? 0
        let minY = wallPoints.map { $0.y }.min() ?? 0
        
        // Height is the Y-range of the wall
        let height = maxY - minY
        
        print("📏 Wall height: \(String(format: "%.2f", height))m (Y range: \(String(format: "%.2f", minY)) to \(String(format: "%.2f", maxY)))")
        
        return max(height, 0)
    }
    
    /// Estimate wall thickness by finding parallel planes
    static func computeWallThickness(plane: DetectedPlane, allPlanes: [DetectedPlane]) -> Float? {
        guard !plane.isHorizontal else { return nil }
        
        // Find parallel walls
        var minDistance: Float?
        
        for otherPlane in allPlanes {
            guard otherPlane.id != plane.id else { continue }
            guard !otherPlane.isHorizontal else { continue }
            
            // Check if planes are parallel
            let dotProduct = abs(simd_dot(plane.normal, otherPlane.normal))
            if dotProduct > parallelThreshold {
                // Calculate distance between parallel planes
                let distance = MeasurementHelper.distanceBetweenParallelPlanes(plane.plane, otherPlane.plane)
                
                // Only consider reasonable wall thicknesses (5cm to 50cm)
                if distance > 0.05 && distance < 0.5 {
                    if let currentMin = minDistance {
                        minDistance = min(currentMin, distance)
                    } else {
                        minDistance = distance
                    }
                }
            }
        }
        
        if let thickness = minDistance {
            print("📏 Wall thickness: \(String(format: "%.2f", thickness))m")
        } else {
            print("⚠️ Could not determine wall thickness - using default 0.15m")
        }
        
        return minDistance ?? 0.15 // Default to 15cm if no parallel wall found
    }
    
    /// Calculate distance between two walls (not necessarily parallel)
    static func distanceBetweenWalls(_ wall1: DetectedPlane, _ wall2: DetectedPlane) -> Float {
        // Use centers of the wall planes
        let center1 = wall1.center
        let center2 = wall2.center
        
        let distance = simd_distance(center1, center2)
        
        print("📏 Distance between walls: \(String(format: "%.2f", distance))m")
        return distance
    }
}

// MARK: - Data Models

/// Represents a detected plane with associated points
struct DetectedPlane: Identifiable {
    let id = UUID()
    let plane: Plane
    let points: [simd_float3]
    let isHorizontal: Bool
    
    /// Center point of the plane (average of all points)
    var center: simd_float3 {
        guard !points.isEmpty else { return simd_float3(0, 0, 0) }
        
        let sum = points.reduce(simd_float3(0, 0, 0)) { $0 + $1 }
        return sum / Float(points.count)
    }
    
    /// Normal vector of the plane
    var normal: simd_float3 {
        plane.normal
    }
    
    /// Estimated length of the plane (for walls)
    var estimatedLength: Float {
        guard points.count >= 2 else { return 0 }
        
        // Project points onto the plane and find the bounding box
        let projected = points.map { projectPointOntoPlane($0, plane) }
        
        // Find min/max in the plane's coordinate system
        let xCoords = projected.map { $0.x }
        let zCoords = projected.map { $0.z }
        
        let xRange = (xCoords.max() ?? 0) - (xCoords.min() ?? 0)
        let zRange = (zCoords.max() ?? 0) - (zCoords.min() ?? 0)
        
        return max(xRange, zRange)
    }
    
    /// Estimated area of the plane
    var estimatedArea: Float {
        guard points.count >= 3 else { return 0 }
        
        // Project points and compute 2D bounding box area
        let projected = points.map { projectPointOntoPlane($0, plane) }
        
        let xCoords = projected.map { $0.x }
        let zCoords = projected.map { $0.z }
        
        let xRange = (xCoords.max() ?? 0) - (xCoords.min() ?? 0)
        let zRange = (zCoords.max() ?? 0) - (zCoords.min() ?? 0)
        
        return xRange * zRange
    }
    
    /// Project a point onto the plane
    private func projectPointOntoPlane(_ point: simd_float3, _ plane: Plane) -> simd_float3 {
        let distance = MeasurementHelper.distanceFromPointToPlane(point, plane)
        return point - plane.normal * distance
    }
}

/// Represents a geometric plane with position and normal
struct Plane {
    let position: simd_float3 // A point on the plane
    let normal: simd_float3   // Unit normal vector
    
    /// Distance from origin along normal
    var d: Float {
        -simd_dot(normal, position)
    }
}
