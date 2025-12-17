#!/usr/bin/env python3
"""
Flask API server for image-to-3D model generation.
Accepts image uploads, runs MiDaS depth estimation + 3D reconstruction, returns model files.
"""

import os
import sys
import tempfile
from pathlib import Path
from flask import Flask, request, jsonify, send_file
from werkzeug.utils import secure_filename
import subprocess

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024  # 50MB max

ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok", "service": "image-to-3d"})

@app.route('/generate', methods=['POST'])
def generate_3d():
    """
    Accept image upload, run predict.py, return URLs to download generated files.
    """
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({"error": "Empty filename"}), 400
    
    if not allowed_file(file.filename):
        return jsonify({"error": f"Invalid file type. Allowed: {ALLOWED_EXTENSIONS}"}), 400
    
    # Save uploaded file
    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = Path(tmpdir) / secure_filename(file.filename)
        output_dir = Path(tmpdir) / "out"
        output_dir.mkdir(exist_ok=True)
        
        file.save(str(input_path))
        print(f"📥 Received image: {input_path}")
        
        # Run predict.py
        script_dir = Path(__file__).parent
        predict_script = script_dir / "predict.py"
        
        try:
            result = subprocess.run(
                [sys.executable, str(predict_script), 
                 "--input", str(input_path),
                 "--output", str(output_dir)],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode != 0:
                print(f"❌ predict.py failed:\n{result.stderr}")
                return jsonify({"error": "3D generation failed", "details": result.stderr}), 500
            
            print(f"✅ 3D model generated successfully")
            print(result.stdout)
            
            # Read generated files
            obj_path = output_dir / "model.obj"
            glb_path = output_dir / "model.glb"
            texture_path = output_dir / "texture.png"
            stats_path = output_dir / "stats.json"
            
            # Check what files were generated
            generated_files = {}
            if obj_path.exists():
                generated_files['obj'] = obj_path.read_bytes()
            if glb_path.exists():
                generated_files['glb'] = glb_path.read_bytes()
            if texture_path.exists():
                generated_files['texture'] = texture_path.read_bytes()
            if stats_path.exists():
                import json
                generated_files['stats'] = json.loads(stats_path.read_text())
            
            # Return file info (in production, you'd save these and provide download URLs)
            return jsonify({
                "status": "success",
                "message": "3D model generated",
                "files": list(generated_files.keys()),
                "stats": generated_files.get('stats', {})
            })
            
        except subprocess.TimeoutExpired:
            return jsonify({"error": "Processing timeout (>2 minutes)"}), 500
        except Exception as e:
            print(f"❌ Error: {e}")
            return jsonify({"error": str(e)}), 500

@app.route('/generate-sync', methods=['POST'])
def generate_3d_sync():
    """
    Accept image upload, run predict.py, return the GLB file directly.
    """
    if 'image' not in request.files:
        return jsonify({"error": "No image file provided"}), 400
    
    file = request.files['image']
    if file.filename == '' or not allowed_file(file.filename):
        return jsonify({"error": "Invalid file"}), 400
    
    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = Path(tmpdir) / secure_filename(file.filename)
        output_dir = Path(tmpdir) / "out"
        output_dir.mkdir(exist_ok=True)
        
        file.save(str(input_path))
        
        script_dir = Path(__file__).parent
        predict_script = script_dir / "predict.py"
        
        try:
            result = subprocess.run(
                [sys.executable, str(predict_script), 
                 "--input", str(input_path),
                 "--output", str(output_dir)],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            if result.returncode != 0:
                return jsonify({"error": "Generation failed", "details": result.stderr}), 500
            
            # Return GLB file
            glb_path = output_dir / "model.glb"
            if glb_path.exists():
                return send_file(
                    str(glb_path),
                    mimetype='model/gltf-binary',
                    as_attachment=True,
                    download_name='model.glb'
                )
            else:
                return jsonify({"error": "GLB file not generated"}), 500
                
        except Exception as e:
            return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("🚀 Starting Image-to-3D API server...")
    print("📡 Endpoints:")
    print("  GET  /health - Health check")
    print("  POST /generate - Generate 3D (returns JSON with file info)")
    print("  POST /generate-sync - Generate 3D (returns GLB file directly)")
    app.run(host='0.0.0.0', port=5001, debug=True)
