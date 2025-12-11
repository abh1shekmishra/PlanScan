# Floor Plan Export Feature

## Overview
The RoomScanner app now includes a complete **Floor Plan Export** feature that generates a 2D top-down view of scanned rooms with scale markings and dimension annotations.

## Features

### 1. **Floor Plan Generation** 
- Converts 3D room data to 2D top-down view
- Renders walls as filled rectangles
- Shows doors and windows with distinct visual markers
- Includes grid overlay for spatial reference
- Calculates proper scaling based on room dimensions

### 2. **Image Formats**
- **PNG**: Lossless format for high-quality export (recommended for printing)
- **JPEG**: Compressed format for email and sharing

### 3. **Scale Markings**
- Scale bar (2-meter reference) at the bottom of the plan
- Room dimensions display (width × height in meters)
- Grid overlay for scale reference
- All measurements in metric units

### 4. **Visual Elements**
- **Walls**: Dark gray filled rectangles
- **Doors**: Blue solid lines
- **Windows**: Cyan dashed lines
- **Background**: White with light gray grid
- **Labels**: Scale bar with dimension text

## Files Added/Modified

### New File: `FloorPlanGenerator.swift`
The core floor plan generation engine that:
- Calculates room bounds from wall data
- Transforms world coordinates to 2D image coordinates
- Renders floor plan elements (walls, doors, windows)
- Adds scale markings and dimension text
- Saves images to the Documents folder

**Key Classes:**
- `FloorPlanGenerator` - Main class with static methods
- `FloorPlanGenerator.ImageFormat` - Enum for PNG/JPEG

**Key Methods:**
- `generateFloorPlan(from:size:)` - Creates floor plan image from room summary
- `saveFloorPlan(_:format:)` - Saves image to Documents directory
- Helper drawing functions for walls, openings, grid, and scale

### Modified: `ModelExporter.swift`
Added floor plan export functionality:
- `exportFloorPlan(roomSummary:format:)` - Exports room to floor plan image
- `FloorPlanFormat` enum with `.png` and `.jpeg` cases

### Modified: `RoomCaptureManager.swift`
Added manager-level floor plan export:
- `exportToFloorPlan(format:)` - Exports the most recent captured room
- Uses room summary data for floor plan generation
- Integrated with existing export system

### Modified: `ContentView.swift`
Added UI for floor plan export:
- **Two new export buttons** in the results screen:
  - "Export Floor Plan (PNG)" - Orange button
  - "Export Floor Plan (JPEG)" - Red button
- `exportFloorPlanPNG()` - Handler for PNG export
- `exportFloorPlanJPEG()` - Handler for JPEG export

## How to Use

### 1. Scan a Room
- Tap "Start Scan" on the welcome screen
- Scan the room using RoomPlan
- Tap "Stop & Process" to complete the scan

### 2. Export Floor Plan
From the results screen, you'll see two new export buttons:
- **"Export Floor Plan (PNG)"** - For high-quality prints
- **"Export Floor Plan (JPEG)"** - For email/sharing

### 3. Share or Save
After selecting format:
- A share sheet appears
- Save to Files, email, or other apps
- Floor plan images are stored in app's Documents folder

## File Storage
Floor plan images are saved to:
```
/Documents/FloorPlan_YYYY-MM-DD_HH-mm-ss.{png|jpg}
```

Example:
- `FloorPlan_2025-12-11_12-30-45.png`
- `FloorPlan_2025-12-11_12-30-45.jpg`

## Technical Details

### Coordinate System
- Uses 3D world coordinates from scanned room
- Top-down view (X-Z plane)
- Height (Y) coordinate ignored for 2D view
- Automatic centering and scaling

### Rendering
- Uses UIGraphics context for drawing
- Vector-based rendering (crisp at any size)
- CGAffineTransform for coordinate transformation
- UIBezierPath for shape drawing

### Scale Calculation
- Automatic bounds calculation from wall positions
- Maintains aspect ratio
- Adapts to any room size
- Proper padding around room

### Wall Rendering
- Uses wall thickness and length from captured data
- Rectangular representation of walls
- Proper rotation/orientation handling

## Example Output

A typical floor plan shows:
```
┌─────────────────────┐
│  ┌───────────┐      │  ← Windows (dashed)
│  │           │      │
│ D            │ Door │  ← Doors (solid line)
│  │           │      │
│  └───────────┘      │
└─────────────────────┘
 2m  ← Scale bar
 4.50m × 3.60m dimensions
```

## Device Compatibility
- iOS 16.0+ (aligned with RoomPlan framework)
- Requires LiDAR for room scanning
- iPhone 12 Pro or later
- Exports available immediately after scan

## Future Enhancements
Potential improvements for future versions:
- Furniture layout within floor plan
- Room name/labels
- Measurement annotations on walls
- Multiple room floor plans on single page
- SVG/PDF export formats
- Custom colors and styles
- Area calculations visualization

## Troubleshooting

### Floor plan not generated?
- Ensure room scan was successful
- Check that at least one wall was detected
- Verify room dimensions are reasonable (> 1m)

### Image quality issues?
- Use PNG format for best quality
- JPEG is better for email/web sharing
- Both formats support 1200x1200 resolution

### Can't find exported file?
- Check Files app → RoomScanner folder
- Floor plans save to app Documents directory
- Use share sheet to see file location
