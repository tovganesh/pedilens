# Wound Detection ML Training

This directory contains everything needed to train a CoreML model for wound boundary detection.

## 📊 Default Dataset

The recommended training dataset is:

**Wound Segmentation Images** by leoscode on Kaggle
- **Source:** https://www.kaggle.com/datasets/leoscode/wound-segmentation-images
- **Size:** 2,760 wound images with segmentation masks (697 MB)
- **License:** Check Kaggle dataset page for current license terms
- **Citation:** If you use this dataset, please acknowledge the original creator on Kaggle

This dataset is downloaded automatically when you run `./download_recommended.sh`.

### Dataset Acknowledgment

If you publish research or deploy models trained on this dataset, please:
1. Cite the original dataset creator (leoscode on Kaggle)
2. Include a link to the dataset: https://www.kaggle.com/datasets/leoscode/wound-segmentation-images
3. Review and comply with the dataset's license terms on Kaggle

---

## 🚀 Recommended: Google Colab (No Installation!)

**Start here:** `QUICK_START_COLAB.md`

1. Open https://colab.research.google.com/
2. Upload `WoundDetection_Colab.ipynb`
3. Enable GPU
4. Run all cells
5. Download trained model
6. Add to Xcode project

**Time:** 30-60 minutes | **Cost:** Free | **Difficulty:** Easy

---

## Alternative: Local Training

### 1. Setup Environment

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Setup Kaggle API

```bash
# Install Kaggle CLI
pip install kaggle

# Get API credentials
# 1. Go to https://www.kaggle.com/account
# 2. Scroll to API section
# 3. Click "Create New API Token"
# 4. Move kaggle.json to ~/.kaggle/

mkdir -p ~/.kaggle
mv ~/Downloads/kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json
```

### 3. Download Dataset

```bash
# Run download script
chmod +x download_kaggle_data.sh
./download_kaggle_data.sh

# Or manually download from Kaggle:
# - Search for "diabetic foot ulcer" or "wound segmentation"
# - Download and extract to wound_data/
```

### 4. Organize Data

Ensure your data follows this structure:

```
wound_data/
├── images/
│   ├── image001.jpg
│   ├── image002.jpg
│   └── ...
└── masks/
    ├── image001.png  (binary mask: white=wound, black=background)
    ├── image002.png
    └── ...
```

### 5. Train Model

```bash
python train_wound_model.py
```

This will:
- Load and augment the dataset
- Train a U-Net model for segmentation
- Save the best model
- Convert to CoreML format
- Output: `models/WoundSegmentation.mlmodel`

### 6. Integrate into PediLens

```bash
# Copy model to Xcode project
cp models/WoundSegmentation.mlmodel ../PediLens/Resources/

# In Xcode:
# 1. Add WoundSegmentation.mlmodel to project
# 2. Ensure it's added to app target
# 3. Build project (Xcode will compile .mlmodel to .mlmodelc)
```

### 7. Update Code

The app will automatically use the CoreML model if available. Update `WoundDetectionService.swift` to use `CoreMLWoundDetectionService`:

```swift
// In CaptureSessionDetailView or wherever detection is called
let detectionService = CoreMLWoundDetectionService()  // Instead of WoundDetectionService()
```

## Training Configuration

Edit `train_wound_model.py` to adjust:

```python
CONFIG = {
    'image_size': (512, 512),      # Input image size
    'batch_size': 8,                # Batch size (reduce if out of memory)
    'epochs': 50,                   # Training epochs
    'learning_rate': 0.001,         # Learning rate
    'validation_split': 0.2,        # Validation split ratio
    'data_dir': './wound_data',     # Data directory
    'output_dir': './models',       # Output directory
    'model_name': 'WoundSegmentation'
}
```

## Recommended Datasets

### Kaggle Datasets

1. **DFUC2020** - Diabetic Foot Ulcer Challenge
   - High-quality foot ulcer images with segmentation masks
   - ~5,000 images
   - Search: "dfuc2020" or "diabetic foot ulcer challenge"

2. **Chronic Wound Dataset**
   - Various wound types
   - Search: "chronic wound dataset"

3. **Foot Ulcer Segmentation**
   - Specific to foot wounds
   - Search: "foot ulcer segmentation"

### Public Medical Datasets

1. **Medetec Wound Database**
   - http://www.medetec.co.uk/
   - Educational wound images
   - May require manual annotation

