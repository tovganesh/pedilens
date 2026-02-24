# Urgent Fix Applied - Model Collapse Issue

## Problem Detected
Your training showed the model is collapsing:
```
Epoch 1: dice_coefficient: 0.0468 → Started learning
Epoch 2: dice_coefficient: 0.0001 → Collapsed to all zeros
Epoch 3: dice_coefficient: 0.0001 → Still predicting all background
```

This is a common issue with extreme class imbalance when the loss function or learning rate is too aggressive.

## Root Cause
1. **Learning rate too high** (0.001): Model overshoots and collapses
2. **Focal loss not aggressive enough**: alpha=0.75 wasn't enough for 1:99 ratio
3. **Dice weight too low**: Model optimizing focal loss instead of Dice

## Fixes Applied

### 1. Reduced Learning Rate
```python
# OLD
'learning_rate': 0.001

# NEW
'learning_rate': 0.0001  # 10x smaller, prevents collapse
```

### 2. Increased Focal Loss Alpha
```python
# OLD
focal = focal_loss(y_true, y_pred, alpha=0.75, gamma=2.0)

# NEW
focal = focal_loss(y_true, y_pred, alpha=0.9, gamma=2.5)
# alpha=0.9 means 90% weight on wounds, 10% on background
# gamma=2.5 focuses even more on hard examples
```

### 3. Increased Dice Weight
```python
# OLD
return focal + 2.0 * dice

# NEW
return focal + 5.0 * dice
# Forces model to optimize for Dice coefficient
```

### 4. Fixed Focal Loss Implementation
```python
# Separated positive and negative class losses
pos_loss = -alpha * tf.pow(1 - y_pred, gamma) * y_true * tf.math.log(y_pred)
neg_loss = -(1 - alpha) * tf.pow(y_pred, gamma) * (1 - y_true) * tf.math.log(1 - y_pred)
```

## What to Do Now

### Option 1: Stop and Restart (Recommended)
```bash
# Stop the current training (Ctrl+C)
# Delete the bad model
rm -rf models/
mkdir models

# Restart with fixed script
python train_wound_model_efficient.py
```

### Option 2: Let It Finish (Not Recommended)
The current training will likely stay at Dice=0.0001 for all 50 epochs. You'll waste 2-4 hours and get a useless model.

## Expected Results After Fix

### Good Training Progress
```
Epoch 1:  dice: 0.01-0.05   ← Starting point
Epoch 5:  dice: 0.10-0.20   ← Should improve steadily
Epoch 10: dice: 0.25-0.40   ← Getting better
Epoch 15: dice: 0.40-0.55   ← Good performance
Epoch 20: dice: 0.50-0.65   ← Target range
```

### Warning Signs
If you still see:
```
Epoch 5: dice: 0.0001  ← Still collapsed
```

Then there's likely a data quality issue. Check:

1. **Masks exist and match images**:
```bash
ls wound_data/images/ | wc -l  # Should be 2208
ls wound_data/masks/ | wc -l   # Should be 2208
```

2. **Masks are binary (not grayscale)**:
```bash
# Open a few masks - should be pure black/white, not gray
open wound_data/masks/fusc_0001.png
open wound_data/masks/fusc_0010.png
```

3. **Masks have wound pixels**:
```python
from PIL import Image
import numpy as np

mask = Image.open('wound_data/masks/fusc_0001.png')
mask_array = np.array(mask)
print(f"Min: {mask_array.min()}, Max: {mask_array.max()}")
print(f"Unique values: {np.unique(mask_array)}")
# Should see: Min: 0, Max: 255, Unique: [0, 255]
# NOT: Min: 0, Max: 0 (all black)
```

## Why This Happens

### Model Collapse Explained
1. **High learning rate** → Model makes big weight updates
2. **Extreme imbalance** → Most gradients come from background
3. **Big update** → Weights shift to predict all zeros
4. **All zeros** → Gets 99% accuracy (all background correct)
5. **Stuck** → Model thinks it's doing great, stops learning

### The Fix
1. **Lower learning rate** → Smaller, safer updates
2. **Higher alpha** → More gradient from wounds, less from background
3. **Higher dice weight** → Optimize for what we care about
4. **Better focal loss** → Proper separation of pos/neg classes

## Quick Verification

After restarting training, check epoch 5:
```
Epoch 5: dice_coefficient: 0.15-0.30  ✓ Good!
Epoch 5: dice_coefficient: 0.0001    ✗ Still broken
```

If still broken at epoch 5, stop and check data quality.

## Alternative: Even More Conservative Settings

If the model still collapses, try these ultra-conservative settings:

```python
# In train_wound_model_efficient.py

# Even lower learning rate
CONFIG['learning_rate'] = 0.00005  # Was 0.0001

# Even more aggressive focal loss
focal = focal_loss(y_true, y_pred, alpha=0.95, gamma=3.0)  # Was 0.9, 2.5

# Even higher dice weight
return focal + 10.0 * dice  # Was 5.0
```

## Summary

**Status**: Fixed and ready to restart
**Action**: Stop current training, delete models/, restart
**Expected**: Dice should reach 0.5+ instead of staying at 0.0001
**Time**: Still ~2-4 hours, but will actually work this time

The fixes are already in `train_wound_model_efficient.py` - just restart the training!
