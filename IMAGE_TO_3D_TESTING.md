# Image to 3D Testing Guide

## Test Environments

### Simulator
```
Device: iPhone 14 Pro
iOS: 17.2
Performance: Real-time depth estimation not available (CPU fallback)
Status: ✅ Can test UI flow, ⚠️ Slow inference
```

### Physical Device
```
Device: iPhone 14 Pro / iPhone 13 / iPhone 12
iOS: 16.0+
Performance: GPU-accelerated, production-ready
Status: ✅ Recommended for testing
```

## Unit Test Scenarios

### Test 1: App Launch
**Objective**: Verify app launches and initializes correctly

**Steps**:
1. Build and run on simulator or device
2. Wait for app to load
3. Observe initial screen

**Expected Results**:
```
✅ App launches without crash
✅ ContentView renders
✅ Default tab is "LiDAR Scan"
✅ Console shows clean logs
✅ No error dialogs
```

**Log Output**:
```
[App starts]
✅ Depth model loaded from CoreML (or synthetic fallback)
ContentView initialized
[App ready]
```

---

### Test 2: Tab Navigation
**Objective**: Verify tab switching works correctly

**Steps**:
1. Observe two tabs at bottom: "LiDAR Scan" and "Photo to 3D"
2. Tap "Photo to 3D" tab
3. Verify view changes
4. Tap "LiDAR Scan" tab
5. Verify view returns

**Expected Results**:
```
✅ "Photo to 3D" tab changes view to ImageTo3DView
✅ "LiDAR Scan" tab returns to original welcome view
✅ Tab icons are visible
✅ Selection state shows visually
```

---

### Test 3: Image Selection
**Objective**: Verify image picker works

**Steps**:
1. On "Photo to 3D" tab
2. Tap "Select Photo" button
3. Choose image from library (or camera)
4. Verify selection

**Expected Results**:
```
✅ Image picker opens
✅ Can select from library
✅ Selected image is captured
✅ Returns to processing screen
```

---

### Test 4: Processing - Normal Image
**Objective**: Verify complete pipeline with valid image

**Test Image**: Clear room photo, 1200x1600 px, well-lit

**Steps**:
1. Select valid room image
2. Wait for processing
3. Observe progress

**Expected Results**:
```
✅ Processing screen shows
✅ Progress bar starts at 0%
✅ Stage indicator updates:
   - "Validating image..."
   - "Estimating depth..."
   - "Generating mesh..."
   - "Finalizing model..."
✅ Total time: 40-70 seconds
✅ No UI freezing (responsive touch)
✅ Model appears in 3D viewer
```

**Console Output**:
```
📸 Processing image (1242x2208)
🎯 Running depth estimation...
✅ Depth estimation completed in 45.23s
📊 Generated 52341 points from depth map
✅ Mesh has 17447 triangles
✅ Applied Laplacian smoothing
✅ Computed vertex normals
✅ Model generation complete
```

---

### Test 5: 3D Viewer Controls
**Objective**: Verify SceneKit viewer is interactive

**Steps**:
1. After model loads in viewer
2. Touch and drag to rotate
3. Two-finger pinch to zoom
4. Observe shading and lighting

**Expected Results**:
```
✅ Model rotates smoothly when dragging
✅ Pinch gesture zooms in/out
✅ Model has proper lighting and shading
✅ No flickering or visual artifacts
```

---

### Test 6: Scale Adjustment
**Objective**: Verify scale slider works

**Steps**:
1. In 3D viewer with loaded model
2. Drag scale slider to minimum (0.5x)
3. Observe model size change
4. Drag slider to maximum (3.0x)
5. Move to middle (1.5x)

**Expected Results**:
```
✅ Slider is responsive
✅ Model size changes immediately
✅ Scale value updates on-screen
✅ No lag or stutter
✅ All scale values (0.5-3.0) work
```

**Scale Display**:
```
Scale: 0.50×  (model appears 50% size)
Scale: 1.50×  (model appears 150% size)
Scale: 3.00×  (model appears 300% size)
```

---

### Test 7: Export USDZ
**Objective**: Verify USDZ export creates valid file

**Steps**:
1. With loaded model in viewer
2. Tap "Export USDZ" button
3. Wait for export to complete
4. Verify success dialog

**Expected Results**:
```
✅ Button shows "Exporting..." temporarily
✅ Success screen appears with filename
✅ File size: 100KB-1MB
✅ Share sheet opens
✅ Can share via AirDrop/Mail
```

