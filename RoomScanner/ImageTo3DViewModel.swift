/*
 ImageTo3DViewModel.swift
 Purpose: MVVM ViewModel for Image-to-3D conversion pipeline.
 
 Responsibilities:
 - Orchestrate image loading and validation
 - Manage depth estimation pipeline
 - Handle mesh generation and export
 - State management for UI binding
 - Error handling and recovery
 - Background thread management
 
 Created: December 2025
 */

import Foundation
import UIKit
import SceneKit
import simd

/// ViewModel for Image-to-3D conversion workflow
@MainActor
class ImageTo3DViewModel: ObservableObject {
    
    // MARK: - Published Properties (for UI binding)
    
    @Published var selectedImage: UIImage?
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0
    @Published var errorMessage: String?
    @Published var generatedModel: GeneratedModel?
    @Published var scaleMultiplier: Float = 1.0 {
        didSet {
            // Regenerate mesh if image is loaded
            if selectedImage != nil && generatedModel != nil {
                Task {
                    await regenerateMeshWithScale()
                }
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let depthEstimator = DepthEstimator.shared
    private let meshConverter = DepthToMeshConverter()
    private var currentDepthMap: DepthMap?
    
    // MARK: - Initialization
    
    nonisolated init() {
        // Load depth model on background thread
        Task.detached {
            try? self.depthEstimator.loadModel()
        }
    }
    
    // MARK: - Main Processing Pipeline
    
    /// Process selected image through entire pipeline: image → depth → mesh → model
    func processImage(_ image: UIImage) {
        errorMessage = nil
        selectedImage = image
        isProcessing = true
        processingProgress = 0
        
        // Capture scale now (before going to background thread)
        let capturedScale = self.scaleMultiplier
        
        // Run on background thread to avoid blocking UI
        Task.detached { [weak self] in
            do {
                // Step 1: Validate image
                guard let self else { return }
                await MainActor.run { self.processingProgress = 0.1 }
                print("📸 Processing image (\(image.size.width)x\(image.size.height))")
                
                // Step 2: Estimate depth (heavy computation)
                let depthMap = try await self.estimateDepth(from: image)
                
                // Step 3: Convert depth to mesh (heavy computation)
                let geometry = await self.convertDepthToMesh(depthMap, scale: capturedScale)
                await MainActor.run { self.processingProgress = 0.8 }
                
                // Step 4: Create model representation and prepare for export
                let meshVertices = self.extractVerticesFromGeometry(geometry)
                let model = GeneratedModel(
                    id: UUID().uuidString,
                    sourceImage: image,
                    sceneGeometry: geometry,
                    meshVertices: meshVertices,
                    createdDate: Date()
                )
                
                // Step 5: Update UI on main thread
                await MainActor.run {
                    self.currentDepthMap = depthMap
                    self.generatedModel = model
                    self.isProcessing = false
                    self.processingProgress = 1.0
                    print("✅ Model generation complete")
                }
                
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.errorMessage = error.localizedDescription
                    self.isProcessing = false
                    self.processingProgress = 0
                    print("❌ Model generation failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Depth Estimation
    
    /// Estimate depth from image on background thread
    private nonisolated func estimateDepth(from image: UIImage) async throws -> DepthMap {
        return try await Task.detached(priority: .userInitiated) { [weak self] () -> DepthMap in
            guard let self else { throw ImageTo3DError.processingCanceled }
            
            print("🎯 Running depth estimation...")
            let startTime = Date()
            
            let depthMap = try self.depthEstimator.estimateDepth(from: image)
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Depth estimation completed in \(String(format: "%.2f", elapsed))s")
            
            return depthMap
        }.value
    }
    
    // MARK: - Mesh Generation
    
    /// Convert depth map to 3D mesh on background thread
    private nonisolated func convertDepthToMesh(_ depthMap: DepthMap, scale: Float) async -> SCNGeometry {
        return await Task.detached(priority: .userInitiated) { () -> SCNGeometry in
            print("🔧 Converting depth to mesh...")
            let startTime = Date()
            
            let geometry = DepthToMeshConverter.convert(
                depthMap: depthMap,
                intrinsics: .default,
                scale: scale
            )
            
            let elapsed = Date().timeIntervalSince(startTime)
            print("✅ Mesh conversion completed in \(String(format: "%.2f", elapsed))s")
            
            return geometry
        }.value
    }
    
    // MARK: - Scale Adjustment
    
    /// Regenerate mesh with new scale when user adjusts slider
    private func regenerateMeshWithScale() async {
        guard let depthMap = currentDepthMap else { return }
        
        print("⚙️ Regenerating mesh with scale: \(scaleMultiplier)x")
        
        let geometry = await convertDepthToMesh(depthMap, scale: scaleMultiplier)
        
        // Update existing model with new geometry
        if var model = generatedModel {
            model.sceneGeometry = geometry
            model.meshVertices = extractVerticesFromGeometry(geometry)
            self.generatedModel = model
        }
    }
    
    // MARK: - Export Support
    
    /// Get USDZ data for export (reuses existing exporter)
    func exportToUSDZ() async throws -> URL {
        guard let model = generatedModel else {
            throw ImageTo3DError.noModelGenerated
        }
        
        print("📦 Exporting to USDZ...")
        
        // Create a temporary USDZ file from the SceneKit geometry
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "image_3d_model_\(Date().timeIntervalSince1970).usdz"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Create SCNScene and export
        let scene = SCNScene()
        let node = SCNNode(geometry: model.sceneGeometry)
        scene.rootNode.addChildNode(node)
        
        // Export to USDZ - use the simple write method
        do {
            try scene.write(to: fileURL, options: nil, delegate: nil, progressHandler: nil)
        } catch {
            // Fallback to simpler approach if needed
            throw ImageTo3DError.exportFailed
        }
        
        print("✅ USDZ exported to: \(fileURL.path)")
        return fileURL
    }
    
    /// Get OBJ data for export (reuses existing exporter)
    func exportToOBJ() async throws -> URL {
        guard let model = generatedModel else {
            throw ImageTo3DError.noModelGenerated
        }
        
        print("📦 Exporting to OBJ...")
        
        let tempDir = FileManager.default.temporaryDirectory
        let baseName = "image_3d_model_\(Date().timeIntervalSince1970)"
        let objURL = tempDir.appendingPathComponent(baseName + ".obj")
        
        // Generate OBJ content
        var objContent = "# Image-generated 3D model\n"
        objContent += "# Generated by ImageTo3D\n\n"
        
        // Write vertices
        for vertex in model.meshVertices {
            objContent += String(format: "v %.6f %.6f %.6f\n", vertex.x, vertex.y, vertex.z)
        }
        
        // Write basic faces (assuming triangles from mesh converter)
        let vertexCount = model.meshVertices.count
        for i in stride(from: 0, to: vertexCount, by: 3) {
            let i1 = i + 1
            let i2 = i + 2
            let i3 = i + 3
            if i3 <= vertexCount {
                objContent += String(format: "f %d %d %d\n", i1, i2, i3)
            }
        }
        
        try objContent.write(to: objURL, atomically: true, encoding: .utf8)
        
        print("✅ OBJ exported to: \(objURL.path)")
        return objURL
    }
    
    /// Get JSON metadata for export (similar to existing LiDAR scans)
    func exportToJSON() async throws -> URL {
        guard let model = generatedModel else {
            throw ImageTo3DError.noModelGenerated
        }
        
        print("📝 Exporting metadata to JSON...")
        
        let metadata = ImageModelMetadata(
            id: model.id,
            sourceType: "photo",
            createdDate: model.createdDate,
            meshVertexCount: model.meshVertices.count,
            scale: scaleMultiplier,
            cameraModel: UIDevice.current.name,
            iosVersion: UIDevice.current.systemVersion
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(metadata)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "image_3d_metadata_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try jsonData.write(to: fileURL)
        
        print("✅ JSON exported to: \(fileURL.path)")
        return fileURL
    }
    
    // MARK: - Utilities
    
    /// Extract vertex array from SCNGeometry for export
    nonisolated private func extractVerticesFromGeometry(_ geometry: SCNGeometry) -> [simd_float3] {
        guard let vertexSource = geometry.sources.first(where: { $0.semantic == .vertex }) else {
            return []
        }
        
        let vertexCount = vertexSource.vectorCount
        var vertices: [simd_float3] = []
        vertices.reserveCapacity(vertexCount)
        
        let data = vertexSource.data
        let stride = vertexSource.dataStride
        let offset = vertexSource.dataOffset
        
        for i in 0..<vertexCount {
            let vertexOffset = offset + (i * stride)
            let vertex = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: vertexOffset, as: simd_float3.self)
            }
            vertices.append(vertex)
        }
        
        return vertices
    }
    
    /// Reset and clear current session
    func reset() {
        selectedImage = nil
        generatedModel = nil
        currentDepthMap = nil
        errorMessage = nil
        isProcessing = false
        processingProgress = 0
        scaleMultiplier = 1.0
    }
}

// MARK: - Data Models

/// Represents a generated 3D model from image
struct GeneratedModel: Identifiable {
    let id: String
    let sourceImage: UIImage
    var sceneGeometry: SCNGeometry
    var meshVertices: [simd_float3]
    let createdDate: Date
}

/// Metadata for exported image-generated models
struct ImageModelMetadata: Codable {
    let id: String
    let sourceType: String  // "photo", "camera"
    let createdDate: Date
    let meshVertexCount: Int
    let scale: Float
    let cameraModel: String
    let iosVersion: String
}

// MARK: - Error Handling

enum ImageTo3DError: LocalizedError {
    case noImageSelected
    case invalidImage
    case depthEstimationFailed
    case meshGenerationFailed
    case noModelGenerated
    case exportFailed
    case processingCanceled
    
    var errorDescription: String? {
        switch self {
        case .noImageSelected:
            return "Please select an image first"
        case .invalidImage:
            return "The selected image is invalid or corrupted"
        case .depthEstimationFailed:
            return "Failed to estimate depth from image. Try a different photo."
        case .meshGenerationFailed:
            return "Failed to generate 3D mesh from depth map"
        case .noModelGenerated:
            return "No 3D model has been generated yet"
        case .exportFailed:
            return "Failed to export model"
        case .processingCanceled:
            return "Processing was canceled"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .depthEstimationFailed:
            return "Try selecting a clearer photo with more visible room structure"
        default:
            return nil
        }
    }
}
