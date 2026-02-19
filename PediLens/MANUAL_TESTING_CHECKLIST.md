# PediLens Manual Testing Checklist

**Test Date:** _____________  
**Tester:** _____________  
**iOS Version:** _____________  
**Device Model:** _____________  
**Build Version:** _____________

## Instructions
- Mark each test case as: ✅ Pass | ❌ Fail | ⚠️ Partial | ➖ N/A
- Document any issues found in the "Issues Found" section at the bottom
- Test on multiple devices if possible (iPhone with/without LiDAR, different iOS versions)

---

## 1. Camera Capture System

### 1.1 Basic Camera Functionality
- [ ] Camera interface launches successfully
- [ ] Camera preview displays correctly
- [ ] Camera permission prompt appears on first launch
- [ ] Camera permission denial is handled gracefully
- [ ] Capture button is accessible and responsive
- [ ] Photo capture completes successfully
- [ ] Captured photo appears in preview

### 1.2 Photo Quality and Formats
- [ ] Photos are captured at maximum device resolution
- [ ] Standard photo format (HEIC) is used
- [ ] Live Photo toggle is available
- [ ] Live Photos capture both still and video components
- [ ] Live Photo video component plays correctly
- [ ] Photo quality is suitable for clinical documentation

### 1.3 Advanced Camera Features
- [ ] HDR is enabled on capable devices
- [ ] Night Mode activates automatically in low light
- [ ] Manual focus control works (tap to focus)
- [ ] Manual exposure control works
- [ ] White balance adjustment works
- [ ] Camera settings persist between sessions

### 1.4 Depth Data Capture (LiDAR/Dual-Camera Devices)
- [ ] Depth data is captured on supported devices
- [ ] Depth data is stored with photo
- [ ] Depth data is used for measurements
- [ ] Graceful degradation on non-depth devices

**Camera Notes:**
_____________________________________________

---

## 2. Wound Detection System

### 2.1 Automatic Detection
- [ ] Wound boundary detection runs automatically
- [ ] Detection completes in reasonable time (<5 seconds)
- [ ] Boundary contour is visually accurate
- [ ] Confidence score is displayed
- [ ] Detection works on various wound types
- [ ] Detection handles different lighting conditions

### 2.2 Manual Refinement
- [ ] Manual boundary adjustment is available
- [ ] User can add/move boundary points
- [ ] Refined boundary updates measurements
- [ ] Detection method is marked as "refined"
- [ ] Original detection is preserved in history

### 2.3 Edge Cases
- [ ] Detection handles photos without wounds gracefully
- [ ] Detection handles multiple wounds (if applicable)
- [ ] Detection handles poor quality images
- [ ] Detection handles extreme lighting conditions

**Detection Notes:**
_____________________________________________

---

## 3. Measurement System

### 3.1 Basic Measurements
- [ ] Area calculation is performed automatically
- [ ] Length and width are calculated
- [ ] Perimeter is calculated
- [ ] Measurements display in both metric and imperial
- [ ] Unit conversion is accurate
- [ ] Measurements update when boundary is refined

### 3.2 Depth and Volume (Depth-Capable Devices)
- [ ] Depth estimation is performed on capable devices
- [ ] Depth values appear reasonable
- [ ] Volume calculation is performed when depth available
- [ ] Volume calculation uses area and depth correctly
- [ ] Graceful handling on non-depth devices

### 3.3 Calibration System
- [ ] Calibration prompt appears
- [ ] Reference object library is available
- [ ] Custom reference object can be added
- [ ] Pixel-to-millimeter ratio is calculated
- [ ] Calibration is applied to measurements
- [ ] Uncalibrated measurement warning appears when needed

### 3.4 Measurement History
- [ ] Previous measurements are preserved
- [ ] Measurement history is accessible
- [ ] Manual adjustments are tracked
- [ ] History shows timestamps and changes

**Measurement Notes:**
_____________________________________________

---

## 4. Data Persistence and Storage

### 4.1 Local Storage
- [ ] Photos are saved to local storage immediately
- [ ] Thumbnails are generated correctly
- [ ] Wound records persist after app restart
- [ ] Capture sessions persist after app restart
- [ ] Measurements persist after app restart
- [ ] Notes and metadata persist after app restart

### 4.2 Storage Management
- [ ] Storage usage is displayed accurately
- [ ] Storage warning appears at 80% capacity
- [ ] Orphaned file cleanup works
- [ ] Storage management UI is accessible
- [ ] File deletion removes files from storage

### 4.3 Data Integrity
- [ ] Checksums are generated for files
- [ ] Integrity verification detects corruption
- [ ] Corrupted files are handled gracefully
- [ ] Data validation prevents invalid records

**Storage Notes:**
_____________________________________________

---

## 5. iCloud Synchronization

