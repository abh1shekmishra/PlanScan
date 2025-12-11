# RoomScanner

A complete iOS application for scanning and measuring indoor spaces using LiDAR technology. Built with Swift, SwiftUI, and Apple's RoomPlan framework.

## Features

- 🏠 **Room Scanning**: Full 3D room capture using LiDAR and RoomPlan (iOS 16+)
- 📏 **Precise Measurements**: 
  - Wall heights
  - Wall thickness
  - Distance between walls
  - Floor area calculations
- 🚪 **Opening Detection**: Automatic detection of doors and windows
- 📤 **Export Options**:
  - JSON format with detailed measurements
  - USDZ 3D models
  - **CSV data for spreadsheets**
  - **📐 2D Floor Plans** (PNG/JPEG with scale markings)
- 🔄 **Fallback Mode**: ARKit-based scanning for devices without full RoomPlan support

## Requirements

### Device Requirements
- **iPhone 12 Pro or later** (requires LiDAR sensor)
- **iOS 16.0 or later** (for RoomPlan API)
- Physical device (Simulator does not support LiDAR)

### Supported Devices
- iPhone 12 Pro / Pro Max
- iPhone 13 Pro / Pro Max
- iPhone 14 Pro / Pro Max
- iPhone 15 Pro / Pro Max
- iPad Pro (2020 and later with LiDAR)

## Installation & Setup

### 1. Open the Project in Xcode

```bash
cd /path/to/RoomScanner
open RoomScanner.xcodeproj
```

### 2. Configure Signing & Capabilities

1. Select the **RoomScanner** target in Xcode
2. Go to **Signing & Capabilities** tab
3. Select your **Team** from the dropdown
4. Ensure **Automatically manage signing** is checked
5. Verify the bundle identifier is unique

### 3. Set Deployment Target

1. Select the **RoomScanner** project in the navigator
2. Select the **RoomScanner** target
3. In **General** tab, set **Minimum Deployments** to **iOS 16.0**

### 4. Link Required Frameworks

The project requires the following frameworks (should be auto-linked):
- `RoomPlan.framework`
- `ARKit.framework`
- `RealityKit.framework`
- `Combine.framework`
- `SwiftUI.framework`

To verify:
1. Select the **RoomScanner** target
2. Go to **Build Phases** → **Link Binary With Libraries**
3. Ensure all frameworks are listed

### 5. Connect Device and Run

1. Connect your LiDAR-enabled iPhone via USB
2. Select your device from the device menu (top toolbar)
3. Click **Run** (⌘R) or press the Play button
4. Grant camera permissions when prompted

## Usage

### Scanning a Room

1. **Launch the app** on your LiDAR-enabled device
2. **Tap "Start Scan"** on the welcome screen
3. **Grant camera permission** if prompted
4. **Follow on-screen instructions**:
   - Move slowly around the room
   - Point camera at all walls, floor, and ceiling
   - Maintain good lighting
   - Keep device steady
5. **Tap "Stop Scan"** when complete
6. **Review measurements** in the results screen

### Exporting Data

#### JSON Export
- Contains detailed measurements, wall positions, and room metadata
- Tap **Export JSON** button in results screen
- Share via AirDrop, Files, or other apps

#### USDZ Export
- 3D model compatible with AR Quick Look
- Tap **Export USDZ** button
- View in Files app or share with others

#### CSV Export
- Tabular data suitable for spreadsheet analysis
- Programmatically accessible via `ModelExporter.exportCSV()`

#### Floor Plan Export ⭐ NEW
- 2D top-down view of scanned room with scale markings
- **PNG format**: High-quality, lossless (ideal for printing)
- **JPEG format**: Compressed, ideal for email/sharing
- Tap **Export Floor Plan (PNG)** or **Export Floor Plan (JPEG)** button
- Includes:
  - Walls rendered as rectangles with proper dimensions
  - Doors marked with solid blue lines
  - Windows marked with dashed cyan lines
  - Grid overlay for spatial reference
  - Scale bar showing 2-meter reference
  - Room dimensions displayed (width × height)
