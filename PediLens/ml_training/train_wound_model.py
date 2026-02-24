#!/usr/bin/env python3
"""
Wound Segmentation Model Training Script
Trains a U-Net model for wound boundary detection and converts to CoreML
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

# Configuration
CONFIG = {
    'image_size': (512, 512),
    'batch_size': 8,
    'epochs': 50,
    'learning_rate': 0.001,
    'validation_split': 0.2,
    'data_dir': './wound_data',
    'output_dir': './models',
    'model_name': 'WoundSegmentation'
}

def create_unet_model(input_shape=(512, 512, 3), num_classes=1):
    """
    Creates a U-Net architecture for semantic segmentation
    
    Args:
        input_shape: Input image shape (height, width, channels)
        num_classes: Number of output classes (1 for binary segmentation)
    
    Returns:
        Keras Model
    """
    inputs = keras.Input(shape=input_shape)
    
    # Encoder (Contracting Path)
    # Block 1
    conv1 = layers.Conv2D(64, 3, activation='relu', padding='same', kernel_initializer='he_normal')(inputs)
    conv1 = layers.Conv2D(64, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv1)
    pool1 = layers.MaxPooling2D(pool_size=(2, 2))(conv1)
    
    # Block 2
    conv2 = layers.Conv2D(128, 3, activation='relu', padding='same', kernel_initializer='he_normal')(pool1)
    conv2 = layers.Conv2D(128, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv2)
    pool2 = layers.MaxPooling2D(pool_size=(2, 2))(conv2)
    
    # Block 3
    conv3 = layers.Conv2D(256, 3, activation='relu', padding='same', kernel_initializer='he_normal')(pool2)
    conv3 = layers.Conv2D(256, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv3)
    pool3 = layers.MaxPooling2D(pool_size=(2, 2))(conv3)
    
    # Block 4
    conv4 = layers.Conv2D(512, 3, activation='relu', padding='same', kernel_initializer='he_normal')(pool3)
    conv4 = layers.Conv2D(512, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv4)
    drop4 = layers.Dropout(0.5)(conv4)
    pool4 = layers.MaxPooling2D(pool_size=(2, 2))(drop4)
    
    # Bottleneck
    conv5 = layers.Conv2D(1024, 3, activation='relu', padding='same', kernel_initializer='he_normal')(pool4)
    conv5 = layers.Conv2D(1024, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv5)
    drop5 = layers.Dropout(0.5)(conv5)
    
    # Decoder (Expanding Path)
    # Block 6
    up6 = layers.Conv2D(512, 2, activation='relu', padding='same', kernel_initializer='he_normal')(
        layers.UpSampling2D(size=(2, 2))(drop5))
    merge6 = layers.concatenate([drop4, up6], axis=3)
    conv6 = layers.Conv2D(512, 3, activation='relu', padding='same', kernel_initializer='he_normal')(merge6)
    conv6 = layers.Conv2D(512, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv6)
    
    # Block 7
    up7 = layers.Conv2D(256, 2, activation='relu', padding='same', kernel_initializer='he_normal')(
        layers.UpSampling2D(size=(2, 2))(conv6))
    merge7 = layers.concatenate([conv3, up7], axis=3)
    conv7 = layers.Conv2D(256, 3, activation='relu', padding='same', kernel_initializer='he_normal')(merge7)
    conv7 = layers.Conv2D(256, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv7)
    
    # Block 8
    up8 = layers.Conv2D(128, 2, activation='relu', padding='same', kernel_initializer='he_normal')(
        layers.UpSampling2D(size=(2, 2))(conv7))
    merge8 = layers.concatenate([conv2, up8], axis=3)
    conv8 = layers.Conv2D(128, 3, activation='relu', padding='same', kernel_initializer='he_normal')(merge8)
    conv8 = layers.Conv2D(128, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv8)
    
    # Block 9
    up9 = layers.Conv2D(64, 2, activation='relu', padding='same', kernel_initializer='he_normal')(
        layers.UpSampling2D(size=(2, 2))(conv8))
    merge9 = layers.concatenate([conv1, up9], axis=3)
    conv9 = layers.Conv2D(64, 3, activation='relu', padding='same', kernel_initializer='he_normal')(merge9)
    conv9 = layers.Conv2D(64, 3, activation='relu', padding='same', kernel_initializer='he_normal')(conv9)
    
    # Output layer
    outputs = layers.Conv2D(num_classes, 1, activation='sigmoid')(conv9)
    
    model = keras.Model(inputs=inputs, outputs=outputs)
    
    return model


def dice_coefficient(y_true, y_pred, smooth=1):
    """
    Dice coefficient for evaluating segmentation quality
    """
    y_true_f = tf.keras.backend.flatten(y_true)
    y_pred_f = tf.keras.backend.flatten(y_pred)
    intersection = tf.keras.backend.sum(y_true_f * y_pred_f)
    return (2. * intersection + smooth) / (tf.keras.backend.sum(y_true_f) + tf.keras.backend.sum(y_pred_f) + smooth)


def dice_loss(y_true, y_pred):
    """
    Dice loss function (1 - dice coefficient)
    """
    return 1 - dice_coefficient(y_true, y_pred)


def load_dataset(data_dir, image_size):
    """
    Load wound images and segmentation masks
    
    Expected directory structure:
    data_dir/
        images/
            image001.jpg
            image002.jpg
            ...
        masks/
            image001.png
            image002.png
            ...
    """
    images_dir = Path(data_dir) / 'images'
    masks_dir = Path(data_dir) / 'masks'
    
    image_files = sorted(list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')))
    
    images = []
    masks = []
    
    print(f"Loading {len(image_files)} images...")
    
    for img_path in image_files:
        # Load image
        img = Image.open(img_path).convert('RGB')
        img = img.resize(image_size)
        img_array = np.array(img) / 255.0  # Normalize to [0, 1]
        images.append(img_array)
        
        # Load corresponding mask
        mask_path = masks_dir / img_path.name
        if mask_path.exists():
            mask = Image.open(mask_path).convert('L')  # Grayscale
            mask = mask.resize(image_size)
            mask_array = np.array(mask) / 255.0  # Normalize to [0, 1]
            mask_array = np.expand_dims(mask_array, axis=-1)  # Add channel dimension
            masks.append(mask_array)
        else:
            print(f"Warning: Mask not found for {img_path.name}")
            # Create empty mask
            masks.append(np.zeros((*image_size, 1)))
    
    return np.array(images), np.array(masks)


def augment_data(images, masks):
    """
    Apply data augmentation to increase dataset size
    """
    augmented_images = []
    augmented_masks = []
    
    for img, mask in zip(images, masks):
        # Original
        augmented_images.append(img)
        augmented_masks.append(mask)
        
        # Horizontal flip
        augmented_images.append(np.fliplr(img))
        augmented_masks.append(np.fliplr(mask))
        
        # Vertical flip
        augmented_images.append(np.flipud(img))
        augmented_masks.append(np.flipud(mask))
        
        # Rotation 90 degrees
        augmented_images.append(np.rot90(img))
        augmented_masks.append(np.rot90(mask))
    
    return np.array(augmented_images), np.array(augmented_masks)


def train_model(config):
    """
    Main training function
    """
    print("=" * 50)
    print("Wound Segmentation Model Training")
    print("=" * 50)
    
    # Create output directory
    os.makedirs(config['output_dir'], exist_ok=True)
    
    # Load dataset
    print("\n1. Loading dataset...")
    images, masks = load_dataset(config['data_dir'], config['image_size'])
    print(f"   Loaded {len(images)} images")
    
    # Augment data
    print("\n2. Augmenting data...")
    images, masks = augment_data(images, masks)
    print(f"   Dataset size after augmentation: {len(images)} images")
    
    # Split into train and validation
    split_idx = int(len(images) * (1 - config['validation_split']))
    train_images, val_images = images[:split_idx], images[split_idx:]
    train_masks, val_masks = masks[:split_idx], masks[split_idx:]
    
    print(f"   Training set: {len(train_images)} images")
    print(f"   Validation set: {len(val_images)} images")
    
    # Create model
    print("\n3. Creating U-Net model...")
    model = create_unet_model(
        input_shape=(*config['image_size'], 3),
        num_classes=1
    )
    
    # Compile model
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=config['learning_rate']),
        loss=dice_loss,
        metrics=['accuracy', dice_coefficient]
    )
    
    print(f"   Model parameters: {model.count_params():,}")
    
    # Callbacks
    callbacks = [
        keras.callbacks.ModelCheckpoint(
            os.path.join(config['output_dir'], 'best_model.h5'),
            save_best_only=True,
            monitor='val_loss'
        ),
        keras.callbacks.EarlyStopping(
            patience=10,
            monitor='val_loss',
            restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            factor=0.5,
            patience=5,
            monitor='val_loss'
        )
    ]
    
    # Train model
    print("\n4. Training model...")
    history = model.fit(
        train_images, train_masks,
        batch_size=config['batch_size'],
        epochs=config['epochs'],
        validation_data=(val_images, val_masks),
        callbacks=callbacks
    )
    
    # Save final model
    model_path = os.path.join(config['output_dir'], f"{config['model_name']}.h5")
    model.save(model_path)
    print(f"\n5. Model saved to {model_path}")
    
    # Save training history
    history_path = os.path.join(config['output_dir'], 'training_history.json')
    with open(history_path, 'w') as f:
        json.dump(history.history, f)
    
    return model, history


def convert_to_coreml(model, config):
    """
    Convert trained Keras model to CoreML format
    """
    print("\n6. Converting to CoreML...")
    
    # Convert to CoreML
    coreml_model = ct.convert(
        model,
        inputs=[ct.ImageType(
            name="image",
            shape=(1, *config['image_size'], 3),
            scale=1/255.0,  # Normalize input
            bias=[0, 0, 0]
        )],
        outputs=[ct.ImageType(name="segmentation_mask")],
        minimum_deployment_target=ct.target.iOS15
    )
    
    # Set model metadata
    coreml_model.author = "PediLens Team"
    coreml_model.short_description = "Wound boundary segmentation model"
    coreml_model.version = "1.0"
    
    # Save CoreML model
    coreml_path = os.path.join(config['output_dir'], f"{config['model_name']}.mlmodel")
    coreml_model.save(coreml_path)
    
    print(f"   CoreML model saved to {coreml_path}")
    print(f"   Model size: {os.path.getsize(coreml_path) / (1024*1024):.2f} MB")
    
    return coreml_model


if __name__ == "__main__":
    print("Starting wound segmentation model training...")
    print(f"TensorFlow version: {tf.__version__}")
    print(f"GPU available: {tf.config.list_physical_devices('GPU')}")
    
    # Train model
    model, history = train_model(CONFIG)
    
    # Convert to CoreML
    coreml_model = convert_to_coreml(model, CONFIG)
    
    print("\n" + "=" * 50)
    print("Training complete!")
    print("=" * 50)
    print(f"\nNext steps:")
    print(f"1. Copy {CONFIG['model_name']}.mlmodel to PediLens Xcode project")
    print(f"2. Add to project target")
    print(f"3. Update WoundDetectionService to use the model")
