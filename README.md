# PediLens

iOS application for wound detection and measurement using machine learning.

## Features

- Wound boundary detection using CoreML
- Automatic measurement calculation
- Patient record management
- Timeline tracking of wound healing
- HIPAA-compliant data storage
- Offline-first architecture

## ML Model Training

The wound detection model can be trained using the provided tools in `PediLens/ml_training/`.

### Dataset Attribution

The default training dataset is **Wound Segmentation Images** by leoscode on Kaggle:
- **Source:** https://www.kaggle.com/datasets/leoscode/wound-segmentation-images
- **Samples:** 2,760 wound images with segmentation masks
- **License:** See Kaggle dataset page for terms

Please acknowledge the dataset creator if you use models trained on this data.

For detailed attribution information, see `PediLens/ml_training/DATASET_ATTRIBUTION.md`.

## Quick Start

### Training a Model

```bash
cd PediLens/ml_training
./download_recommended.sh  # Download dataset
# Then use Google Colab to train (see ml_training/START_HERE.md)
```

### Building the App

```bash
cd PediLens
open PediLens.xcodeproj
# Build and run in Xcode
```

## Documentation

- **ML Training:** `PediLens/ml_training/START_HERE.md`
- **Dataset Info:** `PediLens/ml_training/DATASET_ATTRIBUTION.md`
- **Project Setup:** `PediLens/PROJECT_SETUP_GUIDE.md`

## License

See LICENSE file for details.

## Acknowledgments

- Wound Segmentation Images dataset by leoscode (Kaggle)
- All contributors to open medical imaging datasets
- The Kaggle community for hosting valuable datasets
