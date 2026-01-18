# PediLens - iOS Application

## Project Setup Status

This directory contains the initial project structure for PediLens, a native iOS application for documenting and tracking diabetic foot ulcer healing progression.

### What Has Been Created

#### 1. **Core Data Model** (`Models/PediLens.xcdatamodeld/`)
Complete Core Data model with all required entities:
- **User**: Stores user role (doctor/patient) and iCloud sync preferences
- **Patient**: Patient information (name, ID, date of birth, notes)
- **WoundRecord**: Wound documentation (location, status, assessment dates)
- **CaptureSession**: Individual photo capture sessions with metadata
- **Photo**: Photo storage references and thumbnails
- **Measurement**: Wound measurements (dimensions, area, volume, depth)
- **Note**: Text notes and observations for capture sessions

#### 2. **Persistence Controller** (`Models/PersistenceController.swift`)
- Configured `NSPersistentCloudKitContainer` for CloudKit synchronization
- Enabled persistent history tracking for sync
- Set up merge policies for conflict resolution
- Configured CloudKit container identifier: `iCloud.com.pedilens.app`
- Includes preview instance for SwiftUI previews

#### 3. **File Storage Manager** (`Storage/FileStorageManager.swift`)
Complete file storage system with:
- Photo storage in HEIC format with Data Protection API
- Thumbnail generation (300x300)
- Live Photo video component storage
- Depth data storage
- Storage usage tracking
- Directory structure:
  - `Documents/PediLens/Photos/{sessionID}/`
  - `Documents/PediLens/Exports/`

#### 4. **App Structure**
- `PediLensApp.swift`: Main app entry point with Core Data environment
- `Views/ContentView.swift`: Initial placeholder view
- `Resources/Assets.xcassets`: Asset catalog with AppIcon and AccentColor

#### 5. **Configuration Files**
- **PediLens.entitlements**: iCloud and CloudKit capabilities configured
  - CloudKit container: `iCloud.com.pedilens.app`
  - iCloud services enabled
  - App groups configured
- **Info.plist**: Privacy permissions and app metadata
  - Camera usage description
  - Location usage description
  - Photo library usage description
  - Minimum iOS version: 16.0

### Next Steps to Complete Project Setup

Since Xcode project files (`.pbxproj`) are complex binary-like files that are best created by Xcode itself, you should:

#### Option 1: Create Project in Xcode (Recommended)

1. **Open Xcode** and create a new project:
   - Choose "App" template
   - Product Name: `PediLens`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: Core Data
   - Include CloudKit
   - Bundle Identifier: `com.pedilens.app`
   - Minimum iOS: 16.0

2. **Replace the generated files** with the ones in this directory:
   - Copy `Models/PersistenceController.swift` → Replace Xcode's version
   - Copy `Models/PediLens.xcdatamodeld/` → Replace Xcode's data model
   - Copy `Storage/FileStorageManager.swift` → Add to project
   - Copy `Views/ContentView.swift` → Replace Xcode's version
   - Copy `PediLensApp.swift` → Replace Xcode's version
   - Copy `PediLens.entitlements` → Replace Xcode's version
   - Copy `Info.plist` → Merge with Xcode's version

3. **Configure iCloud Capability**:
   - Select project in navigator
   - Select target → Signing & Capabilities
   - Add "iCloud" capability
   - Enable "CloudKit"
   - Set container: `iCloud.com.pedilens.app`

4. **Verify Build Settings**:
   - Deployment Target: iOS 16.0
   - Swift Language Version: Swift 5
   - Code Signing: Automatic

#### Option 2: Use Existing Files

If you prefer to work with the existing structure:

1. The Core Data model, PersistenceController, and FileStorageManager are complete and ready to use
2. You can import these files into any new Xcode project
3. Make sure to configure the entitlements and Info.plist as shown

### Requirements Satisfied

This setup satisfies the following requirements from Task 1:

✅ Core Data model with all entities (User, Patient, WoundRecord, CaptureSession, Photo, Measurement, Note)  
✅ NSPersistentCloudKitContainer configured for CloudKit sync  
✅ Persistent history tracking enabled  
✅ CloudKit container identifier set: `iCloud.com.pedilens.app`  
✅ iCloud capability configured in entitlements  
✅ File storage directory structure (Photos/, Exports/)  
✅ Minimum iOS version set to 16.0  
✅ Data Protection API enabled for file encryption  

### Architecture Overview

```
PediLens/
├── PediLens/
│   ├── PediLensApp.swift          # App entry point
│   ├── PediLens.entitlements      # iCloud/CloudKit capabilities
│   ├── Info.plist                 # App configuration
│   ├── Views/
│   │   └── ContentView.swift      # Main view
│   ├── Models/
│   │   ├── PersistenceController.swift
│   │   └── PediLens.xcdatamodeld/ # Core Data model
│   ├── Storage/
│   │   └── FileStorageManager.swift
│   └── Resources/
│       └── Assets.xcassets/
└── README.md                      # This file
```

### Core Data Entity Relationships

```
User (1) ──→ (N) Patient
Patient (1) ──→ (N) WoundRecord
WoundRecord (1) ──→ (N) CaptureSession
CaptureSession (1) ──→ (1) Measurement
CaptureSession (1) ──→ (N) Note
```

### CloudKit Sync Configuration

- **Container**: `iCloud.com.pedilens.app`
- **Sync Mode**: Automatic via NSPersistentCloudKitContainer
- **Conflict Resolution**: Property-level merge (newer wins)
- **History Tracking**: Enabled for change detection
- **Remote Notifications**: Enabled for push updates

### File Storage Structure

```
Documents/PediLens/
├── Photos/
│   └── {sessionID}/
│       ├── photo.heic          # Full resolution
│       ├── thumbnail.jpg       # 300x300 preview
│       ├── live_video.mov      # Live Photo video
│       └── depth.dat           # Depth map data
└── Exports/
    └── {exportID}/
        ├── report.pdf
        └── images/
```

### Security Features Implemented

- **File Protection**: `.complete` for sensitive files
- **CloudKit**: End-to-end encryption via Apple's infrastructure
- **Keychain**: Ready for encryption key storage (to be implemented in Task 2)
- **Data Protection API**: Enabled on all file operations

### Next Task

After completing the Xcode project setup, proceed to **Task 2: Implement security and encryption layer**.

---

**Note**: This project requires an Apple Developer account with iCloud/CloudKit capabilities enabled for full functionality.
