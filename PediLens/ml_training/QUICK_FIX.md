# Quick Fix for Your System

## Problem
- You have Python 3.14.0 on Apple Silicon (arm64)
- TensorFlow only supports Python 3.8-3.11
- TensorFlow doesn't work with Python 3.14 yet

## Solution: Install Python 3.11

### Option 1: Using Homebrew (Recommended)

```bash
# Install Python 3.11
brew install python@3.11

# Create virtual environment with Python 3.11
cd PediLens/ml_training
python3.11 -m venv venv
source venv/bin/activate

# Verify Python version
python --version  # Should show Python 3.11.x

# Install TensorFlow for Apple Silicon
pip install --upgrade pip
pip install tensorflow-macos==2.13.0
pip install tensorflow-metal==1.0.0

# Install other dependencies
pip install coremltools Pillow opencv-python numpy pandas matplotlib seaborn kaggle
```

### Option 2: Use PyTorch Instead (Works with Python 3.14)

PyTorch has better compatibility with newer Python versions:

```bash
# Use your existing Python 3.14
cd PediLens/ml_training
python3 -m venv venv
source venv/bin/activate

# Install PyTorch (works with Python 3.14)
pip install torch torchvision
pip install -r requirements-pytorch.txt
```

Then I'll create a PyTorch version of the training script for you.

### Option 3: Use Google Colab (No Installation Needed)

Skip local installation entirely:

1. Go to https://colab.research.google.com/
2. Create new notebook
3. Upload the training script
4. Run in cloud with free GPU
5. Download trained model

## Recommended: Install Python 3.11

```bash
# 1. Install Python 3.11 via Homebrew
brew install python@3.11

# 2. Create virtual environment
cd PediLens/ml_training
python3.11 -m venv venv
source venv/bin/activate

# 3. Verify version
python --version  # Should be 3.11.x

# 4. Install dependencies
pip install --upgrade pip
pip install tensorflow-macos==2.13.0 tensorflow-metal==1.0.0
pip install coremltools Pillow opencv-python numpy pandas matplotlib seaborn kaggle

# 5. Test installation
python -c "import tensorflow as tf; print('TensorFlow:', tf.__version__)"
python -c "import coremltools as ct; print('CoreML Tools:', ct.__version__)"
```

## Quick Commands

```bash
# Install Python 3.11
brew install python@3.11

# Setup environment
cd PediLens/ml_training
python3.11 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install tensorflow-macos==2.13.0 tensorflow-metal==1.0.0 coremltools Pillow opencv-python numpy pandas matplotlib seaborn kaggle

# Verify
python -c "import tensorflow as tf; print('✅ TensorFlow:', tf.__version__)"
```

That's it! After this, you can run `python train_wound_model.py`
