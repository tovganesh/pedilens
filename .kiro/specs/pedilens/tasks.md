# Implementation Plan: PediLens

## Overview

This implementation plan breaks down the PediLens native iOS app into discrete, incremental tasks. The approach follows a bottom-up strategy: starting with core infrastructure (data models, storage, security), then building up to camera capture, ML-based wound detection, measurements, and finally user-facing features like sync and export. Each task builds on previous work, with property-based tests integrated throughout to validate correctness early.

## Tasks

- [x] 1. Set up project structure and core infrastructure
  - Create new Xcode project with SwiftUI and Core Data
  - Configure minimum iOS version (16.0+)
  - Set up Core Data model with entities: User, Patient, WoundRecord, CaptureSession, Photo, Measurement, Note
  - Configure NSPersistentCloudKitContainer for CloudKit sync
  - Add iCloud capability and CloudKit container identifier
  - Set up file storage directory structure (Photos/, Exports/)
  - _Requirements: 5.1, 6.1_

- [ ] 2. Implement security and encryption layer
  - [x] 2.1 Create SecurityManager with encryption/decryption methods
    - Implement AES-256 encryption using Security framework
    - Store encryption keys in Keychain with `.whenUnlockedThisDeviceOnly`
    - Implement key generation and retrieval
    - _Requirements: 5.3, 9.1_
  
  - [x] 2.2 Write property test for encryption round-trip
    - **Property 18: Data Encryption at Rest**
    - **Validates: Requirements 5.3, 9.1**
  
  - [x] 2.3 Implement biometric authentication
    - Use LocalAuthentication framework for Face ID/Touch ID
    - Implement fallback to device passcode
    - Add session timeout logic (5 minutes)
    - _Requirements: 5.4, 9.2_
  
  - [x] 2.4 Write property test for authentication requirement
    - **Property 19: Authentication Requirement**
    - **Validates: Requirements 5.4, 9.2**

- [ ] 3. Implement file storage system
  - [x] 3.1 Create FileStorageManager
    - Implement savePhoto, saveLivePhotoVideo, saveDepthData methods
    - Implement loadPhoto and deleteFiles methods
    - Add thumbnail generation (300x300)
    - Use HEIC format for photos
    - Enable Data Protection API (`.completeFileProtection`)
    - _Requirements: 1.3, 5.1_
  
  - [x] 3.2 Write property test for photo persistence
    - **Property 1: Photo Capture Persistence**
    - **Validates: Requirements 1.3, 1.5, 2.8**
  
  - [x] 3.3 Implement storage quota management
    - Add getStorageUsage method
    - Implement warning at 80% capacity
    - Add orphaned file cleanup
    - _Requirements: 5.5_

- [ ] 4. Implement Core Data persistence layer
  - [x] 4.1 Create PersistenceController singleton
    - Configure NSPersistentCloudKitContainer
    - Enable persistent history tracking
    - Set up merge policies
    - _Requirements: 5.1, 6.1_
  
  - [x] 4.2 Create Core Data entity extensions with convenience methods
    - Add CRUD methods for User, Patient, WoundRecord, CaptureSession
    - Implement fetch requests with predicates
    - _Requirements: 5.1, 10.1_
  
  - [x] 4.3 Write property test for offline functionality
    - **Property 17: Offline Functionality Completeness**
    - **Validates: Requirements 5.2, 13.1, 13.5**
  
  - [x] 4.4 Write property test for data validation
    - **Property 40: Data Validation Before Persistence**
    - **Validates: Requirements 14.1**

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement camera capture system
  - [x] 6.1 Create CameraManager with AVFoundation
    - Set up AVCaptureSession with `.photo` preset
    - Configure AVCaptureDevice for highest resolution
    - Implement startSession and stopSession methods
    - Add camera permission handling
    - _Requirements: 1.1, 11.1_
  
  - [x] 6.2 Implement photo capture with depth data
    - Configure AVCapturePhotoOutput
    - Enable depth data capture on supported devices
    - Implement AVCapturePhotoCaptureDelegate
    - Handle photo delivery asynchronously
    - _Requirements: 1.2, 2.6, 11.1_
  
  - [x] 6.3 Add Live Photo support
    - Configure AVCapturePhotoSettings for Live Photos
    - Store both still image and video components
    - _Requirements: 1.2, 11.4_
  
  - [x] 6.4 Write property test for multi-format photo support
    - **Property 2: Multi-Format Photo Support**
    - **Validates: Requirements 1.2, 11.4**
  
  - [x] 6.5 Implement HDR and Night Mode
    - Enable HDR on capable devices
    - Implement automatic Night Mode in low light
    - _Requirements: 11.2, 11.3_
  
  - [x] 6.6 Write property test for maximum resolution capture
    - **Property 32: Maximum Resolution Capture**
    - **Validates: Requirements 11.1**
  
  - [x] 6.7 Write property test for HDR on capable devices
    - **Property 33: HDR Photography on Capable Devices**
    - **Validates: Requirements 11.2**
  
  - [x] 6.8 Add manual camera controls
    - Implement setFocusPoint and setExposure methods
    - Add white balance control
    - _Requirements: 11.5_

