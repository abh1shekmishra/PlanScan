#!/usr/bin/env python3
"""
Single-image → 3D model pipeline (OBJ + GLTF/GLB) with texture.
Free/open-source: PyTorch (MiDaS), OpenCV, Open3D, trimesh.

Usage:
  python predict.py --input examples/room1.jpg --output out/ --mode single_image

Outputs:
  - out/model.obj + out/model.mtl + out/texture.png
  - out/model.glb (binary glTF)
  - out/stats.json (vertex/face counts)

USDZ conversion:
  - macOS: xcrun usdz_converter out/model.glb out/model.usdz
  - or Reality Converter app / usd_from_gltf (USD toolkit)
"""

import argparse
import json
import os
import sys
from pathlib import Path

import numpy as np
import cv2
from PIL import Image
from rich import print

# Defer heavy imports so CLI help is fast
import torch
import torchvision
import timm
import open3d as o3d
import trimesh

# -----------------------------
# Utility: camera intrinsics
# -----------------------------

def infer_intrinsics(img_w: int, img_h: int, focal_px: float | None = None):
    """Infer reasonable pinhole intrinsics if EXIF is missing.
    cx, cy: principal point at image center.
    fx, fy: focal in pixels. Default heuristic: 1.2 * max(img_w, img_h).
    """
    cx = img_w / 2.0
    cy = img_h / 2.0
    if focal_px is None:
        fx = fy = 1.2 * max(img_w, img_h)
    else:
        fx = fy = float(focal_px)
    K = np.array([[fx, 0, cx], [0, fy, cy], [0, 0, 1]], dtype=np.float32)
    return K

# -----------------------------
# Depth: MiDaS inference
# -----------------------------

def load_midas(device: torch.device):
    """Load a stable MiDaS DPT model via torch.hub (free).
    Prefer DPT_Large; fall back to Hybrid or Small if needed.
    """
    transforms = torch.hub.load("intel-isl/MiDaS", "transforms")
    last_error = None
    for model_name in [
        "DPT_Large",      # robust, accurate
        "DPT_Hybrid",     # smaller
        "MiDaS_small",    # fastest
    ]:
        try:
            model = torch.hub.load("intel-isl/MiDaS", model_name)
            model.eval().to(device)
            # All DPT variants use dpt_transform; MiDaS_small uses small_transform
            if model_name == "MiDaS_small":
                transform = transforms.small_transform
            else:
                transform = transforms.dpt_transform
            return model, transform
        except Exception as e:
            last_error = e
            continue
    raise RuntimeError(f"Failed to load MiDaS model variants: {last_error}")

@torch.no_grad()
def estimate_depth(model, transform, image_bgr: np.ndarray, device: torch.device) -> np.ndarray:
    """Run MiDaS to get relative depth. Returns float32 HxW depth map normalized."""
    img_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    inp = transform(img_rgb).to(device)
    pred = model(inp)
    depth = torch.nn.functional.interpolate(
        pred.unsqueeze(1), size=img_rgb.shape[:2], mode="bicubic", align_corners=False
    ).squeeze().cpu().numpy()
    # Normalize depth to [0,1]
    depth = (depth - depth.min()) / (depth.max() - depth.min() + 1e-8)
    # Post-process: bilateral filter to smooth while preserving edges
    depth = cv2.bilateralFilter(depth.astype(np.float32), d=9, sigmaColor=0.1, sigmaSpace=7)
    return depth.astype(np.float32)

# -----------------------------
# Back-projection → point cloud
# -----------------------------

def depth_to_pointcloud(depth: np.ndarray, K: np.ndarray) -> o3d.geometry.PointCloud:
    H, W = depth.shape
    fx, fy = K[0, 0], K[1, 1]
    cx, cy = K[0, 2], K[1, 2]

    us = np.arange(W)
    vs = np.arange(H)
    u, v = np.meshgrid(us, vs)

    z = depth.copy()
    # Scale relative depth into meters (heuristic). User can override later.
    z = z * 3.0  # assume ~3m max depth for indoor scenes
    x = (u - cx) * z / fx
    y = (v - cy) * z / fy

    pts = np.stack([x, y, z], axis=-1).reshape(-1, 3)
    # remove invalid/near-zero depth
    mask = z.reshape(-1) > 1e-3
    pts = pts[mask]

    pcd = o3d.geometry.PointCloud(o3d.utility.Vector3dVector(pts))
    return pcd

# -----------------------------
# Point cloud cleanup
# -----------------------------

def clean_pointcloud(pcd: o3d.geometry.PointCloud):
    # voxel downsample
    pcd = pcd.voxel_down_sample(voxel_size=0.01)
    # outlier removal
    pcd, _ = pcd.remove_statistical_outlier(nb_neighbors=20, std_ratio=2.0)
    pcd.estimate_normals(
        search_param=o3d.geometry.KDTreeSearchParamHybrid(radius=0.05, max_nn=30)
    )
    return pcd

# -----------------------------
# Meshing
# -----------------------------

def reconstruct_mesh(pcd: o3d.geometry.PointCloud):
    mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
        pcd, depth=8
    )
    # crop mesh to bounding box of points
    bbox = pcd.get_axis_aligned_bounding_box()
    mesh = mesh.crop(bbox)
    mesh.remove_degenerate_triangles()
    mesh.remove_duplicated_triangles()
    mesh.remove_duplicated_vertices()
    mesh.remove_non_manifold_edges()
    mesh = mesh.filter_smooth_simple(number_of_iterations=1)
    # simplify target triangle count
    target = min(len(mesh.triangles), 150_000)
    if target > 0:
        mesh = mesh.simplify_quadric_decimation(target)
    mesh.compute_vertex_normals()
    return mesh

