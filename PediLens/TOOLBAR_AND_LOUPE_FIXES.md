# Toolbar and Loupe Display Fixes

## Issues Fixed

### 1. Toolbar Buttons Not Visible
**Problem**: Clear and Undo buttons were not visible or accessible in the manual tracing view.

**Root Cause**: 
- Using `.bottomBar` placement in toolbar which doesn't always render properly
- Buttons were icon-only without proper styling
- Layout was cramped and unclear

**Solution**:
- Replaced `.bottomBar` toolbar with `.safeAreaInset(edge: .bottom)` for reliable visibility
- Added `.buttonStyle(.bordered)` to make buttons more prominent
- Added `.tint(.red)` to Clear button for visual emphasis
- Improved layout with better spacing and organization
- Changed point count display to show "X pts" format
- Simplified mode picker to show only icons (scribble and grid icons)
- Added `.ultraThinMaterial` background for better contrast

### 2. Loupe Showing Traced Lines
**Problem**: The zoomed preview loupe was showing the traced boundary lines, making it impossible to see where tracing was actually happening.

**Root Cause**:
- The loupe was rendered inside the same ZStack as the Canvas overlay
- Z-ordering caused the Canvas drawing to appear on top or interfere with the loupe

**Solution**:
- Moved the `ZoomedPreviewLoupe` outside the main content ZStack
- Added `.zIndex(1000)` to ensure the loupe renders on top of all other content
- The loupe already correctly crops from the original `UIImage` using `getCroppedZoomedImage()`, which doesn't include any Canvas overlays
- This ensures the loupe shows ONLY the original image without any traced lines

## Technical Details

### Toolbar Layout
```swift
.safeAreaInset(edge: .bottom) {
    HStack(spacing: 12) {
        // Mode picker (100pt width)
        Picker("Mode", selection: $tracingMode) {
            Image(systemName: "scribble").tag(TracingMode.continuous)
            Image(systemName: "circle.grid.cross").tag(TracingMode.pointByPoint)
        }
        .pickerStyle(.segmented)
        
        Spacer()
        
        // Point count display
        Text("\(tracePoints.count) pts")
        
        Spacer()
        
        // Undo button (bordered style)
        Button(action: undoLastPoint) {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        
        // Clear button (bordered style with red tint)
        Button(action: clearTrace) {
            Label("Clear", systemImage: "trash")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
    .padding()
    .background(.ultraThinMaterial)
}
```

### Loupe Z-Index Fix
```swift
// Rendered OUTSIDE the main ZStack
if tracingMode == .continuous, let dragLocation = currentDragLocation {
    ZoomedPreviewLoupe(
        image: image,
        touchLocation: dragLocation,
        viewSize: geometry.size,
        imageSize: imageSize
    )
    .zIndex(1000) // Ensures it's on top of everything
}
```

## User Experience Improvements

1. **Clear Button**: Now prominently displayed with red tint and bordered style
2. **Undo Button**: Bordered style makes it more visible and tappable
3. **Point Count**: Shows "X pts" format for clarity
4. **Mode Picker**: Simplified to icon-only for space efficiency
5. **Loupe**: Now shows clean original image without traced lines
6. **Toolbar**: Always visible at bottom with material background for contrast

## Testing Recommendations

1. Test toolbar visibility on different device sizes (iPhone SE, Pro Max, iPad)
2. Verify Clear button removes all points and resets state
3. Verify Undo button removes last point correctly
4. Confirm loupe shows only original image without any overlays
5. Test mode switching between continuous and point-by-point
6. Verify buttons are disabled when appropriate (empty trace points)

## Files Modified

- `PediLens/PediLens/Views/ContentView.swift`
  - Updated `ManualBoundaryTraceView` toolbar layout
  - Fixed loupe z-ordering and positioning
