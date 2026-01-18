# Requirements Document: PediLens

## Introduction

PediLens is a native iOS application designed to help doctors and patients document and track the healing progression of diabetic foot ulcers. The app leverages iPhone camera capabilities to capture high-quality wound images, provides measurement tools for tracking wound dimensions, and maintains a comprehensive timeline of the healing process. All data is stored locally on the device with optional iCloud synchronization, ensuring offline-first functionality and user privacy.

## Glossary

- **PediLens**: The native iOS application system
- **User**: A doctor or patient using the application
- **Wound_Record**: A collection of data about a specific diabetic foot ulcer including photos, measurements, and metadata
- **Capture_Session**: An instance of taking a photo or live photo of a wound
- **Measurement**: Dimensional data about a wound (length, width, depth, area, volume)
- **Timeline**: Chronological history of all capture sessions for a specific wound
- **Local_Storage**: On-device data storage using iOS file system
- **iCloud_Sync**: Optional cloud backup and synchronization service
- **Export_Package**: A shareable collection of wound data including photos and metadata
- **HIPAA**: Health Insurance Portability and Accountability Act - US healthcare data privacy regulations
- **Live_Photo**: iOS camera feature that captures a short video clip alongside a still image
- **Patient_Identifier**: Name and/or ID used to associate wound records with specific patients
- **Patient_List**: A managed collection of patient identifiers for Doctor users
- **CoreML**: Apple's machine learning framework for on-device model inference
- **Wound_Boundary**: The detected or manually marked perimeter of a wound in a photo
- **Depth_Camera**: iPhone camera hardware that captures depth information using LiDAR or dual-camera systems

## Requirements

### Requirement 1: Wound Photo Capture

**User Story:** As a user, I want to capture high-quality photos of diabetic foot ulcers using my iPhone camera, so that I can document the wound's appearance over time.

#### Acceptance Criteria

1. WHEN a user initiates a capture session, THE PediLens SHALL activate the native iOS camera interface
2. WHEN capturing a wound photo, THE PediLens SHALL support both standard photos and live photos
3. WHEN a photo is captured, THE PediLens SHALL store the image in Local_Storage immediately
4. WHEN the camera interface is active, THE PediLens SHALL provide visual guides to assist with consistent framing and positioning
5. WHEN a capture session completes, THE PediLens SHALL associate the captured media with the active Wound_Record

### Requirement 2: Wound Measurement Tools

**User Story:** As a user, I want to measure wound dimensions directly on captured photos, so that I can track changes in wound size over time.

#### Acceptance Criteria

1. WHEN a user views a captured wound photo, THE PediLens SHALL provide tools to mark and measure wound boundaries
2. WHEN a wound photo is captured, THE PediLens SHALL automatically detect wound boundaries using iOS image processing and CoreML
3. WHEN automatic detection completes, THE PediLens SHALL allow users to review and manually adjust the detected boundaries
4. WHEN a Wound_Boundary is established, THE PediLens SHALL automatically calculate the wound area based on the boundary perimeter
5. WHEN measurements are taken, THE PediLens SHALL calculate length, width, and area from the Wound_Boundary
6. WHERE the device supports depth perception, THE PediLens SHALL estimate wound depth using the iPhone depth camera
7. WHEN depth estimation is available, THE PediLens SHALL calculate wound volume based on area and depth measurements
8. WHEN measurements are completed, THE PediLens SHALL store the Measurement data with the associated photo
9. WHEN displaying measurements, THE PediLens SHALL show units in both metric (cm, cm², cm³) and imperial (inches, in², in³) formats
10. WHEN a user modifies measurements, THE PediLens SHALL preserve the measurement history

### Requirement 3: Wound Timeline and History

**User Story:** As a user, I want to view a chronological timeline of all wound documentation, so that I can assess healing progression over time.

#### Acceptance Criteria

1. WHEN a user opens a Wound_Record, THE PediLens SHALL display a Timeline of all capture sessions in reverse chronological order
2. WHEN displaying the Timeline, THE PediLens SHALL show thumbnail images, timestamps, and key measurements for each session
3. WHEN a user selects a Timeline entry, THE PediLens SHALL display the full capture session details including photos and measurements
4. WHEN comparing Timeline entries, THE PediLens SHALL provide visual indicators of wound size changes
5. THE PediLens SHALL support filtering and sorting Timeline entries by date range

### Requirement 4: Metadata and Notes

**User Story:** As a user, I want to add contextual information to each wound documentation session, so that I can record relevant clinical observations and patient notes.

#### Acceptance Criteria

