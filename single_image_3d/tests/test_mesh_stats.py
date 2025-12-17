#!/usr/bin/env python3
"""Minimal verification for produced meshes."""
import json
import sys
from pathlib import Path

import trimesh


def main():
    if len(sys.argv) < 2:
        print("Usage: python tests/test_mesh_stats.py out_dir/")
        sys.exit(2)
    out_dir = Path(sys.argv[1])
    stats_path = out_dir / "stats.json"
    obj_path = out_dir / "model.obj"

    if not stats_path.exists() or not obj_path.exists():
        print("Missing outputs. Run predict.py first.")
        sys.exit(2)

    with open(stats_path) as f:
        stats = json.load(f)
    print("Stats:", stats)

    mesh = trimesh.load_mesh(obj_path)
    print("Loaded OBJ:", mesh.vertices.shape, mesh.faces.shape)

    # Basic checks
    assert mesh.vertices.shape[0] == stats["vertices"]
    assert mesh.faces.shape[0] == stats["faces"]
    print("Verification OK.")


if __name__ == "__main__":
    main()
