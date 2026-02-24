#!/usr/bin/env python3
"""
Quick script to verify wound dataset quality
Run this to check if masks are correct before training
"""

import os
from pathlib import Path
from PIL import Image
import numpy as np

def verify_dataset(data_dir='./wound_data'):
    """Verify dataset has correct structure and quality"""
    
    print("=" * 60)
    print("Dataset Verification")
    print("=" * 60)
    
    images_dir = Path(data_dir) / 'images'
    masks_dir = Path(data_dir) / 'masks'
    
    # Check directories exist
    if not images_dir.exists():
        print(f"❌ ERROR: {images_dir} does not exist!")
        return False
    
    if not masks_dir.exists():
        print(f"❌ ERROR: {masks_dir} does not exist!")
        return False
    
    print(f"✓ Directories exist")
    
    # Count files
    image_files = sorted(list(images_dir.glob('*.jpg')) + list(images_dir.glob('*.png')))
    mask_files = sorted(list(masks_dir.glob('*.jpg')) + list(masks_dir.glob('*.png')))
    
    print(f"\n1. File Counts:")
    print(f"   Images: {len(image_files)}")
    print(f"   Masks:  {len(mask_files)}")
    
    if len(image_files) == 0:
        print(f"   ❌ ERROR: No images found!")
        return False
    
    if len(mask_files) == 0:
        print(f"   ❌ ERROR: No masks found!")
        return False
    
    if len(image_files) != len(mask_files):
        print(f"   ⚠️  WARNING: Image and mask counts don't match!")
    else:
        print(f"   ✓ Counts match")
    
    # Check first 10 images have corresponding masks
    print(f"\n2. Checking Image-Mask Pairs:")
    matched = 0
    for img_file in image_files[:10]:
        # Try to find corresponding mask
        mask_path = masks_dir / img_file.name
        if not mask_path.exists():
            # Try with different extension
            mask_path = masks_dir / (img_file.stem + '.png')
        if not mask_path.exists():
            mask_path = masks_dir / (img_file.stem + '.jpg')
        
        if mask_path.exists():
            matched += 1
        else:
            print(f"   ❌ No mask for: {img_file.name}")
    
    print(f"   Matched: {matched}/10")
    if matched < 8:
        print(f"   ⚠️  WARNING: Many images missing masks!")
    else:
        print(f"   ✓ Good match rate")
    
    # Check mask quality
    print(f"\n3. Checking Mask Quality:")
    
    masks_with_wounds = 0
    all_black_masks = 0
    grayscale_masks = 0
    
    for mask_file in mask_files[:20]:  # Check first 20
        mask = Image.open(mask_file).convert('L')
        mask_array = np.array(mask)
        
        min_val = mask_array.min()
        max_val = mask_array.max()
        unique_vals = len(np.unique(mask_array))
        wound_pixels = np.sum(mask_array > 128)
        total_pixels = mask_array.size
        wound_ratio = wound_pixels / total_pixels
        
        if max_val == 0:
            all_black_masks += 1
        elif wound_ratio > 0:
            masks_with_wounds += 1
        
        if unique_vals > 10:  # More than 10 unique values = grayscale
            grayscale_masks += 1
    
    print(f"   Masks with wounds: {masks_with_wounds}/20")
    print(f"   All-black masks: {all_black_masks}/20")
    print(f"   Grayscale masks: {grayscale_masks}/20")
    
    if all_black_masks > 5:
        print(f"   ❌ ERROR: Too many all-black masks! Dataset may be corrupted.")
        return False
    
    if masks_with_wounds < 10:
        print(f"   ❌ ERROR: Too few masks with wound pixels! Check dataset.")
        return False
    
    if grayscale_masks > 5:
        print(f"   ⚠️  WARNING: Many grayscale masks. Should be binary (0 or 255).")
    
    print(f"   ✓ Masks look good")
    
    # Show detailed stats for first mask
    print(f"\n4. Sample Mask Analysis:")
    sample_mask_file = mask_files[0]
    mask = Image.open(sample_mask_file).convert('L')
    mask_array = np.array(mask)
    
    print(f"   File: {sample_mask_file.name}")
    print(f"   Size: {mask_array.shape}")
    print(f"   Min value: {mask_array.min()}")
    print(f"   Max value: {mask_array.max()}")
    print(f"   Mean value: {mask_array.mean():.2f}")
    print(f"   Unique values: {len(np.unique(mask_array))}")
    
    wound_pixels = np.sum(mask_array > 128)
    total_pixels = mask_array.size
    wound_ratio = wound_pixels / total_pixels
    
    print(f"   Wound pixels: {wound_pixels}/{total_pixels} ({wound_ratio*100:.2f}%)")
    
    if wound_ratio < 0.001:
        print(f"   ⚠️  WARNING: Very few wound pixels (<0.1%)")
    elif wound_ratio > 0.5:
        print(f"   ⚠️  WARNING: Too many wound pixels (>50%). Mask may be inverted.")
    else:
        print(f"   ✓ Wound ratio looks reasonable")
    
    # Final verdict
    print(f"\n" + "=" * 60)
    print(f"VERDICT:")
    
    if all_black_masks > 5 or masks_with_wounds < 10:
        print(f"❌ DATASET HAS ISSUES - Training will likely fail")
        print(f"\nRecommended actions:")
        print(f"1. Re-download dataset: bash download_recommended.sh")
        print(f"2. Check wound_data/ structure:")
        print(f"   - wound_data/images/ (2208 files)")
        print(f"   - wound_data/masks/ (2208 files)")
        return False
    elif grayscale_masks > 5:
        print(f"⚠️  DATASET MAY HAVE ISSUES - Training might struggle")
        print(f"\nMasks should be binary (pure black/white), not grayscale")
        print(f"Training may still work but Dice coefficient might be lower")
        return True
    else:
        print(f"✓ DATASET LOOKS GOOD - Ready to train!")
        print(f"\nRun: python train_wound_model_efficient.py")
        return True


if __name__ == "__main__":
    import sys
    
    data_dir = './wound_data'
    if len(sys.argv) > 1:
        data_dir = sys.argv[1]
    
    success = verify_dataset(data_dir)
    sys.exit(0 if success else 1)
