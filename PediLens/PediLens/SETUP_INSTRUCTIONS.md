# PediLens Project Setup Instructions

## Quick Start

All the core infrastructure code has been created for you. Follow these steps to complete the Xcode project setup:

### Step 1: Create Xcode Project

1. Open **Xcode**
2. Select **File → New → Project**
3. Choose **iOS → App**
4. Configure the project:
   - **Product Name**: `PediLens`
   - **Team**: Select your development team
   - **Organization Identifier**: `com.pedilens`
   - **Bundle Identifier**: `com.pedilens.app`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **Core Data** ✓ (Check this box!)
   - **Include Tests**: ✓ (Optional but recommended)
5. Save the project in a temporary location (you'll move files later)

### Step 2: Replace Generated Files

The following files have already been created with the correct implementation. Replace Xcode's generated versions:

#### Delete from Xcode's generated project:
- `PediLensApp.swift` (we have a better version)
- `ContentView.swift` (we have a better version)
- `Persistence.swift` (we have `PersistenceController.swift` instead)
- `PediLens.xcdatamodeld` (we have the complete model)

#### Copy these files into your Xcode project:

1. **App Entry Point**:
   ```
   PediLens/PediLensApp.swift → Add to Xcode project root
   ```

2. **Views**:
   ```
   PediLens/Views/ContentView.swift → Add to Views group
   ```

3. **Models** (Core Data):
   ```
   PediLens/Models/PersistenceController.swift → Add to Models group
   PediLens/Models/PediLens.xcdatamodeld/ → Add to Models group (entire folder)
   ```

4. **Storage**:
   ```
   PediLens/Storage/FileStorageManager.swift → Add to Storage group (create group if needed)
   ```

5. **Configuration**:
   ```
   PediLens/PediLens.entitlements → Replace Xcode's version
   PediLens/Info.plist → Merge with Xcode's version (see below)
   ```

### Step 3: Configure Info.plist

Add these keys to your Info.plist (or merge with the provided one):

```xml
<key>NSCameraUsageDescription</key>
<string>PediLens needs camera access to capture wound photos for documentation and tracking.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>PediLens uses your location to tag wound documentation sessions for better record keeping.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>PediLens needs access to save wound photos to your photo library.</string>

<key>LSApplicationCategoryType</key>
<string>public.app-category.medical</string>
```

### Step 4: Configure iCloud Capability

1. Select your project in the Project Navigator
2. Select the **PediLens** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **iCloud**
6. In the iCloud section:
   - Check **CloudKit**
   - Click the **+** button under "Containers"
   - Enter: `iCloud.com.pedilens.app`
   - (Or use your own container identifier if you prefer)

### Step 5: Update Entitlements

Your `PediLens.entitlements` file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.pedilens.app</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.ubiquity-container-identifiers</key>
    <array>
        <string>iCloud.com.pedilens.app</string>
    </array>
</dict>
</plist>
```

### Step 6: Set Deployment Target

1. Select your project in the Project Navigator
2. Select the **PediLens** target
3. Go to **General** tab
4. Set **Minimum Deployments** to **iOS 16.0**

### Step 7: Build and Run

1. Select a simulator (iPhone 15 or later recommended)
2. Press **⌘ + B** to build
3. Press **⌘ + R** to run

You should see the PediLens app launch with a medical cross icon and the app name.

## Verification Checklist

After setup, verify these items:

- [ ] Project builds without errors
- [ ] App runs on simulator
- [ ] Core Data model loads (check console for errors)
- [ ] File storage directories are created (check Documents folder)
- [ ] iCloud capability is enabled
- [ ] CloudKit container is configured
- [ ] Minimum iOS version is 16.0

## What's Been Implemented

### ✅ Task 1 Requirements

All requirements for Task 1 have been implemented:

1. **Core Data Model**: Complete with all 7 entities
   - User, Patient, WoundRecord, CaptureSession, Photo, Measurement, Note
   - Proper relationships and attributes
   - CloudKit sync configuration

2. **Persistence Controller**: 
   - NSPersistentCloudKitContainer configured
   - Persistent history tracking enabled
   - Merge policies set up
   - Preview instance for SwiftUI

3. **File Storage Manager**:
   - Photo storage with HEIC format
   - Thumbnail generation
   - Live Photo support
   - Depth data storage
   - Directory structure (Photos/, Exports/)
   - Data Protection API enabled

4. **iCloud Configuration**:
   - CloudKit container identifier set
   - Entitlements configured
   - Automatic sync enabled

5. **Security**:
   - File protection enabled (`.complete`)
   - Ready for encryption layer (Task 2)

### 📁 Project Structure

```
PediLens/
├── PediLensApp.swift              # ✅ App entry point
├── PediLens.entitlements          # ✅ iCloud/CloudKit config
├── Info.plist                     # ✅ Privacy permissions
├── Views/
│   └── ContentView.swift          # ✅ Initial UI
├── Models/
│   ├── PersistenceController.swift # ✅ Core Data stack
│   └── PediLens.xcdatamodeld/     # ✅ Data model
├── Storage/
│   └── FileStorageManager.swift   # ✅ File operations
└── Resources/
    └── Assets.xcassets/           # ✅ App assets
```

## Troubleshooting

### Build Errors

**Error**: "No such module 'CoreData'"
- **Solution**: Make sure you selected "Core Data" when creating the project

**Error**: "CloudKit container not found"
- **Solution**: Check that iCloud capability is enabled and container ID matches

**Error**: "Code signing failed"
- **Solution**: Select your development team in Signing & Capabilities

### Runtime Errors

**Error**: "Core Data store failed to load"
- **Solution**: Check console for specific error. May need to reset simulator.

**Error**: "Unable to create directory"
- **Solution**: Check app has proper file system permissions

## Next Steps

Once the project is set up and building successfully:

1. **Test the Core Data stack**: 
   - Run the app
   - Check console for "Core Data store loaded successfully" (or similar)

2. **Test file storage**:
   - The FileStorageManager will create directories on first use
   - Check Documents/PediLens/ folder is created

3. **Proceed to Task 2**: Implement security and encryption layer
   - SecurityManager with AES-256 encryption
   - Biometric authentication
   - Keychain integration

## Support

If you encounter issues:

1. Check the console output for specific error messages
2. Verify all files are added to the Xcode project target
3. Clean build folder (⌘ + Shift + K) and rebuild
4. Reset simulator if Core Data issues persist

## Requirements Mapping

This setup satisfies:
- **Requirement 5.1**: Local storage with Core Data
- **Requirement 6.1**: iCloud synchronization infrastructure
- **Requirement 5.3**: File encryption foundation (Data Protection API)

---

**Ready to proceed?** Once your project builds successfully, you can move on to Task 2!
