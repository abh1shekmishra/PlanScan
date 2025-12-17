# Measurement Display Test Guide

This guide helps you verify that all measurements in the PlanScan app are shown in both meters and feet (and m²/ft² for area).

## 1. Prerequisites
- Python backend running (for image-to-3D):
  ```bash
  cd single_image_3d
  source venv/bin/activate
  python server.py
  ```
- Build and run the iOS app on a device (not simulator).

## 2. Test Steps

### A. LiDAR/RoomPlan Scan
1. Tap **Start Scan** and scan a room.
2. Tap **Stop & Process**.
3. On the results screen, verify:
   - Floor area, wall height/length/thickness, and all dimensions show as `X m (Y ft)` or `X m² (Y ft²)`.
   - Floor plan image (View Floor Plan) shows scale and dimensions in both units.
   - Room summary cards and wall details show both units.

### B. Image-to-3D Model
1. Tap **Generate from Photo** and select a room image.
2. Wait for the 3D model to generate and display.
3. On the results screen, verify:
   - Width, length, height, and floor area show as `X m (Y ft)` or `X m² (Y ft²)`.

### C. Exported Files
- Export JSON, USDZ, or floor plan and check that measurement fields are in meters (feet are for display only).

## 3. Troubleshooting
- If you see only meters, update the app and try again.
- If the app crashes or fails to process, try a smaller scan or image.

## 4. Notes
- For very large scans, split into multiple sessions.
- All measurement displays should now be dual-unit everywhere in the UI.

---
If you find any screen missing dual-unit display, let the dev team know!