- [ ] 7. Implement wound detection system
  - [x] 7.1 Create WoundDetectionService with CoreML
    - Set up Vision framework's VNImageRequestHandler
    - Load CoreML segmentation model
    - Implement detectWoundBoundary method
    - Extract boundary contours from segmentation mask
    - Apply Douglas-Peucker algorithm for contour simplification
    - Calculate confidence score
    - _Requirements: 2.2_
  
  - [x] 7.2 Write property test for automatic wound boundary detection
    - **Property 3: Automatic Wound Boundary Detection**
    - **Validates: Requirements 2.2**
  
  - [x] 7.3 Implement manual boundary refinement
    - Add refineDetection method
    - Interpolate user-provided adjustment points
    - Update detection method to `.refined`
    - _Requirements: 2.3_

- [ ] 8. Implement measurement system
  - [x] 8.1 Create MeasurementManager
    - Implement calculateMeasurements method
    - Use Shoelace formula for area calculation
    - Calculate minimum bounding rectangle for length/width
    - Calculate perimeter from boundary points
    - _Requirements: 2.4, 2.5_
  
  - [~] 8.2 Write property test for area calculation
    - **Property 4: Area Calculation from Boundary**
    - **Validates: Requirements 2.4**
  
  - [~] 8.3 Write property test for comprehensive measurements
    - **Property 5: Comprehensive Measurement Calculation**
    - **Validates: Requirements 2.5**
  
  - [~] 8.4 Implement depth estimation
    - Extract depth values from depth map within wound boundary
    - Calculate average depth relative to surrounding tissue
    - Filter outliers using median absolute deviation
    - Convert depth map units to millimeters
    - _Requirements: 2.6_
  
  - [~] 8.5 Write property test for depth estimation
    - **Property 7: Depth Estimation on Capable Devices**
    - **Validates: Requirements 2.6**
  
  - [~] 8.6 Implement volume calculation
    - Integrate depth values over wound area
    - Calculate volume from area and depth
    - _Requirements: 2.7_
  
  - [~] 8.7 Write property test for volume calculation
    - **Property 6: Depth-Based Volume Calculation**
    - **Validates: Requirements 2.7**
  
  - [~] 8.8 Implement calibration system
    - Create createCalibration method
    - Support ruler, coin, and custom reference objects
    - Calculate pixel-to-millimeter ratio
    - _Requirements: 12.1, 12.2_
  
  - [~] 8.9 Write property test for calibration ratio calculation
    - **Property 34: Calibration Ratio Calculation**
    - **Validates: Requirements 12.2**
  
  - [~] 8.10 Write property test for calibration application
    - **Property 35: Calibration Application to Measurements**
    - **Validates: Requirements 12.3**
  
  - [~] 8.11 Implement unit conversion
    - Convert measurements to both metric and imperial
    - Display both unit systems
    - _Requirements: 2.9_
  
  - [~] 8.12 Write property test for dual unit display
    - **Property 8: Dual Unit Display**
    - **Validates: Requirements 2.9**
  
  - [~] 8.13 Implement measurement history
    - Store previous measurement versions
    - Track manual adjustments
    - _Requirements: 2.10_
  
  - [~] 8.14 Write property test for measurement history preservation
    - **Property 9: Measurement History Preservation**
    - **Validates: Requirements 2.10**

