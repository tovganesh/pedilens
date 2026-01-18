# PediLens Project File Setup Guide

## Issue: Missing project.pbxproj File

The `project.pbxproj` file is Xcode's project configuration file. It's a complex XML-like format that's best created by Xcode itself rather than manually.

## Solution: Create Project in Xcode

Follow these steps to create the Xcode project and import all the pre-built source files:

### Step 1: Create New Xcode Project

1. **Open Xcode**

2. **Create New Project**:
   - File → New → Project
   - Choose **iOS → App**
   - Click **Next**

3. **Configure Project**:
   - **Product Name**: `PediLens`
   - **Team**: Select your development team
   - **Organization Identifier**: `com.pedilens`
   - **Bundle Identifier**: `com.pedilens.app`
   - **Interface**: **SwiftUI** ✓
   - **Language**: **Swift** ✓
   - **Storage**: **Core Data** ✓ (IMPORTANT!)
   - **Include Tests**: ✓ (Recommended)
   - Click **Next**

4. **Save Location**:
   - Navigate to the parent directory of your current `PediLens` folder
   - Create a temporary folder (e.g., `PediLens_Temp`)
   - Save the project there

### Step 2: Replace Generated Files

Now you'll replace Xcode's generated files with our pre-built implementations:

#### 2.1 Delete Xcode's Generated Files

In Xcode's Project Navigator, **delete** these files (Move to Trash):
- `PediLensApp.swift`
- `ContentView.swift`
- `Persistence.swift`
- `PediLens.xcdatamodeld`

#### 2.2 Add Our Pre-Built Files

**Drag and drop** these folders/files from your existing `PediLens` directory into Xcode:

1. **Models** folder:
   - `Models/PersistenceController.swift`
   - `Models/PediLens.xcdatamodeld/` (entire folder)

2. **Views** folder:
   - `Views/ContentView.swift`

3. **Managers** folder (create group if needed):
   - `Managers/SecurityManager.swift`

4. **Storage** folder (create group if needed):
   - `Storage/FileStorageManager.swift`

5. **Utilities** folder (create group if needed):
   - `Utilities/Localization.swift`

6. **Resources** folder:
   - `Resources/en.lproj/` (entire folder)

