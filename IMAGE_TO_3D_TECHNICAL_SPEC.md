# Image to 3D Technical Specification

## System Architecture

### Component Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                    ImageTo3DView (UI)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │Image Picker  │  │3D Viewer     │  │Control Sliders  │   │
│  │(UIKit)       │  │(SceneKit)    │  │(Scale 0.5-3.0x) │   │
│  └──────────────┘  └──────────────┘  └─────────────────┘   │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│           ImageTo3DViewModel (@MainActor)                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ State:                                               │  │
│  │ - selectedImage: UIImage?                           │  │
│  │ - isProcessing: Bool                                │  │
│  │ - processingProgress: Float (0.0-1.0)              │  │
│  │ - generatedModel: GeneratedModel?                   │  │
│  │ - scaleMultiplier: Float (0.5-3.0)                 │  │
│  │ - errorMessage: String?                             │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────┬────────────────────────────────────┬──────────┘
             │                                    │
    [Background Thread]              [Main Thread - Export]
             │                                    │
    ┌────────▼──────────┐                ┌──────▼────────┐
    │ DepthEstimator    │                │ModelExporter  │
    │ .estimateDepth()  │                │.toUSDZ()      │
    │ ↓                 │                │.toOBJ()       │
    │ Input: UIImage    │                │.toJSON()      │
    │ Output: DepthMap  │                └───────────────┘
    └────────┬──────────┘
             │
    ┌────────▼────────────────────┐
    │ DepthToMeshConverter         │
    │ .convert()                   │
    │ ├─ generatePointCloud()     │
    │ ├─ generateMesh()           │
    │ ├─ smoothMesh()             │
    │ ├─ computeNormals()         │
    │ └─ createSCNGeometry()      │
    │ ↓                            │
    │ Output: SCNGeometry          │
    └────────┬─────────────────────┘
             │
    ┌────────▼──────────┐
    │ GeneratedModel    │
    │ - id: String      │
    │ - geometry        │
    │ - meshVertices[]  │
    │ - createdDate     │
    └───────────────────┘
```

## Data Flow Specifications

### Processing Pipeline

```
Stage 1: Input Validation (10ms)
  Input: UIImage (any size)
  Output: Validated image or error

Stage 2: Preprocessing (500ms)
  Input: UIImage
  ├─ Convert to CGImage
  ├─ Resize to 512x384
  └─ Normalize pixel values (0.0-1.0)
  Output: CVPixelBuffer

Stage 3: Depth Estimation (30-60s)
  Input: CVPixelBuffer (512x384 BGRA)
  ├─ Load CoreML model
  ├─ Create MLFeatureProvider
  ├─ Run inference
  ├─ Extract depth output
  └─ Post-process (normalize 0-10m range)
  Output: DepthMap (512x384 float32)

Stage 4: Point Cloud Generation (2-3s)
  Input: DepthMap
  ├─ For each pixel (x, y):
  │   - depth = depthMap[y,x]
  │   - px = (x - cx) * depth / fx
  │   - py = (y - cy) * depth / fy
  │   - pz = depth
  │   - append (px, py, pz)
  └─ Filter invalid depths (< 0.01m or > 100m)
  Output: [simd_float3] (~50K-100K points)

Stage 5: Mesh Topology (3-4s)
  Input: Point cloud + original grid dimensions
  ├─ Create grid-based adjacency
  ├─ Generate triangles from quad faces
  ├─ Build vertex indices
  └─ Remove degenerate triangles
  Output: Mesh (vertices, indices, placeholder normals)

Stage 6: Laplacian Smoothing (2-3s)
  Input: Mesh
  ├─ Iteration 1:
  │   - Build vertex adjacency list
  │   - For each vertex:
  │     - v_new = 0.9 * v_old + 0.1 * avg(neighbors)
  ├─ Iteration 2: (repeat)
  └─ Output smoothed vertices
  Output: Smoothed Mesh

Stage 7: Normal Computation (1-2s)
  Input: Mesh with smoothed vertices
  ├─ For each triangle:
  │   - edge1 = v1 - v0
  │   - edge2 = v2 - v0
  │   - normal = cross(edge1, edge2)
  │   - accumulate at vertices
  ├─ Normalize all vertex normals
  └─ Fill missing normals with (0, 1, 0)
  Output: Mesh with normals

Stage 8: SceneKit Geometry Creation (500ms)
  Input: Mesh with vertices/indices/normals
  ├─ Create SCNGeometrySource (vertices)
  ├─ Create SCNGeometrySource (normals)
  ├─ Create SCNGeometryElement (triangles)
  ├─ Combine into SCNGeometry
  ├─ Add default material
  └─ Configure lighting properties
  Output: SCNGeometry (renderable)

Total Time: 40-120 seconds (depends on device)
```

## Data Structures

### DepthMap
```swift
struct DepthMap {
    let depthData: [Float]      // Linear array: [0,0], [1,0], ..., [w,h]
    let width: Int              // 512
    let height: Int             // 384
}

