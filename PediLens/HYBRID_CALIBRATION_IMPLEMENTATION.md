# Hybrid Calibration Implementation - In Progress

## Overview
Implementing hybrid measurement calibration system that uses:
1. LiDAR/ARKit depth (highest accuracy)
2. Reference scale detection (good accuracy)
3. Estimated calibration (fallback)

## Components Implemented

### 1. CalibrationType.swift ✅
Defines calibration types and accuracy levels:
- `CalibrationType`: lidar, referenceScale, estimated
- `MeasurementAccuracy`: high (±1-2mm), medium (±2-5mm), low (±10-20mm)
- `ReferenceObjectType`: ruler, usQuarter, creditCard, calibrationCard, custom
- `ReferenceScaleInfo`: Information about detected reference objects
- `LiDARDepthInfo`: Information about depth measurements

### 2. MeasurementCalibration.swift ✅
Enhanced calibration model:
- Added `calibrationType` field
- Added `accuracy` field
- Added `captureDistance` and `captureAngle`
- Factory methods: `fromLiDAR()`, `fromReferenceScale()`, `estimated()`
- Kept legacy types for backward compatibility

### 3. ScaleDetectionService.swift ✅
Reference scale detection using Vision framework:
- `detectReferenceScale()`: Main detection method
- `detectCreditCard()`: Detects credit cards (85.6mm × 53.98mm)
- `detectUSQuarter()`: Detects US quarters (24.26mm diameter)
- `detectCalibrationCard()`: Detects QR-coded calibration cards
- Rectangle and circle detection helpers

## Components To Implement

### 4. ARMeasurementManager.swift (Next)
LiDAR/ARKit integration:
```swift
class ARMeasurementManager {
    - Check device capabilities (LiDAR availability)
    - Start AR session with world tracking
    - Capture depth data from scene
    - Calculate distance to wound surface
    - Compute field of view at depth
    - Create LiDARDepthInfo
}
```

### 5. Update MeasurementManager.swift
Integrate calibration into measurements:
- Use calibration type for calculations
- Apply accuracy-based adjustments
- Show calibration status
- Validate calibration quality

### 6. Update CameraManager.swift
Add AR session support:
- Initialize AR session for LiDAR devices
- Capture depth alongside photos
- Provide depth info to measurement manager

### 7. CalibrationGuideView.swift
UI for calibration guidance:
- Show device capabilities
- Guide user to place reference scale
- Display calibration status
- Show accuracy indicator
- Allow manual calibration

### 8. Update ContentView.swift
Integrate calibration workflow:
- Check for LiDAR availability
- Prompt for reference scale if needed
- Show calibration status
- Display accuracy with measurements

## Calibration Workflow

```
┌─────────────────────────────────────┐
│ User starts wound capture           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Check device capabilities           │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
┌──────────────┐  ┌──────────────┐
│ Has LiDAR?   │  │ No LiDAR     │
│ Use AR depth │  │ Detect scale │
└──────┬───────┘  └──────┬───────┘
       │                 │
       │          ┌──────┴──────┐
       │          │             │
       │          ▼             ▼
       │    ┌──────────┐  ┌──────────┐
       │    │ Scale    │  │ No scale │
       │    │ found    │  │ Estimate │
       │    └────┬─────┘  └────┬─────┘
       │         │             │
       └─────────┴─────────────┘
                 │
                 ▼
       ┌──────────────────┐
       │ Capture image    │
       │ with calibration │
       └─────────┬────────┘
                 │
                 ▼
       ┌──────────────────┐
       │ Calculate        │
       │ measurements     │
       └──────────────────┘
```

## Device Support

### LiDAR-Enabled Devices
- iPhone 12 Pro, 12 Pro Max
- iPhone 13 Pro, 13 Pro Max
- iPhone 14 Pro, 14 Pro Max
- iPhone 15 Pro, 15 Pro Max
- iPad Pro 11" (2020+)
- iPad Pro 12.9" (2020+)

### All Devices
- Reference scale detection
- Estimated calibration

## Expected Accuracy

| Method | Accuracy | Use Case |
|--------|----------|----------|
| LiDAR | ±1-2mm | Pro devices, best accuracy |
| Credit Card | ±2-3mm | Universal, good accuracy |
| US Quarter | ±3-5mm | Universal, decent accuracy |
| Estimated | ±10-20mm | Fallback only |

## Testing Plan

### Scale Detection Testing
- [ ] Test credit card detection at various angles
- [ ] Test US quarter detection in different lighting
- [ ] Test with multiple reference objects in frame
- [ ] Validate pixel-to-mm calculations
- [ ] Test with partially visible objects

### LiDAR Testing (on Pro devices)
- [ ] Test depth accuracy at 10-50cm range
- [ ] Compare to physical ruler measurements
- [ ] Test with different wound sizes
- [ ] Validate field of view calculations
- [ ] Test in various lighting conditions

### Integration Testing
- [ ] Test fallback from LiDAR to scale
- [ ] Test fallback from scale to estimated
- [ ] Verify calibration persistence
- [ ] Test measurement accuracy improvements
- [ ] Validate UI shows correct calibration type

## Next Steps

1. ✅ Create calibration type models
2. ✅ Update MeasurementCalibration
3. ✅ Implement ScaleDetectionService
4. ⏳ Implement ARMeasurementManager
5. ⏳ Update MeasurementManager
6. ⏳ Update CameraManager
7. ⏳ Create CalibrationGuideView
8. ⏳ Update ContentView
9. ⏳ Add permissions and entitlements
10. ⏳ Test and validate accuracy

## Files Modified/Created

### Created
- `PediLens/PediLens/Models/CalibrationType.swift`
- `PediLens/PediLens/Services/ScaleDetectionService.swift`
- `PediLens/HYBRID_CALIBRATION_IMPLEMENTATION.md`

### Modified
- `PediLens/PediLens/Models/MeasurementCalibration.swift`

### To Create
- `PediLens/PediLens/Services/ARMeasurementManager.swift`
- `PediLens/PediLens/Views/CalibrationGuideView.swift`

### To Modify
- `PediLens/PediLens/Managers/MeasurementManager.swift`
- `PediLens/PediLens/Managers/CameraManager.swift`
- `PediLens/PediLens/Views/ContentView.swift`
- `PediLens/Info.plist` (AR permissions)
- `PediLens/PediLens.entitlements` (AR capabilities)
- `PediLens/project.yml` (ARKit framework)

## Notes

- Scale detection uses Vision framework (no ML training needed)
- LiDAR requires ARKit framework and permissions
- Calibration data stored with each capture session
- UI shows calibration type and accuracy
- Measurements include error margins based on calibration type
