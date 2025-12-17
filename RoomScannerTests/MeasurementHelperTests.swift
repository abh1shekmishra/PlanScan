/*
 MeasurementHelperTests.swift
 Purpose: Unit tests for MeasurementHelper geometric calculations.
 Validates mathematical correctness of plane fitting, distance calculations, and projections.
 
 Test Coverage:
 - Point-to-plane distance calculations
 - Plane fitting from points
 - Parallel plane distance
 - Plane classification (horizontal/vertical)
 - Projection operations
 
 Created: December 2025
 */

import XCTest
import simd
@testable import RoomScanner

final class MeasurementHelperTests: XCTestCase {
    
    // MARK: - Distance Calculations
    
    func testPointToPlaneDistance() {
        // Create a horizontal plane at y=0 (floor)
        let plane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(0, 1, 0)
        )
        
        // Test point 2 meters above the plane
        let point1 = simd_float3(5, 2, 3)
        let distance1 = MeasurementHelper.distanceFromPointToPlane(point1, plane)
        XCTAssertEqual(distance1, 2.0, accuracy: 0.001, "Point 2m above plane should have distance 2.0")
        
        // Test point on the plane
        let point2 = simd_float3(10, 0, -5)
        let distance2 = MeasurementHelper.distanceFromPointToPlane(point2, plane)
        XCTAssertEqual(distance2, 0.0, accuracy: 0.001, "Point on plane should have distance 0.0")
        