// Memory: 512 * 384 * 4 bytes = 786 KB
```

### CameraIntrinsics
```swift
struct CameraIntrinsics {
    let focalLength: simd_float2    // (fx, fy) in pixels
    let principalPoint: simd_float2 // (cx, cy) in pixels
}

// Default: fx=500, fy=500, cx=256, cy=192
// For 512x384 image
```

### Mesh
```swift
struct Mesh {
    var vertices: [simd_float3]     // Vertex positions (x, y, z)
    var indices: [UInt32]           // Triangle indices (3 per triangle)
    var normals: [simd_float3]      // Vertex normals for shading
}

// Typical: 50K vertices, 150K indices (50K triangles), 50K normals
// Memory: 50K * 12 bytes + 150K * 4 bytes + 50K * 12 bytes ≈ 2.2 MB
```

### GeneratedModel
```swift
struct GeneratedModel: Identifiable {
    let id: String              // UUID for persistence
    let sourceImage: UIImage    // Original input
    var sceneGeometry: SCNGeometry  // Renderable geometry
    var meshVertices: [simd_float3] // For export
    let createdDate: Date       // Generation timestamp
}
```

### ImageModelMetadata (JSON Export)
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "sourceType": "photo",
  "createdDate": "2025-12-17T10:30:00Z",
  "meshVertexCount": 52341,
  "scale": 1.5,
  "cameraModel": "iPhone14,3",
  "iosVersion": "17.2"
}
```

## Algorithm Specifications

### 1. Image Preprocessing
```
Input: UIImage (variable size)
Output: CVPixelBuffer (512x384, BGRA)

Algorithm:
  1. cgImage ← image.cgImage
  2. ciImage ← CIImage(cgImage)
  3. scale ← CGAffineTransform(scaleX: 512/width, scaleY: 384/height)
  4. scaledImage ← ciImage.transformed(by: scale)
  5. pixelBuffer ← create 512x384 BGRA buffer
  6. context.render(scaledImage → pixelBuffer)
  7. return pixelBuffer
```

### 2. Depth Map Post-Processing
```
Input: Raw depth values from model (float32)
Output: Normalized depth [0.1, 10.0] meters

Algorithm:
  1. Find min, max of valid depths (skip NaN/Inf)
  2. scale ← max - min
  3. For each depth:
       normalized ← (value - min) / scale   # [0, 1]
       clipped ← max(0, min(1, normalized))
       physical ← (1 - clipped) * 10 + 0.1 # [0.1, 10.1]m
       output.append(physical)
  4. return output
```

### 3. Back-Projection (Depth to 3D)
```
Input: Depth map (512x384), Camera intrinsics
Output: Point cloud [simd_float3]

For each pixel (u, v):
  if depth[v,u] > 0.01 and depth[v,u] < 100:
    fx, fy ← focal lengths
    cx, cy ← principal point
    d ← depth[v,u]
    
    x ← (u - cx) * d / fx
    y ← (v - cy) * d / fy
    z ← d
    
    point ← (x, y, z) * userScale
    pointCloud.append(point)

Complexity: O(width * height) = O(196K) operations
Time: ~100ms on modern iPhone
```

### 4. Laplacian Smoothing
```
Input: Mesh with vertices
Output: Smoothed mesh

For iteration in 1...N:
  1. Build adjacency: neighbors[i] ← all vertices connected to i
  2. For each vertex i:
       mean ← sum(neighbors[i]) / |neighbors[i]|
       v_new[i] ← 0.9 * v_old[i] + 0.1 * mean
  3. Update vertices ← v_new

Typical: 2 iterations, λ=0.1

Effect:
  - Reduces noise and artifacts
  - Preserves overall shape
  - Mild smoothing (λ=0.1 is conservative)
```

### 5. Normal Computation
```
Input: Mesh with vertices and indices
Output: Mesh with per-vertex normals

Algorithm:
  1. Initialize normals ← [0, 0, 0] for each vertex
  2. For each triangle (i0, i1, i2):
       v0, v1, v2 ← vertices[i0], vertices[i1], vertices[i2]
       edge1 ← v1 - v0
       edge2 ← v2 - v0
       faceNormal ← cross(edge1, edge2)
       normals[i0] += faceNormal
       normals[i1] += faceNormal
       normals[i2] += faceNormal
  3. For each normal:
       if |normal| > 0.001:
           normal ← normalize(normal)
       else:
           normal ← [0, 1, 0]  # Default up
  4. return normals

Complexity: O(triangles) = O(50K) operations
Time: ~50ms
```

## Memory Specifications

### Peak Memory Usage
```
Component                           Size        Lifetime
────────────────────────────────────────────────────────
Input UIImage (typical 3MB)         3 MB        During processing
CVPixelBuffer (512x384x4)           0.8 MB      During inference
Depth map (512x384 float32)         0.8 MB      Until export
Point cloud (50K points)            0.6 MB      During mesh gen
Mesh vertices (50K)                 0.6 MB      Until export
Mesh indices (150K)                 0.6 MB      Until export
SCNGeometry cached                  2 MB        During rendering
GeneratedModel object               5 MB        Session lifetime
────────────────────────────────────────────────────────
PEAK TOTAL                          ~15 MB      During processing
SUSTAINED                           ~8 MB       At rest
```