- [ ] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement user role management
  - [ ] 10.1 Create UserManager
    - Implement setUserRole and getUserRole methods
    - Add canAccessFeature method for role-based features
    - Store user role in Core Data
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [ ] 10.2 Implement first-launch role selection
    - Create onboarding UI for role selection
    - Persist selected role
    - _Requirements: 8.1_
  
  - [ ] 10.3 Write property test for doctor patient association requirement
    - **Property 25: Doctor Role Patient Association Requirement**
    - **Validates: Requirements 8.4**
  
  - [ ] 10.4 Write property test for patient self-documentation
    - **Property 26: Patient Role Self-Documentation**
    - **Validates: Requirements 8.5**

- [ ] 11. Implement patient management (doctor role)
  - [ ] 11.1 Create PatientManager
    - Implement CRUD operations for patients
    - Add search functionality with partial matching
    - Implement patient list management
    - _Requirements: 16.4, 17.3_
  
  - [ ] 11.2 Create patient-centric views
    - Implement patient list view grouped by patient
    - Add patient detail view with wound records
    - Calculate aggregate statistics (total wounds, active wounds, healing trends)
    - _Requirements: 17.1, 17.2, 17.5_
  
  - [ ] 11.3 Write property test for patient record display with statistics
    - **Property 45: Patient Record Display with Statistics**
    - **Validates: Requirements 17.2, 17.5**
  
  - [ ] 11.4 Write property test for patient search partial matching
    - **Property 46: Patient Search Partial Matching**
    - **Validates: Requirements 17.4**
  
  - [ ] 11.5 Implement patient identification in capture workflow
    - Prompt for patient ID if not associated
    - Display patient info in camera interface
    - Embed patient metadata in captured images
    - _Requirements: 16.1, 16.2, 16.3_
  
  - [ ] 11.6 Write property test for doctor patient identification prompt
    - **Property 43: Doctor Patient Identification Prompt**
    - **Validates: Requirements 16.1**
  
  - [ ] 11.7 Write property test for patient metadata in doctor captures
    - **Property 44: Patient Metadata in Doctor Captures**
    - **Validates: Requirements 16.2, 16.3, 16.5, 16.6**

- [ ] 12. Implement wound record management
  - [ ] 12.1 Create WoundManager
    - Implement CRUD operations for wound records
    - Add wound record creation with prompts (location, date, patient info)
    - Implement archive and delete functionality
    - _Requirements: 10.1, 10.2, 10.4_
  
  - [ ] 12.2 Write property test for wound record creation prompts
    - **Property 30: Wound Record Creation Prompts**
    - **Validates: Requirements 10.2**
  
  - [ ] 12.3 Write property test for deletion confirmation
    - **Property 31: Deletion Confirmation**
    - **Validates: Requirements 10.5**
  
  - [ ] 12.4 Implement capture session management
    - Create capture sessions associated with wound records
    - Store photos, measurements, and metadata
    - Add notes and tags to capture sessions
    - _Requirements: 1.5, 4.1, 4.4_
  
  - [ ] 12.5 Write property test for automatic timestamp recording
    - **Property 14: Automatic Timestamp Recording**
    - **Validates: Requirements 4.2**
  
  - [ ] 12.6 Write property test for location recording with permission
    - **Property 15: Location Recording with Permission**
    - **Validates: Requirements 4.3**
  
  - [ ] 12.7 Write property test for metadata persistence
    - **Property 16: Metadata Persistence**
    - **Validates: Requirements 4.5, 5.1**

