# Quick Start: Train Wound Detection Model in 30 Minutes

## What You Need

- [ ] Google account
- [ ] Wound images dataset (or download from Kaggle)
- [ ] 30-60 minutes of time

## 5-Step Process

### 1️⃣ Open Colab (2 minutes)

```
1. Go to: https://colab.research.google.com/
2. Sign in with Google
3. Click: File > Upload notebook
4. Upload: WoundDetection_Colab.ipynb
5. Click: Runtime > Change runtime type > GPU > Save
```

### 2️⃣ Prepare Dataset (5-10 minutes)

**Option A: Have your own data**
- Create ZIP with `images/` and `masks/` folders
- Upload when prompted in notebook

**Option B: Download from Kaggle**
- Get API key from https://www.kaggle.com/account
- Search for "diabetic foot ulcer" or "wound segmentation"
- Follow notebook instructions to download

**Option C: Test with sample data**
- Skip for now, use minimal dataset to test
- Come back later with real data

### 3️⃣ Run Training (30-60 minutes)

```
1. Click first cell, press Shift+Enter
2. Keep pressing Shift+Enter for each cell
3. Upload your dataset when prompted
4. Wait for training to complete
5. Watch the progress bars and metrics
```

**What to expect:**
- Setup: ~1 minute
- Data loading: ~2-5 minutes  
- Training: ~30-60 minutes (depends on dataset size)
- Conversion: ~2 minutes

### 4️⃣ Download Model (1 minute)

```
1. Model downloads automatically when training completes
2. Save WoundSegmentation.mlmodel to your computer
3. Also save training_history.json for reference
```

### 5️⃣ Add to PediLens (2 minutes)

```
1. Open PediLens in Xcode
2. Drag WoundSegmentation.mlmodel into project
3. Place in PediLens/Resources/
4. Check "Copy items if needed"
5. Build project (⌘+B)
6. Run and test!
```

## That's It! 🎉

Your app now has real ML-powered wound detection!

## Quick Tips

### While Training
- ✅ Leave the tab open (don't close browser)
- ✅ Check metrics: Dice should be >0.75
- ✅ Watch for errors in output
- ❌ Don't close laptop (may disconnect)

### If Something Goes Wrong
- **Out of memory?** Reduce batch_size to 4
- **Poor results?** Check if masks match images
- **Disconnected?** Reconnect and re-run from start
- **Slow training?** Make sure GPU is enabled

### Good Metrics
- ✅ Validation Dice > 0.75 (75%)
- ✅ Validation Loss < 0.30
- ✅ Training and validation metrics close together

### Bad Metrics
- ❌ Dice < 0.50 (50%) - Check data quality
- ❌ Loss > 0.50 - May need more training
- ❌ Big gap between train/val - Overfitting

## Next Steps

After your first model:

1. **Test it** - Try with real wound images
2. **Evaluate** - Is detection accurate enough?
3. **Improve** - Collect more data if needed
4. **Retrain** - Iterate with better dataset
5. **Deploy** - Use in production

## Resources

- **Full Guide:** See `COLAB_GUIDE.md`
- **Notebook:** `WoundDetection_Colab.ipynb`
- **Datasets:** Search Kaggle for "diabetic foot ulcer"
- **Help:** Check troubleshooting in COLAB_GUIDE.md

## Timeline

| Your Dataset Size | Training Time | Total Time |
|------------------|---------------|------------|
| 100 images | 10-15 min | ~20 min |
| 500 images | 20-30 min | ~40 min |
| 1000 images | 40-60 min | ~70 min |
| 2000+ images | 60-90 min | ~100 min |

## Checklist

Before you start:
- [ ] Have Google account ready
- [ ] Know where your dataset is (or have Kaggle account)
- [ ] Have 30-60 minutes available
- [ ] Xcode project is ready

During training:
- [ ] GPU is enabled in Colab
- [ ] Dataset uploaded successfully
- [ ] Training is running (watch progress)
- [ ] Metrics look good

After training:
- [ ] Model downloaded
- [ ] Added to Xcode project
- [ ] App builds successfully
- [ ] Tested with sample images

## Ready?

Open the notebook and let's train! 🚀

👉 https://colab.research.google.com/

Upload: `WoundDetection_Colab.ipynb`
