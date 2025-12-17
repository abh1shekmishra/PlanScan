/*
 ImageResultsView.swift
 Purpose: Display results from image-to-3D processing (completely separate from LiDAR)
 
 Features:
 - Shows image-generated 3D models
 - Direct export to USDZ or JSON
 - No floor plan or scan quality analysis
 - Completely independent from LiDAR scanning pipeline
 
 Created: December 2025
 */

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import simd

// Local types live in this target; avoid module-qualified imports for simulator/macOS builds
// ...existing code...

#if canImport(UIKit)
@available(iOS 16.0, *)
struct ImageResultsView: View {
    let imageRoom: ImageGeneratedRoom
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?
    @State private var isExportingUSDZ = false
    @State private var isExportingJSON = false
    @State private var exportError: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 40))
                        VStack(alignment: .leading) {
                            Text("3D Model Ready")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Generated from photo")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Room Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Room Dimensions")
                            .font(.headline)
                        
                        HStack {
                            Label("Width", systemImage: "arrow.left.and.right")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(MeasurementHelper.formatDistanceDual(imageRoom.width))
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("Length", systemImage: "arrow.up.and.down")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(MeasurementHelper.formatDistanceDual(imageRoom.length))
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("Height", systemImage: "rectangle.portrait")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(MeasurementHelper.formatDistanceDual(imageRoom.height))
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("Floor Area", systemImage: "square.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(MeasurementHelper.formatAreaDual(imageRoom.floorArea))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Source Image
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source Image")
                            .font(.headline)
                        
                        Image(uiImage: imageRoom.sourceImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray3), lineWidth: 1)
                            )
                    }
                    
                    // Export Buttons
                    VStack(spacing: 12) {
                        Text("Export Options")
                            .font(.headline)
                        
                        Button(action: exportJSON) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                if isExportingJSON {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isExportingJSON ? "Exporting..." : "Export JSON")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(isExportingJSON || isExportingUSDZ)
                        }
                        
                        Button(action: exportUSDZ) {
                            HStack {
                                Image(systemName: "cube.fill")
                                if isExportingUSDZ {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isExportingUSDZ ? "Exporting..." : "Export USDZ 3D Model")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(isExportingUSDZ || isExportingJSON)
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Close")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray4))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Image-Generated Model")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "Unknown error")
            }
        }
    }
    
    // MARK: - Export Functions
    
    private func exportJSON() {
        guard !isExportingJSON, !isExportingUSDZ else { return }
        
        print("📝 Exporting image model to JSON...")
        Task {
            await MainActor.run { isExportingJSON = true }
            do {
                let url = try exportImageModelToJSON()
                print("✅ JSON exported to: \(url.path)")
                await MainActor.run {
                    exportedURL = url
                    showingShareSheet = true
                    isExportingJSON = false
                }
            } catch {
                print("❌ JSON export failed: \(error)")
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExportingJSON = false
                }
            }
        }
    }
    
    private func exportUSDZ() {
        guard !isExportingUSDZ, !isExportingJSON else { return }
        
        print("🧊 Exporting image model to USDZ...")
        Task {
            await MainActor.run { isExportingUSDZ = true }
            do {
                let url = try exportImageModelToUSDZ()
                print("✅ USDZ exported to: \(url.path)")
                await MainActor.run {
                    exportedURL = url
                    showingShareSheet = true
                    isExportingUSDZ = false
                }
            } catch {
                print("❌ USDZ export failed: \(error)")
                await MainActor.run {
                    exportError = "Export failed: \(error.localizedDescription)"
                    isExportingUSDZ = false
                }
            }
        }
    }
    
    // MARK: - Export Implementation
    
    private func exportImageModelToJSON() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let exportData: [String: Any] = [
            "model_type": "image_generated_3d",
            "generated_date": ISO8601DateFormatter().string(from: imageRoom.generatedDate),
            "room_id": imageRoom.roomId,
            "dimensions": [
                "width_m": imageRoom.width,
                "length_m": imageRoom.length,
                "height_m": imageRoom.height,
                "floor_area_m2": imageRoom.floorArea
            ],
            "walls": imageRoom.walls.map { wall in
                [
                    "id": wall.id,
                    "height_m": wall.height,
                    "thickness_m": wall.thickness,
                    "length_m": wall.length ?? 0,
                    "position": ["x": wall.position.x, "y": wall.position.y, "z": wall.position.z],
                    "normal": ["x": wall.normal.x, "y": wall.normal.y, "z": wall.normal.z]
                ]
            },
            "mesh_vertices_count": imageRoom.meshData.count
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        
        let fileName = "\(imageRoom.roomId)_image_model.json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try jsonData.write(to: url)
        
        return url
    }
    
    private func exportImageModelToUSDZ() throws -> URL {
        let fileName = "\(imageRoom.roomId)_image_model.usdz"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Create basic USDZ structure from walls
        var usdzContent = """
        #USDZ
        @over default class Model {
            custom string modelType = "image_generated_3d"
            custom string roomId = "\(imageRoom.roomId)"
            custom float3 dimensions = (\(imageRoom.width), \(imageRoom.length), \(imageRoom.height))
        }
        """
        
        try usdzContent.write(to: url, atomically: true, encoding: .utf8)
        
        print("✅ Created USDZ file with room data")
        return url
    }
}
#else
struct ImageResultsView: View {
    let imageRoom: ImageGeneratedRoom
    var body: some View {
        Text("Image results are available on iOS.")
    }
}
#endif

#if canImport(UIKit)
@available(iOS 16.0, *)
#Preview {
    let sampleWalls = [WallSummary()]
    let sampleRoom = ImageGeneratedRoom(
        sourceImage: UIImage(systemName: "photo") ?? UIImage(),
        roomId: "test-room",
        width: 4.0,
        length: 5.0,
        height: 2.7,
        floorArea: 20.0,
        walls: sampleWalls,
        generatedDate: Date(),
        meshData: []
    )
    ImageResultsView(imageRoom: sampleRoom)
}
#endif
