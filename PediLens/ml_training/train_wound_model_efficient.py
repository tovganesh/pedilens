#!/usr/bin/env python3
"""
Memory-Efficient Wound Segmentation Model Training
Uses data generators to avoid loading all images into RAM
Works on Google Colab free tier (~12 GB RAM)
"""

import os
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import coremltools as ct
from PIL import Image
import json
from pathlib import Path

# Configuration - Optimized for Colab free tier
CONFIG = {
    'image_size': (256, 256),  # Reduced from 512 to save memory
    'batch_size': 4,            # Small batch size
    'epochs': 50,
    'learning_rate': 0.0001,    # Reduced from 0.001 to prevent collapse
    'validation_split': 0.2,
    'data_dir': './wound_data',
    'output_dir': './models',
    'model_name': 'WoundSegmentation',
    'use_augmentation': True,
}

print("=" * 60)
print("Memory-Efficient Wound Segmentation Training")
print("=" * 60)
print(f"\nConfiguration:")
for key, value in CONFIG.items():
    print(f"  {key}: {value}")
print()

def create_unet_model(input_shape=(256, 256, 3), num_classes=1):
    """
    Creates a U-Net architecture (slightly smaller for memory efficiency)
    """
    inputs = keras.Input(shape=input_shape)
    
    # Encoder
    conv1 = layers.Conv2D(32, 3, activation='relu', padding='same')(inputs)
    conv1 = layers.Conv2D(32, 3, activation='relu', padding='same')(conv1)
    pool1 = layers.MaxPooling2D(pool_size=(2, 2))(conv1)
    
    conv2 = layers.Conv2D(64, 3, activation='relu', padding='same')(pool1)
    conv2 = layers.Conv2D(64, 3, activation='relu', padding='same')(conv2)
    pool2 = layers.MaxPooling2D(pool_size=(2, 2))(conv2)
    
    conv3 = layers.Conv2D(128, 3, activation='relu', padding='same')(pool2)
    conv3 = layers.Conv2D(128, 3, activation='relu', padding='same')(conv3)
    pool3 = layers.MaxPooling2D(pool_size=(2, 2))(conv3)
    
    conv4 = layers.Conv2D(256, 3, activation='relu', padding='same')(pool3)
    conv4 = layers.Conv2D(256, 3, activation='relu', padding='same')(conv4)
    drop4 = layers.Dropout(0.5)(conv4)
    pool4 = layers.MaxPooling2D(pool_size=(2, 2))(drop4)
    
    # Bottleneck
    conv5 = layers.Conv2D(512, 3, activation='relu', padding='same')(pool4)
    conv5 = layers.Conv2D(512, 3, activation='relu', padding='same')(conv5)
    drop5 = layers.Dropout(0.5)(conv5)
    
    # Decoder
    up6 = layers.Conv2D(256, 2, activation='relu', padding='same')(layers.UpSampling2D(size=(2, 2))(drop5))
    merge6 = layers.concatenate([drop4, up6], axis=3)
    conv6 = layers.Conv2D(256, 3, activation='relu', padding='same')(merge6)
    conv6 = layers.Conv2D(256, 3, activation='relu', padding='same')(conv6)
    
    up7 = layers.Conv2D(128, 2, activation='relu', padding='same')(layers.UpSampling2D(size=(2, 2))(conv6))
    merge7 = layers.concatenate([conv3, up7], axis=3)
    conv7 = layers.Conv2D(128, 3, activation='relu', padding='same')(merge7)
    conv7 = layers.Conv2D(128, 3, activation='relu', padding='same')(conv7)
    
    up8 = layers.Conv2D(64, 2, activation='relu', padding='same')(layers.UpSampling2D(size=(2, 2))(conv7))
    merge8 = layers.concatenate([conv2, up8], axis=3)
    conv8 = layers.Conv2D(64, 3, activation='relu', padding='same')(merge8)
    conv8 = layers.Conv2D(64, 3, activation='relu', padding='same')(conv8)
    
    up9 = layers.Conv2D(32, 2, activation='relu', padding='same')(layers.UpSampling2D(size=(2, 2))(conv8))
    merge9 = layers.concatenate([conv1, up9], axis=3)
    conv9 = layers.Conv2D(32, 3, activation='relu', padding='same')(merge9)
    conv9 = layers.Conv2D(32, 3, activation='relu', padding='same')(conv9)
    
    outputs = layers.Conv2D(num_classes, 1, activation='sigmoid')(conv9)
    
    model = keras.Model(inputs=inputs, outputs=outputs)
    return model


