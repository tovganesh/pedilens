# Debugging Wound Detection - "No wound boundary found"

## Issue
The CoreML model loads successfully but always returns "No wound boundary found" for all images.

## Changes Made
Added comprehensive logging throughout the detection pipeline to identify where the issue occurs.

## Console Logs to Check

### 1. Model Loading (App Launch)
Look for:
```
✅ CoreML wound detection model loaded successfully
   Model version: 1.0
   Model path: WoundSegmentation.mlmodelc
```

### 2. Detection Start
When you tap "Detect Wound", look for:
```
🤖 Using CoreML model for wound detection
🔮 Performing Vision CoreML request...
   Image size: 256x256
   Crop/scale option: scaleFill
```

### 3. Vision Results
Check what type of results the model returns:
```
📦 Received X result(s) from Vision
   Result 0: <ResultType>
✅ Processing VNCoreMLFeatureValueObservation
   Found MultiArray output
```

### 4. MultiArray Shape
Critical - this shows the model output format:
```
📊 MultiArray shape: [1, 256, 256, 1]
📐 Interpreted dimensions: 256x256
```

### 5. Wound Pixel Detection
This shows if the model is detecting any wound pixels:
```
🎯 Wound pixels: 1234/65536 (1.9%)
```

**IMPORTANT**: If this shows 0 wound pixels, the model is not detecting anything!

### 6. Contour Extraction
```
🔍 Extracting contours from 256x256 mask
   Found contour with 45 points
✅ Extracted 1 contours
```

### 7. Final Result
```
✅ CoreML detection complete:
   Points detected: 45
   Confidence: 75.00%
   Bounding box: (50, 60, 120, 110)
```

## Common Issues

### Issue 1: Zero Wound Pixels
**Symptom**: `🎯 Wound pixels: 0/65536 (0.0%)`

**Possible Causes**:
1. Model output threshold too high (currently 0.5)
2. Model not trained properly
3. Input image preprocessing mismatch
4. Model expects different input format

**Solutions**:
- Lower threshold from 0.5 to 0.3 in `convertMultiArrayToMask`
- Check if model needs different normalization
- Verify training data preprocessing matches inference

### Issue 2: Wrong MultiArray Shape
**Symptom**: `📊 MultiArray shape: [unexpected values]`

**Possible Causes**:
- Model output format doesn't match expected shape
- Batch dimension handling incorrect

**Solutions**:
- Update shape parsing in `convertMultiArrayToMask`
- Check model output specification

### Issue 3: No Contours Found
**Symptom**: `✅ Extracted 0 contours`

**Possible Causes**:
- Wound pixels exist but not forming connected regions
- Boundary detection algorithm not finding edges

**Solutions**:
- Check mask visualization
- Adjust boundary detection sensitivity

### Issue 4: Low Confidence
**Symptom**: Detection succeeds but throws `lowConfidence` error

**Possible Causes**:
- Minimum confidence threshold too high (0.3)
- Contour quality metrics too strict

**Solutions**:
- Lower `minimumConfidence` from 0.3 to 0.2
- Adjust confidence calculation weights

## Testing Steps

1. **Run the app** and check console for model loading message
2. **Take/select an image** with a clear wound
3. **Tap "Detect Wound"** and watch console output
4. **Note where the pipeline stops**:
   - Before Vision request? → Model loading issue
   - After Vision request but 0 pixels? → Threshold/preprocessing issue
   - After pixels detected but no contours? → Contour extraction issue
   - After contours but error? → Confidence threshold issue

## Quick Fixes to Try

### Fix 1: Lower Detection Threshold
In `CoreMLWoundDetectionService.swift`, line ~220:
```swift
let isWound = value > 0.3 // Changed from 0.5
```

### Fix 2: Lower Confidence Threshold
In `CoreMLWoundDetectionService.swift`, line ~35:
```swift
private let minimumConfidence: Float = 0.2 // Changed from 0.3
```

### Fix 3: Check Model Output Range
Add logging to see actual values:
```swift
print("   Value range: min=\(minValue), max=\(maxValue), mean=\(meanValue)")
```

## Next Steps

Based on console output, we can:
1. Adjust thresholds if model is detecting but below threshold
2. Fix preprocessing if model output is all zeros
3. Retrain model if it's fundamentally not working
4. Use fallback detection if CoreML approach needs more work

## Model Information

- **Training Accuracy**: 83.44% Dice coefficient
- **Input**: 256x256 RGB image, normalized [0, 1]
- **Output**: 256x256 single channel, values [0, 1]
- **Threshold**: 0.5 for wound vs background
- **Format**: mlProgram (iOS 15+), FP16 precision
