/*
 ImageTo3DProcessor.swift
 Purpose: Convert reference images to 3D room models using Vision framework
 
 Features:
 - Edge detection and corner detection
 - Room boundary extraction
 - 3D model generation from 2D image
 - Uses Apple Vision framework (free, no external dependencies)
 
 Created: December 2025
 */

import Foundation
import Vision
import CoreGraphics
import CoreImage
#if canImport(UIKit)
import UIKit
#endif
import simd

/// Processes images to extract room data and generate 3D models
class ImageTo3DProcessor {
    
    // API Configuration
    private static let API_BASE_URL = "http://127.0.0.1:5001"
    
    // MARK: - Image Processing with Real 3D Generation
    
    /// Upload image to Python backend, generate actual 3D model, download GLB
    static func generateActual3DModel(from image: UIImage, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "ImageTo3D", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])))
            return
        }
        
        print("📤 Uploading image to Python backend for 3D generation...")
        
        // Health check first to provide clearer errors if server isn't running
        let healthURL = URL(string: "\(API_BASE_URL)/health")!
        var healthRequest = URLRequest(url: healthURL)
        healthRequest.httpMethod = "GET"
        healthRequest.timeoutInterval = 5

        URLSession.shared.dataTask(with: healthRequest) { _, _, _ in
            // Proceed to upload regardless; health endpoint is best-effort
            let uploadURL = URL(string: "\(API_BASE_URL)/generate-sync")!
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"

            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body
            request.timeoutInterval = 120  // 2 minutes for model generation

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error as NSError? {
                    let mapped = NSError(domain: "ImageTo3D", code: error.code, userInfo: [NSLocalizedDescriptionKey: "Cannot connect to local 3D server. Make sure the Python server is running on http://127.0.0.1:5001."])
                    print("❌ API request failed: \(error)")
                    completion(.failure(mapped))
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "ImageTo3D", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])));
                    return
                }

                guard (200...299).contains(http.statusCode), let data = data else {
                    let message = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown server error"
                    completion(.failure(NSError(domain: "ImageTo3D", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (\(http.statusCode)): \(message)"])));
                    return
                }

                // Save GLB to temp file
                let tempDir = FileManager.default.temporaryDirectory
                let glbURL = tempDir.appendingPathComponent("generated_model_\(UUID().uuidString).glb")

                do {
                    try data.write(to: glbURL)
                    print("✅ 3D model generated and saved: \(glbURL.path)")
                    completion(.success(glbURL))
                } catch {
                    print("❌ Failed to save GLB: \(error)")
                    completion(.failure(error))
                }
            }

            task.resume()
        }.resume()
    }
    
    // MARK: - Legacy Image Analysis (fallback)
    
    /// Analyze image and extract room boundaries (legacy Vision-only method)
    static func analyzeRoomImage(_ image: UIImage) -> RoomFromImageData? {
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage from UIImage")
            return nil
        }
        
        print("📷 Analyzing room image...")
        
        // Detect edges in the image
        let edges = detectEdges(cgImage: cgImage)
        guard edges.count > 0 else {
            print("⚠️ No edges detected in image")
            return nil
        }
        
        print("✅ Detected \(edges.count) edge points")
        
        // Find corner points (potential room corners)
        let corners = findCorners(edges: edges, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
        print("🔍 Found \(corners.count) potential corners")
        
        // Extract room boundaries
        let boundingBox = extractBoundingBox(corners: corners, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
        print("📏 Room bounding box: \(boundingBox)")
        
        // Estimate room dimensions based on perspective
        let estimatedDimensions = estimateRoomDimensions(
            boundingBox: boundingBox,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height),
            corners: corners
        )
        
        print("📐 Estimated room dimensions: \(estimatedDimensions)")
        
        return RoomFromImageData(
            originalImage: image,
            detectedCorners: corners,
            boundingBox: boundingBox,
            estimatedWidth: estimatedDimensions.width,
            estimatedLength: estimatedDimensions.length,
            estimatedHeight: estimatedDimensions.height
        )
    }
    
    // MARK: - Edge Detection
    
    private static func detectEdges(cgImage: CGImage) -> [CGPoint] {
        var edges: [CGPoint] = []
        
        // Use CIFilter for edge detection (free, built-in)
        let inputImage = CIImage(cgImage: cgImage)
        
        // Apply Sobel edge detection
        let context = CIContext()
        let edgeDetectFilter = CIFilter(name: "CIEdges")
        edgeDetectFilter?.setValue(inputImage, forKey: kCIInputImageKey)
        edgeDetectFilter?.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let edgeImage = edgeDetectFilter?.outputImage else {
            return edges
        }
        
        // Convert to CGImage for processing
        guard let cgEdgeImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            return edges
        }
        
        // Extract edge points from image
        edges = extractEdgePoints(from: cgEdgeImage, threshold: 0.5)
        
        return edges
    }
    
    private static func extractEdgePoints(from cgImage: CGImage, threshold: Float) -> [CGPoint] {
        var points: [CGPoint] = []
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else {
            return points
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let pixelData = CFDataGetBytePtr(data)
        
        // Sample points at intervals to avoid too many points
        let sampleInterval = 5
        
        for y in stride(from: 0, to: height, by: sampleInterval) {
            for x in stride(from: 0, to: width, by: sampleInterval) {
                let pixelIndex = (y * width + x) * 4
                
                // Check if pixel is an edge (high intensity)
                if pixelIndex + 3 < CFDataGetLength(data) {
                    let alpha = CGFloat(pixelData![pixelIndex + 3]) / 255.0
                    if alpha > CGFloat(threshold) {
                        points.append(CGPoint(x: x, y: y))
                    }
                }
            }
        }
        
        return points
    }
    
    // MARK: - Corner Detection
    
    private static func findCorners(edges: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        guard edges.count > 10 else { return [] }
        
        var corners: [CGPoint] = []
        
        // Find extreme points (likely room corners)
        let minX = edges.min(by: { $0.x < $1.x })?.x ?? 0
        let maxX = edges.max(by: { $0.x < $1.x })?.x ?? imageSize.width
        let minY = edges.min(by: { $0.y < $1.y })?.y ?? 0
        let maxY = edges.max(by: { $0.y < $1.y })?.y ?? imageSize.height
        
        // Add corners at extremes (top-left, top-right, bottom-left, bottom-right)
        corners.append(CGPoint(x: minX, y: minY)) // Top-left
        corners.append(CGPoint(x: maxX, y: minY)) // Top-right
        corners.append(CGPoint(x: minX, y: maxY)) // Bottom-left
        corners.append(CGPoint(x: maxX, y: maxY)) // Bottom-right
        
        // Find additional corners by looking for significant direction changes in edges
        let clusteredCorners = clusterCorners(corners, radius: 50)
        
        return clusteredCorners
    }
    
    private static func clusterCorners(_ corners: [CGPoint], radius: CGFloat) -> [CGPoint] {
        var clusters: [[CGPoint]] = []
        var used = Set<Int>()
        
        for (i, corner) in corners.enumerated() {
            if used.contains(i) { continue }
            
            var cluster = [corner]
            used.insert(i)
            
            for (j, other) in corners.enumerated() {
                if used.contains(j) { continue }
                
                let distance = hypot(corner.x - other.x, corner.y - other.y)
                if distance < radius {
                    cluster.append(other)
                    used.insert(j)
                }
            }
            
            clusters.append(cluster)
        }
        
        // Return average of each cluster
        return clusters.map { cluster in
            let avgX = cluster.map { $0.x }.reduce(0, +) / CGFloat(cluster.count)
            let avgY = cluster.map { $0.y }.reduce(0, +) / CGFloat(cluster.count)
            return CGPoint(x: avgX, y: avgY)
        }
    }
    
    // MARK: - Bounding Box Extraction
    
    private static func extractBoundingBox(corners: [CGPoint], imageSize: CGSize) -> CGRect {
        guard !corners.isEmpty else {
            return CGRect(origin: .zero, size: imageSize)
        }
        
        let minX = corners.min(by: { $0.x < $1.x })?.x ?? 0
        let maxX = corners.max(by: { $0.x < $1.x })?.x ?? imageSize.width
        let minY = corners.min(by: { $0.y < $1.y })?.y ?? 0
        let maxY = corners.max(by: { $0.y < $1.y })?.y ?? imageSize.height
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    // MARK: - Room Dimension Estimation
    
    private static func estimateRoomDimensions(
        boundingBox: CGRect,
        imageSize: CGSize,
        corners: [CGPoint]
    ) -> (width: Float, length: Float, height: Float) {
        // Estimate based on perspective and image analysis
        
        // Assume standard ceiling height (2.7m)
        let estimatedHeight: Float = 2.7
        
        // Bounding box aspect ratio
        let aspectRatio = Float(boundingBox.width / boundingBox.height)
        
        // Estimate dimensions from bounding box (assume average room size)
        // Scale based on percentage of image covered
        let imageCoverage = Float((boundingBox.width * boundingBox.height) / (imageSize.width * imageSize.height))
        
        // Heuristic: larger coverage = smaller room, smaller coverage = larger room
        let scaleFactor = max(0.5, min(3.0, 1.0 / imageCoverage))
        
        // Default room size adjusted by scale factor
        var width = 4.0 * scaleFactor  // 4m default
        var length = 5.0 * scaleFactor  // 5m default
        
        // Adjust based on aspect ratio
        if aspectRatio > 1.0 {
            // Wider image = wider room
            width *= scaleFactor
            length *= (1.0 / scaleFactor)
        } else {
            // Taller image = longer room
            width *= (1.0 / scaleFactor)
            length *= scaleFactor
        }
        
        return (
            width: max(2.0, min(20.0, width)),      // Clamp between 2-20m
            length: max(2.0, min(20.0, length)),    // Clamp between 2-20m
            height: estimatedHeight
        )
    }
    
    // MARK: - 3D Model Generation
    
    static func generate3DModel(from roomData: RoomFromImageData) -> ImageGeneratedRoom {
        print("🎨 Generating 3D room model from image analysis...")
        
        let roomId = "room-from-image-\(UUID().uuidString.prefix(8))"
        let floorArea = roomData.estimatedWidth * roomData.estimatedLength
        
        // Create walls from estimated dimensions
        let walls = createWallsFromDimensions(
            width: roomData.estimatedWidth,
            length: roomData.estimatedLength,
            height: roomData.estimatedHeight
        )
        
        // Generate mesh data for 3D export
        let meshData = generateMeshVertices(from: walls)
        
        let imageRoom = ImageGeneratedRoom(
            sourceImage: roomData.originalImage,
            roomId: roomId,
            width: roomData.estimatedWidth,
            length: roomData.estimatedLength,
            height: roomData.estimatedHeight,
            floorArea: floorArea,
            walls: walls,
            generatedDate: Date(),
            meshData: meshData
        )
        
        print("✅ Generated 3D model: \(walls.count) walls, floor area: \(String(format: "%.2f", floorArea)) m²")
        
        return imageRoom
    }
    
    private static func generateMeshVertices(from walls: [WallSummary]) -> [simd_float3] {
        var vertices: [simd_float3] = []
        
        // Create mesh vertices for all walls
        for wall in walls {
            let pos = wall.position
            let halfLength = (wall.length ?? 0) / 2.0
            let halfThickness = (wall.thickness ?? 0.15) / 2.0
            
            // Create quad vertices for this wall
            vertices.append(simd_float3(pos.x - halfThickness, 0, pos.z))
            vertices.append(simd_float3(pos.x + halfThickness, 0, pos.z))
            vertices.append(simd_float3(pos.x + halfThickness, wall.height, pos.z))
            vertices.append(simd_float3(pos.x - halfThickness, wall.height, pos.z))
        }
        
        return vertices
    }
    
    private static func createWallsFromDimensions(
        width: Float,
        length: Float,
        height: Float
    ) -> [WallSummary] {
        var walls: [WallSummary] = []
        
        // Half dimensions for wall positioning
        let halfWidth = width / 2.0
        let halfLength = length / 2.0
        
        // Wall 1: Front (along X axis, positive Z)
        walls.append(WallSummary(
            length: width,
            height: height,
            thickness: 0.15,
            normal: simd_float3(0, 0, 1),
            start: simd_float3(-halfWidth, 0, halfLength),
            end: simd_float3(halfWidth, 0, halfLength),
            position: simd_float3(0, 0, halfLength)
        ))
        
        // Wall 2: Back (along X axis, negative Z)
        walls.append(WallSummary(
            length: width,
            height: height,
            thickness: 0.15,
            normal: simd_float3(0, 0, -1),
            start: simd_float3(-halfWidth, 0, -halfLength),
            end: simd_float3(halfWidth, 0, -halfLength),
            position: simd_float3(0, 0, -halfLength)
        ))
        
        // Wall 3: Left (along Z axis, negative X)
        walls.append(WallSummary(
            length: length,
            height: height,
            thickness: 0.15,
            normal: simd_float3(-1, 0, 0),
            start: simd_float3(-halfWidth, 0, -halfLength),
            end: simd_float3(-halfWidth, 0, halfLength),
            position: simd_float3(-halfWidth, 0, 0)
        ))
        
        // Wall 4: Right (along Z axis, positive X)
        walls.append(WallSummary(
            length: length,
            height: height,
            thickness: 0.15,
            normal: simd_float3(1, 0, 0),
            start: simd_float3(halfWidth, 0, -halfLength),
            end: simd_float3(halfWidth, 0, halfLength),
            position: simd_float3(halfWidth, 0, 0)
        ))
        
        return walls
    }
}

// MARK: - Data Models

/// Room data extracted from image analysis
struct RoomFromImageData {
    let originalImage: UIImage
    let detectedCorners: [CGPoint]
    let boundingBox: CGRect
    let estimatedWidth: Float
    let estimatedLength: Float
    let estimatedHeight: Float
}

/// Image-generated 3D room model (completely separate from LiDAR scans)
struct ImageGeneratedRoom: Identifiable {
    let id: String = UUID().uuidString
    let sourceImage: UIImage
    let roomId: String
    let width: Float
    let length: Float
    let height: Float
    let floorArea: Float
    let walls: [WallSummary]
    let generatedDate: Date
    let meshData: [simd_float3]  // Raw 3D vertex data for export
}