def dice_coefficient(y_true, y_pred, smooth=1):
    """Dice coefficient metric"""
    # Cast to float32 to ensure type consistency
    y_true = tf.cast(y_true, tf.float32)
    y_pred = tf.cast(y_pred, tf.float32)
    
    y_true_f = tf.keras.backend.flatten(y_true)
    y_pred_f = tf.keras.backend.flatten(y_pred)
    intersection = tf.keras.backend.sum(y_true_f * y_pred_f)
    return (2. * intersection + smooth) / (tf.keras.backend.sum(y_true_f) + tf.keras.backend.sum(y_pred_f) + smooth)


def dice_loss(y_true, y_pred):
    """Dice loss function with better handling for small objects"""
    return 1 - dice_coefficient(y_true, y_pred)


def focal_loss(y_true, y_pred, alpha=0.25, gamma=2.0):
    """
    Focal loss - focuses on hard examples
    Helps with extreme class imbalance
    """
    y_true = tf.cast(y_true, tf.float32)
    y_pred = tf.cast(y_pred, tf.float32)
    
    # Clip predictions to prevent log(0)
    y_pred = tf.clip_by_value(y_pred, 1e-7, 1 - 1e-7)
    
    # Calculate focal loss for positive and negative classes separately
    # Positive class (wounds) - use alpha weighting
    pos_loss = -alpha * tf.pow(1 - y_pred, gamma) * y_true * tf.math.log(y_pred)
    
    # Negative class (background) - use (1-alpha) weighting
    neg_loss = -(1 - alpha) * tf.pow(y_pred, gamma) * (1 - y_true) * tf.math.log(1 - y_pred)
    
    focal = pos_loss + neg_loss
    
    return tf.reduce_mean(focal)


def combined_loss(y_true, y_pred):
    """
    Combined loss function that handles extreme class imbalance
    Uses focal loss + dice loss (both designed for imbalanced data)
    Heavily weights dice loss since that's what we care about
    """
    # Cast to float32
    y_true = tf.cast(y_true, tf.float32)
    y_pred = tf.cast(y_pred, tf.float32)
    
    # Focal loss - automatically handles class imbalance
    # Use high alpha (0.9) to heavily weight positive class (wounds)
    focal = focal_loss(y_true, y_pred, alpha=0.9, gamma=2.5)
    
    # Dice loss - good for segmentation
    dice = dice_loss(y_true, y_pred)
    
    # Weight dice much more heavily (5:1 ratio)
    # This forces the model to optimize for Dice coefficient
    return focal + 5.0 * dice


