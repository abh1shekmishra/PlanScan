/*
 ImageTo3DView.swift
 Purpose: SwiftUI view for Image-to-3D conversion with 3D model viewer.
 
 Features:
 - Image selection from photo library or camera
 - 3D model preview with SceneKit
 - Scale adjustment slider
 - Rotation/pan/zoom controls
 - Export options (USDZ, OBJ, JSON)
 - Loading and error states
 
 Created: December 2025
 */

import SwiftUI
import SceneKit

/// Main UI view for Image-to-3D conversion
@available(iOS 16.0, *)
struct ImageTo3DView: View {
    @StateObject private var viewModel = ImageTo3DViewModel()
    @State private var showingImagePicker = false
    @State private var showingExportSheet = false
    @State private var exportedURL: URL?
    @State private var exportError: String?
    @State private var selectedExportFormat: ExportFormat = .usdz
    @State private var isExporting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if let model = viewModel.generatedModel {
                    // Model viewer screen
                    modelViewerContent(model: model)
                } else if viewModel.selectedImage != nil && viewModel.isProcessing {
                    // Loading screen
                    processingContent
                } else {
                    // Initial screen - image selection
                    selectionContent
                }
            }
            .navigationTitle("Image to 3D")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.generatedModel != nil {
                        Button(action: { viewModel.reset() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $viewModel.selectedImage, sourceType: .photoLibrary)
        }
        .onChange(of: viewModel.selectedImage) { image in
            if let image {
                print("📸 Image received in ImageTo3DView, starting processing...")
                showingImagePicker = false
                viewModel.processImage(image)
            }
        }
        .onAppear {
            print("🎬 ImageTo3DView appeared")
        }
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("Dismiss") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var selectionContent: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Header
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Convert Photo to 3D")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Select an image to generate a 3D model using depth estimation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            
            Spacer()
            
            // Feature list
            VStack(alignment: .leading, spacing: 12) {
                featureItem("Monocular depth estimation", icon: "square.on.square")
                featureItem("AI-powered 3D mesh generation", icon: "cube.fill")
                featureItem("Adjustable scale", icon: "slider.horizontal.3")
                featureItem("Export to USDZ or OBJ", icon: "arrow.down.doc")
                featureItem("Works completely offline", icon: "wifi.slash")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding()
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: { showingImagePicker = true }) {
                    HStack {
                        Image(systemName: "photo.circle")
                        Text("Select Photo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func modelViewerContent(model: GeneratedModel) -> some View {
        VStack(spacing: 0) {
            // 3D Model Viewer
            ZStack {
                SceneKitViewContainer(geometry: model.sceneGeometry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Loading indicator overlay
                if viewModel.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.processingProgress)
                            .tint(.white)
                        Text(String(format: "%.0f%%", viewModel.processingProgress * 100))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
            }
            .background(Color(.systemGray6))
            
            // Controls Panel
            ScrollView {
                VStack(spacing: 16) {
                    // Scale Control
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Scale Multiplier", systemImage: "slider.horizontal.3")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.2f×", viewModel.scaleMultiplier))
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                        }
                        
                        Slider(value: $viewModel.scaleMultiplier, in: 0.5...3.0, step: 0.1)
                            .tint(.purple)
                        
                        Text("Adjust the size of the 3D model")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Model Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model Details")
                            .font(.headline)
                        
                        HStack {
                            Text("Mesh Vertices")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(model.meshVertices.count)")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Generated")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(model.createdDate.formatted(date: .abbreviated, time: .shortened))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Export Options
                    VStack(spacing: 10) {
                        Text("Export Options")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        exportButton(
                            title: "Export USDZ",
                            icon: "cube.fill",
                            format: .usdz,
                            color: .blue
                        )
                        
                        exportButton(
                            title: "Export OBJ",
                            icon: "cube",
                            format: .obj,
                            color: .orange
                        )
                        
                        exportButton(
                            title: "Export Metadata",
                            icon: "doc.text.fill",
                            format: .json,
                            color: .green
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var processingContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Generating 3D Model")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Progress bar
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.processingProgress)
                        .tint(.purple)
                    
                    HStack {
                        Text(String(format: "%.0f%%", viewModel.processingProgress * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        // Stage indicator
                        let stage = getProcessingStage(viewModel.processingProgress)
                        Text(stage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("This may take 30-120 seconds depending on image size and device performance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Processing includes depth estimation and 3D mesh generation.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            
            Spacer()
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func exportButton(
        title: String,
        icon: String,
        format: ExportFormat,
        color: Color
    ) -> some View {
        Button(action: {
            selectedExportFormat = format
            performExport(format)
        }) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
                if isExporting {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isExporting)
    }
    
    private func featureItem(_ text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    private var exportSheet: some View {
        NavigationStack {
            VStack {
                if let url = exportedURL {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Export Successful")
                            .font(.headline)
                        
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        ShareLink(item: url) {
                            Label("Share File", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: { exportedURL = nil }) {
                            Text("Done")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray4))
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Export Logic
    
    private func performExport(_ format: ExportFormat) {
        isExporting = true
        exportError = nil
        
        Task {
            do {
                let url: URL
                switch format {
                case .usdz:
                    url = try await viewModel.exportToUSDZ()
                case .obj:
                    url = try await viewModel.exportToOBJ()
                case .json:
                    url = try await viewModel.exportToJSON()
                }
                
                await MainActor.run {
                    exportedURL = url
                    isExporting = false
                    showingExportSheet = true
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    private func getProcessingStage(_ progress: Float) -> String {
        if progress < 0.25 {
            return "Validating image..."
        } else if progress < 0.5 {
            return "Estimating depth..."
        } else if progress < 0.8 {
            return "Generating mesh..."
        } else {
            return "Finalizing model..."
        }
    }
}

// MARK: - 3D Model Viewer (SceneKit Container)

/// SceneKit-based 3D model viewer
struct SceneKitViewContainer: UIViewRepresentable {
    let geometry: SCNGeometry
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        // Create scene and add geometry
        let scene = SCNScene()
        let node = SCNNode(geometry: geometry)
        
        // Center the model
        if let minBounds = getMinBounds(geometry),
           let maxBounds = getMaxBounds(geometry) {
            let center = (minBounds + maxBounds) / 2.0
            node.position = SCNVector3(center.x, center.y, center.z)
        }
        
        scene.rootNode.addChildNode(node)
        
        // Add lights
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 800
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 800
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(10, 10, 10)
        scene.rootNode.addChildNode(lightNode)
        
        // Add camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(cameraNode)
        
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = false
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update when geometry changes
    }
    
    private func getMinBounds(_ geometry: SCNGeometry) -> simd_float3? {
        guard let source = geometry.sources.first(where: { $0.semantic == .vertex }) else {
            return nil
        }
        return simd_float3(x: -2, y: -2, z: -2)  // Approximation
    }
    
    private func getMaxBounds(_ geometry: SCNGeometry) -> simd_float3? {
        guard let source = geometry.sources.first(where: { $0.semantic == .vertex }) else {
            return nil
        }
        return simd_float3(x: 2, y: 2, z: 2)  // Approximation
    }
}

// MARK: - Supporting Types

enum ExportFormat {
    case usdz
    case obj
    case json
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    ImageTo3DView()
}
#endif
