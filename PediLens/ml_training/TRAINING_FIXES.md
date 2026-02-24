# Training Script Fixes - Focal Loss & CoreML Conversion

## Issues Fixed

### 1. Low Dice Coefficient (0.0001)
**Problem**: Model was predicting all background pixels despite 50x weighting because:
- Wounds are only ~1% of pixels (extreme class imbalance)
- Even with weighted BCE, the model learns that predicting all zeros gives 98.9% accuracy
- The loss function wasn't forcing the model to focus on the rare wound pixels

**Solution**: Replaced weighted BCE with Focal Loss
- Focal Loss automatically down-weights easy examples (background)
- Focuses training on hard examples (wound boundaries)
- Formula: `FL = -α(1-p)^γ * log(p)` where γ=2.0 focuses on hard examples
- Combined with Dice Loss (weighted 2:1) for better segmentation

**Expected Results**:
- Dice coefficient should improve to >0.3 within 10 epochs
- Target: >0.5 (good), >0.7 (excellent)
- Model will now actually predict wound regions instead of all background

### 2. CoreML Conversion Error
**Problem**: 
```
ValueError: Unable to determine the type of the model
```

**Root Causes**:
1. Model was loaded with `compile=True` which tried to recompile with custom loss functions
2. Missing `focal_loss` in custom_objects dict
3. No fallback conversion method

**Solution**:
1. Load model with `compile=False` - we only need architecture for conversion
2. Added `focal_loss` to custom_objects
3. Added proper error handling with fallback to TensorType
4. Added `convert_to="mlprogram"` for better iOS compatibility

## Changes Made

### Loss Function
```python
# OLD: Weighted BCE + Dice
weighted_bce = tf.where(y_true > 0.5, bce * 50.0, bce)
return weighted_bce + dice

# NEW: Focal Loss + Dice (2x weight on Dice)
focal = focal_loss(y_true, y_pred, alpha=0.75, gamma=2.0)
dice = dice_loss(y_true, y_pred)
return focal + 2.0 * dice
```

### Monitoring Metric
```python
# OLD: Monitor validation loss
monitor='val_loss', mode='min'

# NEW: Monitor Dice coefficient (what we actually care about)
monitor='val_dice_coefficient', mode='max'
```

### CoreML Conversion
```python
# Added compile=False and focal_loss to custom_objects
loaded_model = keras.models.load_model(
    model_path,
    custom_objects={
        'dice_loss': dice_loss,
        'dice_coefficient': dice_coefficient,
        'focal_loss': focal_loss,  # NEW
        'combined_loss': combined_loss
    },
    compile=False  # NEW - don't recompile
)
```

## What to Expect

### Training Progress
```
Epoch 1/50
- dice_coefficient: 0.0043 → Should start low
- val_dice_coefficient: 0.0001

Epoch 5/50
- dice_coefficient: 0.15-0.30 → Should improve quickly
- val_dice_coefficient: 0.10-0.25

Epoch 15/50
- dice_coefficient: 0.40-0.60 → Target range
- val_dice_coefficient: 0.35-0.55

Epoch 25+
- dice_coefficient: 0.50-0.75 → Good performance
- val_dice_coefficient: 0.45-0.70
```

### CoreML Conversion
```
8. Converting to CoreML:
   Attempting conversion with ImageType...
   ✓ Conversion successful with ImageType
   CoreML model saved to ./models/WoundSegmentation.mlmodel
   Model size: ~30-50 MB
```

## Running the Fixed Script

```bash
cd PediLens/ml_training
python train_wound_model_efficient.py
```

## If Dice Coefficient Still Low (<0.3 after 20 epochs)

This could indicate data quality issues:

1. **Check mask quality**:
```python
# Add this to verify masks are correct
import matplotlib.pyplot as plt
img = Image.open('wound_data/images/sample.jpg')
mask = Image.open('wound_data/masks/sample.png')
plt.subplot(1,2,1); plt.imshow(img)
plt.subplot(1,2,2); plt.imshow(mask, cmap='gray')
plt.show()
```

2. **Verify wound pixels exist**:
```bash
# Should show wound regions in white
ls wound_data/masks/*.png | head -5 | xargs -I {} open {}
```

3. **Try stronger focal loss**:
```python
# In combined_loss function, increase gamma
focal = focal_loss(y_true, y_pred, alpha=0.75, gamma=3.0)  # Was 2.0
```

## Understanding Focal Loss

Focal Loss solves the class imbalance problem by:

1. **Easy examples** (confident predictions): Down-weighted by `(1-p)^γ`
   - Background pixels (99% of image): Model is confident → loss ≈ 0
   
2. **Hard examples** (uncertain predictions): Full weight
   - Wound boundaries: Model is uncertain → loss is high
   
3. **Result**: Model focuses on learning wound regions, not background

This is much better than weighted BCE for extreme imbalance (1:99 ratio).

## Next Steps After Successful Training

1. **Verify model file exists**:
```bash
ls -lh models/WoundSegmentation.mlmodel
# Should be 30-50 MB
```

2. **Copy to Xcode project**:
```bash
cp models/WoundSegmentation.mlmodel ../PediLens/PediLens/Resources/
```

3. **Add to Xcode**:
   - Open PediLens.xcodeproj
   - Drag WoundSegmentation.mlmodel into Resources folder
   - Check "Copy items if needed"
   - Ensure it's added to PediLens target

4. **Test in app**:
   - Build and run
   - Take a photo of a wound
   - Tap "Auto-Detect Wound"
   - Should see boundary detection

## Troubleshooting

### "Conversion failed with both methods"
- Check TensorFlow version: `pip show tensorflow`
- Should be 2.12.0-2.16.x
- Try: `pip install tensorflow==2.15.0 coremltools==7.1`

### "Model predicts all zeros"
- Check training output - Dice should increase
- If stuck at 0.0001 after 20 epochs, data issue
- Verify masks are binary (0 or 255, not grayscale)

### "Out of memory during training"
- Reduce batch_size: `CONFIG['batch_size'] = 2`
- Reduce image_size: `CONFIG['image_size'] = (128, 128)`
- Use Google Colab with GPU runtime
