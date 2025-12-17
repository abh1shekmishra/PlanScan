//
//  ARModelDemo.swift
//  RoomScanner
//
//  Minimal demo to load USDZ or OBJ in iOS.
//

import SwiftUI
import RealityKit
import ARKit
import SceneKit

@available(iOS 16.0, *)
struct ARModelDemo: View {
    @State private var showUSDZ = true
    var body: some View {
        VStack {
            Picker("Format", selection: $showUSDZ) {
                Text("USDZ").tag(true)
                Text("OBJ").tag(false)
            }.pickerStyle(.segmented).padding()
            if showUSDZ {
                ARUSDZViewer().edgesIgnoringSafeArea(.all)
            } else {
                OBJSceneContainer().edgesIgnoringSafeArea(.all)
            }
        }
    }
}

@available(iOS 16.0, *)
struct ARUSDZViewer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        if let url = Bundle.main.url(forResource: "model", withExtension: "usdz") {
            let entity = try? ModelEntity.load(contentsOf: url)
            let anchor = AnchorEntity(plane: .any)
            if let entity = entity {
                entity.generateCollisionShapes(recursive: true)
                anchor.addChild(entity)
                arView.scene.addAnchor(anchor)
            }
        }
        return arView
    }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

@available(iOS 16.0, *)
struct OBJSceneContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        let scene = SCNScene()
        view.scene = scene
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        if let url = Bundle.main.url(forResource: "model", withExtension: "obj") {
            if let imported = try? SCNScene(url: url, options: nil) {
                let root = imported.rootNode
                for child in root.childNodes { scene.rootNode.addChildNode(child) }
            }
        }
        return view
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
