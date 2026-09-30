# CoreML Wound Detection - Now Working!

## Summary
Successfully integrated the trained CoreML wound detection model into PediLens. The model now detects wound boundaries automatically with ~50% confidence.

## Issues Fixed

### 1. Model Conversion Error
**Problem**: Model failed to load with "The model does not have a valid input feature of type image"

**Solution**: Fixed `fix_model_conversion.py` to use the correct input name `'input_layer'` matching the TensorFlow model's placeholder name.

### 2. Shape Parsing Bug
**Problem**: MultiArray shape `[1, 256, 256, 1]` was incorrectly parsed as `1x256` instead of `256x256`

**Solution**: Updated `convertMultiArrayToMask()` to properly handle different shape formats, specifically detecting channels-last format `[batch, height, width, channels]`.

### 3. Coordinate Scaling Issue
**Problem**: Detection was in wrong location - small box in upper left instead of on the wound

**Solution**: Changed scaling to use actual mask size (256x256) instead of resized image size. The Vision framework automatically resizes to model input size, so we must scale from 256x256 to original image dimensions.

### 4. Over-Simplification
**Problem**: Boundary was too simplified (84 points → 7 points), missing wound details

**Solution**: Reduced Douglas-Peucker tolerance from 2.0 to 0.5 pixels, preserving more boundary detail (84 points → ~20-30 points).

### 5. Spurious Points
**Problem**: Combining multiple contours included noise detections

**Solution**: Use only the largest contour, which represents the main wound boundary. Smaller contours are artifacts or noise.

## Current Performance

- **Detection Rate**: Successfully detects wounds in images
- **Confidence**: ~50% (appropriate for experimental feature)
- **Boundary Quality**: Captures main wound area with reasonable accuracy
- **Speed**: Fast inference on device

## Model Details

- **Architecture**: U-Net with Focal Loss + Dice Loss
- **Training Accuracy**: 83.44% validation Dice coefficient
- **Training Data**: 2,208 wound images from Kaggle
- **Input**: 256x256 RGB, normalized [0, 1]
- **Output**: 256x256 segmentation mask
- **Format**: mlProgram (iOS 15+), FP16 precision
- **Size**: 14.87 MB

## Code Changes

### Files Modified
1. `PediLens/ml_training/fix_model_conversion.py` - Fixed input name
2. `PediLens/PediLens/Services/CoreMLWoundDetectionService.swift` - Fixed shape parsing, scaling, and simplification
3. `PediLens/PediLens/Views/ContentView.swift` - Switched to CoreMLWoundDetectionService

### Key Improvements in CoreMLWoundDetectionService.swift
- Proper MultiArray shape interpretation for all common formats
- Correct coordinate scaling from mask (256x256) to original image size
- Value statistics logging (min/max/mean) for debugging
- Reduced simplification tolerance for better detail
- Comprehensive logging throughout detection pipeline

## Next Steps: Measurement Accuracy

The detection is working, but measurements need improvement. Two approaches:

### 1. iOS Camera Depth/LiDAR
- Use ARKit/LiDAR for depth information
- Calculate real-world scale from depth data
- Requires iPhone with LiDAR (iPhone 12 Pro+)
- Most accurate for supported devices

### 2. Reference Scale Detection
- Detect ruler/scale in image using ML
- Calculate pixels-to-cm ratio from known scale
- Works on all devices
- Requires scale to be in image

## Testing Notes

- Model detects ~2.7% of pixels as wound (1778/65536)
- Extracts 10 contours, largest has 84 points
- Simplifies to ~20-30 points with tolerance 0.5
- Scales correctly from 256x256 to original image dimensions
- Confidence calculation considers point count, smoothness, and size

## Known Limitations

1. **Partial Detection**: May not capture entire wound boundary perfectly
2. **Measurement Accuracy**: Currently uses pixel-based estimation without real-world calibration
3. **Experimental Status**: Marked as experimental feature with disclaimer
4. **Model Generalization**: Trained on specific wound dataset, may not work for all wound types

## User Guidance

The app shows:
- ⚠️ "Experimental Feature" warning
- Recommendation to use Manual Trace for verification
- Confidence percentage (typically 40-60%)
- Measurements (length, width, area, perimeter)

Users should verify auto-detection with manual trace for accurate clinical measurements.
