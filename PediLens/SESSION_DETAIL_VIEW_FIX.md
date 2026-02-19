# Session Detail View Fix

## Problem
After capturing a wound photo:
1. The capture session appeared in the timeline
2. But showed "No measurements"
3. Tapping the session opened a simple metadata view
4. No wound tracing tools or measurement interface was available
5. The actual photo wasn't displayed - only a placeholder icon

## Root Cause
The TimelineView was opening `TimelineDetailView` when a session was tapped, but this view only shows basic metadata (date, time, depth data availability). It doesn't provide:
- Photo display
- Wound boundary tracing tools
- Measurement calculation
- Manual tracing interface

The correct view to open is `CaptureSessionDetailView`, which includes all the wound analysis and measurement features.

## Solution
Changed the TimelineView to open `CaptureSessionDetailView` instead of `TimelineDetailView` when a session is tapped.

### Changes Made

**File**: `PediLens/PediLens/Views/TimelineView.swift`

**Before:**
```swift
.sheet(item: $viewModel.selectedSession) { session in
    TimelineDetailView(session: session)
        .environment(\.managedObjectContext, viewContext)
}
```

**After:**
```swift
.sheet(item: $viewModel.selectedSession) { session in
    CaptureSessionDetailView(session: session)
        .environment(\.managedObjectContext, viewContext)
}
```

## What CaptureSessionDetailView Provides

The `CaptureSessionDetailView` (defined in ContentView.swift) includes:

1. **Photo Display**: Shows the actual captured wound photo
2. **Wound Detection**: Automatically detects wound boundaries using image processing
3. **Manual Tracing**: Allows users to manually trace wound boundaries if automatic detection isn't accurate
4. **Tracing Modes**:
   - Continuous mode: Drag to trace
   - Point-by-point mode: Tap to place individual points
5. **Point Editing**: Drag any point to reposition it
6. **Loupe Tool**: Magnified view for precise tracing
7. **Measurement Calculation**: Automatically calculates:
   - Area (cm² and in²)
   - Length and width (cm and inches)
   - Perimeter (cm and inches)
   - Depth (if depth data available)
   - Volume (if depth data available)
8. **Re-analysis**: Option to re-run wound detection
9. **Measurement Display**: Shows all measurements in both metric and imperial units

## User Flow

### Complete Workflow
1. User taps camera button in Timeline
2. Camera opens
3. User captures wound photo
4. Photo is saved to database
5. Camera dismisses, Timeline refreshes
6. User taps the new session card in Timeline
7. **CaptureSessionDetailView opens** showing:
   - The captured photo
   - Automatically detected wound boundary (if successful)
   - "No measurements" message if not yet analyzed
8. User can:
   - View automatic detection
   - Manually trace if needed
   - Adjust boundary points
   - Save measurements
9. Measurements are saved to database
10. Timeline updates to show measurements

### First-Time Analysis
When a session is opened for the first time:
- Photo loads from storage
- Wound detection runs automatically
- Boundary is drawn on the photo
- Measurements are calculated
- User can review and adjust

### Subsequent Views
When opening an existing session:
- Photo loads from storage
- Saved measurements are displayed
- Saved boundary is shown
- User can re-analyze if needed

## Benefits

1. **Complete Feature Access**: Users can now access all wound analysis tools
2. **Photo Visibility**: Actual wound photos are displayed, not just placeholders
3. **Measurement Capability**: Users can trace and measure wounds
4. **Consistent Experience**: Same interface whether coming from Timeline or other views
5. **Data Completeness**: Sessions can have measurements, not just metadata

## Testing Verification

Test the complete workflow:

1. ✅ Create wound record
2. ✅ Open Timeline
3. ✅ Tap camera FAB
4. ✅ Capture wound photo
5. ✅ Camera dismisses
6. ✅ Session appears in Timeline
7. ✅ Tap session card
8. ✅ **CaptureSessionDetailView opens** (not TimelineDetailView)
9. ✅ Photo is displayed
10. ✅ Wound detection runs automatically
11. ✅ Boundary is drawn on photo
12. ✅ Measurements are calculated and displayed
13. ✅ Can manually trace if needed
14. ✅ Can adjust boundary points
15. ✅ Measurements update in real-time
16. ✅ Close detail view
17. ✅ Timeline shows measurements

## Note on TimelineDetailView

The `TimelineDetailView` is still defined in TimelineView.swift but is no longer used. It could be:
- Removed entirely, OR
- Kept for future use as a "read-only" summary view, OR
- Repurposed for a different use case

For now, it remains in the code but unused.

## Files Modified
- `PediLens/PediLens/Views/TimelineView.swift`

## Related Requirements
- Requirement 1: Wound Photo Capture
- Requirement 2: Wound Measurement Tools
- Requirement 3: Wound Timeline and History
- Requirement 11: Camera Features and Image Quality
