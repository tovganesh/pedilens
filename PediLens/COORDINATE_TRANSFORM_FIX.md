# Coordinate Transformation Fix for Wound Boundary Display

## Issues Identified

### Issue 1: Auto-Detection Boundary Misalignment
The ML model outputs coordinates in image space, but when displayed with `.aspectRatio(contentMode: .fit)`, the image may be letterboxed (have black bars), causing a coordinate offset that isn't accounted for.

### Issue 2: Manual Trace Points Misalignment  
Touch coordinates are in view space, but the conversion to image space doesn't account for the letterboxing offset created by `.aspectRatio(contentMode: .fit)`.

## Root Cause

When an image is displayed with:
```swift
Image(uiImage: image)
    .resizable()
    .aspectRatio(contentMode: .fit)
```

The image is scaled to fit within the view while maintaining aspect ratio. This creates:
- **Horizontal letterboxing** if image is taller than view (black bars on left/right)
- **Vertical letterboxing** if image is wider than view (black bars on top/bottom)

Current code transforms coordinates as:
```swift
let scaleX = viewSize.width / imageSize.width
let scaleY = viewSize.height / imageSize.height
let displayPoint = CGPoint(x: imagePoint.x * scaleX, y: imagePoint.y * scaleY)
```

This assumes the image fills the entire view, which is incorrect with `.fit` mode.

## Correct Transformation

Need to calculate:
1. **Actual displayed image size** (after aspect-fit scaling)
2. **Offset** from view origin to image origin (letterbox offset)
3. **Transform** accounting for both scale and offset

### Correct Formula

```swift
// Calculate aspect-fit scale (use minimum to maintain aspect ratio)
let scaleX = viewSize.width / imageSize.width
let scaleY = viewSize.height / imageSize.height
let scale = min(scaleX, scaleY)  // Use minimum to fit

// Calculate actual displayed image size
let displayedImageSize = CGSize(
    width: imageSize.width * scale,
    height: imageSize.height * scale
)

// Calculate offset (centering)
let offsetX = (viewSize.width - displayedImageSize.width) / 2
let offsetY = (viewSize.height - displayedImageSize.height) / 2

// Transform image coordinates to view coordinates
let displayPoint = CGPoint(
    x: imagePoint.x * scale + offsetX,
    y: imagePoint.y * scale + offsetY
)

// Transform view coordinates to image coordinates (inverse)
let imagePoint = CGPoint(
    x: (viewPoint.x - offsetX) / scale,
    y: (viewPoint.y - offsetY) / scale
)
```

## Files to Fix

### 1. `WoundBoundaryOverlay` (Line ~1306)
Displays the detected boundary - needs correct image-to-view transformation.

### 2. `ManualBoundaryTraceView` (Line ~1350)
- Drawing traced points: needs correct image-to-view transformation
- `addTracePoint`: needs correct view-to-image transformation  
- `handleTap`: needs correct view-to-image transformation
- `DraggablePoint`: needs correct transformations in both directions

### 3. `CaptureSessionDetailView` (Line ~600)
The ZStack that overlays the boundary on the image needs proper geometry.

## Implementation Plan

### Step 1: Create Helper Extension
Add a coordinate transformation helper to handle aspect-fit calculations:

```swift
extension CGSize {
    /// Calculate the actual displayed size and offset when using aspectRatio(.fit)
    func aspectFitTransform(in containerSize: CGSize) -> (size: CGSize, offset: CGPoint, scale: CGFloat) {
        let scaleX = containerSize.width / self.width
        let scaleY = containerSize.height / self.height
        let scale = min(scaleX, scaleY)
        
        let displayedSize = CGSize(
            width: self.width * scale,
            height: self.height * scale
        )
        
        let offset = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2,
            y: (containerSize.height - displayedSize.height) / 2
        )
        
        return (displayedSize, offset, scale)
    }
    
    /// Transform point from image space to view space (accounting for aspect-fit)
    func imageToView(point: CGPoint, containerSize: CGSize) -> CGPoint {
        let transform = self.aspectFitTransform(in: containerSize)
        return CGPoint(
            x: point.x * transform.scale + transform.offset.x,
            y: point.y * transform.scale + transform.offset.y
        )
    }
    
    /// Transform point from view space to image space (accounting for aspect-fit)
    func viewToImage(point: CGPoint, containerSize: CGSize) -> CGPoint {
        let transform = self.aspectFitTransform(in: containerSize)
        return CGPoint(
            x: (point.x - transform.offset.x) / transform.scale,
            y: (point.y - transform.offset.y) / transform.scale
        )
    }
}
```

### Step 2: Update WoundBoundaryOverlay
```swift
struct WoundBoundaryOverlay: View {
    let boundary: WoundBoundary
    let imageSize: CGSize
    let displaySize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Use correct aspect-fit transformation
            let transform = imageSize.aspectFitTransform(in: size)
            
            var path = Path()
            
            if let firstPoint = boundary.points.first {
                let scaledFirst = imageSize.imageToView(
                    point: firstPoint,
                    containerSize: size
                )
                path.move(to: scaledFirst)
                
                for point in boundary.points.dropFirst() {
                    let scaledPoint = imageSize.imageToView(
                        point: point,
                        containerSize: size
                    )
                    path.addLine(to: scaledPoint)
                }
                
                path.closeSubpath()
            }
            
            context.stroke(path, with: .color(.green), lineWidth: 2)
            context.fill(path, with: .color(.green.opacity(0.2)))
        }
    }
}
```

### Step 3: Update ManualBoundaryTraceView
Update all coordinate transformations to use the helper methods.

## Testing

After applying fixes, test with:
1. **Portrait image** (taller than wide) - should have horizontal letterboxing
2. **Landscape image** (wider than tall) - should have vertical letterboxing  
3. **Square image** - minimal letterboxing
4. **Different device sizes** - iPhone, iPad

Verify:
- Auto-detected boundary aligns with wound
- Manual trace points appear where you tap
- Dragging points works correctly
- Zoomed loupe shows correct area

## Alternative Solution

If aspect-fit is causing too many issues, consider using `.aspectRatio(contentMode: .fill)` with `.clipped()`:

```swift
Image(uiImage: image)
    .resizable()
    .aspectRatio(contentMode: .fill)
    .frame(width: geometry.size.width, height: geometry.size.height)
    .clipped()
```

This fills the view completely (no letterboxing) but may crop parts of the image. Simpler coordinate math but loses some image content.

## Priority

**HIGH** - This affects core functionality (wound boundary detection and tracing).

Users cannot accurately trace or verify wound boundaries with misaligned coordinates.
