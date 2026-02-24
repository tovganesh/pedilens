# Simple Dataset Download

## One-Command Download

### Recommended: Best Quality Dataset
```bash
cd PediLens/ml_training
./download_recommended.sh
```

Downloads: Wound Segmentation Images (2760 samples, 697 MB)
Time: 5-10 minutes

### Alternative: Small Test Dataset
```bash
cd PediLens/ml_training
./download_small_test.sh
```

Downloads: Small wound dataset (14 MB)
Time: 1-2 minutes
Good for: Testing the pipeline quickly

## What These Scripts Do

1. ✅ Check Kaggle is installed
2. ✅ Check credentials are configured
3. ✅ Download dataset from Kaggle
4. ✅ Extract files automatically
5. ✅ Show you what was downloaded
6. ✅ Verify structure

## After Download

Check your data:
```bash
cd wound_data
ls -la
```

You should see:
```
images/     - Wound photos
masks/      - Segmentation masks
```

## Then Train

### Option A: Google Colab (Easiest)
1. Go to https://colab.research.google.com/
2. Upload `WoundDetection_Colab.ipynb`
3. Enable GPU (Runtime > Change runtime type > GPU)
4. Run all cells
5. Upload `wound_data` folder when prompted
6. Download trained model

### Option B: Local (Requires Python 3.11)
```bash
python train_wound_model.py
```

## Troubleshooting

### Script doesn't run
```bash
chmod +x download_recommended.sh
./download_recommended.sh
```

### Kaggle credentials error
```bash
# Get API key from https://www.kaggle.com/account
mkdir -p ~/.kaggle
mv ~/Downloads/kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json
```

### Download is slow
- Normal for 697 MB file
- Takes 5-10 minutes on average internet
- Use `download_small_test.sh` for faster testing

### Out of disk space
```bash
# Check space
df -h

# Use smaller dataset
./download_small_test.sh
```

## Manual Download (If Scripts Fail)

1. Go to https://www.kaggle.com/datasets/leoscode/wound-segmentation-images
2. Click "Download" button
3. Extract ZIP to `wound_data/` folder

## Next Steps

See `COLAB_GUIDE.md` for training instructions.