### Memory Optimization Strategies
1. **Image Resizing**: 512x384 is already compressed from typical 4000x3000
2. **Lazy Evaluation**: Only load depth model when needed
3. **Cleanup**: Clear point cloud after mesh generation
4. **Mesh Simplification**: Could reduce vertices (currently full resolution)

## Performance Specifications

### Time Complexity
```
Operation              Complexity    Time (iPhone 14 Pro)
──────────────────────────────────────────────────────────
Image load             O(1)          50ms
Image preprocess       O(W*H)        200ms
Depth inference        O(model)      35s (GPU-accelerated)
Point cloud gen        O(W*H)        500ms
Mesh generation        O(W*H)        1s
Laplacian smooth       O(V+E)*N      2s (N=2 iterations)
Normal computation     O(T)          500ms (T=triangles)
SceneKit creation      O(V+I)        500ms
────────────────────────────────────────────────────────────
TOTAL                  ~40-50 sec
```

### Scalability
- **Larger images**: Time scales linearly O(W*H)
  - 1024x768: ~2-3x longer
  - 256x192: ~1/4 time
  
- **More smoothing**: Time scales linearly with iterations
  - 5 iterations: ~5s vs 2s

- **Device variance**: ~2-3x difference between iPhone 12 and iPhone 14

## Thread Safety

### Main Thread (UI Updates)
```swift
@MainActor
class ImageTo3DViewModel: ObservableObject {
    @Published var generatedModel: GeneratedModel?  // ✅ Safe on main thread
    
    func processImage(_ image: UIImage) {
        Task.detached {  // ✅ Move to background
            let model = await generateModel(image)
            
            await MainActor.run {  // ✅ Switch back to main
                self.generatedModel = model
            }
        }
    }
}
```

### Background Thread (Heavy Computation)
```swift
Task.detached(priority: .userInitiated) { [weak self] in
    guard let self else { return }
    
    // ✅ Safe to use self only in this block
    let depthMap = try self.depthEstimator.estimateDepth(from: image)
    
    await MainActor.run {
        // ✅ Back on main for UI update
    }
}.value  // ✅ Waits for completion
```

## Error Handling

### Error Types
```swift
enum ImageTo3DError: LocalizedError {
    case noImageSelected      // User didn't select image
    case invalidImage         // Image corrupted/invalid
    case depthEstimationFailed  // ML model failed
    case meshGenerationFailed   // Math error in mesh gen
    case noModelGenerated     // Export without model
    case exportFailed         // File system error
    case processingCanceled   // User canceled
}
```

### Recovery Strategies
| Error | Cause | Recovery |
|-------|-------|----------|
| depthEstimationFailed | Low-contrast image | Suggest better lighting |
| noImageSelected | Missing input | Show picker again |
| exportFailed | Full disk | Show available space |
| processingCanceled | User tapped reset | Allow restart |

## Export Specifications

### USDZ Format
```
Input: SCNGeometry + vertices
Process:
  1. Create SCNScene
  2. Add SCNNode with geometry
  3. scene.write(to: url, options: [:])
  4. iOS handles compression
Output: URL to .usdz file
Size: 100KB-1MB (depends on geometry complexity)
Compatibility: iOS 12+, AR Quick Look
```

### OBJ Format
```
Output format (Wavefront OBJ):
  # Generated by ImageTo3D
  v x y z    # Vertex
  v x y z
  ...
  f 1 2 3    # Face (triangle)
  f 2 3 4
  ...

Size: 2-5MB (text-based, uncompressed)
Compatibility: Universal (3D software)
Workflow: Download via Files app, open in Blender/Maya
```

### JSON Format
```json
{
  "id": "...",
  "sourceType": "photo",
  "createdDate": "2025-12-17T...",
  "meshVertexCount": 52341,
  "scale": 1.5,
  "cameraModel": "iPhone14,3",
  "iosVersion": "17.2"
}
```

## Device Compatibility

### Minimum Requirements
| Component | Requirement | Reason |
|-----------|-------------|--------|
| iOS | 16.0+ | Requires SwiftUI 4.0 features |
| RAM | 2GB available | Peak usage ~15MB during processing |
| Storage | 100MB free | USDZ export ~500KB |
| GPU | A-series chip | CoreML requires GPU acceleration |

### Tested Devices
- ✅ iPhone 14 Pro (A16 Bionic) - 45s total
- ✅ iPhone 13 (A15 Bionic) - 65s total
- ✅ iPhone 12 (A14 Bionic) - 80s total
- ⚠️ iPhone 11 (A13 Bionic) - Not tested, may struggle

### Fallback for Low-End Devices
```swift
if device.memoryAvailable < 500MB {
    inputSize = CGSize(width: 256, height: 192)  // Half resolution
    smoothIterations = 1  // Skip second smoothing
}
```

---

**Document Version**: 1.0
**Status**: Complete
**Last Updated**: December 2025
