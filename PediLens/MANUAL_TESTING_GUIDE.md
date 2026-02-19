# PediLens Manual Testing Guide

## Overview
This guide provides instructions for performing manual testing of the PediLens iOS application. Use this in conjunction with the MANUAL_TESTING_CHECKLIST.md document.

## Prerequisites

### Required Hardware
- iPhone running iOS 16.0 or later
- iPhone with LiDAR (iPhone 12 Pro or newer) for depth testing
- iPhone without LiDAR for compatibility testing
- Mac with Xcode 14.0 or later

### Test Environment Setup
1. Build the app in Xcode using the PediLens scheme
2. Install on physical device (Simulator has limited camera/sensor support)
3. Grant all permissions when prompted (Camera, Location, iCloud)
4. Have test materials ready:
   - Printed wound images or test cards
   - Ruler or coin for calibration testing
   - Multiple lighting conditions available

## Testing Approach

### 1. Systematic Testing
- Follow the checklist in order
- Complete one section before moving to the next
- Document all findings immediately
- Take screenshots of issues

### 2. Exploratory Testing
- Try unexpected user flows
- Test edge cases not in checklist
- Attempt to break the app
- Test rapid interactions

### 3. Regression Testing
- Verify previously fixed issues remain fixed
- Test core workflows after each fix
- Ensure new features don't break existing ones

## Test Scenarios

### Scenario 1: First-Time Doctor User
**Goal:** Complete workflow from app launch to first wound documentation

1. Launch app for first time
2. Select "Doctor" role
3. Create first patient (Name: "Test Patient", ID: "TP001")
4. Create wound record (Location: "Left foot, plantar surface")
5. Capture wound photo with Live Photo enabled
6. Review automatic wound detection
7. Manually refine boundary if needed
8. Add calibration using ruler
9. Review measurements (area, length, width)
10. Add note: "Initial assessment"
11. Save capture session
12. View timeline
13. Export as PDF
14. Verify PDF contains all data

**Expected Result:** Complete workflow without errors, all data persisted

### Scenario 2: Patient Self-Documentation
**Goal:** Patient tracks their own wound over time

1. Launch app for first time
2. Select "Patient" role
3. Create wound record (Location: "Right foot")
4. Capture first photo
5. Add note: "Day 1"
6. Wait (or simulate time passing)
7. Capture second photo
8. Add note: "Day 7 - looks better"
9. View timeline
10. Compare two sessions
11. Verify size change indicators
12. Export for sharing with doctor

**Expected Result:** Simple workflow, clear progression tracking

### Scenario 3: Offline Operation
**Goal:** Verify full functionality without network

1. Enable Airplane Mode
2. Launch app
3. Create new wound record
4. Capture multiple photos
5. Add measurements and notes
6. View timeline
7. Verify all data saved locally
8. Disable Airplane Mode
9. Enable iCloud sync
10. Verify queued operations sync

**Expected Result:** No functionality loss offline, automatic sync when online

### Scenario 4: Multi-Patient Management
**Goal:** Doctor manages multiple patients efficiently

1. Create 5 different patients
2. Create 2-3 wound records per patient
3. Capture photos for each wound
4. Use patient search to find specific patient
5. Filter records by date range
6. Filter records by wound status
7. View patient statistics
8. Export data for one patient
9. Verify patient isolation (no data mixing)

**Expected Result:** Efficient multi-patient workflow, accurate filtering

### Scenario 5: Measurement Accuracy
**Goal:** Verify measurement system accuracy

1. Print test card with known dimensions (e.g., 50mm x 50mm square)
2. Capture photo of test card
3. Use ruler for calibration (known length)
4. Measure test card using wound boundary tools
5. Compare measured dimensions to actual
6. Calculate error percentage
7. Repeat with different reference objects
8. Test on multiple devices

**Expected Result:** Measurements within 5% of actual dimensions

### Scenario 6: Security and Privacy
**Goal:** Verify security measures work correctly

1. Launch app (biometric prompt should appear)
2. Deny biometric authentication
3. Verify app doesn't proceed
4. Authenticate successfully
5. Leave app idle for 5+ minutes
6. Return to app (should require re-authentication)
7. Export data and verify HIPAA warning
8. Test anonymization option
9. Verify no third-party network calls (use network monitor)
10. Delete wound record and verify secure deletion

**Expected Result:** All security measures active, data protected

### Scenario 7: Accessibility Testing
**Goal:** Verify app is accessible to users with disabilities

1. Enable VoiceOver in iOS Settings
2. Navigate app using VoiceOver gestures
3. Verify all elements have labels
4. Attempt to capture photo using VoiceOver
5. Disable VoiceOver
6. Enable Voice Control
7. Navigate using voice commands
8. Increase text size to maximum
9. Verify UI adapts correctly
10. Test with Reduce Motion enabled

**Expected Result:** Full functionality with accessibility features