def create_data_generator(data_dir, image_size, batch_size, validation_split=0.2, subset='training'):
    """
    Creates a memory-efficient data generator using tf.keras.preprocessing
    """
    images_dir = Path(data_dir) / 'images'
    masks_dir = Path(data_dir) / 'masks'
    
    # Get list of image files
    image_files = sorted(list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')))
    
    # Split into train/val
    split_idx = int(len(image_files) * (1 - validation_split))
    if subset == 'training':
        image_files = image_files[:split_idx]
    else:
        image_files = image_files[split_idx:]
    
    print(f"  {subset.capitalize()} set: {len(image_files)} images")
    
    def generator():
        while True:
            # Shuffle for each epoch
            file_list = image_files.copy()
            np.random.shuffle(file_list)
            
            for i in range(0, len(file_list), batch_size):
                batch_files = file_list[i:i+batch_size]
                batch_images = []
                batch_masks = []
                
                for img_path in batch_files:
                    # Load and preprocess image
                    img = Image.open(img_path).convert('RGB')
                    img = img.resize(image_size)
                    img_array = np.array(img) / 255.0
                    
                    # Load mask
                    mask_path = masks_dir / img_path.name
                    # Try different extensions
                    if not mask_path.exists():
                        mask_path = masks_dir / img_path.stem
                        # Try with different extensions
                        for ext in ['.png', '.jpg', '.jpeg', '.PNG', '.JPG']:
                            test_path = masks_dir / (img_path.stem + ext)
                            if test_path.exists():
                                mask_path = test_path
                                break
                    
                    if mask_path.exists():
                        mask = Image.open(mask_path).convert('L')
                        mask = mask.resize(image_size)
                        mask_array = np.array(mask) / 255.0
                        # Binarize mask (threshold at 0.5)
                        mask_array = (mask_array > 0.5).astype(np.float32)
                        mask_array = np.expand_dims(mask_array, axis=-1)
                    else:
                        print(f"Warning: Mask not found for {img_path.name}")
                        mask_array = np.zeros((*image_size, 1), dtype=np.float32)
                    
                    # Optional: Apply augmentation
                    if CONFIG['use_augmentation'] and subset == 'training' and np.random.random() > 0.5:
                        # Random horizontal flip
                        if np.random.random() > 0.5:
                            img_array = np.fliplr(img_array)
                            mask_array = np.fliplr(mask_array)
                        
                        # Random vertical flip
                        if np.random.random() > 0.5:
                            img_array = np.flipud(img_array)
                            mask_array = np.flipud(mask_array)
                    
                    batch_images.append(img_array)
                    batch_masks.append(mask_array)
                
                # Ensure float32 dtype for TensorFlow compatibility
                yield np.array(batch_images, dtype=np.float32), np.array(batch_masks, dtype=np.float32)
    
    return generator


def train_model(config):
    """Main training function using data generators"""
    print("\n" + "=" * 60)
    print("Starting Training")
    print("=" * 60)
    
    # Create output directory
    os.makedirs(config['output_dir'], exist_ok=True)
    
    # Count total images
    images_dir = Path(config['data_dir']) / 'images'
    total_images = len(list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')))
    
    print(f"\n1. Dataset Info:")
    print(f"   Total images: {total_images}")
    print(f"   Image size: {config['image_size']}")
    print(f"   Batch size: {config['batch_size']}")
    
    # Calculate steps
    train_size = int(total_images * (1 - config['validation_split']))
    val_size = total_images - train_size
    steps_per_epoch = train_size // config['batch_size']
    validation_steps = val_size // config['batch_size']
    
    print(f"\n2. Training Setup:")
    print(f"   Training samples: {train_size}")
    print(f"   Validation samples: {val_size}")
    print(f"   Steps per epoch: {steps_per_epoch}")
    print(f"   Validation steps: {validation_steps}")
    
    # Verify data before training
    print(f"\n3. Verifying Data:")
    images_dir = Path(config['data_dir']) / 'images'
    masks_dir = Path(config['data_dir']) / 'masks'
    image_files = sorted(list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')))
    
    masks_found = 0
    for img_file in image_files[:10]:  # Check first 10
        mask_path = masks_dir / img_file.name
        if not mask_path.exists():
            # Try with different extension
            mask_path = masks_dir / (img_file.stem + '.png')
        if mask_path.exists():
            masks_found += 1
            # Check if mask has wound pixels
            mask = Image.open(mask_path).convert('L')
            mask_array = np.array(mask)
            wound_pixels = np.sum(mask_array > 128)
            total_pixels = mask_array.size
            wound_ratio = wound_pixels / total_pixels
            if masks_found == 1:  # Print first one
                print(f"   Sample mask: {mask_path.name}")
                print(f"   Wound pixels: {wound_pixels}/{total_pixels} ({wound_ratio*100:.1f}%)")
    
    print(f"   Masks found: {masks_found}/10 samples checked")
    if masks_found < 5:
        print(f"   ⚠️  WARNING: Few masks found! Check your data structure.")
        print(f"   Expected: wound_data/masks/ with same filenames as images/")
    
    # Create data generators
    print(f"\n4. Creating Data Generators:")
    train_gen = create_data_generator(
        config['data_dir'],
        config['image_size'],
        config['batch_size'],
        config['validation_split'],
        subset='training'
    )
    
    val_gen = create_data_generator(
        config['data_dir'],
        config['image_size'],
        config['batch_size'],
        config['validation_split'],
        subset='validation'
    )
    
    # Create model
    print(f"\n5. Creating Model:")
    model = create_unet_model(
        input_shape=(*config['image_size'], 3),
        num_classes=1
    )
    
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=config['learning_rate']),
        loss=combined_loss,  # Use combined loss instead of just dice_loss
        metrics=['accuracy', dice_coefficient]
    )
    
    print(f"   Model parameters: {model.count_params():,}")
    
    # Callbacks
    callbacks = [
        keras.callbacks.ModelCheckpoint(
            os.path.join(config['output_dir'], 'best_model.h5'),
            save_best_only=True,
            monitor='val_dice_coefficient',  # Monitor Dice instead of loss
            mode='max',  # We want to maximize Dice
            verbose=1
        ),
        keras.callbacks.EarlyStopping(
            patience=15,  # Increased patience for Dice to improve
            monitor='val_dice_coefficient',
            mode='max',
            restore_best_weights=True,
            verbose=1
        ),
        keras.callbacks.ReduceLROnPlateau(
            factor=0.5,
            patience=5,
            monitor='val_dice_coefficient',
            mode='max',
            verbose=1
        )
    ]
    
    # Train
    print(f"\n6. Training Model:")
    print(f"   This will take approximately {config['epochs'] * steps_per_epoch * config['batch_size'] / 60:.0f} minutes")
    print()
    
    history = model.fit(
        train_gen(),
        steps_per_epoch=steps_per_epoch,
        epochs=config['epochs'],
        validation_data=val_gen(),
        validation_steps=validation_steps,
        callbacks=callbacks,
        verbose=1
    )
    
    # Save final model
    model_path = os.path.join(config['output_dir'], f"{config['model_name']}.h5")
    model.save(model_path)
    print(f"\n7. Model saved to {model_path}")
    
    # Save history
    history_path = os.path.join(config['output_dir'], 'training_history.json')
    with open(history_path, 'w') as f:
        history_dict = {}
        for key, value in history.history.items():
            history_dict[key] = [float(v) for v in value]
        json.dump(history_dict, f, indent=2)
    
    return model, history


def convert_to_coreml(model, config):
    """Convert to CoreML format"""
    print(f"\n8. Converting to CoreML:")
    
    # Load the saved model to ensure it's in the right format
    model_path = os.path.join(config['output_dir'], f"{config['model_name']}.h5")
    loaded_model = keras.models.load_model(
        model_path,
        custom_objects={
            'dice_loss': dice_loss,
            'dice_coefficient': dice_coefficient,
            'focal_loss': focal_loss,
            'combined_loss': combined_loss
        },
        compile=False  # Don't compile, we just need the architecture
    )
    
    try:
        # Convert with proper ImageType input for Vision framework
        print("   Converting with ImageType for Vision framework...")
        coreml_model = ct.convert(
            loaded_model,
            source='tensorflow',
            inputs=[ct.ImageType(
                name="image",
                shape=(1, config['image_size'][0], config['image_size'][1], 3),
                scale=1.0/255.0,  # Normalize to [0, 1]
                bias=[0, 0, 0],
                color_layout=ct.colorlayout.RGB
            )],
            # Output as MultiArray (more compatible for segmentation)
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.iOS15,
            compute_precision=ct.precision.FLOAT16  # Smaller model size
        )
        print("   ✓ Conversion successful with ImageType")
    except Exception as e:
        print(f"   Error: Conversion failed: {e}")
        print(f"   Please run fix_model_conversion.py to fix the model")
        raise
    
    coreml_model.author = "PediLens Team"
    coreml_model.short_description = "Wound boundary segmentation model"
    coreml_model.version = "1.0"
    
    # Use .mlpackage extension for mlprogram format
    coreml_path = os.path.join(config['output_dir'], f"{config['model_name']}.mlpackage")
    coreml_model.save(coreml_path)
    
    print(f"   CoreML model saved to {coreml_path}")
    
    # Calculate directory size for mlpackage
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(coreml_path):
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            total_size += os.path.getsize(filepath)
    
    print(f"   Model size: {total_size / (1024*1024):.2f} MB")
    
    return coreml_model


if __name__ == "__main__":
    print(f"TensorFlow version: {tf.__version__}")
    print(f"GPU available: {len(tf.config.list_physical_devices('GPU')) > 0}")
    
    # Check memory
    try:
        import psutil
        mem = psutil.virtual_memory()
        print(f"Available RAM: {mem.available / (1024**3):.1f} GB / {mem.total / (1024**3):.1f} GB")
    except:
        pass
    
    # Train model
    model, history = train_model(CONFIG)
    
    # Convert to CoreML
    coreml_model = convert_to_coreml(model, CONFIG)
    
    print("\n" + "=" * 60)
    print("Training Complete!")
    print("=" * 60)
    print(f"\nFinal Metrics:")
    print(f"  Training Loss: {history.history['loss'][-1]:.4f}")
    print(f"  Validation Loss: {history.history['val_loss'][-1]:.4f}")
    print(f"  Training Dice: {history.history['dice_coefficient'][-1]:.4f}")
    print(f"  Validation Dice: {history.history['val_dice_coefficient'][-1]:.4f}")
    print(f"\nNext steps:")
    print(f"1. Copy {CONFIG['model_name']}.mlpackage to PediLens Xcode project")
    print(f"2. Add to project target")
    print(f"3. Build and test!")
    print(f"\nCommand to copy:")
    print(f"   cp -r models/{CONFIG['model_name']}.mlpackage ../PediLens/PediLens/Resources/")
