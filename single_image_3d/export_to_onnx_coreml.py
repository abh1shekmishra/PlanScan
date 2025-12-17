#!/usr/bin/env python3
"""
Export MiDaS to ONNX and optionally to CoreML (free and offline).

Examples:
  python export_to_onnx_coreml.py --onnx midas.onnx
  python export_to_onnx_coreml.py --onnx midas.onnx --mlmodel MiDaS.mlmodel

Notes:
- Uses torch.hub to fetch MiDaS DPT_Large (stable) by default.
- ONNX opset 12 works for CoreML conversion in most environments.
- CoreML conversion requires `pip install coremltools onnx`.
"""

import argparse
import sys


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="DPT_Large", choices=["DPT_Large", "DPT_Hybrid", "MiDaS_small"], help="MiDaS variant")
    ap.add_argument("--onnx", required=True, help="Output ONNX path")
    ap.add_argument("--mlmodel", help="Optional CoreML .mlmodel output path")
    ap.add_argument("--height", type=int, default=384, help="Input height")
    ap.add_argument("--width", type=int, default=384, help="Input width")
    return ap.parse_args()


def export_onnx(model_name: str, h: int, w: int, onnx_path: str):
    import torch
    print(f"Loading MiDaS model: {model_name}")
    model = torch.hub.load("intel-isl/MiDaS", model_name)
    model.eval()
    dummy = torch.randn(1, 3, h, w)
    print(f"Exporting ONNX → {onnx_path}")
    torch.onnx.export(
        model,
        dummy,
        onnx_path,
        input_names=["input"],
        output_names=["depth"],
        opset_version=12,
        dynamic_axes={"input": {0: "N"}, "depth": {0: "N"}},
    )


def export_coreml_from_torch(model_name: str, h: int, w: int, mlmodel_path: str):
    print("Converting PyTorch → CoreML (no ONNX)")
    import torch
    import coremltools as ct
    model = torch.hub.load("intel-isl/MiDaS", model_name)
    model.eval()
    example_input = torch.randn(1, 3, h, w)
    traced = torch.jit.trace(model, example_input)
    mlmodel = ct.convert(traced, inputs=[ct.TensorType(name="input", shape=example_input.shape)])
    mlmodel.save(mlmodel_path)
    print(f"Saved CoreML model → {mlmodel_path}")


def main():
    args = parse_args()
    export_onnx(args.model, args.height, args.width, args.onnx)
    if args.mlmodel:
        export_coreml_from_torch(args.model, args.height, args.width, args.mlmodel)


if __name__ == "__main__":
    sys.exit(main())
