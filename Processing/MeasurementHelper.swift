/*
 MeasurementHelper.swift
 Purpose: Mathematical utilities for geometric calculations and plane fitting.
 Provides helper functions for distance calculations, plane operations, and conversions.
 
 Key Features:
 - Point-to-plane distance calculations
 - Plane fitting from point clouds using SVD
 - Distance between parallel planes
 - Geometric utilities for 3D space
 
 Created: December 2025
 */

import Foundation
import simd
import Accelerate

/// Helper utilities for measurements and geometric calculations
struct MeasurementHelper {
    
    // MARK: - Constants
    
    /// Tolerance for floating point comparisons
    static let epsilon: Float = 0.0001
    
    /// Standard wall thickness when unknown (meters)
    static let defaultWallThickness: Float = 0.15
    
    /// Standard ceiling height when unknown (meters)
    static let defaultCeilingHeight: Float = 2.5
    
    // MARK: - Distance Calculations
    
    /// Calculate distance from a point to a plane
    /// Formula: distance = |ax + by + cz + d| / sqrt(a² + b² + c²)
    /// where (a,b,c) is the plane normal and d is the plane constant
    static func distanceFromPointToPlane(_ point: simd_float3, _ plane: Plane) -> Float {
        let numerator = simd_dot(plane.normal, point) + plane.d
        return numerator // Normal is already unit length
    }
    
    /// Calculate distance between two parallel planes
    static func distanceBetweenParallelPlanes(_ plane1: Plane, _ plane2: Plane) -> Float {
        // For parallel planes, the distance is |d1 - d2| / |normal|
        // Since normals are unit length, it simplifies to |d1 - d2|
        return abs(plane1.d - plane2.d)
    }
    
    /// Calculate minimum distance between two non-parallel planes
    static func distanceBetweenPlanes(_ plane1: Plane, _ plane2: Plane) -> Float {
        // If planes are parallel, use parallel distance formula
        let dotProduct = simd_dot(plane1.normal, plane2.normal)
        if abs(dotProduct) > 0.95 {
            return distanceBetweenParallelPlanes(plane1, plane2)
        }
        
        // For non-parallel planes, use distance between their centers
        return simd_distance(plane1.position, plane2.position)
    }
    
    // MARK: - Plane Fitting
    
    /// Fit a plane to a set of 3D points using least squares (SVD method)
    /// This implements PCA-based plane fitting
    static func planeFromPoints(_ points: [simd_float3]) -> Plane? {
        guard points.count >= 3 else { return nil }
        
        // Calculate centroid (mean position)
        let sum = points.reduce(simd_float3(0, 0, 0)) { $0 + $1 }
        let centroid = sum / Float(points.count)
        
        // Center the points
        let centeredPoints = points.map { $0 - centroid }
        
        // Build covariance matrix
        var m11: Float = 0, m12: Float = 0, m13: Float = 0
        var m22: Float = 0, m23: Float = 0, m33: Float = 0
        
        for point in centeredPoints {
            m11 += point.x * point.x
            m12 += point.x * point.y
            m13 += point.x * point.z
            m22 += point.y * point.y
            m23 += point.y * point.z
            m33 += point.z * point.z
        }
        
        // Covariance matrix is symmetric
        let covarianceMatrix: [Float] = [
            m11, m12, m13,
            m12, m22, m23,
            m13, m23, m33
        ]
        
        // Perform SVD to find eigenvectors
        // The eigenvector with smallest eigenvalue is the plane normal
        var matrixA = covarianceMatrix
        var s = [Float](repeating: 0, count: 3)
        var u = [Float](repeating: 0, count: 9)
        var vt = [Float](repeating: 0, count: 9)
        
        var m: __CLPK_integer = 3
        var n: __CLPK_integer = 3
        var lda: __CLPK_integer = 3
        var ldu: __CLPK_integer = 3
        var ldvt: __CLPK_integer = 3
        var lwork: __CLPK_integer = -1
        var work = [Float](repeating: 0, count: 1)
        var iwork = [__CLPK_integer](repeating: 0, count: 8 * 3)
        var info: __CLPK_integer = 0
        var jobz: Int8 = Int8(UInt8(ascii: "A"))
        
        // Query optimal workspace
        sgesdd_(&jobz,
                &m, &n, &matrixA, &lda, &s, &u, &ldu, &vt, &ldvt,
                &work, &lwork, &iwork, &info)
        
        lwork = __CLPK_integer(work[0])
        work = [Float](repeating: 0, count: Int(lwork))
        
        // Actual SVD computation
        sgesdd_(&jobz,
                &m, &n, &matrixA, &lda, &s, &u, &ldu, &vt, &ldvt,
                &work, &lwork, &iwork, &info)
        
        guard info == 0 else {
            print("⚠️ SVD failed with info: \(info)")
            return fallbackPlaneFromPoints(points)
        }
        
        // The last column of U is the normal (smallest eigenvalue)
        let normal = simd_normalize(simd_float3(u[6], u[7], u[8]))
        
        return Plane(position: centroid, normal: normal)
    }
    