- Perfect for:
  - Interior design planning
  - Furniture layout visualization
  - Documentation and archival
  - Sharing with contractors
  - Printing floor plans to scale

### JSON Format Example

```json
{
  "project": "RoomScanner",
  "timestamp": "2025-12-10T15:00:00Z",
  "device": "iPhone14,3",
  "ios_version": "16.0",
  "rooms": [
    {
      "roomId": "room-abc123",
      "floorArea": 16.2,
      "walls": [
        {
          "id": "wall-1",
          "height": 2.7,
          "thickness": 0.15,
          "length": 4.5,
          "position": [0.0, 1.35, -2.25],
          "normal": [0.0, 0.0, 1.0]
        }
      ],
      "openings": [
        {
          "id": "door-1",
          "type": "door",
          "width": 0.9,
          "height": 2.1,
          "position": [-2.25, 1.05, 1.0]
        }
      ]
    }
  ]
}
```

## Architecture

### Project Structure

```
RoomScanner/
├── RoomScanner/
│   ├── RoomScannerApp.swift          # App entry point
│   ├── ContentView.swift             # Main navigation view
│   └── Assets.xcassets/              # Images and colors
├── Sources/
│   ├── Scanner/
│   │   ├── RoomCaptureManager.swift  # Main scanning logic
│   │   └── RoomCaptureDelegate.swift # RoomPlan callbacks
│   ├── UI/
│   │   └── ScanView.swift            # Scanning interface
│   └── Processing/
│       ├── MeshProcessor.swift       # ARKit mesh processing
│       ├── MeasurementHelper.swift   # Geometric calculations
│       └── ModelExporter.swift       # Export functionality
├── Supporting/
│   └── Info.plist                    # App configuration
└── RoomScannerTests/                 # Unit tests
```

### Key Components

#### RoomCaptureManager
- Manages scanning lifecycle
- Handles RoomPlan and ARKit fallback
- Publishes scan state and results
- Main interface for ContentView

#### RoomCaptureDelegate
- Implements RoomPlan delegate methods
- Processes captured room data
- Handles export to USDZ

#### MeshProcessor
- ARKit fallback plane detection
- RANSAC-based plane fitting
- Wall measurement extraction

#### MeasurementHelper
- Geometric utility functions
- Point-to-plane distance calculations
- SVD-based plane fitting

#### ModelExporter
- JSON, USDZ, and CSV export
- File management
- Share sheet integration

## Troubleshooting

### "RoomPlan Not Supported" Error

**Cause**: Device doesn't have LiDAR or iOS version < 16.0

**Solutions**:
- Verify device has LiDAR (iPhone 12 Pro or later)
- Update to iOS 16.0 or later
- App will use ARKit fallback mode automatically

### Camera Permission Denied

**Cause**: User denied camera access

**Solutions**:
1. Open **Settings** → **RoomScanner**
2. Enable **Camera** permission
3. Restart the app

### Poor Scan Quality

**Causes & Solutions**:
- **Low light**: Turn on more lights in the room
- **Moving too fast**: Move device slowly and steadily
- **Reflective surfaces**: Scan at an angle to minimize reflections
- **Small room**: Ensure you can back up enough to capture all walls
- **Texture-less walls**: Add temporary markers or objects for tracking

### Export Fails

**Cause**: Insufficient storage or permission issues

**Solutions**:
- Free up device storage
- Check Files app permissions
- Try exporting to different location

### App Crashes During Scan

**Causes & Solutions**:
- **Memory pressure**: Close other apps before scanning
- **Overheating**: Let device cool down
- **iOS bug**: Update to latest iOS version
- **Check Xcode console** for specific error messages

### Simulator Limitations

⚠️ **RoomScanner cannot run in Simulator** because:
- Simulator doesn't support LiDAR
- RoomPlan requires physical device
- ARKit features are limited

**Solution**: Always test on physical LiDAR-enabled device

## Development

### Building from Source

```bash
# Clone the repository (if applicable)
git clone <repository-url>
cd RoomScanner

# Open in Xcode
open RoomScanner.xcodeproj

# Build and run on device
# Select your device and press ⌘R
```