**File Verification**:
```bash
ls ~/Library/Developer/CoreSimulator/Devices/[ID]/data/Containers/Data/Library/Documents/
# Should show: image_3d_model_[TIMESTAMP].usdz
```

---

### Test 8: Export OBJ
**Objective**: Verify OBJ export creates valid file

**Steps**:
1. With loaded model
2. Tap "Export OBJ" button
3. Wait for completion
4. Check success dialog

**Expected Results**:
```
✅ Export completes
✅ File created: image_3d_model_[TIMESTAMP].obj
✅ File size: 2-5MB (text-based)
✅ Share works
```

**File Content Check**:
```
# image_3d_model_1702816200.obj
v 0.123456 0.234567 0.345678
v 0.234567 0.345678 0.456789
...
f 1 2 3
f 2 3 4
...
```

---

### Test 9: Export JSON
**Objective**: Verify metadata export

**Steps**:
1. Tap "Export Metadata" button
2. Wait for completion
3. Verify JSON validity

**Expected Results**:
```
✅ Export completes
✅ File created: image_3d_metadata_[TIMESTAMP].json
✅ File size: 500 bytes-1KB
```

**JSON Verification**:
```json
{
  "id": "abc-123...",
  "sourceType": "photo",
  "createdDate": "2025-12-17T10:30:00Z",
  "meshVertexCount": 52341,
  "scale": 1.5,
  "cameraModel": "iPhone14,3",
  "iosVersion": "17.2"
}
```

---

### Test 10: Reset Button
**Objective**: Verify session reset works

**Steps**:
1. With loaded model
2. Tap close button (X) or "Reset"
3. Verify return to selection screen

**Expected Results**:
```
✅ Returns to welcome screen
✅ State is cleared
✅ Can select new image
✅ Previous model is not shown
```

---

### Test 11: Error Handling - Blurry Image
**Objective**: Verify graceful error handling

**Test Image**: Blurry or low-contrast photo

**Steps**:
1. Select blurry image
2. Wait for processing
3. Observe error handling

**Expected Results**:
```
✅ Processing starts normally
✅ Completes but with lower quality
   OR shows error alert
✅ Alert message is clear
✅ "Dismiss" button returns to selection
✅ Can try another image
```

---

### Test 12: No Regression - LiDAR Scanning
**Objective**: Verify existing scanning feature still works

**Steps**:
1. Return to "LiDAR Scan" tab
2. Tap "Start Scan"
3. Grant permissions if needed
4. Move device around room
5. Tap "Stop Scan"
6. Observe results

**Expected Results**:
```
✅ Scanning works as before
✅ Results display normally
✅ All measurements are accurate
✅ No performance degradation
```

---

### Test 13: No Regression - Existing Exports
**Objective**: Verify LiDAR exports still work

**Steps**:
1. Complete LiDAR scan
2. Tap "Export JSON"
3. Verify export works
4. Tap "Export USDZ" 
5. Verify export works
6. Tap "Export Floor Plan"
7. Verify export works

**Expected Results**:
```
✅ JSON export works
✅ USDZ export works
✅ Floor Plan export works
✅ No new errors
✅ File sizes are normal
```

---

### Test 14: Memory Management (Long Session)
**Objective**: Verify no memory leaks during extended use

**Device**: iPhone 12 (2GB available RAM)

**Steps**:
1. Open "Photo to 3D" tab
2. Select and process 3-4 different images (one after another)
3. Export each as USDZ
4. Reset between sessions
5. Monitor Xcode memory gauge

**Expected Results**:
```
✅ Peak memory per image: ~15MB
✅ Returns to ~8MB baseline after reset
✅ No continuous memory growth
✅ No memory warnings
✅ App remains responsive
```

**Xcode Monitoring**:
```
Memory Gauge in Xcode Debug Navigator:
- Start: ~8MB
- Image 1 processing: 20MB
- After reset: ~8MB
- Image 2 processing: 20MB
- After reset: ~8MB
✅ Pattern repeats without growth
```

---

### Test 15: Performance on iPhone 12
**Objective**: Verify acceptable performance on older device

**Device**: iPhone 12 (A14 Bionic)

**Steps**:
1. Process typical room image
2. Record total time
3. Measure peak memory
4. Check thermal state

**Expected Results**:
```
✅ Processing completes in 60-90 seconds
✅ Peak memory: 18-25MB
✅ No throttling warnings
✅ Device does not get excessively hot
✅ Model quality is acceptable
```

