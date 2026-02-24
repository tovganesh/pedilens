# ML Training Environment Setup Guide

## Issue: TensorFlow Installation Error

If you're getting `ERROR: Could not find a version that satisfies the requirement tensorflow>=2.13.0`, this is likely because you're on Apple Silicon (M1/M2/M3 Mac).

## Solution Options

### Option 1: TensorFlow for Apple Silicon (Recommended for M1/M2/M3)

```bash
# 1. Create virtual environment with Python 3.10 or 3.11
python3.10 -m venv venv
source venv/bin/activate

# 2. Upgrade pip
pip install --upgrade pip

# 3. Install TensorFlow for macOS
pip install tensorflow-macos==2.13.0
pip install tensorflow-metal==1.0.0

# 4. Install other dependencies
pip install coremltools Pillow opencv-python numpy pandas matplotlib seaborn kaggle
```

### Option 2: PyTorch (Better Compatibility)

PyTorch often works better on Apple Silicon and is easier to install:

```bash
# 1. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 2. Install PyTorch
pip install torch torchvision

# 3. Install other dependencies
pip install -r requirements-pytorch.txt

# 4. Use the PyTorch training script instead
python train_wound_model_pytorch.py
```

### Option 3: Use Google Colab (No Local Setup)

If local installation is problematic, use Google Colab for free GPU training:

1. Go to https://colab.research.google.com/
2. Upload `train_wound_model.py`
3. Upload your dataset
4. Run training in the cloud
5. Download the trained model

## Checking Your System

```bash
# Check if you have Apple Silicon
uname -m
# Output: arm64 = Apple Silicon (M1/M2/M3)
# Output: x86_64 = Intel Mac

# Check Python version
python3 --version
# Recommended: Python 3.10 or 3.11

# Check if TensorFlow is installed
python3 -c "import tensorflow as tf; print(tf.__version__)"
```

## Step-by-Step Installation (Apple Silicon)

### 1. Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Python 3.10

```bash
brew install python@3.10
```

### 3. Create Virtual Environment

```bash
cd PediLens/ml_training
python3.10 -m venv venv
source venv/bin/activate
```

### 4. Install TensorFlow for macOS

```bash
pip install --upgrade pip
pip install tensorflow-macos==2.13.0
pip install tensorflow-metal==1.0.0
```

### 5. Install CoreML Tools

```bash
pip install coremltools
```

### 6. Install Other Dependencies

```bash
pip install Pillow opencv-python numpy pandas matplotlib seaborn kaggle
```

### 7. Verify Installation

```bash
python3 -c "import tensorflow as tf; print('TensorFlow version:', tf.__version__)"
python3 -c "import coremltools as ct; print('CoreML Tools version:', ct.__version__)"
```

## Alternative: Minimal Installation (CoreML Only)

If you just want to use pre-trained models or convert existing models:

```bash
# Only install CoreML tools
pip install coremltools Pillow numpy

# You can convert ONNX models to CoreML without TensorFlow
pip install onnx
```

## Troubleshooting

### Error: "No module named 'tensorflow'"

```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Reinstall TensorFlow
pip uninstall tensorflow tensorflow-macos tensorflow-metal
pip install tensorflow-macos==2.13.0 tensorflow-metal==1.0.0
```

### Error: "Could not find a version that satisfies..."

```bash
# Check Python version (must be 3.8-3.11)
python3 --version

# Try specific version
pip install tensorflow-macos==2.12.0
```

### Error: "Metal device not found"

```bash
# Install Metal plugin
pip install tensorflow-metal==1.0.0

# Verify GPU is available
python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

### Error: "ImportError: numpy.core.multiarray"

```bash
# Reinstall numpy
pip uninstall numpy
pip install numpy==1.24.0
```

## Using Google Colab (Easiest Option)

If local installation is too complex, use Google Colab:

1. **Open Colab**: https://colab.research.google.com/
2. **Create New Notebook**
3. **Upload Training Script**:
   ```python
   from google.colab import files
   uploaded = files.upload()  # Upload train_wound_model.py
   ```

4. **Install Dependencies**:
   ```python
   !pip install coremltools tensorflow
   ```

5. **Upload Dataset**:
   ```python
   from google.colab import drive
   drive.mount('/content/drive')
   # Or upload directly
   uploaded = files.upload()
   ```

6. **Run Training**:
   ```python
   !python train_wound_model.py
   ```

7. **Download Model**:
   ```python
   files.download('models/WoundSegmentation.mlmodel')
   ```

## Recommended Approach by System

### Apple Silicon Mac (M1/M2/M3)
✅ **Best**: TensorFlow-macOS with Metal
- Follow "Option 1" above
- Native performance with GPU acceleration

### Intel Mac
✅ **Best**: Regular TensorFlow
```bash
pip install tensorflow==2.13.0
pip install -r requirements.txt
```

### Linux
✅ **Best**: TensorFlow with CUDA (if GPU available)
```bash
pip install tensorflow==2.13.0
pip install -r requirements.txt
```

### Windows
✅ **Best**: Use WSL2 or Google Colab
- TensorFlow on Windows can be tricky
- WSL2 provides Linux environment
- Or use Colab for simplicity

## Quick Test

After installation, test if everything works:

```bash
python3 << EOF
import tensorflow as tf
import coremltools as ct
import numpy as np
from PIL import Image

print("✅ TensorFlow version:", tf.__version__)
print("✅ CoreML Tools version:", ct.__version__)
print("✅ GPU available:", len(tf.config.list_physical_devices('GPU')) > 0)
print("✅ All dependencies working!")
EOF
```

## Next Steps

Once installation is complete:

1. Download wound dataset from Kaggle
2. Organize data into `wound_data/images` and `wound_data/masks`
3. Run training: `python train_wound_model.py`
4. Copy model to Xcode project

## Support

If you continue to have issues:

1. Check Python version: `python3 --version` (should be 3.8-3.11)
2. Check system architecture: `uname -m`
3. Try PyTorch alternative: `pip install -r requirements-pytorch.txt`
4. Use Google Colab as fallback
5. Check TensorFlow installation guide: https://www.tensorflow.org/install