1. WHEN creating or editing a capture session, THE PediLens SHALL allow users to add text notes
2. WHEN a capture session is created, THE PediLens SHALL automatically record the timestamp
3. WHEN a capture session is created, THE PediLens SHALL automatically record device location (if permission granted)
4. THE PediLens SHALL support tagging capture sessions with predefined categories (e.g., "improved", "unchanged", "worsened")
5. WHEN metadata is added, THE PediLens SHALL store it with the associated Wound_Record in Local_Storage

### Requirement 5: Local Storage and Data Persistence

**User Story:** As a user, I want all my wound documentation stored securely on my device, so that I can access my data without an internet connection.

#### Acceptance Criteria

1. THE PediLens SHALL store all Wound_Records, photos, and metadata in Local_Storage
2. WHEN the app is offline, THE PediLens SHALL provide full read and write access to all stored data
3. WHEN storing sensitive medical data, THE PediLens SHALL encrypt data at rest using iOS encryption APIs
4. WHEN Local_Storage is accessed, THE PediLens SHALL require device authentication (Face ID, Touch ID, or passcode)
5. THE PediLens SHALL manage storage efficiently to prevent excessive device storage consumption

### Requirement 6: iCloud Synchronization

**User Story:** As a user, I want to optionally sync my wound documentation to iCloud, so that I can access my data across multiple devices and have a backup.

#### Acceptance Criteria

1. WHERE iCloud_Sync is enabled, THE PediLens SHALL synchronize all Wound_Records to the user's iCloud account
2. WHEN iCloud_Sync is enabled, THE PediLens SHALL sync changes automatically when network connectivity is available
3. WHEN sync conflicts occur, THE PediLens SHALL preserve both versions and allow user resolution
4. WHERE iCloud_Sync is disabled, THE PediLens SHALL function entirely with Local_Storage
5. WHEN iCloud_Sync status changes, THE PediLens SHALL notify the user of sync progress and any errors

### Requirement 7: Data Export and Sharing

**User Story:** As a user, I want to export and share wound documentation with healthcare providers or patients, so that I can facilitate collaborative care.

#### Acceptance Criteria

1. WHEN a user initiates export, THE PediLens SHALL create an Export_Package containing selected photos, measurements, and metadata
2. WHEN creating an Export_Package, THE PediLens SHALL support multiple formats (PDF report, image files with metadata, or native format)
3. WHEN sharing data, THE PediLens SHALL use iOS native share sheet for secure transmission
4. WHEN exporting data, THE PediLens SHALL allow users to select specific Timeline entries or date ranges
5. WHEN an Export_Package is created, THE PediLens SHALL include a summary report with wound progression statistics

### Requirement 8: User Roles and Workflows

**User Story:** As a doctor or patient, I want workflows tailored to my role, so that the app supports my specific documentation needs.

#### Acceptance Criteria

1. WHEN a user first launches PediLens, THE PediLens SHALL prompt the user to select their role (Doctor or Patient)
2. WHERE the user role is Doctor, THE PediLens SHALL provide features for managing multiple patient Wound_Records
3. WHERE the user role is Patient, THE PediLens SHALL provide simplified workflows focused on self-documentation
4. WHEN a Doctor user creates a Wound_Record, THE PediLens SHALL require association with patient identifiers (name and/or ID)
5. WHEN a Patient user creates a Wound_Record, THE PediLens SHALL focus on personal tracking without patient identifiers

### Requirement 16: Patient Identification and Tagging

**User Story:** As a doctor or care provider, I want to tag each wound photo with patient name and ID during capture, so that I can maintain organized records for multiple patients.

#### Acceptance Criteria

1. WHEN a Doctor user initiates a capture session, THE PediLens SHALL prompt for patient identification if not already associated
2. WHEN capturing a wound photo, THE PediLens SHALL display the associated patient name and ID in the camera interface
3. WHEN a capture session completes, THE PediLens SHALL embed patient metadata with the captured image
4. THE PediLens SHALL allow Doctor users to create and manage a patient list with names and IDs
5. WHEN viewing Wound_Records, THE PediLens SHALL display patient identifiers prominently for Doctor users
6. WHEN exporting data, THE PediLens SHALL include patient identification in the Export_Package metadata

### Requirement 17: Patient-Centric Views and Search

**User Story:** As a doctor or care provider, I want to view and search all wound documentation organized by patient, so that I can review a patient's complete wound healing history.

#### Acceptance Criteria

1. WHERE the user role is Doctor, THE PediLens SHALL provide a patient-centric view showing all Wound_Records grouped by patient
2. WHEN a Doctor user selects a patient, THE PediLens SHALL display all associated Wound_Records with summary statistics
3. THE PediLens SHALL provide search functionality to find patients by name or ID
4. WHEN searching, THE PediLens SHALL support partial matching and display results in real-time
5. WHEN viewing a patient's records, THE PediLens SHALL show aggregate data including total wounds tracked, active wounds, and healing trends
6. THE PediLens SHALL allow filtering patient records by date range, wound status, or wound location