2. **AZH Wound Assessment Dataset**
   - Research dataset
   - Contact institution for access

## Data Annotation

If your dataset doesn't include segmentation masks:

### Option 1: LabelMe (Recommended)

```bash
pip install labelme

# Start annotation tool
labelme wound_data/images --output wound_data/annotations

# Convert to masks
python convert_labelme_to_masks.py
```

### Option 2: CVAT (Computer Vision Annotation Tool)

1. Install CVAT: https://github.com/opencv/cvat
2. Create segmentation task
3. Export masks in PNG format

### Option 3: Roboflow

1. Upload images to Roboflow
2. Use polygon annotation tool
3. Export in "Semantic Segmentation" format

## Model Architecture

The training script uses U-Net architecture:

```
Input (512x512x3)
    ↓
Encoder (Contracting Path)
    Conv2D(64) → Conv2D(64) → MaxPool
    Conv2D(128) → Conv2D(128) → MaxPool
    Conv2D(256) → Conv2D(256) → MaxPool
    Conv2D(512) → Conv2D(512) → MaxPool
    ↓
Bottleneck
    Conv2D(1024) → Conv2D(1024)
    ↓
Decoder (Expanding Path)
    UpSample → Conv2D(512) → Concatenate
    UpSample → Conv2D(256) → Concatenate
    UpSample → Conv2D(128) → Concatenate
    UpSample → Conv2D(64) → Concatenate
    ↓
Output (512x512x1) - Segmentation Mask
```

## Training Tips

### Improve Accuracy

1. **More Data**
   - Aim for 1,000+ images minimum
   - Use data augmentation (built-in)

2. **Better Annotations**
   - Precise boundary tracing
   - Consistent labeling

3. **Hyperparameter Tuning**
   - Adjust learning rate
   - Try different batch sizes
   - Increase epochs

4. **Transfer Learning**
   - Start with pre-trained ImageNet weights
   - Fine-tune on wound data

### Handle Overfitting

- Increase dropout rate
- Add more augmentation
- Reduce model complexity
- Get more training data

### Speed Up Training

- Use GPU (CUDA)
- Reduce image size
- Increase batch size
- Use mixed precision training

## Evaluation

After training, evaluate your model:

```python
# In train_wound_model.py, add:
from sklearn.metrics import jaccard_score, f1_score

# Calculate IoU (Intersection over Union)
iou = jaccard_score(y_true, y_pred, average='binary')

# Calculate Dice coefficient
dice = f1_score(y_true, y_pred, average='binary')

print(f"IoU: {iou:.4f}")
print(f"Dice: {dice:.4f}")
```

Good metrics:
- IoU > 0.7 (70%)
- Dice > 0.8 (80%)

## Troubleshooting

### Out of Memory

```python
# Reduce batch size
CONFIG['batch_size'] = 4

# Reduce image size
CONFIG['image_size'] = (256, 256)
```

### Poor Performance

1. Check data quality
2. Verify mask alignment with images
3. Increase training epochs
4. Try different learning rates

### Model Too Large

```python
# Reduce model complexity
# In create_unet_model(), use fewer filters:
conv1 = layers.Conv2D(32, 3, ...)  # Instead of 64
conv2 = layers.Conv2D(64, 3, ...)  # Instead of 128
```

### CoreML Conversion Fails

```python
# Try different conversion options
coreml_model = ct.convert(
    model,
    inputs=[ct.ImageType(name="image", shape=(1, 512, 512, 3))],
    minimum_deployment_target=ct.target.iOS14  # Try older iOS version
)
```

## Next Steps

1. **Collect More Data**: Continuously improve dataset
2. **Active Learning**: Use app to collect real-world images
3. **Model Updates**: Retrain periodically with new data
4. **A/B Testing**: Compare model versions
5. **Cloud Backup**: Consider cloud API for difficult cases

## Resources

- [CoreML Tools Documentation](https://apple.github.io/coremltools/)
- [TensorFlow Tutorials](https://www.tensorflow.org/tutorials)
- [U-Net Paper](https://arxiv.org/abs/1505.04597)
- [Medical Image Segmentation](https://paperswithcode.com/task/medical-image-segmentation)
- [MONAI Framework](https://monai.io/)

## Support

For issues or questions:
1. Check training logs in `models/training_history.json`
2. Review model architecture
3. Verify data format
4. Test with sample images