    /// Fallback plane fitting using cross product (for 3 points)
    private static func fallbackPlaneFromPoints(_ points: [simd_float3]) -> Plane? {
        guard points.count >= 3 else { return nil }
        
        // Use first 3 points that aren't collinear
        for i in 0..<(points.count - 2) {
            for j in (i+1)..<(points.count - 1) {
                for k in (j+1)..<points.count {
                    if let plane = planeFrom3Points(points[i], points[j], points[k]) {
                        return plane
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Create a plane from exactly 3 points
    static func planeFrom3Points(_ p1: simd_float3, _ p2: simd_float3, _ p3: simd_float3) -> Plane? {
        let v1 = p2 - p1
        let v2 = p3 - p1
        
        let normal = simd_cross(v1, v2)
        let normalLength = simd_length(normal)
        
        guard normalLength > epsilon else { return nil } // Points are collinear
        
        let unitNormal = normal / normalLength
        
        return Plane(position: p1, normal: unitNormal)
    }
    
    // MARK: - Plane Classification
    
    /// Check if a plane is horizontal (floor or ceiling)
    static func isHorizontalPlane(_ plane: Plane, tolerance: Float = 0.1) -> Bool {
        let upVector = simd_float3(0, 1, 0)
        let dotProduct = abs(simd_dot(plane.normal, upVector))
        return dotProduct > (1.0 - tolerance)
    }
    
    /// Check if a plane is vertical (wall)
    static func isVerticalPlane(_ plane: Plane, tolerance: Float = 0.1) -> Bool {
        let upVector = simd_float3(0, 1, 0)
        let dotProduct = abs(simd_dot(plane.normal, upVector))
        return dotProduct < tolerance
    }
    
    /// Check if two planes are parallel
    static func arePlanesParallel(_ plane1: Plane, _ plane2: Plane, threshold: Float = 0.95) -> Bool {
        let dotProduct = abs(simd_dot(plane1.normal, plane2.normal))
        return dotProduct > threshold
    }
    
    /// Check if two planes are perpendicular
    static func arePlanesPerpendicular(_ plane1: Plane, _ plane2: Plane, threshold: Float = 0.1) -> Bool {
        let dotProduct = abs(simd_dot(plane1.normal, plane2.normal))
        return dotProduct < threshold
    }
    
    // MARK: - Projections
    
    /// Project a point onto a plane
    static func projectPointOntoPlane(_ point: simd_float3, _ plane: Plane) -> simd_float3 {
        let distance = distanceFromPointToPlane(point, plane)
        return point - plane.normal * distance
    }
    
    /// Project a point onto a line defined by origin and direction
    static func projectPointOntoLine(_ point: simd_float3, lineOrigin: simd_float3, lineDirection: simd_float3) -> simd_float3 {
        let v = point - lineOrigin
        let t = simd_dot(v, lineDirection) / simd_dot(lineDirection, lineDirection)
        return lineOrigin + t * lineDirection
    }
    
    // MARK: - Conversions
    
    /// Convert ARKit units to meters (ARKit already uses meters, but kept for clarity)
    static func toMeters(_ arkitUnits: Float) -> Float {
        return arkitUnits
    }
    
    /// Convert meters to centimeters for display
    static func toCentimeters(_ meters: Float) -> Float {
        return meters * 100.0
    }
    
    /// Convert square meters to square feet
    static func toSquareFeet(_ squareMeters: Float) -> Float {
        return squareMeters * 10.764
    }

    /// Convert meters to feet
    static func toFeet(_ meters: Float) -> Float {
        return meters * 3.28084
    }

    /// Format distance showing both meters and feet
    static func formatDistanceDual(_ meters: Float, precision: Int = 2) -> String {
        let feet = toFeet(meters)
        return String(format: "%.2f m (%.2f ft)", meters, feet)
    }

    /// Format area showing both square meters and square feet
    static func formatAreaDual(_ squareMeters: Float, precision: Int = 2) -> String {
        let sqFt = toSquareFeet(squareMeters)
        return String(format: "%.2f m² (%.2f ft²)", squareMeters, sqFt)
    }
    
    // MARK: - Formatting
    
    /// Format distance in meters with appropriate precision
    static func formatDistance(_ meters: Float, precision: Int = 2) -> String {
        return String(format: "%.\(precision)f m", meters)
    }
    
    /// Format area with appropriate unit
    static func formatArea(_ squareMeters: Float, precision: Int = 2) -> String {
        return String(format: "%.\(precision)f m²", squareMeters)
    }
    
    /// Format angle in degrees
    static func formatAngle(_ radians: Float, precision: Int = 1) -> String {
        let degrees = radians * 180.0 / .pi
        return String(format: "%.\(precision)f°", degrees)
    }
    
    // MARK: - Validation
    
    /// Check if a measurement is within reasonable bounds
    static func isReasonableWallHeight(_ height: Float) -> Bool {
        return height > 1.8 && height < 5.0
    }
    
    /// Check if a measurement is a reasonable wall thickness
    static func isReasonableWallThickness(_ thickness: Float) -> Bool {
        return thickness > 0.05 && thickness < 0.8
    }
    
    /// Check if a measurement is a reasonable room dimension
    static func isReasonableRoomDimension(_ dimension: Float) -> Bool {
        return dimension > 1.0 && dimension < 100.0
    }
    
    /// Check if floor area is reasonable
    static func isReasonableFloorArea(_ area: Float) -> Bool {
        return area > 2.0 && area < 1000.0
    }
}

// MARK: - Geometry Utilities

extension simd_float3 {
    /// Create from array
    init(_ array: [Float]) {
        precondition(array.count >= 3)
        self.init(array[0], array[1], array[2])
    }
    
    /// Convert to array
    func toArray() -> [Float] {
        return [x, y, z]
    }
    
    /// String representation for debugging
    var debugDescription: String {
        return String(format: "(%.2f, %.2f, %.2f)", x, y, z)
    }
}

extension simd_float4x4 {
    /// Extract translation component
    var translation: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
    
    /// Extract rotation matrix (3x3)
    var rotation: simd_float3x3 {
        return simd_float3x3(
            simd_float3(columns.0.x, columns.0.y, columns.0.z),
            simd_float3(columns.1.x, columns.1.y, columns.1.z),
            simd_float3(columns.2.x, columns.2.y, columns.2.z)
        )
    }
}
