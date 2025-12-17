# Convert GLTF/GLB to USDZ (Free Tools)

## Xcode Command-Line Tools (macOS)

```bash
xcrun usdz_converter out/model.glb out/model.usdz
```

If `usdz_converter` is missing, install Xcode + Command Line Tools.

## Reality Converter (Apple)
- Download the free app from Apple Developer.
- Open `out/model.glb` and export as USDZ.

## USD Toolkit (usd_from_gltf)
- Install USD and use `usd_from_gltf` utility.
- See Pixar USD docs for installation.

Notes:
- USDZ supports textures; GLB should embed or reference `texture.png`.
- Keep triangle count modest (< 200k) for mobile performance.