        // Test point below the plane
        let point3 = simd_float3(0, -1.5, 0)
        let distance3 = MeasurementHelper.distanceFromPointToPlane(point3, plane)
        XCTAssertEqual(abs(distance3), 1.5, accuracy: 0.001, "Point 1.5m below plane should have distance 1.5")
    }
    
    func testDistanceBetweenParallelPlanes() {
        // Two horizontal planes at different heights
        let plane1 = Plane(
            position: simd_float3(0, 0, 0),    // Floor at y=0
            normal: simd_float3(0, 1, 0)
        )
        
        let plane2 = Plane(
            position: simd_float3(0, 2.7, 0),  // Ceiling at y=2.7
            normal: simd_float3(0, 1, 0)
        )
        
        let distance = MeasurementHelper.distanceBetweenParallelPlanes(plane1, plane2)
        XCTAssertEqual(distance, 2.7, accuracy: 0.001, "Distance between floor and ceiling should be 2.7m")
    }
    
    func testDistanceBetweenPlanesNonParallel() {
        // Two perpendicular walls
        let wall1 = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)  // Facing +X
        )
        
        let wall2 = Plane(
            position: simd_float3(5, 0, 5),
            normal: simd_float3(0, 0, 1)  // Facing +Z
        )
        
        let distance = MeasurementHelper.distanceBetweenPlanes(wall1, wall2) 
        
        // Distance should be approximately sqrt(50) ≈ 7.07
        XCTAssertEqual(distance, sqrt(50), accuracy: 0.1, "Distance should be approximately 7.07m")
    }
    
    // MARK: - Plane Fitting
    
    func testPlaneFrom3Points() { 
        // Three points forming a horizontal plane at y=1
        let p1 = simd_float3(0, 1, 0)
        let p2 = simd_float3(1, 1, 0)
        let p3 = simd_float3(0, 1, 1)
        
        let plane = MeasurementHelper.planeFrom3Points(p1, p2, p3)
        XCTAssertNotNil(plane, "Should create plane from 3 non-collinear points")
        
        if let plane = plane {
            // Normal should point upward (0, 1, 0) or downward (0, -1, 0)
            let normalY = abs(plane.normal.y)
            XCTAssertEqual(normalY, 1.0, accuracy: 0.01, "Normal should be vertical")
            
            // All three points should be on the plane
            let dist1 = abs(MeasurementHelper.distanceFromPointToPlane(p1, plane))
            let dist2 = abs(MeasurementHelper.distanceFromPointToPlane(p2, plane))
            let dist3 = abs(MeasurementHelper.distanceFromPointToPlane(p3, plane))
            
            XCTAssertLessThan(dist1, 0.01, "Point 1 should be on plane")
            XCTAssertLessThan(dist2, 0.01, "Point 2 should be on plane")
            XCTAssertLessThan(dist3, 0.01, "Point 3 should be on plane")
        }
    }
    
    func testPlaneFrom3CollinearPoints() {
        // Three collinear points (on a line)
        let p1 = simd_float3(0, 0, 0)
        let p2 = simd_float3(1, 0, 0)
        let p3 = simd_float3(2, 0, 0)
        
        let plane = MeasurementHelper.planeFrom3Points(p1, p2, p3)
        XCTAssertNil(plane, "Should not create plane from collinear points")
    }
    
    func testPlaneFromPointCloud() {
        // Generate points on a tilted plane
        var points: [simd_float3] = []
        
        // Plane equation: 2x + 3y + z = 6
        for x in stride(from: Float(0), to: Float(3), by: Float(0.5)) {
            for y in stride(from: Float(0), to: Float(2), by: Float(0.5)) {
                let z = 6 - 2*x - 3*y
                if z >= 0 {
                    points.append(simd_float3(x, y, z))
                }
            }
        }
        
        let plane = MeasurementHelper.planeFromPoints(points)
        XCTAssertNotNil(plane, "Should fit plane to point cloud")
        
        if let plane = plane {
            // Check that normal is normalized
            let normalLength = simd_length(plane.normal)
            XCTAssertEqual(normalLength, 1.0, accuracy: 0.01, "Normal should be unit length")
            
            // All points should be close to the plane
            for point in points {
                let distance = abs(MeasurementHelper.distanceFromPointToPlane(point, plane))
                XCTAssertLessThan(distance, 0.1, "All points should be close to fitted plane")
            }
        }
    }
    
    // MARK: - Plane Classification
    
    func testIsHorizontalPlane() {
        // Floor plane (normal pointing up)
        let floorPlane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(0, 1, 0)
        )
        XCTAssertTrue(MeasurementHelper.isHorizontalPlane(floorPlane), "Floor should be horizontal")
        
        // Ceiling plane (normal pointing down)
        let ceilingPlane = Plane(
            position: simd_float3(0, 3, 0),
            normal: simd_float3(0, -1, 0)
        )
        XCTAssertTrue(MeasurementHelper.isHorizontalPlane(ceilingPlane), "Ceiling should be horizontal")
        
        // Wall plane (normal horizontal)
        let wallPlane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        XCTAssertFalse(MeasurementHelper.isHorizontalPlane(wallPlane), "Wall should not be horizontal")
    }
    
    func testIsVerticalPlane() {
        // Wall plane
        let wallPlane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        XCTAssertTrue(MeasurementHelper.isVerticalPlane(wallPlane), "Wall should be vertical")
        
        // Floor plane
        let floorPlane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(0, 1, 0)
        )
        XCTAssertFalse(MeasurementHelper.isVerticalPlane(floorPlane), "Floor should not be vertical")
    }
    
    func testArePlanesParallel() {
        // Two parallel walls
        let wall1 = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        
        let wall2 = Plane(
            position: simd_float3(5, 0, 0),
            normal: simd_float3(1, 0, 0)  // Same direction
        )
        
        XCTAssertTrue(MeasurementHelper.arePlanesParallel(wall1, wall2), "Walls should be parallel")
        
        // Opposite normals (still parallel)
        let wall3 = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        
        let wall4 = Plane(
            position: simd_float3(5, 0, 0),
            normal: simd_float3(-1, 0, 0)  // Opposite direction
        )
        
        XCTAssertTrue(MeasurementHelper.arePlanesParallel(wall3, wall4), "Opposite normals are still parallel")
        
        // Perpendicular walls
        let wall5 = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        
        let wall6 = Plane(
            position: simd_float3(0, 0, 5),
            normal: simd_float3(0, 0, 1)  // Perpendicular
        )
        
        XCTAssertFalse(MeasurementHelper.arePlanesParallel(wall5, wall6), "Perpendicular walls should not be parallel")
    }
    
    func testArePlanesPerpendicular() {
        // Wall and floor (perpendicular)
        let wall = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        
        let floor = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(0, 1, 0)
        )
        
        XCTAssertTrue(MeasurementHelper.arePlanesPerpendicular(wall, floor), "Wall and floor should be perpendicular")
        
        // Parallel walls
        let wall2 = Plane(
            position: simd_float3(5, 0, 0),
            normal: simd_float3(1, 0, 0)
        )
        
        XCTAssertFalse(MeasurementHelper.arePlanesPerpendicular(wall, wall2), "Parallel walls should not be perpendicular")
    }
    
    // MARK: - Projections
    
    func testProjectPointOntoPlane() {
        // Horizontal plane at y=0
        let plane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(0, 1, 0)
        )
        
        // Point above the plane
        let point = simd_float3(3, 5, 2)
        let projected = MeasurementHelper.projectPointOntoPlane(point, plane)
        
        // Projected point should have y=0
        XCTAssertEqual(projected.y, 0.0, accuracy: 0.001, "Projected point should be on plane")
        XCTAssertEqual(projected.x, point.x, accuracy: 0.001, "X coordinate should be preserved")
        XCTAssertEqual(projected.z, point.z, accuracy: 0.001, "Z coordinate should be preserved")
    }
    
    func testProjectPointOntoLine() {
        // Line along X-axis
        let lineOrigin = simd_float3(0, 0, 0)
        let lineDirection = simd_float3(1, 0, 0)
        
        // Point off the line
        let point = simd_float3(3, 4, 2)
        let projected = MeasurementHelper.projectPointOntoLine(point, lineOrigin: lineOrigin, lineDirection: lineDirection)
        
        // Projected point should be on X-axis at x=3
        XCTAssertEqual(projected.x, 3.0, accuracy: 0.001, "Projected X should match")
        XCTAssertEqual(projected.y, 0.0, accuracy: 0.001, "Projected Y should be 0")
        XCTAssertEqual(projected.z, 0.0, accuracy: 0.001, "Projected Z should be 0")
    }
    
    // MARK: - Validation
    
    func testIsReasonableWallHeight() {
        XCTAssertTrue(MeasurementHelper.isReasonableWallHeight(2.5), "2.5m is reasonable")
        XCTAssertTrue(MeasurementHelper.isReasonableWallHeight(2.7), "2.7m is reasonable")
        XCTAssertTrue(MeasurementHelper.isReasonableWallHeight(3.0), "3.0m is reasonable")
        
        XCTAssertFalse(MeasurementHelper.isReasonableWallHeight(1.5), "1.5m is too short")
        XCTAssertFalse(MeasurementHelper.isReasonableWallHeight(6.0), "6.0m is too tall")
    }
    
    func testIsReasonableWallThickness() {
        XCTAssertTrue(MeasurementHelper.isReasonableWallThickness(0.15), "15cm is reasonable")
        XCTAssertTrue(MeasurementHelper.isReasonableWallThickness(0.20), "20cm is reasonable")
        
        XCTAssertFalse(MeasurementHelper.isReasonableWallThickness(0.02), "2cm is too thin")
        XCTAssertFalse(MeasurementHelper.isReasonableWallThickness(1.5), "1.5m is too thick")
    }
    
    func testIsReasonableFloorArea() {
        XCTAssertTrue(MeasurementHelper.isReasonableFloorArea(15.0), "15m² is reasonable")
        XCTAssertTrue(MeasurementHelper.isReasonableFloorArea(50.0), "50m² is reasonable")
        
        XCTAssertFalse(MeasurementHelper.isReasonableFloorArea(0.5), "0.5m² is too small")
        XCTAssertFalse(MeasurementHelper.isReasonableFloorArea(5000), "5000m² is too large")
    }
    
    // MARK: - Formatting
    
    func testFormatDistance() {
        let formatted1 = MeasurementHelper.formatDistance(2.567, precision: 2)
        XCTAssertEqual(formatted1, "2.57 m", "Should format to 2 decimals")
        
        let formatted2 = MeasurementHelper.formatDistance(0.123, precision: 3)
        XCTAssertEqual(formatted2, "0.123 m", "Should format to 3 decimals")
    }
    
    func testFormatArea() {
        let formatted = MeasurementHelper.formatArea(16.234, precision: 2)
        XCTAssertEqual(formatted, "16.23 m²", "Should format area correctly")
    }
    
    // MARK: - Conversions
    
    func testToCentimeters() {
        let meters: Float = 2.5
        let centimeters = MeasurementHelper.toCentimeters(meters)
        XCTAssertEqual(centimeters, 250.0, accuracy: 0.1, "2.5m should be 250cm")
    }
    
    func testToSquareFeet() {
        let squareMeters: Float = 10.0
        let squareFeet = MeasurementHelper.toSquareFeet(squareMeters)
        XCTAssertEqual(squareFeet, 107.64, accuracy: 0.1, "10m² should be approximately 107.64 sq ft")
    }
}

// MARK: - Performance Tests

extension MeasurementHelperTests {
    
    func testPlaneFromPointsPerformance() {
        // Generate large point cloud
        var points: [simd_float3] = []
        for x in 0..<100 {
            for z in 0..<100 {
                let y = Float.random(in: 0...0.1)  // Slight noise
                points.append(simd_float3(Float(x) * 0.1, y, Float(z) * 0.1))
            }
        }
        
        measure {
            _ = MeasurementHelper.planeFromPoints(points)
        }
    }
    
    func testDistanceCalculationsPerformance() {
        let plane = Plane(
            position: simd_float3(0, 0, 0),
            normal: simd_float3(0, 1, 0)
        )
        
        var points: [simd_float3] = []
        for _ in 0..<10000 {
            points.append(simd_float3(
                Float.random(in: -10...10),
                Float.random(in: -10...10),
                Float.random(in: -10...10)
            ))
        }
        
        measure {
            for point in points {
                _ = MeasurementHelper.distanceFromPointToPlane(point, plane)
            }
        }
    }
}
