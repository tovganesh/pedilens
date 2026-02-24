# Google Colab Training Guide

Complete step-by-step guide to train your wound detection model using Google Colab (no local installation needed!).

## Why Google Colab?

✅ Free GPU access
✅ No local installation required  
✅ Pre-installed ML libraries
✅ Easy to use
✅ Save and share notebooks

## Step-by-Step Instructions

### Step 1: Open Google Colab

1. Go to https://colab.research.google.com/
2. Sign in with your Google account
3. Click "File" > "Upload notebook"
4. Upload `WoundDetection_Colab.ipynb` from this directory

**OR**

1. Go to https://colab.research.google.com/
2. Click "File" > "New notebook"
3. Copy and paste the code from `WoundDetection_Colab.ipynb`

### Step 2: Enable GPU

**IMPORTANT:** Enable GPU for faster training!

1. Click "Runtime" in the menu
2. Select "Change runtime type"
3. Under "Hardware accelerator", select "GPU" (T4 GPU)
4. Click "Save"

### Step 3: Prepare Your Dataset

You need wound images and their corresponding segmentation masks.

#### Option A: Use Sample Dataset (for testing)

If you don't have a dataset yet, you can create a small sample dataset:

```python
# Run this in a Colab cell to create sample data
!mkdir -p wound_data/images wound_data/masks

# This will create dummy data for testing
# Replace with real data for actual training
```

#### Option B: Upload Your Own Dataset

1. Prepare a ZIP file with this structure:
   ```
   wound_dataset.zip
   ├── images/
   │   ├── image001.jpg
   │   ├── image002.jpg
   │   └── ...
   └── masks/
       ├── image001.png
       ├── image002.png
       └── ...
   ```

2. In Colab, run the upload cell:
   ```python
   from google.colab import files
   uploaded = files.upload()
   ```

3. Select your ZIP file

#### Option C: Download from Kaggle

1. Get Kaggle API credentials:
   - Go to https://www.kaggle.com/account
   - Scroll to "API" section
   - Click "Create New API Token"
   - Download `kaggle.json`

2. In Colab, upload `kaggle.json`:
   ```python
   from google.colab import files
   uploaded = files.upload()  # Upload kaggle.json
   ```

3. Download dataset:
   ```python
   !pip install kaggle
   !mkdir -p ~/.kaggle
   !cp kaggle.json ~/.kaggle/
   !chmod 600 ~/.kaggle/kaggle.json
   
   # Search for datasets
   !kaggle datasets list -s "diabetic foot ulcer"
   
   # Download (replace with actual dataset name)
   !kaggle datasets download -d <username>/<dataset-name>
   !unzip <dataset-name>.zip -d wound_data/
   ```

### Step 4: Run the Notebook

Execute cells in order (Shift+Enter or click the play button):

1. **Setup Environment** - Installs dependencies (~1 minute)
2. **Upload Dataset** - Upload your data
3. **Configuration** - Set training parameters
4. **Data Loading** - Loads and augments images (~2-5 minutes)
5. **Build Model** - Creates U-Net architecture (~30 seconds)
6. **Train Model** - Trains the model (~30-60 minutes depending on dataset size)
7. **Convert to CoreML** - Converts to iOS format (~2 minutes)
8. **Download Model** - Downloads the .mlmodel file

### Step 5: Monitor Training

Watch the training progress:
- Loss should decrease
- Dice coefficient should increase (aim for >0.80)
- Validation metrics should be close to training metrics

**Good metrics:**
- Validation Dice > 0.75 (75%)
- Validation Loss < 0.25

**If metrics are poor:**
- Check if masks align with images
- Increase training epochs
- Add more training data
- Adjust learning rate

### Step 6: Download Your Model

After training completes:

1. The notebook will automatically download `WoundSegmentation.mlmodel`
2. Save it to your computer
3. You'll also get `training_history.json` with metrics

### Step 7: Add Model to PediLens

1. Open your PediLens Xcode project
2. Drag `WoundSegmentation.mlmodel` into the project navigator
3. Place it in `PediLens/Resources/` folder
4. In the dialog, check "Copy items if needed"
5. Ensure "PediLens" target is selected
6. Build the project (⌘+B)

Xcode will automatically compile the `.mlmodel` to `.mlmodelc` format.

### Step 8: Test in App

1. Run the app on simulator or device
2. Open a wound image
3. Tap "Auto-Detect Wound"
4. The model will now use your trained model!

## Tips for Better Results

### Data Quality

✅ **Good:**
- Clear, well-lit images
- Wound clearly visible
- Consistent image quality
- Accurate mask annotations

