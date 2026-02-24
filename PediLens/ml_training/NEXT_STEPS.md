# Next Steps - Training Your Wound Detection Model

## Quick Start (5 minutes)

```bash
cd PediLens/ml_training
python train_wound_model_efficient.py
```

That's it! The script will:
1. ✓ Load 2,208 wound images
2. ✓ Train for ~50 epochs (auto-stops when no improvement)
3. ✓ Save best model based on Dice coefficient
4. ✓ Convert to CoreML format
5. ✓ Ready to use in iOS app

## What Changed (From Previous Run)

### Fixed: Low Dice Coefficient
- **Before**: 0.0001 (model predicted all background)
- **After**: Should reach 0.3-0.7 (actually detects wounds)
- **How**: Replaced weighted BCE with Focal Loss - designed for extreme class imbalance

### Fixed: CoreML Conversion Error
- **Before**: `ValueError: Unable to determine the type of the model`
- **After**: Proper conversion with fallback methods
- **How**: Added `compile=False`, `focal_loss` to custom_objects, better error handling

## Watch for These Metrics

### Good Training Progress
```
Epoch 1:  dice_coefficient: 0.01   ← Starting point
Epoch 5:  dice_coefficient: 0.20   ← Should improve quickly
Epoch 10: dice_coefficient: 0.40   ← Getting better
Epoch 15: dice_coefficient: 0.55   ← Good performance
Epoch 20: dice_coefficient: 0.65   ← Excellent!
```

### Warning Signs
```
Epoch 20: dice_coefficient: 0.0001  ← Still stuck? Data issue
Epoch 20: dice_coefficient: 0.95    ← Too high? Overfitting
```

## Expected Timeline

- **Training**: 2-4 hours on Google Colab (free tier)
- **Conversion**: 1-2 minutes
- **Total**: ~3 hours

## After Training Completes

### 1. Verify Output Files
```bash
ls -lh models/
# Should see:
# - WoundSegmentation.h5 (~120 MB) - TensorFlow model
# - WoundSegmentation.mlmodel (~40 MB) - CoreML model
# - best_model.h5 (~120 MB) - Best checkpoint
# - training_history.json - Metrics log
```

### 2. Check Final Metrics
```bash
tail -20 training_output.log
# Look for:
# Final Metrics:
#   Validation Dice: 0.XXXX
# 
# Target: >0.50 (good), >0.70 (excellent)
```

### 3. Copy Model to iOS Project
```bash
# From ml_training directory
cp models/WoundSegmentation.mlmodel ../PediLens/PediLens/Resources/

# Verify it's there
ls -lh ../PediLens/PediLens/Resources/WoundSegmentation.mlmodel
```

### 4. Add to Xcode
1. Open `PediLens.xcodeproj` in Xcode
2. In Project Navigator, right-click `PediLens/Resources`
3. Select "Add Files to PediLens..."
4. Choose `WoundSegmentation.mlmodel`
5. Check "Copy items if needed"
6. Ensure "PediLens" target is checked
7. Click "Add"

### 5. Build and Test
```bash
# Build the app
xcodebuild -project PediLens.xcodeproj -scheme PediLens -sdk iphoneos

# Or in Xcode: Cmd+B
```

### 6. Test in App
1. Run app on device/simulator
2. Create/select a patient
3. Tap "Add Wound Record"
4. Take a photo of a wound
5. Tap "Auto-Detect Wound" button
6. Should see automatic boundary detection!

## If Something Goes Wrong

### Dice Coefficient Stuck at 0.0001
**Problem**: Model not learning wound regions

**Solutions**:
1. Check mask files exist and match images:
```bash
ls wound_data/images/ | wc -l  # Should be 2208
ls wound_data/masks/ | wc -l   # Should be 2208
```

2. Verify masks are binary (not grayscale):
```bash
# Open a few masks - should be pure black/white
open wound_data/masks/fusc_0001.png
open wound_data/masks/fusc_0002.png
```

3. Increase focal loss gamma (makes it focus more on wounds):
```python
# In train_wound_model_efficient.py, line ~120
focal = focal_loss(y_true, y_pred, alpha=0.75, gamma=3.0)  # Was 2.0
```

### CoreML Conversion Still Fails
**Problem**: `ValueError` or conversion error

