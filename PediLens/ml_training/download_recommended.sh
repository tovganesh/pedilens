#!/bin/bash
# Download the recommended wound dataset (Wound Segmentation Images - 2760 samples)

set -e  # Exit on error

echo "=========================================="
echo "Downloading Recommended Wound Dataset"
echo "=========================================="
echo ""
echo "Dataset: Wound Segmentation Images"
echo "Creator: leoscode (Kaggle)"
echo "Source: https://www.kaggle.com/datasets/leoscode/wound-segmentation-images"
echo "Size: 697 MB"
echo "Samples: 2,760 images with masks"
echo "Quality: High - Best for training"
echo ""
echo "By downloading this dataset, you agree to:"
echo "- Review and comply with the dataset license on Kaggle"
echo "- Acknowledge the dataset creator in any publications"
echo ""

# Check if kaggle is installed
if ! command -v kaggle &> /dev/null; then
    echo "❌ Error: Kaggle CLI not found."
    echo "Install with: pip install kaggle"
    exit 1
fi

# Check for Kaggle credentials
if [ ! -f ~/.kaggle/kaggle.json ]; then
    echo "❌ Error: Kaggle credentials not found!"
    echo ""
    echo "Setup instructions:"
    echo "1. Go to https://www.kaggle.com/account"
    echo "2. Scroll to 'API' section"
    echo "3. Click 'Create New API Token'"
    echo "4. Move downloaded kaggle.json to ~/.kaggle/"
    echo "5. Run: chmod 600 ~/.kaggle/kaggle.json"
    echo ""
    exit 1
fi

echo "✅ Kaggle CLI found"
echo "✅ Credentials configured"
echo ""

# Create data directory
mkdir -p wound_data
cd wound_data

echo "📥 Downloading Wound Segmentation Images (697 MB)..."
echo "This will take 5-10 minutes depending on your internet speed..."
echo ""

kaggle datasets download -d leoscode/wound-segmentation-images

echo ""
echo "✅ Download complete!"
echo ""
echo "📦 Extracting files..."

unzip -q wound-segmentation-images.zip
rm wound-segmentation-images.zip

echo "✅ Extraction complete!"
echo ""

# Check what we got
echo "=========================================="
echo "Download Summary"
echo "=========================================="
echo ""
echo "📁 Location: $(pwd)"
echo ""

# List contents
echo "Contents:"
ls -lh | head -10
echo ""

# Check for images and masks folders
if [ -d "images" ] && [ -d "masks" ]; then
    IMAGE_COUNT=$(ls images 2>/dev/null | wc -l | tr -d ' ')
    MASK_COUNT=$(ls masks 2>/dev/null | wc -l | tr -d ' ')
    
    echo "✅ Perfect structure found!"
    echo "   Images: $IMAGE_COUNT files"
    echo "   Masks: $MASK_COUNT files"
    
    if [ "$IMAGE_COUNT" -eq "$MASK_COUNT" ]; then
        echo "   ✅ Counts match!"
    else
        echo "   ⚠️  Warning: Image and mask counts don't match"
    fi
elif [ -d "images" ]; then
    IMAGE_COUNT=$(ls images 2>/dev/null | wc -l | tr -d ' ')
    echo "⚠️  Found images/ folder but no masks/"
    echo "   Images: $IMAGE_COUNT files"
    echo "   You may need to create or locate masks"
else
    echo "⚠️  Unexpected structure. Contents:"
    ls -la
    echo ""
    echo "You may need to reorganize files into:"
    echo "  - images/ (wound photos)"
    echo "  - masks/ (segmentation masks)"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Verify the data looks correct:"
echo "   ls images | head -5"
echo "   ls masks | head -5"
echo ""
echo "2. Train using Google Colab (recommended):"
echo "   - Open https://colab.research.google.com/"
echo "   - Upload WoundDetection_Colab.ipynb"
echo "   - Upload this wound_data folder"
echo "   - Run all cells"
echo ""
echo "3. Or train locally (if Python 3.11 installed):"
echo "   cd .."
echo "   python train_wound_model.py"
echo ""
echo "✅ Dataset ready for training!"
echo ""
