# Fix CoreML Model - Vision Framework Compatibility

## Problem

The model was converted without proper `ImageType` input, causing this error:
```
⚠️ Failed to load CoreML model: The model does not have a valid input feature of type image
```

The Vision framework requires models to have an `ImageType` input, but the current model has a generic tensor input.

## Solution

Run the fix script to reconvert the model with proper input specification:

```bash
cd PediLens/ml_training
python fix_model_conversion.py
```

## What the Script Does

1. Loads the trained model (`WoundSegmentation.h5`)
2. Converts it with proper `ImageType` input:
   - Input: `image` (256x256 RGB, normalized to [0,1])
   - Output: Segmentation mask (256x256 MultiArray)
   - Format: ML Program (iOS 15+)
   - Precision: FP16 (smaller file size)
3. Saves as `WoundSegmentation_Fixed.mlpackage`

## After Running the Script

### 1. Copy Fixed Model
```bash
# Remove old models
rm -rf ../PediLens/PediLens/Resources/WoundSegmentation*.mlpackage

# Copy fixed model
cp -r models/WoundSegmentation_Fixed.mlpackage ../PediLens/PediLens/Resources/WoundSegmentation.mlpackage
```

### 2. Verify in Xcode
```bash
# Regenerate Xcode project
cd ../
xcodegen generate

# Build
xcodebuild -project PediLens.xcodeproj -scheme PediLens -sdk iphonesimulator build
```

### 3. Test
Run the app and check console:
```
✅ CoreML wound detection model loaded successfully
🤖 Using CoreML model for wound detection
```

## Expected Output

```
============================================================
Fixing CoreML Model Conversion
============================================================

1. Loading trained model...
   Model path: ./models/WoundSegmentation.h5
   ✓ Model loaded successfully
   Input shape: (None, 256, 256, 3)
   Output shape: (None, 256, 256, 1)

2. Converting to CoreML with proper ImageType input...
   ✓ Conversion successful

3. Saving fixed model...
   ✓ Model saved to ./models/WoundSegmentation_Fixed.mlpackage
   Model size: 38.45 MB

4. Verifying model...
   Model type: mlProgram
   Inputs: ['image']
   Outputs: ['Identity']
   Input 'image' type: imageType
   ✓ Image type detected - Vision framework compatible!
     Width: 256
     Height: 256
     Color space: RGB

============================================================
Conversion Complete!
============================================================
```

## Why This Fixes It

### Before (Broken)
```python
# Fallback conversion without input specification
ct.convert(model, source='tensorflow')
# Creates: Generic tensor input (incompatible with Vision)
```

### After (Fixed)
```python
# Explicit ImageType input
ct.convert(
    model,
    inputs=[ct.ImageType(
        name="image",
        shape=(1, 256, 256, 3),
        scale=1.0/255.0,
        color_layout=ct.colorlayout.RGB
    )]
)
# Creates: ImageType input (compatible with Vision)
```

## Troubleshooting

### If script fails with "No module named 'tensorflow'"
```bash
# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run script
python fix_model_conversion.py
```

### If model file not found
```bash
# Check if model exists
ls -la models/WoundSegmentation.h5

# If not, you need to train the model first
python train_wound_model_efficient.py
```

### If conversion still fails
Check coremltools version:
```bash
pip show coremltools
# Should be 7.0 or higher
```

Update if needed:
```bash
pip install --upgrade coremltools
```

## Quick Commands

```bash
# Full fix process
cd PediLens/ml_training
python fix_model_conversion.py
rm -rf ../PediLens/PediLens/Resources/WoundSegmentation*.mlpackage
cp -r models/WoundSegmentation_Fixed.mlpackage ../PediLens/PediLens/Resources/WoundSegmentation.mlpackage
cd ..
xcodegen generate
xcodebuild -project PediLens.xcodeproj -scheme PediLens -sdk iphonesimulator build
```

## Verification

After fixing, the app console should show:
```
📦 Found CoreML model at: .../WoundSegmentation.mlmodelc
✅ CoreML wound detection model loaded successfully
   Model version: 1.0
   Model path: WoundSegmentation.mlmodelc
```

And when detecting:
```
🤖 Using CoreML model for wound detection
✅ CoreML detection complete:
   Points detected: 52
   Confidence: 78.50%
```

---

**Status**: Ready to fix
**Time**: ~2 minutes
**Result**: Vision-compatible CoreML model
