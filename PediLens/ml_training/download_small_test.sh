#!/bin/bash
# Download small wound dataset for quick testing (14 MB)

set -e

echo "Downloading Small Test Dataset (14 MB)..."
echo "Good for: Quick testing of training pipeline"
echo ""

if ! command -v kaggle &> /dev/null; then
    echo "❌ Kaggle CLI not found. Install: pip install kaggle"
    exit 1
fi

if [ ! -f ~/.kaggle/kaggle.json ]; then
    echo "❌ Kaggle credentials not found. See DATASET_DOWNLOAD_GUIDE.md"
    exit 1
fi

mkdir -p wound_data
cd wound_data

echo "📥 Downloading..."
kaggle datasets download -d yasinpratomo/wound-dataset

echo "📦 Extracting..."
unzip -q wound-dataset.zip
rm wound-dataset.zip

echo "✅ Done! Dataset in: $(pwd)"
ls -lh
