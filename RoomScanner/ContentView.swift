//
//  ContentView.swift
//  RoomScanner
//
//  Created by Abhishek trezi on 10/12/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    @State private var showingResults = false
    @State private var showingShareSheet = false
    @State private var exportedURL: URL?
    @State private var isExportingUSDZ = false
    @State private var isExportingJSON = false
    @State private var isExportingFloorPlan = false
    @State private var showingFloorPlanViewer = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isProcessingImage = false
    @State private var imageProcessingError: String?
    
    var body: some View {
        ZStack {
            Group {
                if manager.isScanning {
                    ScanView()
                        .edgesIgnoringSafeArea(.all)
                } else if !manager.capturedRooms.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 40))
                                VStack(alignment: .leading) {
                                    Text("Scan Complete")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    Text("\(manager.capturedRooms.count) room(s) captured")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            
                            ForEach(manager.capturedRooms) { room in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Room: \(room.roomId)")
                                        .font(.headline)
                                    
                                    HStack {
                                        Text("Floor Area")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "%.2f m²", room.floorArea))
                                            .fontWeight(.semibold)
                                    }
                                    
                                    HStack {
                                        Text("Walls")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(room.walls.count) walls")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                
                                // Door/Window Analysis Section
                                if !room.openings.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Door/Window Analysis")
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        let doors = room.openings.filter { $0.type == "door" }
                                        let windows = room.openings.filter { $0.type == "window" }
                                        
                                        HStack {
                                            Label("Total Openings", systemImage: "square.grid.2x2")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(room.openings.count)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                        }
                                        
                                        if !doors.isEmpty {
                                            HStack {
                                                Label("Doors", systemImage: "door.right.hand")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text("\(doors.count)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            
                                            let totalDoorArea = doors.reduce(0) { $0 + (Float($1.width) * Float($1.height)) }
                                            HStack {
                                                Text("  Door Area")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(String(format: "%.2f m²", totalDoorArea))
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        
                                        if !windows.isEmpty {
                                            HStack {
                                                Label("Windows", systemImage: "square.split.2x1")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text("\(windows.count)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            
                                            let totalWindowArea = windows.reduce(0) { $0 + (Float($1.width) * Float($1.height)) }
                                            HStack {
                                                Text("  Window Area")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(String(format: "%.2f m²", totalWindowArea))
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                        
                                        let totalOpeningArea = room.openings.reduce(0) { $0 + (Float($1.width) * Float($1.height)) }
                                        Divider()
                                        HStack {
                                            Text("Total Opening Area")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text(String(format: "%.2f m²", totalOpeningArea))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                
                                // Quality Report Section
                                if let report = room.qualityReport {
                                    ScanQualityView(report: report)
                                }
                                
                                // Wall Details Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Wall Details")
                                        .font(.headline)
                                        .padding(.bottom, 4)
                                    
                                    ForEach(Array(room.walls.enumerated()), id: \.element.id) { index, wall in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Wall \(index + 1)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                Spacer()
                                                Text(wall.id)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Divider()
                                            
                                            HStack {
                                                Label("Height", systemImage: "arrow.up.and.down")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(String(format: "%.2f m", wall.height))
                                                    .font(.caption)
                                            }
                                            
                                            if let length = wall.length {
                                                HStack {
                                                    Label("Length", systemImage: "ruler")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(String(format: "%.2f m", length))
                                                        .font(.caption)
                                                }
                                            }
                                            
                                            if let thickness = wall.thickness {
                                                HStack {
                                                    Label("Thickness", systemImage: "arrow.left.and.right")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text(String(format: "%.2f m", thickness))
                                                        .font(.caption)
                                                }
                                            }
                                            
                                            HStack {
                                                Label("Position", systemImage: "location")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(String(format: "(%.2f, %.2f, %.2f)", wall.position.x, wall.position.y, wall.position.z))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            
                            VStack(spacing: 12) {
                                Button(action: { showingFloorPlanViewer = true }) {
                                    HStack {
                                        Image(systemName: "map")
                                        Text("View Floor Plan")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.indigo)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: exportJSON) {
                                    HStack {
                                        Image(systemName: "doc.text")
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
                                    .cornerRadius(10)
                                    .disabled(isExportingJSON || isExportingUSDZ)
                                }

                                Button(action: exportUSDZ) {
                                    HStack {
                                        Image(systemName: "cube")
                                        if isExportingUSDZ {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(isExportingUSDZ ? "Exporting..." : "Export USDZ")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .disabled(isExportingUSDZ)
                                }

                                Button(action: exportFloorPlan) {
                                    HStack {
                                        Image(systemName: "square.grid.2x2")
                                        if isExportingFloorPlan {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        Text(isExportingFloorPlan ? "Exporting..." : "Export Floor Plan")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .disabled(isExportingFloorPlan || isExportingJSON || isExportingUSDZ)
                                }
                                
                                Button(action: resetScan) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("New Scan")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                            }
                            .padding()
                        }
                        .padding()
                    }
                } else {
                    WelcomeView(
                        onStartScan: {
                            print("🚀 Start scan button tapped")
                            manager.startScan()
                        },
                        onImagePicker: {
                            print("📸 Image picker button tapped")
                            showingImagePicker = true
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingFloorPlanViewer) {
                if let room = manager.capturedRooms.last {
                    FloorPlanViewer(room: room)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if let image = selectedImage {
                            processImageTo3D(image)
                        }
                    }
            }
            
            // Error overlay
            if let error = manager.errorMessage {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text("Error")
                                .fontWeight(.bold)
                            Spacer()
                            Button(action: { manager.errorMessage = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        Text(error)
                            .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                }
            }
        }
    }
    
    private func exportJSON() {
        guard !isExportingJSON, !isExportingUSDZ, !isExportingFloorPlan else { 
            print("⚠️ Export already in progress")
            return 
        }
        
        print("📝 Exporting JSON...")
        Task {
            await MainActor.run { isExportingJSON = true }
            do {
                let url = try ModelExporter.exportJSON(rooms: manager.capturedRooms)
                print("✅ JSON exported to: \(url.path)")
                await MainActor.run {
                    exportedURL = url
                    showingShareSheet = true
                    isExportingJSON = false
                }
            } catch {
                print("❌ JSON export failed: \(error)")
                await MainActor.run {
                    manager.errorMessage = "Export failed: \(error.localizedDescription)"
                    isExportingJSON = false
                }
            }
        }
    }

    private func exportUSDZ() {
        guard !isExportingUSDZ, !isExportingJSON, !isExportingFloorPlan else { 
            print("⚠️ Export already in progress")
            return 
        }
        
        Task {
            await MainActor.run { isExportingUSDZ = true }
            print("🧊 Exporting USDZ...")
            guard let url = await manager.exportToUSDZ() else { return }
            print("✅ USDZ exported to: \(url.path)")
            await MainActor.run {
                exportedURL = url
                showingShareSheet = true
                isExportingUSDZ = false
            }
        }
    }

    private func exportFloorPlan() {
        guard !isExportingFloorPlan, !isExportingJSON, !isExportingUSDZ else { 
            print("⚠️ Export already in progress")
            return 
        }
        
        print("📐 Exporting floor plan...")
        Task {
            await MainActor.run { isExportingFloorPlan = true }
            if let url = manager.exportToFloorPlan() {
                print("✅ Floor plan exported to: \(url.path)")
                await MainActor.run {
                    exportedURL = url
                    showingShareSheet = true
                    isExportingFloorPlan = false
                }
            } else {
                await MainActor.run {
                    isExportingFloorPlan = false
                }
            }
        }
    }
    
    private func resetScan() {
        print("🔄 Starting new scan...")
        manager.resetForNewScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            manager.startScan()
        }
    }
    
    private func processImageTo3D(_ image: UIImage) {
        print("🖼️ Processing image to 3D model...")
        isProcessingImage = true
        imageProcessingError = nil
        
        Task {
            // Analyze image using Vision framework
            guard let roomData = ImageTo3DProcessor.analyzeRoomImage(image) else {
                await MainActor.run {
                    imageProcessingError = "Failed to detect room boundaries in image"
                    isProcessingImage = false
                }
                return
            }
            
            print("✅ Room analysis complete: \(roomData.estimatedWidth)m × \(roomData.estimatedLength)m × \(roomData.estimatedHeight)m")
            
            // Generate 3D model from image analysis
            let room3D = ImageTo3DProcessor.generate3DModel(from: roomData)
            
            // Add to captured rooms (background thread)
            await MainActor.run {
                manager.capturedRooms.append(room3D)
                isProcessingImage = false
                selectedImage = nil
                
                print("✅ 3D model generated successfully!")
                print("Room dimensions: \(roomData.estimatedWidth)m W × \(roomData.estimatedLength)m L × \(roomData.estimatedHeight)m H")
                print("Floor area: \(String(format: "%.2f", room3D.floorArea)) m²")
            }
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    let onStartScan: () -> Void
    let onImagePicker: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "ruler.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("PlanScan")
                .font(.system(size: 32, weight: .bold))
            
            Text("Scan and measure indoor spaces using LiDAR")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "ruler", text: "Measure wall heights")
                FeatureRow(icon: "square.grid.3x3", text: "Compute floor area")
                FeatureRow(icon: "doc.text", text: "Export JSON (Save to Files)")
                FeatureRow(icon: "cube", text: "Export USDZ 3D model")
                FeatureRow(icon: "square.grid.2x2", text: "Export 2D floor plan")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button(action: onStartScan) {
                HStack(spacing: 10) {
                    Image(systemName: "scanner.fill")
                    Text("Start Scan")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .padding(.horizontal, 40)
            
            Divider()
                .padding(.horizontal)
            
            Button(action: onImagePicker) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.circle")
                    Text("Generate from Photo")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
            }
            .padding(.horizontal, 40)
            
            Text("Requires iPhone with LiDAR (iPhone 12 Pro or later)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Results View
@available(iOS 16.0, *)
struct ResultsView: View {
    @EnvironmentObject var manager: RoomCaptureManager
    let rooms: [CapturedRoomSummary]
    @Binding var showingExportOptions: Bool
    @Binding var exportedURL: URL?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 40))
                    VStack(alignment: .leading) {
                        Text("Scan Complete")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(rooms.count) room(s) captured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                
                ForEach(rooms) { room in
                    RoomCard(room: room)
                }
                
                VStack(spacing: 12) {
                    Button(action: exportJSON) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Export JSON")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
    
    private func exportJSON() {
        do {
            let url = try ModelExporter.exportJSON(rooms: rooms)
            exportedURL = url
            showingExportOptions = true
        } catch {
            print("Error exporting JSON: \(error)")
        }
    }
}

struct RoomCard: View {
    let room: CapturedRoomSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room: \(room.roomId)")
                .font(.headline)
            
            HStack {
                Text("Floor Area")
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f m²", room.floorArea))
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Walls")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(room.walls.count)")
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Openings (doors/windows)")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(room.openings.count)")
                    .fontWeight(.semibold)
            }

            if !room.walls.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wall Details")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(room.walls.prefix(4)) { wall in
                        Text("• \(wall.id): h=\(String(format: "%.2f", wall.height))m, len=\(String(format: "%.2f", wall.length ?? 0))m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if room.walls.count > 4 {
                        Text("…plus \(room.walls.count - 4) more wall(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 6)
            }

            if !room.openings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Openings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ForEach(room.openings.prefix(4)) { opening in
                        Text("• \(opening.type) \(opening.id): w=\(String(format: "%.2f", opening.width))m, h=\(String(format: "%.2f", opening.height))m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if room.openings.count > 4 {
                        Text("…plus \(room.openings.count - 4) more opening(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Floor Plan Viewer
@available(iOS 16.0, *)
struct FloorPlanViewer: View {
    let room: CapturedRoomSummary
    @Environment(\.dismiss) var dismiss
    @State private var floorPlanImage: UIImage?
    @State private var isGenerating = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if isGenerating {
                    ProgressView("Generating floor plan...")
                } else if let image = floorPlanImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Unable to generate floor plan")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Floor Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if floorPlanImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: Image(uiImage: floorPlanImage!), preview: SharePreview("Floor Plan", image: Image(uiImage: floorPlanImage!)))
                    }
                }
            }
        }
        .onAppear {
            generateFloorPlan()
        }
    }
    
    private func generateFloorPlan() {
        guard !isGenerating else { return }

        isGenerating = true

        // Use background queue for expensive operation
        DispatchQueue.global(qos: .userInitiated).async {
            let image = FloorPlanGenerator.generateFloorPlan(from: room)

            DispatchQueue.main.async {
                floorPlanImage = image
                isGenerating = false
            }
        }
    }
}

// MARK: - Scan Quality View
@available(iOS 16.0, *)
struct ScanQualityView: View {
    let report: ScanQualityReport
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scan Quality & Accuracy")
                    .font(.headline)
                Spacer()
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            // Overall Quality Badge
            HStack(spacing: 16) {
                Circle()
                    .fill(qualityColor(report.overallQuality))
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.overallQuality.description)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Quality Score: \(report.qualityScore)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(report.coveragePercentage))%")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Coverage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if showDetails {
                Divider()
                
                // Issues Section
                if !report.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issues Found (\(report.issues.count))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(report.issues.prefix(5)) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: issue.severity.icon)
                                    .foregroundColor(issueColor(issue.severity))
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(issue.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if report.issues.count > 5 {
                            Text("...and \(report.issues.count - 5) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                }
                
                // Recommendations
                if !report.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recommendations")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ForEach(report.recommendations, id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                
                                Text(recommendation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private func qualityColor(_ quality: ScanQuality) -> Color {
        switch quality {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
    
    private func issueColor(_ severity: ValidationIssue.IssueSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Share Sheet
@available(iOS 16.0, *)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    if #available(iOS 16.0, *) {
        ContentView()
            .environmentObject(RoomCaptureManager())
    }
}

