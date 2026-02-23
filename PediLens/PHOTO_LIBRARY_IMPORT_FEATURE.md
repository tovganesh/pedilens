# Photo Library Import Feature

## Summary
Added the ability to import wound photos from the device's photo library in addition to capturing them with the camera. Users can now choose between taking a new photo or selecting an existing one from their gallery.

## Changes Made

### 1. Added PhotosUI Framework
**File**: `PediLens/PediLens/Views/TimelineView.swift`

Added import for PhotosUI framework:
```swift
import PhotosUI
```

### 2. Updated Floating Action Button to Menu
Changed the single camera button to a menu with two options:

**Before**: Single camera button
**After**: Menu button with options:
- "Take Photo" (camera icon) - Opens camera
- "Choose from Library" (photo library icon) - Opens photo picker

### 3. Updated Empty State Button
Changed the empty state "Capture Photo" button to a menu with the same two options for consistency.

### 4. Added Photo Picker State Management
Added to TimelineViewModel:
```swift
@Published var showingPhotoPicker: Bool = false
@Published var selectedPhoto: PhotosPickerItem?
```

### 5. Added PhotosPicker Integration
Added PhotosPicker modifier to TimelineView:
```swift
.photosPicker(isPresented: $viewModel.showingPhotoPicker, 
              selection: $viewModel.selectedPhoto, 
              matching: .images)
.onChange(of: viewModel.selectedPhoto) { newValue in
    if newValue != nil {
        viewModel.importPhoto()
    }
}
```

### 6. Implemented Photo Import Logic
Added `importPhoto()` method to TimelineViewModel that:
1. Loads image data from PhotosPicker selection
2. Converts to JPEG format (0.9 quality)
3. Creates a new CaptureSession entity
4. Saves photo to FileStorageManager
5. Updates session with photo path
6. Associates patient metadata if available
7. Updates wound record timestamp
8. Refreshes timeline

## User Experience

### Workflow 1: Take Photo with Camera
1. User taps FAB (+ button) in timeline
2. Menu appears with two options
3. User taps "Take Photo"
4. Camera opens in full screen
5. User captures photo
6. Photo is saved and timeline refreshes

### Workflow 2: Import from Library
1. User taps FAB (+ button) in timeline
2. Menu appears with two options
3. User taps "Choose from Library"
4. iOS photo picker appears
5. User selects a photo from their library
6. Photo is imported and saved
7. Timeline refreshes with new session

### Empty State
When no photos exist:
- Shows "Add Photo" button
- Tapping shows same menu with camera/library options
- Provides clear path to add first photo

## Technical Details

### Photo Processing
- Library photos are converted to JPEG with 0.9 compression quality
- Same storage structure as camera photos
- Stored in: `Documents/PediLens/Photos/{sessionID}/photo.heic`
- Thumbnails generated automatically by FileStorageManager

### Session Creation
- Uses same CaptureSessionManager as camera captures
- Creates session first to get UUID
- Saves photo with that UUID
- Updates session with actual file path
- Maintains data consistency

### Patient Association
- Imported photos are associated with the wound record
- Patient metadata is attached if available (doctor mode)
- Same workflow as camera captures

### Metadata
- Timestamp: Set to import time
- Location: Not available for library photos (set to nil)
- Depth data: Not available for library photos
- Live photo: Not supported for library imports

## Benefits

1. **Flexibility**: Users can use existing photos instead of only new captures
2. **Convenience**: Import photos taken with other cameras or apps
3. **Retrospective Documentation**: Add historical photos to timeline
4. **Better Quality**: Use photos from professional cameras
5. **Consistent Interface**: Same menu pattern for both empty and populated states
6. **Accessibility**: Menu provides clear options with icons and labels

## Limitations

### Library Photos vs Camera Captures
Library photos do not include:
- Depth data (no LiDAR information)
- Live photo video component
- Location metadata (privacy consideration)
- Camera settings metadata

These limitations are acceptable as the primary use case is wound documentation, and the photo itself is the most important data.

## Testing Verification

Test the following scenarios:

1. ✅ Tap FAB → Menu appears with two options
2. ✅ Select "Take Photo" → Camera opens
3. ✅ Select "Choose from Library" → Photo picker opens
4. ✅ Select photo from library → Photo imports successfully
5. ✅ Timeline refreshes → New session appears
6. ✅ Tap session → Opens detail view with imported photo
7. ✅ Trace wound → Measurements work correctly
8. ✅ Empty state button → Shows same menu
9. ✅ Import multiple photos → All appear in timeline
10. ✅ Patient association → Works for doctor mode

## Privacy Considerations

- Photo library access requires user permission
- iOS automatically prompts for permission on first use
- Users can grant limited access (select photos only)
- No location data is extracted from library photos
- Photos are copied to app's private storage
- Original library photos remain unchanged

## Future Enhancements

Potential improvements:
1. Extract EXIF metadata from library photos (timestamp, camera model)
2. Support batch import (multiple photos at once)
3. Show photo source indicator (camera vs library)
4. Add option to edit/crop before importing
5. Support video import for wound documentation

## Files Modified
- `PediLens/PediLens/Views/TimelineView.swift`

## Related Requirements
- Requirement 1: Wound Photo Capture
- Requirement 3: Wound Timeline and History
- Requirement 10: Wound Record Management
