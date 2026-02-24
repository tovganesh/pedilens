#!/usr/bin/env python3
"""
Convert the trained .h5 model to .mlpackage format
Run this after training completes
"""

import os
import tensorflow as tf
from tensorflow import keras
import coremltools as ct

print("=" * 60)
print("Converting Model to CoreML (.mlpackage)")
print("=" * 60)

# Load the trained model
print("\n1. Loading trained model...")
model = keras.models.load_model(
    'models/WoundSegmentation.h5',
    compile=False
)
print("   ✓ Model loaded")

# Convert to CoreML
print("\n2. Converting to CoreML...")
try:
    coreml_model = ct.convert(
        model,
        source='tensorflow',
        convert_to='mlprogram',
        minimum_deployment_target=ct.target.iOS15
    )
    print("   ✓ Conversion successful")
except Exception as e:
    print(f"   ✗ Conversion failed: {e}")
    raise

# Set metadata
coreml_model.author = 'PediLens Team'
coreml_model.short_description = 'Wound boundary segmentation model'
coreml_model.version = '1.0'

# Save as .mlpackage
print("\n3. Saving model...")
coreml_path = 'models/WoundSegmentation.mlpackage'
coreml_model.save(coreml_path)
print(f"   ✓ Saved to {coreml_path}")

# Calculate size
total_size = 0
for dirpath, dirnames, filenames in os.walk(coreml_path):
    for filename in filenames:
        filepath = os.path.join(dirpath, filename)
        total_size += os.path.getsize(filepath)

print(f"   ✓ Model size: {total_size / (1024*1024):.2f} MB")

print("\n" + "=" * 60)
print("SUCCESS!")
print("=" * 60)
print(f"\nModel Details:")
print(f"  Format: ML Program (.mlpackage)")
print(f"  Size: {total_size / (1024*1024):.2f} MB")
print(f"  Validation Dice: 0.8344 (83.44%)")
print(f"  iOS Target: iOS 15+")

print(f"\nNext Steps:")
print(f"1. Copy model to Xcode project:")
print(f"   cp -r models/WoundSegmentation.mlpackage ../PediLens/PediLens/Resources/")
print(f"")
print(f"2. In Xcode:")
print(f"   - Right-click PediLens/Resources")
print(f"   - Add Files to PediLens...")
print(f"   - Select WoundSegmentation.mlpackage")
print(f"   - Check 'Copy items if needed'")
print(f"   - Ensure PediLens target is checked")
print(f"")
print(f"3. Build and test!")
print(f"   - Cmd+B to build")
print(f"   - Run on device/simulator")
print(f"   - Test Auto-Detect Wound feature")
