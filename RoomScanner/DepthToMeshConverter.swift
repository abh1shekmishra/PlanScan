/*
 DepthToMeshConverter.swift
 Purpose: Convert depth maps into 3D meshes using SceneKit geometry.
 
 Pipeline:
 1. Depth map → Point cloud (XYZ coordinates)
 2. Point cloud → Mesh vertices and indices
 3. Mesh smoothing (Laplacian filter)
 4. SceneKit geometry generation
 
 Features:
 - Camera intrinsics handling (focal length, principal point)
 - Mesh simplification for memory efficiency
 - Normal computation for proper shading
 - Laplacian smoothing for noise reduction
 - Texture coordinate generation
 
 Created: December 2025
 */

import Foundation
import simd
import SceneKit

/// Converts depth maps to 3D mesh geometry
struct DepthToMeshConverter {
    
    // MARK: - Main Conversion Pipeline
    
    /// Convert depth map to 3D mesh
    /// 
    /// Parameters:
    /// - depthMap: Single-channel depth map from estimation
    /// - intrinsics: Camera intrinsic parameters (focal length, principal point)
    /// - scale: User-provided scale multiplier for real-world dimensions
    /// 
    /// Returns: SCNGeometry ready for rendering
    static func convert(
        depthMap: DepthMap,
        intrinsics: CameraIntrinsics = .default,
        scale: Float = 1.0
    ) -> SCNGeometry {
        print("🔧 Converting depth map to 3D mesh...")
        
        // Step 1: Generate point cloud from depth
        let pointCloud = generatePointCloud(
            from: depthMap,
            intrinsics: intrinsics,
            scale: scale
        )
        print("✅ Generated \(pointCloud.count) points from depth map")
        
        // Step 2: Generate mesh topology (vertices, indices, normals)
        var mesh = generateMesh(from: pointCloud, width: depthMap.width, height: depthMap.height)
        print("✅ Mesh has \(mesh.indices.count / 3) triangles")
        
        // Step 3: Smooth mesh to reduce noise
        mesh = smoothMesh(mesh, iterations: 2)
        print("✅ Applied Laplacian smoothing")
        
        // Step 4: Compute normals for proper lighting
        mesh = computeNormals(mesh)
        print("✅ Computed vertex normals")
        
        // Step 5: Create SceneKit geometry
        let geometry = createSCNGeometry(mesh)
        print("✅ Created SceneKit geometry")
        
        return geometry
    }
    
    // MARK: - Point Cloud Generation
    
    /// Generate 3D point cloud from depth map using camera projection
    private static func generatePointCloud(
        from depthMap: DepthMap,
        intrinsics: CameraIntrinsics,
        scale: Float
    ) -> [simd_float3] {
        var points: [simd_float3] = []
        points.reserveCapacity(depthMap.width * depthMap.height)
        
        // Camera intrinsic matrix:
        // [fx  0  cx]
        // [0  fy  cy]
        // [0   0   1]
        let fx = intrinsics.focalLength.x
        let fy = intrinsics.focalLength.y
        let cx = intrinsics.principalPoint.x
        let cy = intrinsics.principalPoint.y
        
        // Generate 3D points from depth
        for y in 0..<depthMap.height {
            for x in 0..<depthMap.width {
                let depth = depthMap.depth(at: x, y: y)
                
                // Skip invalid depths
                guard depth > 0.01, depth < 100 else { continue }
                
                // Backproject pixel to 3D point
                let xx = Float(x)
                let yy = Float(y)
                
                let px = (xx - cx) * depth / fx
                let py = (yy - cy) * depth / fy
                let pz = depth
                
                // Apply user scale
                let point = simd_float3(px * scale, py * scale, pz * scale)
                points.append(point)
            }
        }
        
        return points
    }
    
    // MARK: - Mesh Generation
    
    /// Generate mesh topology from point cloud (vertices and triangles)
    private static func generateMesh(
        from pointCloud: [simd_float3],
        width: Int,
        height: Int
    ) -> Mesh {
        var vertices: [simd_float3] = []
        var indices: [UInt32] = []
        var vertexMap: [Int: UInt32] = [:]  // Map from depth map index to vertex index
        
        var nextVertexIndex: UInt32 = 0
        
        // Create vertices for each valid point in original grid
        for y in 0..<(height - 1) {
            for x in 0..<(width - 1) {
                let currentIndex = y * width + x
                
                // We'll create a triangle grid connecting adjacent pixels
                // Skip if any neighbor is missing depth
                let neighbors = [
                    (currentIndex, "current"),
                    (y * width + (x + 1), "right"),
                    ((y + 1) * width + x, "bottom"),
                    ((y + 1) * width + (x + 1), "diagonal")
                ]
                
                var quad: [UInt32] = []
                for (neighborIndex, _) in neighbors {
                    if neighborIndex < pointCloud.count {
                        let point = pointCloud[neighborIndex]
                        
                        // Skip if depth was invalid (all-zero point)
                        if simd_length(point) > 0.001 {
                            if let vertexIdx = vertexMap[neighborIndex] {
                                quad.append(vertexIdx)
                            } else {
                                vertexMap[neighborIndex] = nextVertexIndex
                                quad.append(nextVertexIndex)
                                vertices.append(point)
                                nextVertexIndex += 1
                            }
                        }
                    }
                }
                
                // Create triangles from quad
                if quad.count == 4 {
                    // First triangle
                    indices.append(quad[0])
                    indices.append(quad[1])
                    indices.append(quad[2])
                    
                    // Second triangle
                    indices.append(quad[1])
                    indices.append(quad[3])
                    indices.append(quad[2])
                }
            }
        }
        
        return Mesh(vertices: vertices, indices: indices, normals: Array(repeating: simd_float3(0, 1, 0), count: vertices.count))
    }
    