- [ ] 13. Implement timeline and history views
  - [ ] 13.1 Create timeline UI
    - Display capture sessions in reverse chronological order
    - Show thumbnails, timestamps, and key measurements
    - Implement timeline entry selection for detail view
    - _Requirements: 3.1, 3.2, 3.3_
  
  - [ ] 13.2 Write property test for timeline chronological ordering
    - **Property 10: Timeline Chronological Ordering**
    - **Validates: Requirements 3.1**
  
  - [ ] 13.3 Write property test for timeline entry completeness
    - **Property 11: Timeline Entry Completeness**
    - **Validates: Requirements 3.2, 10.3**
  
  - [ ] 13.4 Implement comparison views
    - Add visual indicators for wound size changes
    - Calculate and display change percentages
    - _Requirements: 3.4_
  
  - [ ] 13.5 Write property test for wound size change indicators
    - **Property 12: Wound Size Change Indicators**
    - **Validates: Requirements 3.4**
  
  - [ ] 13.6 Implement filtering and sorting
    - Add date range filter
    - Add wound status filter
    - Add wound location filter
    - _Requirements: 3.5, 17.6_
  
  - [ ] 13.7 Write property test for timeline date range filtering
    - **Property 13: Timeline Date Range Filtering**
    - **Validates: Requirements 3.5, 17.6**
  
  - [ ] 13.8 Write property test for multi-criteria record filtering
    - **Property 47: Multi-Criteria Record Filtering**
    - **Validates: Requirements 17.6**

- [ ] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Implement CloudKit synchronization
  - [ ] 15.1 Create SyncManager
    - Implement enableSync and disableSync methods
    - Add forceSyncNow method
    - Implement getSyncStatus method
    - _Requirements: 6.1, 6.2, 6.4_
  
  - [ ] 15.2 Write property test for iCloud sync when enabled
    - **Property 20: iCloud Sync When Enabled**
    - **Validates: Requirements 6.1, 6.2**
  
  - [ ] 15.3 Write property test for local-only operation when sync disabled
    - **Property 22: Local-Only Operation When Sync Disabled**
    - **Validates: Requirements 6.4**
  
  - [ ] 15.4 Implement sync conflict resolution
    - Detect conflicts using persistent history
    - Preserve both versions
    - Create UI for user resolution
    - _Requirements: 6.3_
  
  - [ ] 15.5 Write property test for sync conflict preservation
    - **Property 21: Sync Conflict Preservation**
    - **Validates: Requirements 6.3**
  
  - [ ] 15.6 Implement offline sync queue
    - Queue sync operations when offline
    - Automatically process queue when connectivity restored
    - Implement exponential backoff for retries
    - _Requirements: 13.2, 13.3_
  
  - [ ] 15.7 Write property test for offline sync queue
    - **Property 37: Offline Sync Queue**
    - **Validates: Requirements 13.2**
  
  - [ ] 15.8 Write property test for automatic sync queue processing
    - **Property 38: Automatic Sync Queue Processing**
    - **Validates: Requirements 13.3**
  
  - [ ] 15.9 Add sync status UI indicators
    - Display sync status (synced, pending, offline, error)
    - Show sync progress
    - _Requirements: 13.4_
  
  - [ ] 15.10 Write property test for sync status UI indication
    - **Property 39: Sync Status UI Indication**
    - **Validates: Requirements 13.4**

- [ ] 16. Implement export system
  - [ ] 16.1 Create ExportManager
    - Implement createExport method for multiple formats
    - Support PDF, images, and native format
    - Add export options (include photos, measurements, notes, anonymize, date range)
    - _Requirements: 7.1, 7.2, 7.4_
  
  - [ ] 16.2 Write property test for export package creation
    - **Property 23: Export Package Creation**
    - **Validates: Requirements 7.1, 7.5**
  
  - [ ] 16.3 Write property test for multi-format export support
    - **Property 24: Multi-Format Export Support**
    - **Validates: Requirements 7.2**
  
  - [ ] 16.4 Implement PDF report generation
    - Use PDFKit to create reports
    - Include wound progression charts
    - Add measurement tables with trend analysis
    - Embed photos with timestamps
    - Add HIPAA compliance disclaimer
    - _Requirements: 7.2, 9.5_
  
  - [ ] 16.5 Write property test for HIPAA export warning
    - **Property 29: HIPAA Export Warning**
    - **Validates: Requirements 9.5**
  
  - [ ] 16.6 Implement data anonymization
    - Remove patient identifiers from exports
    - Provide anonymization option in export UI
    - _Requirements: 9.3_
  
  - [ ] 16.7 Write property test for data anonymization option
    - **Property 27: Data Anonymization Option**
    - **Validates: Requirements 9.3**
  
  - [ ] 16.8 Implement share functionality
    - Use iOS native share sheet
    - Handle share completion and errors
    - _Requirements: 7.3_

