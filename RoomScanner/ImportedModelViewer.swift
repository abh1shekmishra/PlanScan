//
//  ImportedModelViewer.swift
//  RoomScanner
//
//  Presents an imported USDZ or OBJ file from a URL.
//

import SwiftUI
import RealityKit
import ARKit
import SceneKit
import ModelIO

@available(iOS 16.0, *)
struct ImportedModelViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var isUSDZ: Bool { url.pathExtension.lowercased() == "usdz" }
    var isOBJ: Bool { url.pathExtension.lowercased() == "obj" }
    var isGLTF: Bool { let ext = url.pathExtension.lowercased(); return ext == "glb" || ext == "gltf" }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isUSDZ {
                    ARFileUSDZView(url: url).edgesIgnoringSafeArea(.all)
                } else if isOBJ {
                    OBJFileSceneView(url: url).edgesIgnoringSafeArea(.all)
                } else if isGLTF {
                    GLTFFileSceneView(url: url).edgesIgnoringSafeArea(.all)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Unsupported format: .\(url.pathExtension)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
struct ARFileUSDZView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        
        do {
            let entity = try ModelEntity.loadModel(contentsOf: url)
            let anchor = AnchorEntity(plane: .any)
            entity.generateCollisionShapes(recursive: true)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)
        } catch {
            print("❌ Failed to load USDZ: \(error)")
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

@available(iOS 16.0, *)
struct OBJFileSceneView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        let scene = SCNScene()
        view.scene = scene
        
        do {
            let imported = try SCNScene(url: url, options: [SCNSceneSource.LoadingOption.convertToYUp: true])
            for child in imported.rootNode.childNodes {
                scene.rootNode.addChildNode(child)
            }
        } catch {
            print("❌ Failed to load OBJ: \(error)")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

@available(iOS 16.0, *)
struct GLTFFileSceneView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        
        // Try loading the scene directly
        if let scene = try? SCNScene(url: url, options: nil) {
            view.scene = scene
        } else {
            // Fallback: empty scene if loading fails
            view.scene = SCNScene()
        }

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
