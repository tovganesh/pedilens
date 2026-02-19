# Patient List Auto-Refresh Fix

## Problem
After adding a patient in doctor mode, the patient list remained empty and didn't show the newly added patient. The list only updated after restarting the app or navigating away and back.

## Root Cause
The PatientListView was using a manual loading approach with a ViewModel that fetched patients asynchronously. This approach had two issues:

1. **No automatic updates**: When Core Data changed (new patient added), the view didn't automatically refresh
2. **Manual refresh required**: The view only loaded patients on appear, not when data changed

## Solution
Refactored PatientListView to use SwiftUI's `@FetchRequest` property wrapper, which automatically observes Core Data changes and updates the view.

### Changes Made

**File**: `PediLens/PediLens/Views/PatientListView.swift`

#### Before (Manual Loading)
```swift
@StateObject private var viewModel: PatientListViewModel

init(user: User) {
    _viewModel = StateObject(wrappedValue: PatientListViewModel(user: user))
}

// ViewModel manually fetched patients
func loadPatients() {
    Task {
        patients = try await patientManager.fetchPatients(for: user)
    }
}
```

#### After (Automatic Updates)
```swift
@FetchRequest private var patients: FetchedResults<Patient>

init(user: User) {
    self.user = user
    _patients = FetchRequest<Patient>(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.name, ascending: true)],
        predicate: NSPredicate(format: "user == %@", user),
        animation: .default
    )
}
```

### Key Benefits

1. **Automatic Updates**: View automatically refreshes when patients are added, updated, or deleted
2. **Simpler Code**: Removed ViewModel class and manual loading logic
3. **Better Performance**: Core Data efficiently tracks changes and only updates what's needed
4. **Consistent Behavior**: Matches SwiftUI best practices for Core Data integration
5. **Animated Changes**: Default animation provides smooth transitions when data changes

### How It Works

1. `@FetchRequest` creates a live query to Core Data
2. Query is filtered by the current user: `predicate: NSPredicate(format: "user == %@", user)`
3. Results are sorted alphabetically by name
4. When AddPatientView saves a new patient, Core Data notifies the FetchRequest
5. FetchRequest automatically updates the `patients` property
6. SwiftUI detects the change and re-renders the view
7. New patient appears in the list with animation

### Testing Verification

Test the following scenarios:
1. ✅ Add a patient - should appear immediately in the list
2. ✅ Add multiple patients - all should appear
3. ✅ Search for patients - filtering should work
4. ✅ Delete a patient - should disappear immediately
5. ✅ Edit a patient - changes should reflect immediately
6. ✅ Empty state - should show when no patients exist
7. ✅ Search with no results - should show appropriate message

## Related Code

The same pattern should be used in other views that display Core Data entities:
- WoundListView (already uses FetchRequest)
- TimelineView (check if it needs similar fix)
- Any other list views

## Technical Notes

### FetchRequest Initialization
The FetchRequest must be initialized in the `init()` method because it needs the user parameter to create the predicate. This is a common pattern when filtering FetchRequests by a parameter.

### Predicate Format
```swift
NSPredicate(format: "user == %@", user)
```
This filters patients to only show those belonging to the current doctor user.

### Sort Descriptors
```swift
sortDescriptors: [NSSortDescriptor(keyPath: \Patient.name, ascending: true)]
```
Patients are sorted alphabetically by name for easy browsing.

## Files Modified
- `PediLens/PediLens/Views/PatientListView.swift`

## Related Requirements
- Requirement 8: User Roles and Workflows
- Requirement 17: Patient-Centric Views and Search