- [ ] 17. Implement error handling and logging
  - [ ] 17.1 Add comprehensive error handling
    - Implement error recovery strategies (retry, queue, graceful degradation)
    - Add user-facing error messages with actionable steps
    - Implement transaction rollback on failures
    - _Requirements: All error scenarios_
  
  - [ ] 17.2 Implement local error logging
    - Create encrypted log files
    - Implement log rotation (7 days, 10MB max)
    - Add user-accessible log export (sanitized)
    - _Requirements: 14.4_
  
  - [ ] 17.3 Write property test for local error logging
    - **Property 42: Local Error Logging**
    - **Validates: Requirements 14.4**
  
  - [ ] 17.4 Implement data integrity checks
    - Add checksum generation for files
    - Implement periodic integrity verification
    - Add corruption detection and recovery
    - _Requirements: 14.3_
  
  - [ ] 17.5 Write property test for data integrity checksums
    - **Property 41: Data Integrity Checksums**
    - **Validates: Requirements 14.3**

- [ ] 18. Implement privacy and security features
  - [ ] 18.1 Write property test for no third-party data transmission
    - **Property 28: No Third-Party Data Transmission**
    - **Validates: Requirements 9.4**
  
  - [ ] 18.2 Implement session timeout
    - Add 5-minute inactivity timer
    - Require re-authentication after timeout
    - _Requirements: 9.2_
  
  - [ ] 18.3 Implement secure deletion
    - Overwrite file data before removal
    - Securely delete encryption keys
    - _Requirements: 10.5_

- [ ] 19. Implement accessibility features
  - [ ] 19.1 Add VoiceOver support
    - Add accessibility labels to all UI elements
    - Implement custom accessibility actions
    - Test with VoiceOver enabled
    - _Requirements: 15.1_
  
  - [ ] 19.2 Add Dynamic Type support
    - Use system font sizes
    - Test with various text size settings
    - _Requirements: 15.2_
  
  - [ ] 19.3 Add Voice Control support
    - Add voice control labels
    - Test hands-free operation
    - _Requirements: 15.4_
  
  - [ ] 19.4 Implement alternative interaction methods
    - Add alternative camera controls for accessibility
    - Add alternative measurement tools
    - _Requirements: 15.5_

- [ ] 20. Polish and optimization
  - [ ] 20.1 Implement performance optimizations
    - Resize images for ML inference
    - Use background queues for processing
    - Implement lazy loading and pagination
    - Cache detection results
    - _Requirements: Performance considerations_
  
  - [ ] 20.2 Add storage management UI
    - Display storage usage
    - Provide cleanup tools
    - Warn at 80% capacity
    - _Requirements: 5.5_
  
  - [ ] 20.3 Implement uncalibrated measurement warning
    - Display warning when no calibration available
    - _Requirements: 12.5_
  
  - [ ] 20.4 Write property test for uncalibrated measurement warning
    - **Property 36: Uncalibrated Measurement Warning**
    - **Validates: Requirements 12.5**

- [ ] 21. Final checkpoint - Comprehensive testing
  - Run all unit tests and property-based tests
  - Perform manual testing checklist (camera, detection, measurements, sync, export, security, accessibility)
  - Test on multiple iOS versions and device types
  - Verify HIPAA compliance measures
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- All tasks are required for comprehensive implementation with property-based testing
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties with minimum 100 iterations
- Unit tests validate specific examples and edge cases
- The implementation uses Swift and native iOS frameworks (SwiftUI, Core Data, AVFoundation, CoreML, CloudKit)
- Minimum iOS version is 16.0 for LiDAR and latest camera APIs
- No third-party dependencies in production code (except SwiftCheck for testing)