---

## Integration Test Cases

### Integration Test 1: Full Workflow
**Objective**: Complete end-to-end user journey

**Steps**:
1. Launch app
2. Navigate to "Photo to 3D"
3. Select room image
4. Wait for processing
5. View 3D model
6. Adjust scale (1.0x → 2.0x → 1.5x)
7. Export as USDZ
8. Share file
9. Return to "LiDAR Scan"
10. Verify ready state

**Expected Results**:
```
✅ All steps complete without errors
✅ No crashes or warnings
✅ Exports are valid files
✅ Can switch back to scan mode
```

---

### Integration Test 2: Concurrent Operations
**Objective**: Verify app stability with rapid interactions

**Steps**:
1. Start processing image
2. While processing:
   - Adjust scale slider rapidly
   - Tap different buttons
   - Switch tabs back/forth
3. Wait for completion

**Expected Results**:
```
✅ Processing continues uninterrupted
✅ Slider adjustments queue properly
✅ No crashes from concurrent operations
✅ Final model is valid
```

---

## Test Data

### Sample Images (Recommended)
```
1. Indoor room (well-lit)
   - Size: 1200x1600
   - Format: JPEG
   - Location: Center of room, facing corner
   - Quality: Clear, no blur

2. Kitchen scene (varied depth)
   - Size: 1200x1600
   - Appliances, counters, walls visible

3. Living room (large space)
   - Size: 1200x1600
   - Multiple depth layers (near/far)
```

### Test Data Sets
| Image | Lighting | Complexity | Expected Time |
|-------|----------|-----------|----------------|
| Room 1 | Good | Low | 40s |
| Room 2 | Mixed | Medium | 55s |
| Room 3 | Poor | High | 65s |
| Blurry | Poor | Low | 60s (may fail) |

---

## Regression Testing

### Before Publishing Update
```
☑ Scan feature works
☑ Floor plan generation works
☑ Existing exports work
☑ Navigation unchanged
☑ Launch time not increased
☑ Memory usage acceptable
```

### Post-Publication Monitoring
```
☑ Monitor crash logs (Xcode Organizer)
☑ Track performance metrics (MetricKit)
☑ Gather user feedback
☑ Test new model versions
```

---

## Test Results Template

```
Test Date: December 17, 2025
Device: iPhone 14 Pro
iOS: 17.2
Build: RoomScanner v2.0.0 (Debug)

Test Name                    | Status | Notes
─────────────────────────────|────────|──────────────────
1. App Launch                | ✅     | Clean startup
2. Tab Navigation            | ✅     | Both tabs working
3. Image Selection           | ✅     | Picker responsive
4. Processing - Normal       | ✅     | 45s total
5. 3D Viewer Controls        | ✅     | Rotate/zoom smooth
6. Scale Adjustment          | ✅     | Slider responsive
7. Export USDZ               | ✅     | 500KB file
8. Export OBJ                | ✅     | 2.3MB file
9. Export JSON               | ✅     | 800 bytes
10. Reset Button             | ✅     | Returns to selection
11. Error Handling           | ✅     | Shows alert
12. LiDAR Scan No Regression | ✅     | Works normally
13. Existing Exports         | ✅     | JSON/USDZ/Floor plan
14. Memory Management        | ✅     | No leaks detected
15. iPhone 12 Performance    | ✅     | 75s, acceptable

Overall Status: ✅ PASS

Issues Found: None
Recommendations: Ready for release
```

---

## Known Issues & Workarounds

| Issue | Severity | Workaround |
|-------|----------|-----------|
| Slow inference on iPhone 12 | Low | Use smaller depth model (MiDaS-tiny) |
| OBJ files are large (text) | Low | Normal for wavefront format |
| Depth ambiguity in flat scenes | Medium | Adjust scale slider manually |
| No texture on mesh | Low | Future enhancement |

---

## Success Criteria

### For Release
- ✅ All 15 tests pass on iPhone 14 Pro
- ✅ All 15 tests pass on iPhone 13
- ✅ All 15 tests pass on iPhone 12
- ✅ No crashes or memory leaks
- ✅ Processing time acceptable
- ✅ Exports are valid
- ✅ UI is responsive
- ✅ No regressions to scanning

### For Production
- ✅ User feedback positive
- ✅ Crash rate < 0.1%
- ✅ Performance metrics stable
- ✅ Support requests < 5/month

---

**Document Version**: 1.0
**Status**: Ready for testing
**Last Updated**: December 2025