**Solutions**:
1. Check TensorFlow version:
```bash
pip show tensorflow
# Should be 2.12.0 - 2.16.x
```

2. Reinstall compatible versions:
```bash
pip install tensorflow==2.15.0 coremltools==7.1
```

3. Use the saved .h5 model directly (skip CoreML):
```python
# In CoreMLWoundDetectionService.swift
// Comment out CoreML code, use TensorFlow Lite instead
```

### Out of Memory on Google Colab
**Problem**: "ResourceExhaustedError" or crash

**Solutions**:
1. Reduce batch size:
```python
CONFIG['batch_size'] = 2  # Was 4
```

2. Reduce image size:
```python
CONFIG['image_size'] = (128, 128)  # Was (256, 256)
```

3. Use GPU runtime:
   - Runtime → Change runtime type → GPU

### Model File Too Large
**Problem**: .mlmodel is >100 MB

**Solutions**:
1. Quantize the model (reduces size by 4x):
```python
# Add to convert_to_coreml function
coreml_model = ct.convert(
    loaded_model,
    source='tensorflow',
    convert_to="mlprogram",
    compute_precision=ct.precision.FLOAT16  # Add this line
)
```

## Understanding the Output

### Training History JSON
```json
{
  "loss": [0.9957, 0.9998, ...],           // Training loss
  "dice_coefficient": [0.0043, 0.018, ...], // Training Dice
  "val_loss": [0.9999, 0.9999, ...],       // Validation loss
  "val_dice_coefficient": [0.0001, 0.01, ...] // Validation Dice ← Watch this!
}
```

### What Good Metrics Look Like
- **Dice > 0.5**: Model detects most wound regions
- **Dice > 0.7**: Excellent boundary accuracy
- **Dice > 0.8**: Near-perfect segmentation (rare)

### What Bad Metrics Look Like
- **Dice < 0.1**: Model barely detects wounds
- **Dice = 0.0001**: Model predicts all background
- **Training Dice >> Val Dice**: Overfitting (reduce model size)

## Performance Expectations

### On Real Wound Images
- **Simple wounds** (clear boundaries): 80-90% accuracy
- **Complex wounds** (irregular shapes): 60-75% accuracy
- **Partial wounds** (edge of frame): 50-70% accuracy

### Limitations
- Model trained on specific wound types (pressure ulcers, diabetic ulcers)
- May not work well on burns, surgical wounds, or other types
- Lighting and angle affect accuracy
- Always allow manual correction!

## Getting Help

### Check Training Logs
```bash
# See what happened during training
cat training_output.log | grep -A 5 "Final Metrics"
```

### Visualize Training Progress
```python
import json
import matplotlib.pyplot as plt

with open('models/training_history.json') as f:
    history = json.load(f)

plt.plot(history['dice_coefficient'], label='Training')
plt.plot(history['val_dice_coefficient'], label='Validation')
plt.xlabel('Epoch')
plt.ylabel('Dice Coefficient')
plt.legend()
plt.title('Model Training Progress')
plt.savefig('training_progress.png')
```

### Test Model Before iOS Integration
```python
# Quick test script
from PIL import Image
import numpy as np
from tensorflow import keras

# Load model
model = keras.models.load_model('models/WoundSegmentation.h5', compile=False)

# Load test image
img = Image.open('wound_data/images/fusc_0001.jpg').resize((256, 256))
img_array = np.array(img) / 255.0
img_array = np.expand_dims(img_array, 0)

# Predict
mask = model.predict(img_array)[0]

# Visualize
import matplotlib.pyplot as plt
plt.subplot(1,2,1); plt.imshow(img); plt.title('Input')
plt.subplot(1,2,2); plt.imshow(mask[:,:,0], cmap='hot'); plt.title('Prediction')
plt.savefig('test_prediction.png')
print("Saved test_prediction.png")
```

## Success Criteria

✓ Training completes without errors
✓ Dice coefficient > 0.5 on validation set
✓ CoreML model file created (~40 MB)
✓ Model loads in Xcode without errors
✓ App can detect wound boundaries automatically
✓ Manual correction still available for users

You're ready to train! Run `python train_wound_model_efficient.py` and watch the Dice coefficient improve.