### Running Tests

```bash
# Run unit tests in Xcode
⌘U

# Or use command line
xcodebuild test -scheme RoomScanner -destination 'platform=iOS,name=Your Device'
```

### Debug Mode

The app includes DEBUG mode features:
- Sample data generation (no device needed for UI testing)
- Verbose logging to console
- Performance metrics

Enable by adding `-DDEBUG` to build settings or using Debug build configuration.

### Adding to Existing Project

To integrate RoomScanner functionality into your app:

1. Copy `Sources/` folder to your project
2. Add frameworks: RoomPlan, ARKit, RealityKit
3. Copy Info.plist camera permissions
4. Set deployment target to iOS 16.0+
5. Import and use `RoomCaptureManager`:

```swift
import SwiftUI

@main
struct YourApp: App {
    @StateObject private var scanManager = RoomCaptureManager()
    
    var body: some Scene {
        WindowGroup {
            YourContentView()
                .environmentObject(scanManager)
        }
    }
}
```

## API Reference

### RoomCaptureManager

```swift
class RoomCaptureManager: ObservableObject {
    @Published var isScanning: Bool
    @Published var capturedRooms: [CapturedRoomSummary]
    @Published var errorMessage: String?
    
    func startScan()
    func stopScan()
    func addMeshAnchor(_ anchor: ARMeshAnchor)
}
```

### ModelExporter

```swift
struct ModelExporter {
    static func exportJSON(rooms: [CapturedRoomSummary]) throws -> URL
    static func exportUSDZ(capturedRoom: CapturedRoom) async throws -> URL
    static func exportCSV(rooms: [CapturedRoomSummary]) throws -> URL
}
```

### MeasurementHelper

```swift
struct MeasurementHelper {
    static func distanceFromPointToPlane(_ point: simd_float3, _ plane: Plane) -> Float
    static func planeFromPoints(_ points: [simd_float3]) -> Plane?
    static func formatDistance(_ meters: Float) -> String
}
```

## Privacy & Permissions

RoomScanner requires the following permissions:

- **Camera**: Required for room scanning and LiDAR capture
- **Files (Optional)**: For saving and sharing exports

All scanning is performed **locally on device**. No data is sent to external servers.

## Performance Tips

- **Close background apps** before scanning for optimal performance
- **Scan in good lighting** for best results
- **Keep device cool** - extended scanning can cause heating
- **Use landscape orientation** for wider field of view
- **Scan methodically** - move slowly in a circular pattern

## Known Limitations

- Requires LiDAR hardware (not available on base iPhone models)
- RoomPlan requires iOS 16+ (older devices use ARKit fallback)
- Fallback mode doesn't detect openings (doors/windows)
- Large rooms (>50m²) may take longer to process
- Glass and reflective surfaces may cause tracking issues
- Outdoor spaces not supported

## Future Enhancements

Potential features for future versions:
- [ ] Multi-room scanning in single session
- [ ] Floor plan 2D view generation
- [ ] Furniture detection and measurement
- [ ] Cloud sync for scans
- [ ] Comparison between multiple scans
- [ ] CAD/DXF export format
- [ ] AR preview of measurements
- [ ] Room dimension annotations

## Support

For issues, questions, or contributions:
- Check **Troubleshooting** section above
- Review Xcode console logs for errors
- Ensure device meets requirements
- Verify permissions are granted

## License

[Specify your license here - MIT, Apache 2.0, etc.]

## Credits

Built with:
- **RoomPlan** - Apple's room scanning framework
- **ARKit** - Apple's augmented reality platform
- **SwiftUI** - Apple's declarative UI framework
- **RealityKit** - Apple's 3D rendering engine

## Version History

### Version 1.0 (December 2025)
- Initial release
- RoomPlan integration
- ARKit fallback mode
- JSON/USDZ/CSV export
- Measurement calculations
- SwiftUI interface

---

**Note**: This app requires a physical LiDAR-enabled device. Testing on Simulator is not supported for scanning features.
