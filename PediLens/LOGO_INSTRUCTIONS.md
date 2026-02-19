# PediLens Logo Instructions

## Logo Design

The PediLens logo features:
- **Blue gradient background** - Professional medical app aesthetic
- **Foot outline with toes** - Represents podiatric/foot care focus
- **Camera lens overlay** - Represents the imaging/photography aspect
- **Measurement marks** - Represents the measurement/tracking functionality

## Converting SVG to iOS App Icons

### Option 1: Using Online Tools (Easiest)
1. Go to https://appicon.co  
2. Upload `logo.svg`
3. Download the generated AppIcon.appiconset
4. Replace the contents of `PediLens/PediLens/Resources/Assets.xcassets/AppIcon.appiconset/`

### Option 2: Using macOS Preview
1. Open `logo.svg` in Safari
2. Take a screenshot or export as PNG at 1024x1024
3. Open in Preview
4. Use Tools > Adjust Size to create different sizes:
   - 1024x1024 (App Store)
   - 180x180 (iPhone 3x)
   - 120x120 (iPhone 2x)
   - 167x167 (iPad Pro)
   - 152x152 (iPad 2x)
   - 76x76 (iPad 1x)
   - 60x60 (iPhone settings)
   - 40x40 (Spotlight)
   - 29x29 (Settings)
   - 20x20 (Notifications)

### Option 3: Using ImageMagick (Command Line)
```bash
# Install ImageMagick if not already installed
brew install imagemagick

# Convert SVG to PNG at different sizes
convert -background none -resize 1024x1024 logo.svg AppIcon-1024.png
convert -background none -resize 180x180 logo.svg AppIcon-180.png
convert -background none -resize 120x120 logo.svg AppIcon-120.png
convert -background none -resize 167x167 logo.svg AppIcon-167.png
convert -background none -resize 152x152 logo.svg AppIcon-152.png
convert -background none -resize 76x76 logo.svg AppIcon-76.png
convert -background none -resize 60x60 logo.svg AppIcon-60.png
convert -background none -resize 40x40 logo.svg AppIcon-40.png
convert -background none -resize 29x29 logo.svg AppIcon-29.png
convert -background none -resize 20x20 logo.svg AppIcon-20.png
```

## Required iOS App Icon Sizes

According to Apple's Human Interface Guidelines, you need:

| Size | Usage | Filename |
|------|-------|----------|
| 1024x1024 | App Store | AppIcon-1024.png |
| 180x180 | iPhone 3x | AppIcon-60@3x.png |
| 120x120 | iPhone 2x | AppIcon-60@2x.png |
| 167x167 | iPad Pro | AppIcon-83.5@2x.png |
| 152x152 | iPad 2x | AppIcon-76@2x.png |
| 76x76 | iPad 1x | AppIcon-76.png |
| 60x60 | iPhone settings | AppIcon-60.png |
| 40x40 | Spotlight | AppIcon-40.png |
| 29x29 | Settings | AppIcon-29.png |
| 20x20 | Notifications | AppIcon-20.png |

## Customization

To customize the logo colors, edit `logo.svg`:

- **Background gradient**: Change `#007AFF` and `#0051D5` (lines 5-6)
- **Foot color**: Change `#FFFFFF` and `#E8E8E8` (lines 8-9)
- **Lens color**: Change `#007AFF` in the camera lens group (lines 42-48)

## Alternative: SF Symbols Approach

If you prefer using SF Symbols for a simpler icon:

1. Open Xcode
2. Go to Assets.xcassets > AppIcon
3. Use SF Symbol: `camera.viewfinder` or `camera.metering.center.weighted`
4. Combine with `figure.walk` or custom foot icon

## Design Rationale

- **Blue**: Medical/healthcare standard, trustworthy
- **Foot + Camera**: Clearly communicates the app's purpose
- **Measurement marks**: Emphasizes precision and tracking
- **Clean, modern**: Professional appearance suitable for medical use
- **High contrast**: Ensures visibility at all sizes

## Next Steps

1. Convert the SVG to required PNG sizes
2. Add to Xcode project in AppIcon.appiconset
3. Test on device to ensure clarity at all sizes
4. Consider creating a simplified version for smaller sizes (20x20, 29x29)
