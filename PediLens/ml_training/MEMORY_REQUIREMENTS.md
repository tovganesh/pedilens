# Memory Requirements and Optimization

## Problem: Colab Out of Memory

Google Colab free tier crashes when training with the full dataset (2,760 images) because:

### Memory Calculation

**Original approach (loads all data into RAM):**
```
2,760 images × 512×512×3 (RGB) × 4 bytes (float32) = ~4.1 GB
After 4x augmentation: 11,040 images = ~16.4 GB
Masks: ~16.4 GB
Model: ~2 GB
Total: ~35 GB RAM needed
```

**Colab Free Tier:** ~12-13 GB RAM available ❌

## Solutions

### Solution 1: Use Data Generators (Recommended) ⭐

Load data in batches instead of all at once.

**Memory usage:**
```
Batch size 8: ~32 MB per batch
Model: ~2 GB
Total: ~2.5 GB RAM needed ✅
```

See: `train_wound_model_efficient.py`

### Solution 2: Reduce Dataset Size

Use subset of images for training.

**Options:**
- 500 images: ~3 GB RAM (good results)
- 1000 images: ~6 GB RAM (better results)
- 2000 images: ~12 GB RAM (best results, may work on Colab)

See: `train_wound_model_subset.py`

### Solution 3: Reduce Image Size

Train with smaller images.

**Memory savings:**
- 512×512: 16.4 GB (original)
- 256×256: 4.1 GB (75% reduction)
- 128×128: 1 GB (94% reduction)

Trade-off: Lower resolution = less accurate detection

### Solution 4: Use Colab Pro

Upgrade to Colab Pro for more RAM.

**Colab Pro:**
- RAM: ~25 GB
- Better GPU (V100/A100)
- Cost: $10/month
- Can handle full dataset

## Recommended Approach

### For Free Colab

**Option A: Data Generator (Best)**
```python
# Uses ~2.5 GB RAM
# Full dataset
# Slightly slower training
```

**Option B: Subset + Smaller Images**
```python
CONFIG = {
    'image_size': (256, 256),  # Reduce from 512
    'max_samples': 1000,        # Use subset
    'batch_size': 4,            # Smaller batches
}
# Uses ~4 GB RAM
```

### For Colab Pro

```python
CONFIG = {
    'image_size': (512, 512),   # Full resolution
    'batch_size': 16,           # Larger batches
    # Use all 2,760 images
}
# Uses ~20 GB RAM
```

## Memory-Efficient Training Scripts

### 1. Efficient Version (Data Generator)
**File:** `train_wound_model_efficient.py`
- Uses TensorFlow data generators
- Loads batches on-the-fly
- ~2.5 GB RAM usage
- Works on free Colab ✅

### 2. Subset Version
**File:** `train_wound_model_subset.py`
- Loads subset of data
- Configurable sample count
- ~4-8 GB RAM usage
- Works on free Colab ✅

### 3. Original Version
**File:** `train_wound_model.py`
- Loads all data into RAM
- ~35 GB RAM usage
- Requires Colab Pro or local GPU ❌

## Quick Fix for Colab

Add this to the beginning of your Colab notebook:

```python
# Memory-efficient configuration
CONFIG = {
    'image_size': (256, 256),      # Reduced from 512
    'batch_size': 4,                # Reduced from 8
    'max_samples': 1000,            # Use subset
    'epochs': 50,
    'learning_rate': 0.001,
    'validation_split': 0.2,
}

# Or use data generator (see train_wound_model_efficient.py)
```

## Monitoring Memory Usage

### In Colab

```python
# Check RAM usage
!free -h

# Check GPU memory
!nvidia-smi

# Monitor during training
import psutil
print(f"RAM: {psutil.virtual_memory().percent}%")
```

### Warning Signs

- RAM usage > 90%: Likely to crash soon
- "ResourceExhaustedError": Out of memory
- Kernel crashes: Exceeded memory limit

## Performance Comparison

| Approach | RAM | Training Time | Accuracy | Colab Free |
|----------|-----|---------------|----------|------------|
| Original (all data) | 35 GB | 60 min | Best | ❌ |
| Data generator | 2.5 GB | 90 min | Best | ✅ |
| Subset (1000) | 6 GB | 30 min | Good | ✅ |
| Smaller images (256) | 4 GB | 45 min | Good | ✅ |
| Colab Pro | 25 GB | 45 min | Best | ✅ ($) |

## Recommendations by Use Case

### Quick Testing
```python
CONFIG = {
    'image_size': (128, 128),
    'max_samples': 200,
    'batch_size': 4,
    'epochs': 20,
}
# Time: 10 min, RAM: 1 GB
```

### Good Quality Model
```python
CONFIG = {
    'image_size': (256, 256),
    'max_samples': 1000,
    'batch_size': 4,
    'epochs': 50,
}
# Time: 30 min, RAM: 6 GB
```

### Best Quality (Free Colab)
```python
# Use data generator with full dataset
# See train_wound_model_efficient.py
# Time: 90 min, RAM: 2.5 GB
```

### Production Quality (Colab Pro)
```python
CONFIG = {
    'image_size': (512, 512),
    'batch_size': 16,
    'epochs': 50,
}
# Time: 45 min, RAM: 20 GB
```

## Next Steps

1. **Try efficient version first:**
   ```bash
   # Use the memory-efficient script
   python train_wound_model_efficient.py
   ```

2. **Or use subset:**
   ```bash
   # Train on 1000 images
   python train_wound_model_subset.py
   ```

3. **Monitor memory:**
   - Watch RAM usage in Colab
   - Reduce batch_size if needed
   - Reduce image_size if needed

4. **Upgrade if needed:**
   - Colab Pro for full dataset
   - Or use local GPU with more RAM

## Files

- `train_wound_model_efficient.py` - Memory-efficient version ⭐
- `train_wound_model_subset.py` - Subset training
- `train_wound_model.py` - Original (requires lots of RAM)
- `WoundDetection_Colab_Efficient.ipynb` - Updated Colab notebook
