# Measurement Accuracy Improvement Plan

## Goal
Achieve scale-level accuracy for wound measurements using:
1. iOS camera depth/LiDAR capabilities
2. Reference scale detection in images

## Current Measurement Approach

The app currently uses pixel-based measurements with estimated calibration:
- Measures wound in pixels
- Converts to cm using assumed pixel-to-cm ratio
- No real-world calibration
- Accuracy depends on camera distance and angle

## Approach 1: iOS Depth/LiDAR Integration

### Overview
Use ARKit and LiDAR scanner (iPhone 12 Pro+) to get real-world depth information and calculate accurate scale.

### Implementation Steps

#### 1. Add ARKit Framework
- Import ARKit and RealityKit
- Request camera and AR permissions
- Check device capabilities (LiDAR availability)

#### 2. Create AR Session Manager
```swift
class ARMeasurementManager {
    - Start AR session with world tracking
    - Capture depth data from scene
    - Calculate distance to wound surface
    - Compute pixels-to-meters ratio
    - Convert measurements to real-world units
}
```

#### 3. Depth-Based Calibration
- Use `ARFrame.sceneDepth` or `ARFrame.smoothedSceneDepth`
- Get depth at wound location
- Calculate field of view at that depth
- Derive accurate pixel-to-cm conversion

#### 4. Integration Points
- `CameraManager`: Add AR session support
- `MeasurementManager`: Use depth-based calibration
- `ContentView`: Show AR guidance overlay

### Advantages
- Most accurate method (±1-2mm accuracy)
- No external reference needed
- Works in any lighting
- Automatic calibration

### Disadvantages
- Only works on LiDAR-equipped devices (iPhone 12 Pro+, iPad Pro 2020+)
- Requires AR permissions
- Higher battery usage
- More complex implementation

### Device Support
- iPhone 12 Pro, 12 Pro Max
- iPhone 13 Pro, 13 Pro Max
- iPhone 14 Pro, 14 Pro Max
- iPhone 15 Pro, 15 Pro Max
- iPad Pro 11" (2020+), 12.9" (2020+)

## Approach 2: Reference Scale Detection

### Overview
Detect a ruler or reference object of known size in the image and use it to calibrate measurements.

### Implementation Steps

#### 1. Scale Detection Options

**Option A: Standard Ruler Detection**
- Train ML model to detect rulers
- Recognize measurement markings
- Calculate pixels-per-cm from ruler

**Option B: Reference Object Detection**
- Use common objects (coin, credit card, etc.)
- Known dimensions: US quarter = 24.26mm, credit card = 85.6mm × 53.98mm
- Detect object and use for calibration

**Option C: Printed Reference Scale**
- Provide printable calibration card
- QR code + measurement grid
- Detect card and extract scale

#### 2. Create Scale Detection Service
```swift
class ScaleDetectionService {
    - detectRuler(in image: UIImage) -> RulerInfo?
    - detectReferenceObject(in image: UIImage) -> ObjectInfo?
    - calculateCalibration(from scale: ScaleInfo) -> MeasurementCalibration
}
```

#### 3. Computer Vision Approach
- Use Vision framework for object detection
- Detect lines and markings
- OCR for reading measurements
- Calculate pixel-to-cm ratio

#### 4. Integration Points
- Run scale detection before wound detection
- Store calibration with capture session
- Use calibration for all measurements
- Show calibration confidence

### Advantages
- Works on all iOS devices
- No special hardware required
- Can use existing rulers/objects
- Offline processing

### Disadvantages
- Requires scale in image
- Accuracy depends on scale quality
- Affected by perspective/angle
- Additional user step

## Recommended Implementation Strategy

### Phase 1: Reference Scale Detection (All Devices)
1. Implement printed reference card detection
2. Add UI for "Place scale in image" guidance
3. Detect and validate scale
4. Calculate and store calibration
5. Apply to measurements

### Phase 2: LiDAR Integration (Pro Devices)
1. Detect device capabilities
2. Implement AR session for depth
3. Calculate depth-based calibration
4. Fallback to scale detection if unavailable
5. Show accuracy indicator

### Phase 3: Hybrid Approach
1. Use LiDAR when available (most accurate)
2. Fall back to scale detection (good accuracy)
3. Fall back to estimated calibration (current method)
4. Show calibration method and confidence

## Technical Implementation Details

### 1. Enhanced MeasurementCalibration Model

```swift
enum CalibrationType {
    case lidar(depth: Float)           // LiDAR-based, ±1-2mm
    case referenceScale(confidence: Float)  // Scale-based, ±2-5mm
    case estimated                      // Current method, ±10-20mm
}

struct MeasurementCalibration {
    var pixelsPerCentimeter: CGFloat
    var calibrationType: CalibrationType
    var accuracy: MeasurementAccuracy  // high, medium, low
    var captureDistance: Float?        // meters
    var captureAngle: Float?           // degrees from perpendicular
}
```

### 2. Calibration Workflow

```
1. User starts capture
2. Check device capabilities
   ├─ Has LiDAR? → Use AR depth
   └─ No LiDAR → Prompt for scale
3. Capture image with calibration
4. Validate calibration quality
5. Store with capture session
6. Use for all measurements
```

### 3. UI/UX Considerations

- Show calibration status indicator
- Guide user to optimal distance/angle
- Validate calibration before capture
- Allow manual calibration override
- Display accuracy estimate with measurements

## Expected Accuracy Improvements

| Method | Current | With Scale | With LiDAR |
|--------|---------|------------|------------|
| Length | ±20% | ±5% | ±2% |
| Width | ±20% | ±5% | ±2% |
| Area | ±40% | ±10% | ±4% |
| Perimeter | ±20% | ±5% | ±2% |

## Files to Modify

### New Files
1. `PediLens/PediLens/Services/ARMeasurementManager.swift`
2. `PediLens/PediLens/Services/ScaleDetectionService.swift`
3. `PediLens/PediLens/Views/CalibrationGuideView.swift`
4. `PediLens/PediLens/Models/CalibrationType.swift`

### Modified Files
1. `PediLens/PediLens/Models/MeasurementCalibration.swift` - Add calibration types
2. `PediLens/PediLens/Managers/MeasurementManager.swift` - Use enhanced calibration
3. `PediLens/PediLens/Managers/CameraManager.swift` - Add AR support
4. `PediLens/PediLens/Views/ContentView.swift` - Add calibration UI
5. `PediLens/PediLens.entitlements` - Add AR permissions

### Configuration
1. `Info.plist` - Add AR usage descriptions
2. `project.yml` - Add ARKit framework

## Testing Strategy

1. **Scale Detection Testing**
   - Test with various rulers (metric, imperial)
   - Test with reference objects (coins, cards)
   - Test at different angles and distances
   - Validate calibration accuracy

2. **LiDAR Testing**
   - Test on supported devices
   - Test at various distances (10cm - 50cm)
   - Test with different wound sizes
   - Compare to manual measurements

3. **Accuracy Validation**
   - Measure known-size objects
   - Compare to physical ruler measurements
   - Test in various lighting conditions
   - Validate across device types

## Next Steps

1. Decide on implementation priority (Scale vs LiDAR first)
2. Design calibration UI/UX flow
3. Implement scale detection service
4. Add calibration validation
5. Update measurement calculations
6. Test accuracy improvements
7. Document calibration process for users

## Resources

- [ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [LiDAR Scanner](https://developer.apple.com/augmented-reality/lidar/)
- [Depth API](https://developer.apple.com/documentation/arkit/ardepthdata)
