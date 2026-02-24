#!/bin/bash
# Script to download wound datasets from Kaggle

echo "=========================================="
echo "Wound Dataset Download Script"
echo "=========================================="
echo ""

# Check if kaggle is installed
if ! command -v kaggle &> /dev/null; then
    echo "Error: Kaggle CLI not found. Installing..."
    pip install kaggle
fi

# Check for Kaggle credentials
if [ ! -f ~/.kaggle/kaggle.json ]; then
    echo "Error: Kaggle credentials not found!"
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

# Create data directory
mkdir -p wound_data
cd wound_data

echo "Available wound datasets:"
echo "1. Diabetic Foot Ulcer (DFUC2020)"
echo "2. Chronic Wound Dataset"
echo "3. Foot Ulcer Segmentation Challenge"
echo ""

# Example: Download DFUC2020 dataset
# Note: Replace with actual dataset identifiers from Kaggle
echo "Searching for wound-related datasets..."
kaggle datasets list -s "diabetic foot ulcer"
echo ""
kaggle datasets list -s "wound segmentation"
echo ""

echo "=========================================="
echo "Manual Download Instructions:"
echo "=========================================="
echo ""
echo "1. Visit Kaggle and search for wound datasets:"
echo "   - https://www.kaggle.com/datasets"
echo "   - Search: 'diabetic foot ulcer'"
echo "   - Search: 'wound segmentation'"
echo "   - Search: 'chronic wound'"
echo ""
echo "2. Popular datasets:"
echo "   - DFUC2020: Diabetic Foot Ulcer Challenge"
echo "   - Medetec Wound Database"
echo "   - Foot Ulcer Segmentation"
echo ""
echo "3. Download format should be:"
echo "   wound_data/"
echo "     images/"
echo "       image001.jpg"
echo "       image002.jpg"
echo "     masks/"
echo "       image001.png"
echo "       image002.png"
echo ""
echo "4. If masks are not provided, you'll need to:"
echo "   - Use annotation tools (LabelMe, CVAT)"
echo "   - Manually segment wound boundaries"
echo "   - Save as binary masks (white=wound, black=background)"
echo ""

# Example download command (uncomment and modify with actual dataset)
# kaggle datasets download -d <username>/<dataset-name>
# unzip <dataset-name>.zip
# rm <dataset-name>.zip

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Organize data into images/ and masks/ folders"
echo "2. Verify data format"
echo "3. Run: python train_wound_model.py"
