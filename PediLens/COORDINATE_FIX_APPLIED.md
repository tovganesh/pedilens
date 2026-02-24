# Coordinate Transformation Fix Applied

## Issues Fixed

### 1. Auto-Detection Boundary Misalignment
The ML model's detected boundary was appearing offset from the actual wound because coordinate transformations didn't account for aspect-fit letterboxing.

### 2. Manual Trace Points Misalignment
Touch points were appearing in the wrong location because the view-to-image coordinate conversion didn't account for the centering offset created by aspect-fit display.

## Root Cause

When displaying images with `.aspectRatio(contentMode: .fit)`, SwiftUI scales the image to fit within the view while maintaining aspect ratio. This creates letterboxing (black bars) when the image and view have different aspect ratios.

The old code assumed the image filled the entire view:
```swift
// WRONG - doesn't account for letterboxing
let scaleX = viewSize.width / imageSize.width
let scaleY = viewSize.height / imageSize.height
let displayPoint = CGPoint(x: imagePoint.x * scaleX, y: imagePoint.y * scaleY)
```

## Solution Applied

### 1. Created CoordinateTransform.swift
New utility file with helper functions for aspect-fit coordinate transformations:

- `aspectFitTransform(in:)` - Calculates displayed size, offset, and scale
- `imageToView(point:containerSize:)` - Transforms image coords to view coords
- `viewToImage(point:containerSize:)` - Transforms view coords to image coords
- `AspectFitGeometry` - Struct that encapsulates all transformation logic

### 2. Updated WoundBoundaryOverlay
Now uses `AspectFitGeometry` to correctly transform boundary points from image space to view space, accounting for letterboxing offset.

### 3. Updated ManualBoundaryTraceView
Fixed all coordinate transformations:
- Drawing traced points: Uses `imageToView()` for correct display
- `addTracePoint()`: Uses `viewToImage()` to convert touch to image coords
- `handleTap()`: Uses `viewToImage()` for tap detection
- `DraggablePoint`: Uses both transformations for dragging

## How It Works

### Aspect-Fit Calculation
```swift
// Calculate scale (use minimum to maintain aspect ratio)
let scaleX = containerSize.width / imageSize.width
let scaleY = containerSize.height / imageSize.height
let scale = min(scaleX, scaleY)  // Key: use minimum!

// Calculate displayed size
let displayedSize = CGSize(
    width: imageSize.width * scale,
    height: imageSize.height * scale
)

// Calculate centering offset
let offset = CGPoint(
    x: (containerSize.width - displayedSize.width) / 2,
    y: (containerSize.height - displayedSize.height) / 2
)
```

### Image to View Transformation
```swift
let viewPoint = CGPoint(
    x: imagePoint.x * scale + offset.x,
    y: imagePoint.y * scale + offset.y
)
```

### View to Image Transformation
```swift
let imagePoint = CGPoint(
    x: (viewPoint.x - offset.x) / scale,
    y: (viewPoint.y - offset.y) / scale
)
```

## Files Modified

1. **Created**: `PediLens/PediLens/Utilities/CoordinateTransform.swift`
   - New utility for coordinate transformations
   - Handles aspect-fit geometry calculations

2. **Modified**: `PediLens/PediLens/Views/ContentView.swift`
   - `WoundBoundaryOverlay`: Fixed boundary display
   - `ManualBoundaryTraceView`: Fixed drawing and touch handling
   - `handleTap()`: Fixed tap-to-point conversion
   - `addTracePoint()`: Fixed drag-to-trace conversion
   - `DraggablePoint`: Fixed point dragging

## Testing Checklist

Test with different image aspect ratios:

- [ ] **Portrait image** (taller than wide, e.g., 3:4)
  - Should have horizontal letterboxing (black bars on sides)
  - Boundary should align with wound
  - Trace points should appear where you tap

- [ ] **Landscape image** (wider than tall, e.g., 16:9)
  - Should have vertical letterboxing (black bars on top/bottom)
  - Boundary should align with wound
  - Trace points should appear where you tap

- [ ] **Square image** (1:1)
  - Minimal or no letterboxing
  - Boundary should align with wound
  - Trace points should appear where you tap

- [ ] **Different devices**
  - iPhone (various sizes)
  - iPad
  - Different orientations

## Expected Behavior After Fix

### Auto-Detection
1. Take photo of wound
2. Tap "Auto-Detect Wound"
3. Green boundary should appear exactly around the wound
4. No offset or misalignment

### Manual Trace
1. Tap "Manual Trace"
2. Tap or drag on the wound boundary
3. Orange points should appear exactly where you tap/drag
4. Dragging points should follow your finger precisely
5. Zoomed loupe should show the correct area

## Build Instructions

1. Add `CoordinateTransform.swift` to Xcode project:
   - Right-click `PediLens/Utilities` folder
   - Add Files to PediLens...
   - Select `CoordinateTransform.swift`
   - Ensure "PediLens" target is checked

2. Build project:
   ```bash
   xcodebuild -project PediLens.xcodeproj -scheme PediLens
   # Or in Xcode: Cmd+B
   ```

3. Test on device or simulator

## Troubleshooting

### If boundary still appears offset:
1. Check that `CoordinateTransform.swift` is added to the target
2. Verify the image is displayed with `.aspectRatio(contentMode: .fit)`
3. Check console for any errors during coordinate transformation

### If points appear in wrong location:
1. Verify `AspectFitGeometry` is being used in all transformations
2. Check that `viewSize` parameter matches the actual view size
3. Ensure `imageSize` is the original image size, not the displayed size

### If dragging doesn't work:
1. Check that `DraggablePoint` is using the updated transformation
2. Verify the hit area (44x44) is positioned correctly
3. Test with larger hit area if needed

## Performance Notes

The coordinate transformations are lightweight calculations (simple arithmetic) and should have negligible performance impact. The `AspectFitGeometry` struct caches the calculated values to avoid redundant calculations.

## Future Improvements

Consider these enhancements:
1. Add visual debug mode to show letterboxing areas
2. Add coordinate validation to detect out-of-bounds points
3. Add unit tests for coordinate transformations
4. Consider caching `AspectFitGeometry` instances for repeated use

## Related Issues

This fix resolves:
- Auto-detected boundaries appearing offset from wounds
- Manual trace points not aligning with touch location
- Dragged points jumping to wrong positions
- Inconsistent behavior across different image aspect ratios

---

**Status**: ✅ Fixed
**Priority**: HIGH (Core functionality)
**Testing**: Required before release
