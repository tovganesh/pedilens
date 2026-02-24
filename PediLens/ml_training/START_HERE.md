# START HERE - Wound Detection Model Training

## Dataset Acknowledgment

This training uses the **Wound Segmentation Images** dataset by leoscode on Kaggle.

- **Source:** https://www.kaggle.com/datasets/leoscode/wound-segmentation-images
- **Samples:** 2,760 wound images with segmentation masks
- **Size:** 697 MB
- **License:** See Kaggle dataset page for license terms

Please acknowledge the dataset creator if you use models trained on this data.

---

## Quick Start (3 Steps)

### Step 1: Download Dataset (5-10 minutes)
```bash
cd PediLens/ml_training
./download_recommended.sh
```

This downloads the Wound Segmentation Images dataset (2,760 samples, 697 MB).

### Step 2: Train Model (30-60 minutes)

**Option A: Google Colab (Recommended - No setup needed)**
1. Open https://colab.research.google.com/
2. Upload `WoundDetection_Colab.ipynb`
3. Enable GPU: Runtime > Change runtime type > GPU > Save
4. Run all cells (Shift+Enter through each)
5. Upload `wound_data` folder when prompted
6. Wait for training (~30-60 min)
7. Download `WoundSegmentation.mlmodel`

**Option B: Local (Requires Python 3.11)**
```bash
python train_wound_model.py
```

### Step 3: Add to PediLens (2 minutes)
1. Open PediLens in Xcode
2. Drag `WoundSegmentation.mlmodel` into project
3. Place in `PediLens/Resources/`
4. Check "Copy items if needed"
5. Build (⌘+B)
6. Run and test!

## That's It! 🎉

Your app now has real ML-powered wound detection.

---

## Files Overview

### Download Scripts (Use These!)
- **`download_recommended.sh`** ⭐ - Best dataset (2760 samples)
- **`download_small_test.sh`** - Quick test (14 MB)

### Training
- **`WoundDetection_Colab.ipynb`** ⭐ - Upload to Google Colab
- **`train_wound_model.py`** - Local training script

### Documentation
- **`SIMPLE_DOWNLOAD.md`** - Download instructions
- **`COLAB_GUIDE.md`** - Detailed Colab guide
- **`DATASET_DOWNLOAD_GUIDE.md`** - Comprehensive dataset guide

### Other Files
- `requirements.txt` - Python dependencies (not needed for Colab)
- `INSTALLATION_GUIDE.md` - Local setup (if not using Colab)

## Recommended Path

1. ✅ Use `download_recommended.sh` to get data
2. ✅ Use Google Colab for training (free GPU!)
3. ✅ Add model to Xcode
4. ✅ Test in app

## Need Help?

- **Download issues?** See `SIMPLE_DOWNLOAD.md`
- **Training issues?** See `COLAB_GUIDE.md`
- **Dataset questions?** See `DATASET_DOWNLOAD_GUIDE.md`
- **General overview?** See `../COLAB_TRAINING_READY.md`

## Quick Commands

```bash
# Download dataset
./download_recommended.sh

# Check what you got
ls -la wound_data/

# Count images
ls wound_data/images | wc -l
ls wound_data/masks | wc -l

# Then use Google Colab to train!
```

## Timeline

| Task | Time |
|------|------|
| Download dataset | 5-10 min |
| Upload to Colab | 2-5 min |
| Train model | 30-60 min |
| Download model | 1 min |
| Add to Xcode | 2 min |
| **Total** | **40-80 min** |

## Success Criteria

✅ Dataset downloaded (2760 images + masks)
✅ Colab notebook runs without errors
✅ Training completes (Dice > 0.75)
✅ Model file downloads
✅ Xcode builds successfully
✅ App detects wounds

Ready? Run `./download_recommended.sh` to begin! 🚀
