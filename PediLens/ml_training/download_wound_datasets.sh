#!/bin/bash
# Download actual wound datasets from Kaggle

set -e  # Exit on error

echo "=========================================="
echo "Wound Dataset Downloader"
echo "=========================================="
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
    echo "Please follow these steps:"
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

echo "Available Wound Datasets:"
echo ""
echo "1. Wound Segmentation Images (2760 samples) - RECOMMENDED"
echo "   - 697 MB"
echo "   - High quality segmentation masks"
echo "   - Best for training"
echo ""
echo "2. Wound Dataset (smaller, 14 MB)"
echo "   - Good for testing"
echo "   - Fewer images"
echo ""
echo "3. Wound Classification Dataset (94 MB)"
echo "   - Categorized wound images"
echo "   - May need mask creation"
echo ""
echo "4. Leprosy Chronic Wound Images (115 MB)"
echo "   - Specialized wound type"
echo ""

read -p "Which dataset do you want to download? (1-4, or 'all' for all): " choice

case $choice in
    1)
        echo ""
        echo "📥 Downloading Wound Segmentation Images (697 MB)..."
        kaggle datasets download -d leoscode/wound-segmentation-images
        echo "✅ Download complete!"
        echo ""
        echo "📦 Extracting..."
        unzip -q wound-segmentation-images.zip
        rm wound-segmentation-images.zip
        echo "✅ Extracted!"
        ;;
    2)
        echo ""
        echo "📥 Downloading Wound Dataset (14 MB)..."
        kaggle datasets download -d yasinpratomo/wound-dataset
        echo "✅ Download complete!"
        echo ""
        echo "📦 Extracting..."
        unzip -q wound-dataset.zip
        rm wound-dataset.zip
        echo "✅ Extracted!"
        ;;
    3)
        echo ""
        echo "📥 Downloading Wound Classification Dataset (94 MB)..."
        kaggle datasets download -d ibrahimfateen/wound-classification
        echo "✅ Download complete!"
        echo ""
        echo "📦 Extracting..."
        unzip -q wound-classification.zip
        rm wound-classification.zip
        echo "✅ Extracted!"
        ;;
    4)
        echo ""
        echo "📥 Downloading Leprosy Chronic Wound Images (115 MB)..."
        kaggle datasets download -d orvile/leprosy-chronic-wound-images-co2wounds-v2
        echo "✅ Download complete!"
        echo ""
        echo "📦 Extracting..."
        unzip -q leprosy-chronic-wound-images-co2wounds-v2.zip
        rm leprosy-chronic-wound-images-co2wounds-v2.zip
        echo "✅ Extracted!"
        ;;
    all)
        echo ""
        echo "📥 Downloading all datasets (this will take a while)..."
        
        echo "  1/4: Wound Segmentation Images..."
        kaggle datasets download -d leoscode/wound-segmentation-images
        unzip -q wound-segmentation-images.zip -d dataset1
        rm wound-segmentation-images.zip
        
        echo "  2/4: Wound Dataset..."
        kaggle datasets download -d yasinpratomo/wound-dataset
        unzip -q wound-dataset.zip -d dataset2
        rm wound-dataset.zip
        
        echo "  3/4: Wound Classification..."
        kaggle datasets download -d ibrahimfateen/wound-classification
        unzip -q wound-classification.zip -d dataset3
        rm wound-classification.zip
        
        echo "  4/4: Leprosy Chronic Wound..."
        kaggle datasets download -d orvile/leprosy-chronic-wound-images-co2wounds-v2
        unzip -q leprosy-chronic-wound-images-co2wounds-v2.zip -d dataset4
        rm leprosy-chronic-wound-images-co2wounds-v2.zip
        
        echo "✅ All datasets downloaded!"
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Download Complete!"
echo "=========================================="
echo ""
echo "📁 Files are in: $(pwd)"
echo ""
echo "Next steps:"
echo "1. Check the downloaded files"
echo "2. Organize into images/ and masks/ folders if needed"
echo "3. Run: python ../train_wound_model.py"
echo ""

# Show what was downloaded
echo "Downloaded files:"
ls -lh
echo ""

# Check structure
echo "Checking structure..."
if [ -d "images" ] && [ -d "masks" ]; then
    echo "✅ Perfect! Found images/ and masks/ folders"
    echo "   Images: $(ls images | wc -l) files"
    echo "   Masks: $(ls masks | wc -l) files"
elif [ -d "images" ]; then
    echo "⚠️  Found images/ but no masks/ folder"
    echo "   You may need to create masks manually"
else
    echo "⚠️  Dataset structure varies"
    echo "   You may need to reorganize files into:"
    echo "   - images/ (wound photos)"
    echo "   - masks/ (segmentation masks)"
fi

echo ""
echo "=========================================="
