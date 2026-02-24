#!/usr/bin/env python3
"""
Fix CoreML model conversion to work with Vision framework
Converts the trained model with proper ImageType input
"""

import os
import numpy as np
import tensorflow as tf
from tensorflow import keras
import coremltools as ct

print("=" * 60)
print("Fixing CoreML Model Conversion")
print("=" * 60)

# Configuration
MODEL_PATH = './models/WoundSegmentation.h5'
OUTPUT_PATH = './models/WoundSegmentation_Fixed.mlpackage'
IMAGE_SIZE = (256, 256)

# Custom loss functions (needed to load the model)
def dice_coefficient(y_true, y_pred, smooth=1):
    y_true = tf.cast(y_true, tf.float32)
    y_pred = tf.cast(y_pred, tf.float32)
    y_true_f = tf.keras.backend.flatten(y_true)
    y_pred_f = tf.keras.backend.flatten(y_pred)
    intersection = tf.keras.backend.sum(y_true_f * y_pred_f)
    return (2. * intersection + smooth) / (tf.keras.backend.sum(y_true_f) + tf.keras.backend.sum(y_pred_f) + smooth)

def dice_loss(y_true, y_pred):
    return 1 - dice_coefficient(y_true, y_pred)

def focal_loss(y_true, y_pred, alpha=0.25, gamma=2.0):
    y_true = tf.cast(y_true, tf.float32)
    y_pred = tf.cast(y_pred, tf.float32)
    y_pred = tf.clip_by_value(y_pred, 1e-7, 1 - 1e-7)
    pos_loss = -alpha * tf.pow(1 - y_pred, gamma) * y_true * tf.math.log(y_pred)
    neg_loss = -(1 - alpha) * tf.pow(y_pred, gamma) * (1 - y_true) * tf.math.log(1 - y_pred)
    focal = pos_loss + neg_loss
    return tf.reduce_mean(focal)

def combined_loss(y_true, y_pred):
    y_true = tf.cast(y_true, tf.float32)
    y_pred = tf.cast(y_pred, tf.float32)
    focal = focal_loss(y_true, y_pred, alpha=0.9, gamma=2.5)
    dice = dice_loss(y_true, y_pred)
    return focal + 5.0 * dice

print("\n1. Loading trained model...")
print(f"   Model path: {MODEL_PATH}")

# Load the model
model = keras.models.load_model(
    MODEL_PATH,
    custom_objects={
        'dice_loss': dice_loss,
        'dice_coefficient': dice_coefficient,
        'focal_loss': focal_loss,
        'combined_loss': combined_loss
    },
    compile=False
)

print(f"   ✓ Model loaded successfully")
print(f"   Input shape: {model.input_shape}")
print(f"   Output shape: {model.output_shape}")

print("\n2. Converting to CoreML with proper ImageType input...")

# Get the actual input name from the model
input_name = model.input.name.split(':')[0]  # Remove ':0' suffix if present
print(f"   Model input name: {input_name}")

# Convert with explicit ImageType input for Vision framework compatibility
# Use the actual input name from the model (input_layer)
coreml_model = ct.convert(
    model,
    source='tensorflow',
    inputs=[ct.ImageType(
        name='input_layer',  # Match the TensorFlow model's input name
        shape=(1, IMAGE_SIZE[0], IMAGE_SIZE[1], 3),
        scale=1.0/255.0,  # Normalize to [0, 1]
        bias=[0, 0, 0],
        color_layout=ct.colorlayout.RGB
    )],
    # Don't specify output as ImageType - let it be a MultiArray
    # This is more compatible with segmentation models
    convert_to="mlprogram",
    minimum_deployment_target=ct.target.iOS15,
    compute_precision=ct.precision.FLOAT16  # Use FP16 for smaller model size
)

print("   ✓ Conversion successful")

# Set metadata
coreml_model.author = "PediLens Team"
coreml_model.short_description = "Wound boundary segmentation model (U-Net)"
coreml_model.version = "1.0"
coreml_model.license = "Proprietary"

print("\n3. Saving fixed model...")
coreml_model.save(OUTPUT_PATH)

# Calculate size
total_size = 0
for dirpath, dirnames, filenames in os.walk(OUTPUT_PATH):
    for filename in filenames:
        filepath = os.path.join(dirpath, filename)
        total_size += os.path.getsize(filepath)

print(f"   ✓ Model saved to {OUTPUT_PATH}")
print(f"   Model size: {total_size / (1024*1024):.2f} MB")

print("\n4. Verifying model...")

# Print model spec
spec = coreml_model.get_spec()
print(f"   Model type: {spec.WhichOneof('Type')}")
print(f"   Inputs: {[inp.name for inp in spec.description.input]}")
print(f"   Outputs: {[out.name for out in spec.description.output]}")

# Check input type
for inp in spec.description.input:
    print(f"   Input '{inp.name}' type: {inp.type.WhichOneof('Type')}")
    if inp.type.HasField('imageType'):
        print(f"   ✓ Image type detected - Vision framework compatible!")
        print(f"     Width: {inp.type.imageType.width}")
        print(f"     Height: {inp.type.imageType.height}")
        print(f"     Color space: {inp.type.imageType.colorSpace}")

print("\n" + "=" * 60)
print("Conversion Complete!")
print("=" * 60)

print(f"\nNext steps:")
print(f"1. Copy the fixed model:")
print(f"   cp {OUTPUT_PATH} ../PediLens/PediLens/Resources/WoundSegmentation.mlpackage")
print(f"")
print(f"2. Remove old model (if exists):")
print(f"   rm ../PediLens/PediLens/Resources/WoundSegmentation\\ 2.mlpackage")
print(f"")
print(f"3. Rebuild the app in Xcode")
print(f"")
print(f"The model should now load successfully with Vision framework!")