7. **Root files**:
   - `PediLensApp.swift`
   - `PediLens.entitlements`
   - `Info.plist` (merge with Xcode's version)

8. **Tests**:
   - Drag `PediLensTests/SecurityManagerTests.swift` to the test target
   - Drag `PediLensTests/SecurityManagerPropertyTests.swift` to the test target

**Important**: When dragging, ensure:
- ✅ "Copy items if needed" is checked
- ✅ "Create groups" is selected (not "Create folder references")
- ✅ Target membership includes "PediLens" (for app files) or "PediLensTests" (for test files)

### Step 3: Configure Project Settings

#### 3.1 Set Deployment Target

1. Select project in Navigator
2. Select **PediLens** target
3. **General** tab
4. Set **Minimum Deployments** to **iOS 16.0**

#### 3.2 Add iCloud Capability

1. Select **PediLens** target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **iCloud**
5. Check **CloudKit**
6. Click **+** under "Containers"
7. Enter: `iCloud.com.pedilens.app`

#### 3.3 Configure Info.plist

Add these privacy descriptions (if not already present):

```xml
<key>NSCameraUsageDescription</key>
<string>PediLens needs camera access to capture wound photos for documentation and tracking.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>PediLens uses your location to tag wound documentation sessions for better record keeping.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>PediLens needs access to save wound photos to your photo library.</string>

<key>NSFaceIDUsageDescription</key>
<string>PediLens uses Face ID to protect sensitive patient data.</string>
```

#### 3.4 Configure Entitlements

Ensure `PediLens.entitlements` contains:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.pedilens.app</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

### Step 4: Add Localization

1. Select `Localizable.strings` in Project Navigator
2. Open **File Inspector** (right panel)
3. Click **Localize...**
4. Select **English**
5. Click **Localize**

### Step 5: Build and Test

1. **Clean Build Folder**: Product → Clean Build Folder (⌘⇧K)
2. **Build**: Product → Build (⌘B)
3. **Run**: Product → Run (⌘R)

### Step 6: Verify Setup

Run the verification checklist:

- [ ] Project builds without errors
- [ ] App runs on simulator
- [ ] Core Data model loads (check console)
- [ ] File storage directories created
- [ ] iCloud capability enabled
- [ ] CloudKit container configured
- [ ] Localization working (check strings display)
- [ ] Tests run successfully (⌘U)

### Step 7: Move Project Files

Once everything works:

1. Close Xcode
2. Copy the `.xcodeproj` folder from `PediLens_Temp` to your original `PediLens` directory
3. Delete `PediLens_Temp`
4. Open `PediLens/PediLens.xcodeproj`

## Alternative: Use Swift Package Manager

If you prefer a more modern approach:

### Create Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PediLens",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "PediLens", targets: ["PediLens"])
    ],
    dependencies: [
        // Add SwiftCheck for property-based testing
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "PediLens",
            dependencies: [],
            path: "PediLens"
        ),
        .testTarget(
            name: "PediLensTests",
            dependencies: ["PediLens", "SwiftCheck"],
            path: "PediLensTests"
        )
    ]
)
```

However, note that SwiftUI apps with Core Data and CloudKit are typically better managed through Xcode projects.

## Troubleshooting

### Build Errors

**Error**: "No such module 'CoreData'"
- **Solution**: Ensure "Core Data" was checked when creating the project

**Error**: "CloudKit container not found"
- **Solution**: Verify iCloud capability is enabled and container ID matches

**Error**: "Code signing failed"
- **Solution**: Select your development team in Signing & Capabilities

### Runtime Errors

**Error**: "Core Data store failed to load"
- **Solution**: Check console for specific error. May need to reset simulator.

**Error**: "Unable to create directory"
- **Solution**: Check app has proper file system permissions

### Localization Issues

**Issue**: Strings not displaying in English
- **Solution**: Ensure `Localizable.strings` is in `en.lproj` folder
- **Solution**: Verify file is included in target membership

**Issue**: L10n helper not found
- **Solution**: Ensure `Localization.swift` is added to project
- **Solution**: Check target membership

## File Structure After Setup

```
PediLens/
├── PediLens.xcodeproj/
│   ├── project.pbxproj          ← Created by Xcode
│   ├── project.xcworkspace/
│   └── xcshareddata/
├── PediLens/
│   ├── PediLensApp.swift
│   ├── PediLens.entitlements
│   ├── Info.plist
│   ├── Models/
│   │   ├── PersistenceController.swift
│   │   └── PediLens.xcdatamodeld/
│   ├── Views/
│   │   └── ContentView.swift
│   ├── Managers/
│   │   └── SecurityManager.swift
│   ├── Storage/
│   │   └── FileStorageManager.swift
│   ├── Utilities/
│   │   └── Localization.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── en.lproj/
│           └── Localizable.strings
├── PediLensTests/
│   ├── SecurityManagerTests.swift
│   └── SecurityManagerPropertyTests.swift
├── .gitignore
└── README.md
```

## Next Steps

After successful project setup:

1. ✅ Verify all files are in project
2. ✅ Run tests (⌘U)
3. ✅ Test localization
4. ✅ Commit to git
5. 🔄 Continue with remaining tasks (Task 2.2+)

## Support

If you encounter issues:

1. Check console output for specific errors
2. Verify all files are added to correct targets
3. Clean build folder and rebuild
4. Reset simulator if Core Data issues persist
5. Refer to `SETUP_INSTRUCTIONS.md` for detailed guidance

## References

- [Xcode Project File Format](https://developer.apple.com/documentation/xcode)
- [Core Data Setup](https://developer.apple.com/documentation/coredata)
- [CloudKit Configuration](https://developer.apple.com/documentation/cloudkit)
- [Localization Guide](https://developer.apple.com/localization/)