### Requirement 9: Privacy and Security Compliance

**User Story:** As a user handling sensitive medical data, I want the app to protect patient privacy and comply with healthcare regulations, so that I can use it confidently in clinical settings.

#### Acceptance Criteria

1. THE PediLens SHALL implement encryption for all stored medical data using iOS security frameworks
2. THE PediLens SHALL require device authentication before accessing any Wound_Records
3. WHEN handling patient identifiable information, THE PediLens SHALL provide options to anonymize data for sharing
4. THE PediLens SHALL not transmit any data to third-party servers without explicit user consent
5. WHEN exporting data, THE PediLens SHALL provide warnings about HIPAA compliance responsibilities

### Requirement 10: Wound Record Management

**User Story:** As a user, I want to create, organize, and manage multiple wound records, so that I can track different wounds or patients separately.

#### Acceptance Criteria

1. THE PediLens SHALL allow users to create multiple Wound_Records
2. WHEN creating a Wound_Record, THE PediLens SHALL prompt for wound location, initial assessment date, and optional patient information
3. WHEN displaying Wound_Records, THE PediLens SHALL show a list view with wound identifiers and last update timestamps
4. THE PediLens SHALL allow users to archive or delete Wound_Records
5. WHEN a Wound_Record is deleted, THE PediLens SHALL prompt for confirmation and optionally create a final Export_Package

### Requirement 11: Camera Features and Image Quality

**User Story:** As a user, I want to leverage advanced iPhone camera features to capture the highest quality wound documentation, so that clinical details are clearly visible.

#### Acceptance Criteria

1. WHEN capturing photos, THE PediLens SHALL support the highest resolution available on the device
2. WHEN the device supports it, THE PediLens SHALL enable HDR (High Dynamic Range) photography
3. WHEN capturing in low light conditions, THE PediLens SHALL automatically enable Night Mode if available
4. WHEN capturing Live_Photos, THE PediLens SHALL store both the still image and video components
5. THE PediLens SHALL provide manual controls for focus, exposure, and white balance

### Requirement 12: Measurement Calibration

**User Story:** As a user, I want to calibrate measurements using a reference object, so that wound dimensions are accurate and consistent.

#### Acceptance Criteria

1. WHEN taking measurements, THE PediLens SHALL allow users to place a reference object (ruler, coin) in the photo for scale calibration
2. WHEN a reference object is identified, THE PediLens SHALL calculate a pixel-to-distance ratio for accurate measurements
3. WHEN calibration is set, THE PediLens SHALL apply the calibration to all measurements in that capture session
4. THE PediLens SHALL provide a library of common reference objects with known dimensions
5. WHEN no calibration is available, THE PediLens SHALL warn users that measurements are estimates

### Requirement 13: Offline-First Architecture

**User Story:** As a user who may work in areas with limited connectivity, I want the app to function fully offline, so that I can document wounds regardless of network availability.

#### Acceptance Criteria

1. THE PediLens SHALL provide all core functionality without requiring network connectivity
2. WHEN the device is offline, THE PediLens SHALL queue iCloud_Sync operations for later execution
3. WHEN network connectivity is restored, THE PediLens SHALL automatically process queued sync operations
4. THE PediLens SHALL clearly indicate sync status (synced, pending, offline) in the user interface
5. WHEN offline, THE PediLens SHALL allow full creation, editing, and viewing of all Wound_Records

### Requirement 14: Data Integrity and Validation

**User Story:** As a user, I want the app to validate and protect my data, so that I don't lose important wound documentation due to errors or corruption.

#### Acceptance Criteria

1. WHEN storing data, THE PediLens SHALL validate all Wound_Record data structures before persisting
2. WHEN data corruption is detected, THE PediLens SHALL attempt recovery from iCloud_Sync backups if available
3. THE PediLens SHALL maintain data integrity checksums for all stored photos and metadata
4. WHEN critical errors occur, THE PediLens SHALL log errors locally for troubleshooting without transmitting data externally
5. THE PediLens SHALL perform periodic data integrity checks and notify users of any issues

### Requirement 15: Accessibility and Usability

**User Story:** As a user with accessibility needs, I want the app to support iOS accessibility features, so that I can use it effectively regardless of visual or motor limitations.

#### Acceptance Criteria

1. THE PediLens SHALL support VoiceOver for screen reading
2. THE PediLens SHALL support Dynamic Type for adjustable text sizes
3. THE PediLens SHALL provide sufficient color contrast for users with visual impairments
4. THE PediLens SHALL support Voice Control for hands-free operation
5. WHEN accessibility features are enabled, THE PediLens SHALL provide alternative interaction methods for camera and measurement tools