# -----------------------------
# UV + texture baking (simple projection)
# -----------------------------

def compute_uv(mesh: o3d.geometry.TriangleMesh, K: np.ndarray, img_w: int, img_h: int):
    verts = np.asarray(mesh.vertices)  # Nx3 camera space
    fx, fy = K[0, 0], K[1, 1]
    cx, cy = K[0, 2], K[1, 2]

    X, Y, Z = verts[:, 0], verts[:, 1], verts[:, 2]
    # Project: u = fx * X/Z + cx; v = fy * Y/Z + cy
    eps = 1e-6
    u = fx * X / (Z + eps) + cx
    v = fy * Y / (Z + eps) + cy
    # Normalize to [0,1]
    u = np.clip(u / img_w, 0, 1)
    v = np.clip(v / img_h, 0, 1)
    # Invert v for typical image origin differences
    v = 1.0 - v
    uv = np.stack([u, v], axis=1)
    return uv.astype(np.float32)

# -----------------------------
# Export: OBJ+MTL+PNG and GLB
# -----------------------------

def export_obj_glb(mesh: o3d.geometry.TriangleMesh, uv: np.ndarray, texture_path: Path, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    obj_path = out_dir / "model.obj"
    mtl_path = out_dir / "model.mtl"
    glb_path = out_dir / "model.glb"

    # Convert Open3D mesh to trimesh
    vertices = np.asarray(mesh.vertices)
    faces = np.asarray(mesh.triangles)

    # Load texture image
    tex_img = Image.open(texture_path).convert("RGB")
    tex_arr = np.array(tex_img)

    # Construct Trimesh with UVs + texture
    tm = trimesh.Trimesh(vertices=vertices, faces=faces, process=False)
    # Attach UVs
    tm.visual.uv = uv
    # Attach texture via PBR material
    material = trimesh.visual.material.PBRMaterial(
        baseColorTexture=tex_arr
    )
    tm.visual.material = material

    # Export OBJ (+MTL)
    obj_str = trimesh.exchange.obj.export_obj(tm, include_texture=True)
    with open(obj_path, "w", encoding="utf-8") as f:
        f.write(obj_str)
    # Write texture alongside
    tex_out = out_dir / "texture.png"
    tex_img.save(tex_out)

    # Export GLB (binary glTF)
    glb = trimesh.exchange.gltf.export_glb(tm)
    glb_bytes = glb if isinstance(glb, (bytes, bytearray)) else bytes(glb)
    with open(glb_path, "wb") as f:
        f.write(glb_bytes)

    return obj_path, glb_path, tex_out

# -----------------------------
# Stats
# -----------------------------

def write_stats(mesh: o3d.geometry.TriangleMesh, out_dir: Path):
    stats = {
        "vertices": int(len(mesh.vertices)),
        "faces": int(len(mesh.triangles)),
        "bbox": {
            "min": list(np.asarray(mesh.get_axis_aligned_bounding_box().get_min_bound())),
            "max": list(np.asarray(mesh.get_axis_aligned_bounding_box().get_max_bound())),
        },
    }
    with open(out_dir / "stats.json", "w") as f:
        json.dump(stats, f, indent=2)
    return stats

# -----------------------------
# Main CLI
# -----------------------------

def run_single_image(input_path: Path, output_dir: Path):
    image_bgr = cv2.imread(str(input_path))
    if image_bgr is None:
        raise FileNotFoundError(f"Failed to read image: {input_path}")
    H, W = image_bgr.shape[:2]

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[green]Device:[/] {device}")
    model, transform = load_midas(device)

    depth = estimate_depth(model, transform, image_bgr, device)
    print(f"[green]Depth computed:[/] shape={depth.shape}, range=({depth.min():.3f},{depth.max():.3f})")

    K = infer_intrinsics(W, H)
    pcd = depth_to_pointcloud(depth, K)
    pcd = clean_pointcloud(pcd)
    print(f"[green]Point cloud:[/] {np.asarray(pcd.points).shape[0]} points")

    mesh = reconstruct_mesh(pcd)
    print(f"[green]Mesh:[/] {len(mesh.vertices)} vertices, {len(mesh.triangles)} faces")

    # UVs and texture
    uv = compute_uv(mesh, K, W, H)

    # Save texture from original image
    out_dir = output_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    texture_path = out_dir / "texture.png"
    Image.fromarray(cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)).save(texture_path)

    obj_path, glb_path, tex_out = export_obj_glb(mesh, uv, texture_path, out_dir)
    stats = write_stats(mesh, out_dir)

    print(f"[cyan]OBJ:[/] {obj_path}")
    print(f"[cyan]GLB:[/] {glb_path}")
    print(f"[cyan]Texture:[/] {tex_out}")
    print(f"[cyan]Stats:[/] {out_dir / 'stats.json'}")


def main():
    ap = argparse.ArgumentParser(description="Single-image → 3D pipeline")
    ap.add_argument("--input", required=True, help="Input image path")
    ap.add_argument("--output", required=True, help="Output folder")
    ap.add_argument("--mode", default="single_image", choices=["single_image"], help="Pipeline mode")
    args = ap.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output)
    if args.mode == "single_image":
        run_single_image(input_path, output_dir)
    else:
        print("Unsupported mode.")
        sys.exit(2)


if __name__ == "__main__":
    main()
