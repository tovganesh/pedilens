# Dataset Download Guide

## Quick Download

Use the new script to download actual wound datasets:

```bash
cd PediLens/ml_training
./download_wound_datasets.sh
```

## Available Datasets

### 1. Wound Segmentation Images (RECOMMENDED) ⭐
- **Size:** 697 MB
- **Images:** 2,760 samples
- **Quality:** High quality with segmentation masks
- **Best for:** Training production models
- **Kaggle:** `leoscode/wound-segmentation-images`

### 2. Wound Dataset
- **Size:** 14 MB
- **Images:** Smaller dataset
- **Best for:** Quick testing
- **Kaggle:** `yasinpratomo/wound-dataset`

### 3. Wound Classification Dataset
- **Size:** 94 MB
- **Images:** Categorized wound images
- **Note:** May need manual mask creation
- **Kaggle:** `ibrahimfateen/wound-classification`

### 4. Leprosy Chronic Wound Images
- **Size:** 115 MB
- **Images:** Specialized wound type
- **Best for:** Specific use cases
- **Kaggle:** `orvile/leprosy-chronic-wound-images-co2wounds-v2`

## Step-by-Step Instructions

### 1. Run Download Script

```bash
cd PediLens/ml_training
./download_wound_datasets.sh
```

### 2. Choose Dataset

When prompted, enter:
- `1` for Wound Segmentation Images (recommended)
- `2` for smaller Wound Dataset
- `3` for Wound Classification
- `4` for Leprosy Chronic Wound
- `all` to download everything

### 3. Wait for Download

The script will:
- Download the dataset from Kaggle
- Extract the files
- Show you what was downloaded

### 4. Check Structure

After download, check if you have the right structure:

```bash
ls -la wound_data/
```

**Expected structure:**
```
wound_data/
├── images/
│   ├── image001.jpg
│   ├── image002.jpg
│   └── ...
└── masks/
    ├── image001.png
    ├── image002.png
    └── ...
```

## If Structure is Different

Some datasets may have different folder structures. Here's how to reorganize:

### Check what you have:
```bash
cd wound_data
ls -la
```

### Common scenarios:

#### Scenario 1: Files in root directory
```bash
# Create folders
mkdir -p images masks

# Move image files
mv *.jpg images/ 2>/dev/null || true
mv *.png images/ 2>/dev/null || true

# If masks are named differently (e.g., *_mask.png)
mv *_mask.png masks/ 2>/dev/null || true
```

#### Scenario 2: Nested folders
```bash
# Find all images
find . -name "*.jpg" -o -name "*.jpeg" | while read file; do
    cp "$file" images/
done

# Find all masks
find . -name "*mask*.png" | while read file; do
    cp "$file" masks/
done
```

#### Scenario 3: No masks provided
If the dataset doesn't include segmentation masks, you have two options:

**Option A:** Use Google Colab approach (recommended)
- Upload images to Colab
- Use pre-trained model for initial segmentation
- Manually refine if needed

**Option B:** Create masks manually
- Use annotation tools like LabelMe or CVAT
- Draw wound boundaries
- Export as binary masks

## Manual Download (Alternative)

If the script doesn't work, download manually:

### 1. Go to Kaggle
```
https://www.kaggle.com/datasets/leoscode/wound-segmentation-images
```

### 2. Click "Download"
- Sign in to Kaggle
- Click the download button
- Save the ZIP file

### 3. Extract
```bash
cd PediLens/ml_training
mkdir -p wound_data
unzip ~/Downloads/wound-segmentation-images.zip -d wound_data/
```

## Verify Dataset

After organizing, verify your dataset:

```bash
cd PediLens/ml_training

# Count images
echo "Images: $(ls wound_data/images | wc -l)"

# Count masks
echo "Masks: $(ls wound_data/masks | wc -l)"

# Check if counts match
if [ $(ls wound_data/images | wc -l) -eq $(ls wound_data/masks | wc -l) ]; then
    echo "✅ Counts match!"
else
    echo "⚠️  Image and mask counts don't match"
fi
```

## Sample Dataset for Testing

If you just want to test the training pipeline, create a small sample dataset:

```bash
cd PediLens/ml_training
mkdir -p wound_data/images wound_data/masks

# Download a few sample images (you'll need to provide these)
# Or use the smallest dataset (option 2) for testing
```

## Troubleshooting

### "Kaggle credentials not found"
```bash
# Get API key from https://www.kaggle.com/account
# Download kaggle.json
mkdir -p ~/.kaggle
mv ~/Downloads/kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json
```

### "Dataset not found"
- Check your internet connection
- Verify Kaggle credentials are correct
- Try downloading manually from Kaggle website

### "Out of disk space"
- Check available space: `df -h`
- Download smaller dataset (option 2)
- Or use Google Colab instead

### "Extraction failed"
```bash
# Install unzip if missing
brew install unzip

# Or extract manually
unzip wound-segmentation-images.zip -d wound_data/
```

## Next Steps

After downloading and organizing your dataset:

1. **Verify structure:**
   ```bash
   ls wound_data/images | head -5
   ls wound_data/masks | head -5
   ```

2. **Check image-mask pairs:**
   ```bash
   # First image
   ls wound_data/images | head -1
   # Corresponding mask should exist
   ls wound_data/masks | head -1
   ```

3. **Start training:**
   - **Local:** `python train_wound_model.py`
   - **Colab:** Upload to Colab and run notebook

## Recommended Workflow

### For Quick Testing (30 minutes)
1. Download dataset #2 (14 MB)
2. Verify structure
3. Train with Google Colab
4. Test model in app

### For Production Model (2-3 hours)
1. Download dataset #1 (697 MB) - recommended
2. Verify and organize data
3. Train with Google Colab (free GPU)
4. Evaluate results
5. Deploy to app

### For Best Results (ongoing)
1. Start with dataset #1
2. Train initial model
3. Test in real-world scenarios
4. Collect your own wound images
5. Retrain with combined dataset
6. Iterate and improve

## Dataset Quality Tips

### Good Dataset
- ✅ Clear, well-lit images
- ✅ Consistent image quality
- ✅ Accurate mask annotations
- ✅ Variety of wound types
- ✅ 500+ image-mask pairs

### Poor Dataset
- ❌ Blurry or dark images
- ❌ Inconsistent sizes
- ❌ Inaccurate masks
- ❌ Too few samples (<100)
- ❌ Missing masks

## Resources

- **Kaggle Datasets:** https://www.kaggle.com/datasets
- **Search terms:** "wound", "ulcer", "diabetic foot", "wound segmentation"
- **Annotation tools:** LabelMe, CVAT, Roboflow
- **Training guide:** See `COLAB_GUIDE.md`
