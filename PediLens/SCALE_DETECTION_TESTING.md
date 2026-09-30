# Scale Detection Testing Guide

## Status
Scale detection service implemented. Currently fixing compilation errors from API migration.

## What's Implemented

### Core Components ✅
1. **CalibrationType.swift** - Calibration type definitions
2. **MeasurementCalibration.swift** - Enhanced calibration model
3. **ScaleDetectionService.swift** - Reference scale detection
4. **UncalibratedMeasurementWarning.swift** - Updated for new API

### Detection Capabilities
- Credit card detection (85.6mm × 53.98mm)
- US quarter detection (24.26mm diameter)
- Calibration card detection (QR code based)

## Migration Status

### Files Updated ✅
- `CalibrationType.swift` - Created
- `MeasurementCalibration.swift` - Enhanced with new types
- `ScaleDetectionService.swift` - Created
- `UncalibratedMeasurementWarning.swift` - Updated
- `Measurement+Extensions.swift` - Updated

### Files Needing Update ⏳
The following files still use the old `referenceObject` parameter API:
- `ContentView.swift` - 3 instances
- `MeasurementManager.swift` - createCalibration method
- `AccessibilityHelpers.swift` - announceCalibrationSet
- Test files (can be updated later)

## Quick Fix for Testing

To get the app building quickly for testing, we can:

1. Update `MeasurementCalibration` to support both old and new initialization
2. Add a legacy initializer that converts old API to new API
3. Update the key files (ContentView, MeasurementManager)

## Testing Plan

Once building:

### 1. Credit Card Detection
- Place credit card in frame with wound
- Take photo
- Check console for detection logs
- Verify calibration is applied

### 2. US Quarter Detection  
- Place quarter in frame
- Take photo
- Check detection and calibration

### 3. No Scale (Fallback)
- Take photo without any reference
- Should use estimated calibration
- Should show warning

## Expected Console Output

```
🔍 Detecting reference scale in image...
✅ Detected credit card
Calibration: Reference Scale (Credit Card)
Accuracy: Medium accuracy (±2-5mm)
Pixels per cm: XX.XX
```

## Next Steps

1. Fix remaining compilation errors
2. Build and run app
3. Test credit card detection
4. Test quarter detection
5. Verify measurements improve
6. Then implement LiDAR support

## Testing Checklist

- [ ] App builds successfully
- [ ] Credit card detected in image
- [ ] Quarter detected in image
- [ ] Calibration applied to measurements
- [ ] Accuracy indicator shows correct level
- [ ] Measurements more accurate than before
- [ ] Fallback to estimated works
- [ ] Warning shown for uncalibrated