### Scenario 8: Sync Conflict Resolution
**Goal:** Test conflict handling between devices

**Requires:** Two devices with same iCloud account

1. Device A: Create wound record, enable sync
2. Device B: Wait for sync, verify record appears
3. Both devices: Go offline (Airplane Mode)
4. Device A: Edit wound record, add note "From Device A"
5. Device B: Edit same wound record, add note "From Device B"
6. Both devices: Go online
7. Wait for sync conflict detection
8. Verify conflict resolution UI appears
9. Choose version to keep
10. Verify resolution syncs to both devices

**Expected Result:** Conflicts detected, both versions preserved, user resolves

## Common Issues and Troubleshooting

### Camera Not Working
- Check camera permissions in Settings > Privacy > Camera
- Verify device camera is functional (test with Camera app)
- Restart app
- Restart device

### Sync Not Working
- Verify iCloud account is signed in
- Check iCloud Drive is enabled
- Verify network connectivity
- Check iCloud storage availability
- Force sync using sync button

### Measurements Seem Inaccurate
- Verify calibration was performed
- Check reference object dimensions are correct
- Ensure photo is clear and in focus
- Verify wound boundary is accurate
- Test with known dimensions

### App Crashes
- Note exact steps to reproduce
- Check device logs in Xcode
- Verify iOS version compatibility
- Check available storage
- Report with crash logs

### Performance Issues
- Check device storage (low storage impacts performance)
- Verify device meets minimum requirements
- Close other apps
- Restart device
- Check for memory leaks in Xcode Instruments

## Test Data Management

### Creating Test Data
- Use consistent naming: "Test Patient 1", "Test Patient 2", etc.
- Use test wound locations: "Test Location A", "Test Location B"
- Add notes indicating test data: "TEST DATA - DO NOT USE"
- Take photos of test cards, not real wounds

### Cleaning Test Data
- Delete all test patients after testing
- Verify deletion removes all associated data
- Check storage is freed
- Verify sync removes data from iCloud

## Reporting Issues

### Issue Report Template
```
**Title:** Brief description of issue

**Severity:** Critical | Major | Minor

**Steps to Reproduce:**
1. Step one
2. Step two
3. Step three

**Expected Result:**
What should happen

**Actual Result:**
What actually happened

**Environment:**
- Device: iPhone 14 Pro
- iOS Version: 17.2
- App Version: 1.0.0
- Build: 123

**Screenshots/Videos:**
[Attach if available]

**Additional Notes:**
Any other relevant information
```

### Severity Definitions
- **Critical:** App crashes, data loss, security breach, core feature broken
- **Major:** Feature doesn't work as expected, significant usability issue
- **Minor:** Cosmetic issue, minor inconvenience, edge case

## Testing Best Practices

1. **Test on Real Devices:** Simulator cannot test camera, biometrics, or sensors
2. **Test Multiple Devices:** Different iPhone models, iOS versions
3. **Test Different Conditions:** Various lighting, network conditions, storage levels
4. **Document Everything:** Screenshots, videos, detailed notes
5. **Reproduce Issues:** Verify issues are reproducible before reporting
6. **Test Positive and Negative Cases:** Both success and failure paths
7. **Think Like a User:** Test realistic workflows, not just happy paths
8. **Be Thorough:** Don't skip steps, even if they seem obvious
9. **Communicate Clearly:** Provide actionable feedback to developers
10. **Retest Fixes:** Verify fixes work and don't introduce new issues

## Testing Schedule Recommendation

### Day 1: Core Functionality
- Camera capture
- Wound detection
- Basic measurements
- Data persistence

### Day 2: Advanced Features
- Depth measurements
- Calibration
- Timeline and history
- Filtering and search

### Day 3: User Roles and Workflows
- Doctor workflow
- Patient workflow
- Patient management
- Multi-patient scenarios

### Day 4: Sync and Export
- iCloud synchronization
- Offline operation
- Export formats
- Data sharing

### Day 5: Security and Accessibility
- Authentication
- Encryption
- Privacy compliance
- Accessibility features

### Day 6: Edge Cases and Stress Testing
- Error handling
- Performance testing
- Multi-device testing
- Regression testing

### Day 7: Final Verification
- Retest critical issues
- Verify all fixes
- Complete documentation
- Sign off

## Success Criteria

The app is ready for release when:
- ✅ All critical and major issues are resolved
- ✅ Core workflows complete without errors
- ✅ Security measures are verified
- ✅ Accessibility requirements are met
- ✅ Performance is acceptable
- ✅ Multi-device compatibility is confirmed
- ✅ Documentation is complete
- ✅ Test coverage is comprehensive

## Contact

For questions about testing:
- Review requirements.md for feature specifications
- Review design.md for technical details
- Check TASK_21_TEST_RESULTS.md for automated test results
- Consult with development team for clarifications
