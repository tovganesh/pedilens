# Action Plan - Fix Model Collapse

## Current Situation
Your training is showing model collapse:
- Dice coefficient stuck at 0.0001
- Model predicting all background pixels
- Training will waste 2-4 hours producing a useless model

## Immediate Actions

### Step 1: Stop Current Training
```bash
# Press Ctrl+C to stop the training
# Or close the terminal/Colab notebook
```

### Step 2: Verify Dataset Quality
```bash
cd PediLens/ml_training
python verify_data.py
```

**Expected output:**
```
✓ DATASET LOOKS GOOD - Ready to train!
```

**If you see errors:**
```
❌ DATASET HAS ISSUES - Training will likely fail
```

Then re-download the dataset:
```bash
bash download_recommended.sh
```

### Step 3: Clean Old Models
```bash
rm -rf models/
mkdir models
```

### Step 4: Restart Training with Fixed Script
```bash
python train_wound_model_efficient.py
```

## What Changed in the Fix

### 1. Lower Learning Rate
```python
0.001 → 0.0001  # 10x smaller, prevents collapse
```

### 2. More Aggressive Focal Loss
```python
alpha: 0.75 → 0.9   # 90% weight on wounds
gamma: 2.0 → 2.5    # Focus more on hard examples
```

### 3. Higher Dice Weight
```python
focal + 2.0 * dice → focal + 5.0 * dice
# Forces optimization for Dice coefficient
```

## What to Watch For

### Good Training (Fixed)
```
Epoch 1:  dice: 0.01-0.05
Epoch 5:  dice: 0.15-0.25   ← Should improve
Epoch 10: dice: 0.30-0.45   ← Getting better
Epoch 15: dice: 0.45-0.60   ← Good!
```

### Bad Training (Still Broken)
```
Epoch 1:  dice: 0.05
Epoch 5:  dice: 0.0001  ← Collapsed again
```

If still collapsed at epoch 5, **STOP** and check data quality.

## Troubleshooting

### If Model Still Collapses

1. **Verify data quality**:
```bash
python verify_data.py
```

2. **Check masks visually**:
```bash
# Open a few masks - should see white wound regions
open wound_data/masks/fusc_0001.png
open wound_data/masks/fusc_0010.png
open wound_data/masks/fusc_0100.png
```

3. **Try ultra-conservative settings**:

Edit `train_wound_model_efficient.py`:
```python
# Line 18: Even lower learning rate
CONFIG['learning_rate'] = 0.00005  # Was 0.0001

# Line 142: Even more aggressive focal loss
focal = focal_loss(y_true, y_pred, alpha=0.95, gamma=3.0)

# Line 148: Even higher dice weight
return focal + 10.0 * dice
```

### If Dataset Has Issues

Re-download the dataset:
```bash
cd PediLens/ml_training

# Remove old data
rm -rf wound_data/

# Download fresh copy
bash download_recommended.sh

# Verify it's good
python verify_data.py
```

Should see:
```
Images: 2208
Masks:  2208
Masks with wounds: 20/20
✓ DATASET LOOKS GOOD
```

## Timeline

- **Stop training**: 1 minute
- **Verify data**: 2 minutes
- **Clean and restart**: 1 minute
- **New training**: 2-4 hours
- **Total**: ~3 hours to working model

## Success Criteria

After restarting, by epoch 10 you should see:
- ✓ Dice coefficient > 0.3
- ✓ Dice coefficient increasing each epoch
- ✓ Validation dice similar to training dice

If you see this, let it run to completion!

## Quick Commands

```bash
# Stop training: Ctrl+C

# Verify data
python verify_data.py

# Clean and restart
rm -rf models/ && mkdir models
python train_wound_model_efficient.py

# Monitor progress (in another terminal)
tail -f training_output.log | grep "dice_coefficient"
```

## Expected Final Results

After ~2-4 hours:
```
Final Metrics:
  Training Dice: 0.55-0.70
  Validation Dice: 0.50-0.65

✓ CoreML model saved to ./models/WoundSegmentation.mlmodel
```

Then copy to iOS:
```bash
cp models/WoundSegmentation.mlmodel ../PediLens/PediLens/Resources/
```

## Summary

1. **Stop** current training (it's broken)
2. **Verify** dataset quality
3. **Clean** old models
4. **Restart** with fixed script
5. **Watch** for Dice > 0.3 by epoch 10
6. **Wait** for completion (~3 hours)
7. **Copy** model to iOS project

The fixes are already in the script - just restart!