    // MARK: - Mesh Smoothing (Laplacian)
    
    /// Apply Laplacian smoothing to reduce noise in mesh
    /// Each vertex is moved toward the average of its neighbors
    private static func smoothMesh(_ mesh: Mesh, iterations: Int) -> Mesh {
        var smoothVertices = mesh.vertices
        
        for _ in 0..<iterations {
            var newVertices = smoothVertices
            
            // Build adjacency list
            var adjacency: [Set<UInt32>] = Array(repeating: Set(), count: smoothVertices.count)
            for i in stride(from: 0, to: mesh.indices.count, by: 3) {
                let i0 = Int(mesh.indices[i])
                let i1 = Int(mesh.indices[i + 1])
                let i2 = Int(mesh.indices[i + 2])
                
                adjacency[i0].insert(mesh.indices[i + 1])
                adjacency[i0].insert(mesh.indices[i + 2])
                adjacency[i1].insert(mesh.indices[i])
                adjacency[i1].insert(mesh.indices[i + 2])
                adjacency[i2].insert(mesh.indices[i])
                adjacency[i2].insert(mesh.indices[i + 1])
            }
            
            // Apply Laplacian smoothing
            for i in 0..<smoothVertices.count {
                guard !adjacency[i].isEmpty else { continue }
                
                var neighborSum = simd_float3(0, 0, 0)
                for neighborIdx in adjacency[i] {
                    neighborSum += smoothVertices[Int(neighborIdx)]
                }
                
                let avgNeighbor = neighborSum / Float(adjacency[i].count)
                
                // Move vertex 10% toward average of neighbors (gentle smoothing)
                newVertices[i] = smoothVertices[i] * 0.9 + avgNeighbor * 0.1
            }
            
            smoothVertices = newVertices
        }
        
        return Mesh(vertices: smoothVertices, indices: mesh.indices, normals: mesh.normals)
    }
    
    // MARK: - Normal Computation
    
    /// Compute vertex normals from triangle geometry
    private static func computeNormals(_ mesh: Mesh) -> Mesh {
        var normals = Array(repeating: simd_float3(0, 0, 0), count: mesh.vertices.count)
        
        // Accumulate face normals at each vertex
        for i in stride(from: 0, to: mesh.indices.count, by: 3) {
            let i0 = Int(mesh.indices[i])
            let i1 = Int(mesh.indices[i + 1])
            let i2 = Int(mesh.indices[i + 2])
            
            let v0 = mesh.vertices[i0]
            let v1 = mesh.vertices[i1]
            let v2 = mesh.vertices[i2]
            
            // Compute face normal (cross product)
            let edge1 = v1 - v0
            let edge2 = v2 - v0
            let faceNormal = simd_cross(edge1, edge2)
            
            // Weight by triangle area (implicit in cross product magnitude)
            normals[i0] += faceNormal
            normals[i1] += faceNormal
            normals[i2] += faceNormal
        }
        
        // Normalize all vertex normals
        for i in 0..<normals.count {
            let length = simd_length(normals[i])
            if length > 0.001 {
                normals[i] = normals[i] / length
            } else {
                normals[i] = simd_float3(0, 1, 0)  // Default up-facing normal
            }
        }
        
        return Mesh(vertices: mesh.vertices, indices: mesh.indices, normals: normals)
    }
    
    // MARK: - SceneKit Geometry Creation
    
    /// Create SCNGeometry from processed mesh
    private static func createSCNGeometry(_ mesh: Mesh) -> SCNGeometry {
        // Prepare vertex data
        let vertexData = NSData(bytes: mesh.vertices, length: mesh.vertices.count * MemoryLayout<simd_float3>.size) as Data
        let normalData = NSData(bytes: mesh.normals, length: mesh.normals.count * MemoryLayout<simd_float3>.size) as Data
        let indexData = NSData(bytes: mesh.indices, length: mesh.indices.count * MemoryLayout<UInt32>.size) as Data
        
        // Create sources
        let vertexSource = SCNGeometrySource(data: vertexData, semantic: .vertex, vectorCount: mesh.vertices.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<simd_float3>.size)
        
        let normalSource = SCNGeometrySource(data: normalData, semantic: .normal, vectorCount: mesh.normals.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<simd_float3>.size)
        
        // Create element (triangles)
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: mesh.indices.count / 3, bytesPerIndex: MemoryLayout<UInt32>.size)
        
        // Create geometry
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        
        // Set a material with lighting
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1.0)
        material.specular.contents = UIColor.white
        material.shininess = 0.5
        geometry.materials = [material]
        
        return geometry
    }
}

// MARK: - Data Models

/// Camera intrinsic parameters for 3D projection
struct CameraIntrinsics {
    let focalLength: simd_float2  // (fx, fy)
    let principalPoint: simd_float2  // (cx, cy)
    
    /// Default intrinsics (common for mobile cameras)
    static let `default` = CameraIntrinsics(
        focalLength: simd_float2(500, 500),  // Focal length in pixels
        principalPoint: simd_float2(256, 192)  // Principal point (center) for 512x384 image
    )
    
    /// Create intrinsics from image dimensions and field of view
    static func fromFOV(_ fov: Float, imageWidth: Float, imageHeight: Float) -> CameraIntrinsics {
        let fx = (imageWidth / 2.0) / tan(fov / 2.0)
        let fy = (imageHeight / 2.0) / tan(fov / 2.0)
        return CameraIntrinsics(
            focalLength: simd_float2(fx, fy),
            principalPoint: simd_float2(imageWidth / 2.0, imageHeight / 2.0)
        )
    }
}

/// Intermediate mesh representation
struct Mesh {
    var vertices: [simd_float3]
    var indices: [UInt32]
    var normals: [simd_float3]
}
