# Floor Plan Export UI Guide

## Results Screen Layout

After successfully scanning a room, the results screen displays:

```
┌─────────────────────────────────┐
│         Scan Complete           │
│    ✓ 1 room(s) captured         │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Room: room-00001               │
│  Floor Area: 16.20 m²           │
│                                 │
│  Walls (4)                      │
│  [Wall details...]              │
│                                 │
│  Openings (2)                   │
│  [Door and window details...]   │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│   EXPORT BUTTONS (NEW)          │
├─────────────────────────────────┤
│  📄 Export JSON                 │  ← Existing
├─────────────────────────────────┤
│  📦 Export USDZ                 │  ← Existing
├─────────────────────────────────┤
│  📐 Export Floor Plan (PNG)     │  ← NEW
├─────────────────────────────────┤
│  📐 Export Floor Plan (JPEG)    │  ← NEW
└─────────────────────────────────┘
```

## Button Colors & Icons

| Button | Color | Icon | Purpose |
|--------|-------|------|---------|
| Export JSON | Blue | doc.text | Structured data export |
| Export USDZ | Green | cube.box | 3D model export |
| Export Floor Plan (PNG) | Orange | square.grid.2x2 | 2D floor plan (lossless) |
| Export Floor Plan (JPEG) | Red | square.grid.2x2 | 2D floor plan (compressed) |

## Floor Plan Example Output

### What You'll See

When exported, the floor plan shows:

```
         FLOOR PLAN (PNG/JPEG)
    
    ┏━━━━━━━━━━━━━━━━━━━━━┓
    ┃                     ┃
    ┃  ┌───────────────┐  ┃
    ┃  │    WINDOW     │  ┃ ← Dashed line (cyan)
    ┃  └───────────────┘  ┃
    ┃         │DOOR│      ┃ ← Solid line (blue)
    ┃                     ┃
    ┗━━━━━━━━━━━━━━━━━━━━━┛
    
    Walls: Dark gray (filled)
    
    [2m scale bar]
    4.50m × 3.60m
```

### Components

1. **Walls** - Dark gray rectangles representing room boundaries
2. **Doors** - Blue solid lines at openings
3. **Windows** - Cyan dashed lines at window positions
4. **Grid** - Light gray reference grid for scale
5. **Scale Bar** - 2-meter reference measurement
6. **Dimensions** - Room width × length in meters
7. **Background** - White for printing

## Usage Flow

```
1. Complete Room Scan
   ↓
2. View Results Screen
   ↓
3. Choose Export Format:
   - PNG (Higher Quality) 
   - JPEG (Smaller File)
   ↓
4. Tap Button
   ↓
5. Share Sheet Appears
   ↓
6. Choose Destination:
   - Save to Files
   - Email
   - Messages
   - Print
   - Other Apps
```

## File Naming Convention

Floor plans are automatically named with timestamp:

```
FloorPlan_YYYY-MM-DD_HH-mm-ss.png
FloorPlan_YYYY-MM-DD_HH-mm-ss.jpg
```

Example:
- `FloorPlan_2025-12-11_14-30-22.png`
- `FloorPlan_2025-12-11_14-30-22.jpg`

## Feature Comparison

| Feature | JSON | USDZ | Floor Plan |
|---------|------|------|-----------|
| 3D Model | ❌ | ✅ | ❌ |
| 2D Floor Plan | ❌ | ❌ | ✅ |
| Editable Data | ✅ | ❌ | ❌ |
| Printable | ❌ | ❌ | ✅ |
| Scale Reference | ❌ | ✅ | ✅ |
| Dimensions | ✅ | ✅ | ✅ |
| File Size | Small | Large | Medium |
| Email Friendly | ✅ | ❌ | ✅ |

## Tips for Best Results

### For PNG Export (Recommended for Printing)
- Higher quality and clarity
- Larger file size
- No compression artifacts
- Best for professional documents

### For JPEG Export (Recommended for Sharing)
- Smaller file size
- Faster to email
- Good quality for most uses
- Some compression artifacts

### Printing Tips
1. Export as PNG for best quality
2. Use landscape orientation
3. Scale to fit paper size
4. Check scale bar before measuring on paper
5. Walls are to scale with marked dimensions

## Keyboard Shortcuts
None currently - tap buttons on screen to export

## Accessibility Features
- Clear button labels with icons
- Color-coded buttons for easy identification
- Share sheet built-in for standard iOS accessibility
- All text is readable and properly contrasted
