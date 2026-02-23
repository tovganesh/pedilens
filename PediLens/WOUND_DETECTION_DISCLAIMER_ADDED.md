# Wound Detection Disclaimer Implementation

## Overview
Added prominent disclaimers about automatic wound detection being experimental, encouraging users to use manual tracing for accurate measurements.

## Changes Made

### 1. Pre-Analysis Disclaimer
Added an informational banner before the analysis buttons that:
- Explains automatic detection is experimental
- Recommends manual trace for best accuracy
- Uses blue info icon for visibility
- Appears when photo is loaded but no analysis has been performed yet

### 2. Post-Detection Warning
Added a warning banner when automatic detection results are displayed that:
- Shows an orange warning triangle icon
- Labels the feature as "Experimental"
- Advises users to verify or adjust using Manual Trace
- Only appears for automatic detection (not for manually traced or refined boundaries)
- Integrated into the green "Wound Detection" success card

### 3. Button Label Updates
- Changed "Analyze Wound" to "Auto-Detect Wound" for clarity
- Added "(Recommended)" to "Manual Trace" button to guide users
- Updated accessibility labels to be more descriptive

## User Experience Flow

### Before Analysis
1. User opens a capture session
2. Photo loads
3. Blue info banner explains analysis options
4. Two buttons presented:
   - "Auto-Detect Wound" (experimental)
   - "Manual Trace (Recommended)" (accurate)

### After Automatic Detection
1. Green success card shows detection results
2. Orange warning banner appears within the card
3. Warning explains experimental nature
4. User can proceed to manual trace to verify/adjust

### After Manual Trace
1. Green success card shows detection results
2. No warning banner (manual trace is trusted)
3. Measurements displayed with confidence

## Technical Details

### Detection Method Check
```swift
if case .automatic = boundary.detectionMethod {
    // Show warning only for automatic detection
}
```

This ensures the warning only appears for automatically detected boundaries, not for:
- Manual traces
- Refined boundaries (user-adjusted automatic detection)

### Visual Hierarchy
- Info banner: Blue background, info circle icon
- Warning banner: Orange triangle icon, smaller text
- Both use system colors for consistency with iOS design

## Files Modified
- `PediLens/PediLens/Views/ContentView.swift` - Added disclaimers to CaptureSessionDetailView

## Testing Recommendations
1. Open a capture session without existing measurements
2. Verify blue info banner appears
3. Tap "Auto-Detect Wound"
4. Verify orange warning appears in detection results
5. Tap "Manual Trace" from a fresh session
6. Verify no warning appears after manual trace
7. Test accessibility labels with VoiceOver

## Next Steps
As mentioned in the context transfer, the next priority is:
- Improve manual tracing UX (smoother drawing, better point editing)
- Consider implementing basic color-based segmentation for better automatic detection
