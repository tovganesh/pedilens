# Timeline Capture Button Fix

## Problem
After creating a wound record and navigating to the Timeline view, there was no way to capture wound photos. The view showed "No Timeline Entries" with a message to "Capture your first wound photo to start tracking", but provided no button or action to actually open the camera.

## Root Cause
The TimelineView was designed only to display capture sessions, not to initiate new captures. It was missing:
1. A button to open the camera
2. A sheet/fullScreenCover to present the CameraView
3. State management for showing/hiding the camera

## Solution
Added a floating action button (FAB) and an empty state button to open the camera for capturing wound photos.

### Changes Made

**File**: `PediLens/PediLens/Views/TimelineView.swift`

#### 1. Added Floating Action Button

Added a circular camera button that floats in the bottom-right corner:

```swift
// Floating action button for camera
VStack {
    Spacer()
    HStack {
        Spacer()
        Button(action: { viewModel.showingCamera = true }) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .padding()
    }
}
```

#### 2. Added Camera Presentation

Added fullScreenCover to present the CameraView:

```swift
.fullScreenCover(isPresented: $viewModel.showingCamera) {
    CameraView(woundRecord: viewModel.woundRecord) {
        // Refresh timeline when camera dismisses
        viewModel.loadSessions()
    }
    .environment(\.managedObjectContext, viewContext)
}
```

#### 3. Added Empty State Button

Added a prominent button in the empty state view:

```swift
Button(action: { viewModel.showingCamera = true }) {
    Label("Capture Photo", systemImage: "camera.fill")
        .font(.headline)
}
.buttonStyle(.borderedProminent)
```

#### 4. Added State Management

Added `showingCamera` state to the ViewModel:

```swift
@Published var showingCamera: Bool = false
```

## User Experience

### Empty State (No Photos)
- Shows message: "No Timeline Entries"
- Shows subtitle: "Capture your first wound photo to start tracking"
- Shows prominent "Capture Photo" button
- User taps button → Camera opens

### With Existing Photos
- Timeline list is displayed
- Floating action button (FAB) appears in bottom-right corner
- User taps FAB → Camera opens
- After capturing photo → Timeline automatically refreshes

### After Capture
- Camera dismisses
- Timeline reloads automatically
- New capture session appears at the top of the list
- User can tap the session to view details

## Benefits

1. **Clear Call-to-Action**: Users immediately see how to capture photos
2. **Always Accessible**: FAB is always visible, even when scrolling through timeline
3. **Automatic Refresh**: Timeline updates immediately after capture
4. **Consistent UX**: Uses same CameraView as other parts of the app
5. **Proper Integration**: Camera properly associates photos with the wound record

## Design Decisions

### Why Floating Action Button?
- Always visible regardless of scroll position
- Common mobile pattern for primary actions
- Doesn't clutter the navigation bar
- Easy to reach with thumb on mobile devices

### Why fullScreenCover instead of sheet?
- Camera needs full screen for best experience
- Matches iOS camera app behavior
- Provides immersive capture experience
- Better for focusing on the task

### Why Refresh on Dismiss?
- Ensures timeline shows latest data
- Provides immediate feedback to user
- Avoids confusion about whether photo was saved
- Maintains data consistency

## Testing Verification

Test the following scenarios:

1. ✅ Create new wound record
2. ✅ Navigate to Timeline view
3. ✅ See empty state with "Capture Photo" button
4. ✅ Tap button → Camera opens
5. ✅ Capture photo → Camera dismisses
6. ✅ Timeline shows new capture session
7. ✅ Tap FAB when timeline has entries
8. ✅ Camera opens again
9. ✅ Capture another photo
10. ✅ Timeline shows both sessions in chronological order

## Files Modified
- `PediLens/PediLens/Views/TimelineView.swift`

## Related Requirements
- Requirement 1: Wound Photo Capture
- Requirement 3: Wound Timeline and History
- Requirement 10: Wound Record Management
