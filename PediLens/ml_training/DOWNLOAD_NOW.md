# Download Dataset Now

## Quick Command

Run this to download the recommended wound dataset:

```bash
cd PediLens/ml_training
./download_wound_datasets.sh
```

When prompted, enter `1` for the best dataset (Wound Segmentation Images - 2760 samples).

## What Happens

1. Script checks Kaggle credentials ✅ (you already have this)
2. Downloads 697 MB dataset (~5-10 minutes depending on internet)
3. Extracts files automatically
4. Shows you what was downloaded

## After Download

Check your data:
```bash
ls -la wound_data/
```

You should see folders with images and masks.

## Then Train

### Option A: Google Colab (Recommended)
1. Open https://colab.research.google.com/
2. Upload `WoundDetection_Colab.ipynb`
3. Upload your `wound_data` folder when prompted
4. Run all cells
5. Download trained model

### Option B: Local (if you fix Python version)
```bash
python train_wound_model.py
```

## Need Help?

See `DATASET_DOWNLOAD_GUIDE.md` for detailed instructions and troubleshooting.