### 5.1 Sync Enable/Disable
- [ ] iCloud sync can be enabled
- [ ] iCloud sync can be disabled
- [ ] Sync status is displayed correctly
- [ ] Local-only mode works when sync disabled
- [ ] iCloud permission prompt appears

### 5.2 Sync Operations
- [ ] New records sync to iCloud
- [ ] Updated records sync to iCloud
- [ ] Deleted records sync to iCloud
- [ ] Photos sync to iCloud
- [ ] Sync progress is displayed
- [ ] Sync completes successfully

### 5.3 Offline Sync Queue
- [ ] Operations queue when offline
- [ ] Queue processes when connectivity restored
- [ ] Queued operations complete successfully
- [ ] Sync status shows "pending" when queued

### 5.4 Conflict Resolution
- [ ] Conflicts are detected
- [ ] Both versions are preserved
- [ ] Conflict resolution UI appears
- [ ] User can choose version to keep
- [ ] Resolved conflicts sync correctly

**Sync Notes:**
_____________________________________________

---

## 6. Export and Sharing

### 6.1 Export Package Creation
- [ ] Export can be initiated
- [ ] Export format selection works (PDF, images, native)
- [ ] Export options are available (photos, measurements, notes)
- [ ] Date range filtering works
- [ ] Export package is created successfully

### 6.2 PDF Report Generation
- [ ] PDF report is generated
- [ ] Report includes wound progression charts
- [ ] Report includes measurement tables
- [ ] Report includes photos with timestamps
- [ ] Report includes HIPAA disclaimer
- [ ] PDF is readable and well-formatted

### 6.3 Data Anonymization
- [ ] Anonymization option is available
- [ ] Patient identifiers are removed when anonymized
- [ ] Anonymized export contains clinical data
- [ ] Non-anonymized export contains patient info

### 6.4 Sharing
- [ ] iOS share sheet appears
- [ ] Export can be shared via email
- [ ] Export can be shared via AirDrop
- [ ] Export can be saved to Files app
- [ ] Share completion is handled correctly

**Export Notes:**
_____________________________________________

---

## 7. Security and Privacy

### 7.1 Authentication
- [ ] Biometric authentication prompt appears on launch
- [ ] Face ID/Touch ID works correctly
- [ ] Passcode fallback works
- [ ] Authentication required for sensitive operations
- [ ] Session timeout works (5 minutes)
- [ ] Re-authentication required after timeout

### 7.2 Data Encryption
- [ ] Data at rest is encrypted
- [ ] Encryption keys are stored in Keychain
- [ ] File protection is enabled
- [ ] Encrypted data can be decrypted successfully
- [ ] Encryption doesn't impact performance significantly

### 7.3 Privacy Compliance
- [ ] No third-party data transmission
- [ ] Only CloudKit is used for sync
- [ ] HIPAA warning appears on export
- [ ] Secure deletion overwrites data
- [ ] Audit logging works (if implemented)

**Security Notes:**
_____________________________________________

---

## 8. User Roles and Workflows

### 8.1 Role Selection
- [ ] Role selection appears on first launch
- [ ] Doctor role can be selected
- [ ] Patient role can be selected
- [ ] Role persists after app restart
- [ ] Role determines available features

### 8.2 Doctor Workflow
- [ ] Patient management is available
- [ ] Patient list is displayed
- [ ] Patient search works
- [ ] Patient identification prompt appears in capture
- [ ] Patient metadata is embedded in captures
- [ ] Patient-centric views work
- [ ] Multiple patients can be managed

### 8.3 Patient Workflow
- [ ] Simplified workflow for self-documentation
- [ ] No patient identifier required
- [ ] Personal timeline view works
- [ ] Basic export functionality available

**Role/Workflow Notes:**
_____________________________________________

---

## 9. Patient Management (Doctor Role)

### 9.1 Patient CRUD Operations
- [ ] New patient can be created
- [ ] Patient name and ID are required
- [ ] Patient list displays all patients
- [ ] Patient details can be viewed
- [ ] Patient information can be edited
- [ ] Patient can be deleted (with confirmation)

### 9.2 Patient Search and Filtering
- [ ] Search by patient name works
- [ ] Search by patient ID works
- [ ] Partial matching works
- [ ] Real-time search results display
- [ ] Filter by date range works
- [ ] Filter by wound status works
- [ ] Filter by wound location works

### 9.3 Patient Statistics
- [ ] Total wounds tracked is displayed
- [ ] Active wounds count is displayed
- [ ] Healing trends are shown
- [ ] Aggregate statistics are accurate

**Patient Management Notes:**
_____________________________________________

---

## 10. Wound Record Management

### 10.1 Wound Record CRUD
- [ ] New wound record can be created
- [ ] Creation prompts for location and date
- [ ] Wound record list displays correctly
- [ ] Wound record details can be viewed
- [ ] Wound record can be edited
- [ ] Wound record can be archived
- [ ] Wound record can be deleted (with confirmation)