❌ **Bad:**
- Blurry images
- Poor lighting
- Masks don't match wounds
- Inconsistent image sizes

### Training Parameters

**Small dataset (<500 images):**
```python
CONFIG = {
    'image_size': (256, 256),  # Smaller size
    'batch_size': 4,
    'epochs': 100,  # More epochs
    'learning_rate': 0.0001,  # Lower learning rate
}
```

**Large dataset (>2000 images):**
```python
CONFIG = {
    'image_size': (512, 512),
    'batch_size': 16,
    'epochs': 50,
    'learning_rate': 0.001,
}
```

### Data Augmentation

The notebook includes:
- Horizontal flip
- Vertical flip
- 90° rotation

This effectively 4x your dataset size!

## Troubleshooting

### "Out of Memory" Error

```python
# Reduce batch size
CONFIG['batch_size'] = 4

# Or reduce image size
CONFIG['image_size'] = (256, 256)
```

### "Runtime disconnected"

Colab has usage limits. If disconnected:
1. Reconnect to runtime
2. Re-run cells from the beginning
3. Or save checkpoint and resume

### Poor Model Performance

1. **Check data quality:**
   ```python
   # Visualize samples
   import matplotlib.pyplot as plt
   plt.imshow(images[0])
   plt.show()
   plt.imshow(masks[0].squeeze(), cmap='gray')
   plt.show()
   ```

2. **Increase training time:**
   ```python
   CONFIG['epochs'] = 100
   ```

3. **Adjust learning rate:**
   ```python
   CONFIG['learning_rate'] = 0.0001
   ```

### CoreML Conversion Fails

```python
# Try older iOS version
minimum_deployment_target=ct.target.iOS14

# Or simpler conversion
coreml_model = ct.convert(model)
```

## Saving Your Work

### Save Notebook to Google Drive

1. Click "File" > "Save a copy in Drive"
2. Your notebook is saved and can be reopened anytime

### Download Notebook

1. Click "File" > "Download" > "Download .ipynb"
2. Save locally for backup

### Mount Google Drive (Optional)

Save outputs directly to Drive:

```python
from google.colab import drive
drive.mount('/content/drive')

# Save model to Drive
CONFIG['output_dir'] = '/content/drive/MyDrive/PediLens/models'
```

## Cost

Google Colab is **FREE** with limitations:
- ~12 hours max runtime
- GPU access may be limited during peak times
- Sessions disconnect after inactivity

**Colab Pro** ($10/month):
- Longer runtimes
- Better GPUs (V100, A100)
- Priority access

For this project, **free tier is sufficient**!

## Expected Timeline

| Task | Time |
|------|------|
| Setup & upload data | 5-10 min |
| Data loading | 2-5 min |
| Model training (500 images) | 20-30 min |
| Model training (2000 images) | 60-90 min |
| CoreML conversion | 2-3 min |
| **Total** | **30-110 min** |

## Next Steps After Training

1. ✅ Download `WoundSegmentation.mlmodel`
2. ✅ Add to Xcode project
3. ✅ Test with sample images
4. ✅ Evaluate performance
5. ✅ Collect more data if needed
6. ✅ Retrain with improved dataset
7. ✅ Deploy to production

## Resources

- **Colab Documentation:** https://colab.research.google.com/notebooks/intro.ipynb
- **Kaggle Datasets:** https://www.kaggle.com/datasets
- **CoreML Tools:** https://apple.github.io/coremltools/
- **U-Net Paper:** https://arxiv.org/abs/1505.04597

## Getting Help

If you encounter issues:

1. Check the error message in Colab
2. Review the troubleshooting section above
3. Verify your dataset structure
4. Try with a smaller dataset first
5. Check Colab's status page

## Quick Reference

### Essential Colab Shortcuts

- `Shift + Enter` - Run cell
- `Ctrl + M B` - Insert cell below
- `Ctrl + M A` - Insert cell above
- `Ctrl + M D` - Delete cell
- `Ctrl + M Z` - Undo cell deletion

### Check GPU Status

```python
!nvidia-smi
```

### Check Available RAM

```python
!free -h
```

### Check Disk Space

```python
!df -h
```

## Success Checklist

- [ ] Opened Colab notebook
- [ ] Enabled GPU runtime
- [ ] Uploaded dataset (images + masks)
- [ ] Verified data structure
- [ ] Ran all cells successfully
- [ ] Training completed with good metrics
- [ ] Downloaded .mlmodel file
- [ ] Added model to Xcode project
- [ ] Tested in PediLens app
- [ ] Model detects wounds accurately

You're ready to train! 🚀
