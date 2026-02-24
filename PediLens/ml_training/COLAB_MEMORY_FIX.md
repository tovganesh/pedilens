# Google Colab Memory Fix

## Problem

Google Colab free tier crashes with "Out of Memory" error when training with the full dataset (2,760 images).

**Why:**
- Dataset: 2,760 images × 4 (augmentation) = 11,040 images
- Memory needed: ~35 GB
- Colab free RAM: ~12 GB
- Result: Crash ❌

## Quick Fix

### Option 1: Use Memory-Efficient Script (Recommended) ⭐

Replace the data loading section in your Colab notebook with this:

```python
# Memory-Efficient Configuration
CONFIG = {
    'image_size': (256, 256),  # Reduced from 512
    'batch_size': 4,            # Small batches
    'epochs': 50,
    'learning_rate': 0.001,
    'validation_split': 0.2,
    'data_dir': './wound_data',
    'output_dir': './models',
    'model_name': 'WoundSegmentation'
}

# Use data generator instead of loading all images
def create_data_generator(data_dir, image_size, batch_size, subset='training'):
    images_dir = Path(data_dir) / 'images'
    masks_dir = Path(data_dir) / 'masks'
    image_files = sorted(list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')))
    
    # Split train/val
    split_idx = int(len(image_files) * 0.8)
    if subset == 'training':
        image_files = image_files[:split_idx]
    else:
        image_files = image_files[split_idx:]
    
    def generator():
        while True:
            np.random.shuffle(image_files)
            for i in range(0, len(image_files), batch_size):
                batch_files = image_files[i:i+batch_size]
                batch_images = []
                batch_masks = []
                
                for img_path in batch_files:
                    img = Image.open(img_path).convert('RGB')
                    img = img.resize(image_size)
                    img_array = np.array(img) / 255.0
                    batch_images.append(img_array)
                    
                    mask_path = masks_dir / img_path.name
                    if mask_path.exists():
                        mask = Image.open(mask_path).convert('L')
                        mask = mask.resize(image_size)
                        mask_array = np.array(mask) / 255.0
                        mask_array = np.expand_dims(mask_array, axis=-1)
                        batch_masks.append(mask_array)
                
                yield np.array(batch_images), np.array(batch_masks)
    
    return generator

# Create generators
train_gen = create_data_generator(CONFIG['data_dir'], CONFIG['image_size'], CONFIG['batch_size'], 'training')
val_gen = create_data_generator(CONFIG['data_dir'], CONFIG['image_size'], CONFIG['batch_size'], 'validation')

# Calculate steps
total_images = len(list((Path(CONFIG['data_dir']) / 'images').glob('*.jpg')))
train_size = int(total_images * 0.8)
val_size = total_images - train_size
steps_per_epoch = train_size // CONFIG['batch_size']
validation_steps = val_size // CONFIG['batch_size']

# Train with generator
history = model.fit(
    train_gen(),
    steps_per_epoch=steps_per_epoch,
    epochs=CONFIG['epochs'],
    validation_data=val_gen(),
    validation_steps=validation_steps,
    callbacks=callbacks
)
```

**Memory usage:** ~2.5 GB ✅

### Option 2: Use Smaller Images

```python
CONFIG = {
    'image_size': (256, 256),  # Instead of 512
    'batch_size': 4,
    'epochs': 50,
}
```

**Memory usage:** ~4 GB ✅

### Option 3: Use Subset of Data

```python
# Load only first 1000 images
image_files = image_files[:1000]
```

**Memory usage:** ~6 GB ✅

### Option 4: Upgrade to Colab Pro

- Cost: $10/month
- RAM: ~25 GB
- Better GPU
- Can handle full dataset

## Step-by-Step Fix for Existing Notebook

### 1. Check Current Memory

Add this cell at the top:

```python
!free -h
import psutil
mem = psutil.virtual_memory()
print(f"Available: {mem.available / (1024**3):.1f} GB")
print(f"Total: {mem.total / (1024**3):.1f} GB")
```

### 2. Modify Configuration

Change this:

```python
# OLD - Uses too much memory
CONFIG = {
    'image_size': (512, 512),
    'batch_size': 8,
}
```

To this:

```python
# NEW - Memory efficient
CONFIG = {
    'image_size': (256, 256),  # Smaller images
    'batch_size': 4,            # Smaller batches
}
```

### 3. Use Data Generator

Replace the data loading section with the generator code above.

### 4. Monitor Memory

Add this cell to monitor during training:

```python
import psutil
import time

def monitor_memory():
    while True:
        mem = psutil.virtual_memory()
        print(f"RAM: {mem.percent}% ({mem.used / (1024**3):.1f} GB / {mem.total / (1024**3):.1f} GB)")
        time.sleep(30)

# Run in background
import threading
thread = threading.Thread(target=monitor_memory, daemon=True)
thread.start()
```

## Complete Memory-Efficient Notebook

Use the new notebook: `WoundDetection_Colab_Efficient.ipynb`

Or use the Python script: `train_wound_model_efficient.py`

## Memory Usage Comparison

| Approach | RAM | Works on Free Colab |
|----------|-----|---------------------|
| Original (all data, 512×512) | 35 GB | ❌ |
| Data generator (512×512) | 3 GB | ✅ |
| Smaller images (256×256) | 4 GB | ✅ |
| Subset (1000 images) | 6 GB | ✅ |
| Data generator (256×256) | 2.5 GB | ✅ ⭐ |

## Expected Results

### With 256×256 Images
- Dice coefficient: 0.70-0.80 (70-80%)
- Good enough for testing
- Can upscale to 512×512 later

### With Data Generator (512×512)
- Dice coefficient: 0.75-0.85 (75-85%)
- Production quality
- Slightly slower training

## Troubleshooting

### Still Running Out of Memory?

1. **Reduce batch size further:**
   ```python
   CONFIG['batch_size'] = 2
   ```

2. **Use even smaller images:**
   ```python
   CONFIG['image_size'] = (128, 128)
   ```

3. **Disable augmentation:**
   ```python
   # Don't augment data
   # Just use original images
   ```

4. **Clear memory between runs:**
   ```python
   import gc
   gc.collect()
   tf.keras.backend.clear_session()
   ```

### Check If It's Working

```python
# This should show low memory usage
!free -h

# Should see ~2-4 GB used, not 12+ GB
```

## Recommended Settings for Free Colab

```python
CONFIG = {
    'image_size': (256, 256),   # Good balance
    'batch_size': 4,             # Safe for 12 GB RAM
    'epochs': 50,                # Enough for convergence
    'learning_rate': 0.001,
    'validation_split': 0.2,
    'use_data_generator': True,  # Essential!
}
```

This will:
- ✅ Work on free Colab
- ✅ Use ~2.5 GB RAM
- ✅ Train on full dataset
- ✅ Take ~60-90 minutes
- ✅ Produce good quality model

## Next Steps

1. Try the memory-efficient script: `train_wound_model_efficient.py`
2. Or update your Colab notebook with the fixes above
3. Monitor memory usage during training
4. If still having issues, reduce image size to 128×128

See `MEMORY_REQUIREMENTS.md` for detailed explanation.