### 10.2 Capture Session Management
- [ ] Capture sessions are associated with wounds
- [ ] Multiple sessions per wound work
- [ ] Session photos are displayed
- [ ] Session measurements are displayed
- [ ] Notes can be added to sessions
- [ ] Tags can be added to sessions

**Wound Record Notes:**
_____________________________________________

---

## 11. Timeline and History

### 11.1 Timeline Display
- [ ] Timeline displays in reverse chronological order
- [ ] Thumbnails are displayed
- [ ] Timestamps are displayed
- [ ] Key measurements are displayed
- [ ] Timeline entry selection works
- [ ] Full session details are displayed

### 11.2 Comparison and Trends
- [ ] Wound size change indicators work
- [ ] Change percentages are calculated correctly
- [ ] Visual indicators show improvement/worsening
- [ ] Comparison between sessions works

### 11.3 Filtering and Sorting
- [ ] Date range filter works
- [ ] Wound status filter works
- [ ] Wound location filter works
- [ ] Multiple filters can be combined
- [ ] Filters update timeline correctly

**Timeline Notes:**
_____________________________________________

---

## 12. Accessibility Features

### 12.1 VoiceOver Support
- [ ] VoiceOver reads all UI elements
- [ ] Accessibility labels are descriptive
- [ ] Navigation works with VoiceOver
- [ ] Camera controls are accessible
- [ ] Measurement tools are accessible
- [ ] Custom actions work with VoiceOver

### 12.2 Dynamic Type
- [ ] Text scales with system settings
- [ ] UI layout adapts to larger text
- [ ] No text truncation at large sizes
- [ ] Readability is maintained

### 12.3 Voice Control
- [ ] Voice Control labels are present
- [ ] Voice commands work for navigation
- [ ] Camera can be controlled by voice
- [ ] Hands-free operation is possible

### 12.4 Visual Accessibility
- [ ] Color contrast is sufficient
- [ ] UI is usable without color
- [ ] Alternative interaction methods work
- [ ] Reduce Motion is respected

**Accessibility Notes:**
_____________________________________________

---

## 13. Error Handling and Edge Cases

### 13.1 Network Errors
- [ ] Offline mode works correctly
- [ ] Network loss during sync is handled
- [ ] Network restoration triggers sync
- [ ] Error messages are user-friendly

### 13.2 Storage Errors
- [ ] Low storage warning appears
- [ ] Full storage prevents new captures
- [ ] Storage errors are handled gracefully
- [ ] Recovery options are provided

### 13.3 Camera Errors
- [ ] Camera unavailable is handled
- [ ] Camera permission denial is handled
- [ ] Capture failures are handled
- [ ] Error messages guide user to fix

### 13.4 Data Errors
- [ ] Corrupted data is detected
- [ ] Recovery from backup works
- [ ] Validation errors are displayed
- [ ] Transaction rollback works

**Error Handling Notes:**
_____________________________________________

---

## 14. Performance and Optimization

### 14.1 App Performance
- [ ] App launches quickly (<3 seconds)
- [ ] Camera preview is smooth (30+ fps)
- [ ] Photo capture is responsive (<1 second)
- [ ] Detection completes quickly (<5 seconds)
- [ ] UI is responsive during processing
- [ ] No noticeable lag or stuttering

### 14.2 Memory and Battery
- [ ] Memory usage is reasonable
- [ ] No memory leaks detected
- [ ] Battery drain is acceptable
- [ ] Background processing is efficient

### 14.3 Data Optimization
- [ ] Images are compressed appropriately
- [ ] Thumbnails load quickly
- [ ] Lazy loading works for large lists
- [ ] Pagination works for timeline
- [ ] Cache improves performance

**Performance Notes:**
_____________________________________________

---

## 15. Multi-Device Testing

### 15.1 Device Compatibility
- [ ] Works on iPhone 12 Pro and newer (LiDAR)
- [ ] Works on older iPhones (without LiDAR)
- [ ] Works on different screen sizes
- [ ] Adapts to device capabilities

### 15.2 iOS Version Compatibility
- [ ] Works on iOS 16.0
- [ ] Works on iOS 17.x
- [ ] Works on latest iOS version
- [ ] Graceful degradation on older versions

**Multi-Device Notes:**
_____________________________________________

---

## Issues Found

### Critical Issues (Blocking)
1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

### Major Issues (High Priority)
1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

### Minor Issues (Low Priority)
1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

### Enhancement Suggestions
1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

---

## Test Summary

**Total Test Cases:** _____  
**Passed:** _____  
**Failed:** _____  
**Partial:** _____  
**N/A:** _____  

**Overall Status:** ⬜ Ready for Release | ⬜ Needs Fixes | ⬜ Major Issues

**Tester Signature:** _____________  
**Date:** _____________

---

## Notes for Developers

_____________________________________________
_____________________________________________
_____________________________________________
_____________________________________________
