# Single-Image → 3D Model Pipeline (Free & Open-Source)

This prototype accepts a single RGB image (iPhone photo) and produces a textured 3D mesh in OBJ and GLB formats. No paid APIs, no closed-source services.

- Depth: MiDaS (PyTorch)
- Point cloud + meshing: Open3D
- UV + texture + export: trimesh + PNG texture
- **REST API server** for seamless iOS integration
- Optional conversion to USDZ with Xcode toolchain

## Quickstart

### Method 1: Command Line

#### 1) Create and activate environment

```bash
# macOS (zsh)
python3 -m venv venv
source venv/bin/activate
pip install -U pip wheel
pip install -r single_image_3d/requirements.txt
```

#### 2) Run prediction

```bash
python single_image_3d/predict.py --input examples/room1.jpg --output out/ --mode single_image
```

Outputs:
- `out/model.obj`, `out/model.mtl`, `out/texture.png`
- `out/model.glb`
- `out/stats.json`

> Note: Place a sample image at `examples/room1.jpg`. Use your own photos to avoid copyright issues.

#### 3) Verify outputs

```bash
python single_image_3d/tests/test_mesh_stats.py out/
```

### Method 2: API Server (for iOS app integration)

#### 1) Start the server

```bash
source venv/bin/activate
python single_image_3d/server.py
```

Server runs on `http://localhost:5001` with endpoints:
- `GET /health` - Health check
- `POST /generate-sync` - Upload image, returns GLB file directly

#### 2) Use from iOS app

The iOS app's **"Generate from Photo"** button:
1. Picks image from photo library
2. Uploads to local Python server at `http://127.0.0.1:5001`
3. Server runs MiDaS depth estimation + 3D reconstruction
4. Returns generated `.glb` file
5. iOS app displays it in AR/3D viewer using SceneKit

**No internet required** - everything runs locally on your Mac!

## USDZ Conversion (free tooling)

- Option A (Xcode):

```bash
# Convert GLB → USDZ (requires Xcode command-line tools)
xcrun usdz_converter out/model.glb out/model.usdz
```

- Option B (Reality Converter app):
  - Open `out/model.glb` and export as USDZ.

- Option C (USD toolkit):
  - Use `usd_from_gltf` from Pixar USD. See their docs.

## iOS Integration (Swift)

### RealityKit (USDZ)

```swift
import SwiftUI
import RealityKit
import ARKit

struct ARUSDZViewer: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        
        // Load USDZ from app bundle or Files (adjust path)
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
```

### SceneKit (OBJ)

```swift
import SwiftUI
import SceneKit

struct OBJSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        let scene = SCNScene()
        view.scene = scene
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        
        // Load OBJ from app bundle
        if let url = Bundle.main.url(forResource: "model", withExtension: "obj") {
            let node = SCNNode()
            let asset = try? SCNScene(url: url, options: nil)
            if let asset = asset {
                // Use root node of imported scene
                if let importedNode = asset.rootNode.childNodes.first {
                    scene.rootNode.addChildNode(importedNode)
                }
            }
        }
        return view
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
```

## On-Device Option (CoreML)

You can convert MiDaS to CoreML via ONNX using only free tools.

### Export MiDaS to ONNX (script provided)

Use the provided helper script to export a stable DPT model to ONNX:

```bash
source venv/bin/activate
python single_image_3d/export_to_onnx_coreml.py --onnx midas.onnx --mlmodel MiDaS.mlmodel
```

Under the hood, it runs the following steps.

### Manual: Export MiDaS to ONNX

```python
import torch
model = torch.hub.load("intel-isl/MiDaS", "DPT_SwinV2_L_384").eval()
dummy = torch.randn(1, 3, 384, 384)
torch.onnx.export(
    model, dummy, "midas.onnx",
    input_names=["input"], output_names=["depth"], opset_version=12
)
```

### Convert ONNX → CoreML (script provided)

Alternatively, run the provided script with `--mlmodel` path as above. Manual one-liner below:

```bash
pip install coremltools onnx
python - <<'PY'
import coremltools as ct
import onnx
onnx_model = onnx.load("midas.onnx")
mlmodel = ct.converters.onnx.convert(onnx_model)
mlmodel.save("MiDaS.mlmodel")
PY
```

### Swift: run CoreML depth, then back-project

```swift
import CoreML
import Accelerate

func backProject(depth: [[Float]], width: Int, height: Int, fx: Float, fy: Float, cx: Float, cy: Float) -> [SIMD3<Float>] {
    var points = [SIMD3<Float>]()
    points.reserveCapacity(width * height)
    for y in 0..<height {
        for x in 0..<width {
            let z = depth[y][x]
            let X = (Float(x) - cx) * z / fx
            let Y = (Float(y) - cy) * z / fy
            points.append(SIMD3<Float>(X, Y, z))
        }
    }
    return points
}
```

- Meshing on-device is non-trivial; recommended hybrid: run depth on-device, send points to server for Poisson meshing, then return OBJ/GLB.

## Performance Notes

- MiDaS depth (2MP image):
  - CPU: ~3–6s
  - GPU (CUDA): ~0.3–1.2s
- Meshing (Poisson): 1–5s depending on point count
- Mobile budget: aim < 200k triangles for smooth AR; rooms < 50k recommended.

## Licenses

All libraries used are open-source:
- PyTorch (BSD), TorchVision (BSD), timm (Apache-2.0)
- OpenCV (Apache-2.0)
- Open3D (MIT)
- trimesh (MIT)
- pygltflib (MIT)
- scikit-image (BSD-3)

No GPL-only dependencies are required.

## USDZ Conversion via USD Toolkit

If `xcrun usdz_converter` is not available, you can install Pixar USD (free) and use `usd_from_gltf`:

```bash
brew install usd
usd_from_gltf single_image_3d/out/model.glb single_image_3d/out/model.usdz
```

## UX Guidance

- Single-image 3D is ambiguous; show a warning: "best-effort from one photo".
- Allow user to provide one reference (e.g., door height 2.0m) to scale.
- Provide progress steps and a quality score; offer multi-photo option for better results.
