# PediLens Localization Guide

## Overview

PediLens uses iOS native localization with `Localizable.strings` files. Currently, only English is supported, but the structure is ready for additional languages.

## Structure

```
PediLens/Resources/
└── en.lproj/
    └── Localizable.strings  # English strings
```

## Usage in Code

### Using the L10n Helper (Recommended)

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        VStack {
            Text(L10n.App.name)
            Text(L10n.Camera.capture)
            Button(L10n.Button.save) {
                // Save action
            }
        }
    }
}
```

### Using NSLocalizedString Directly

```swift
let message = NSLocalizedString("camera.permission.message", comment: "Camera permission")
```

### Formatted Strings

For strings with parameters:

```swift
// Storage warning with percentage
let warning = L10n.Storage.Warning.message(percentage: 85)

// Detection confidence
let confidence = L10n.Detection.confidence(percentage: 92)

// Timeline entry with date
let entry = L10n.Accessibility.Timeline.entry(date: "Jan 15, 2024")
```

## String Categories

### App General
- App name and tagline

### Authentication
- Face ID/Touch ID prompts
- Authentication errors

### Camera
- Permission requests
- Capture controls
- Camera modes (HDR, Night Mode, Live Photo)

### Location
- Permission requests

### Storage
- Storage warnings
- Management options

### Wound Records
- Record creation and management
- Status labels
- Deletion confirmations

### Measurements
- Measurement types (length, width, area, depth, volume)
- Calibration
- Units (metric and imperial)

### Patient Management
- Patient information fields
- Search and selection
- Statistics

### User Roles
- Role selection
- Role descriptions

### Timeline
- Timeline navigation
- Filtering and sorting

### Notes
- Note categories
- Note management

### Export
- Export formats
- Export options
- HIPAA warnings

### Sync
- Sync status indicators
- Conflict resolution

### Errors
- Generic error messages
- Specific error types

### Buttons
- Common button labels

### Accessibility
- VoiceOver labels
- Accessibility descriptions

### Wound Detection
- Detection status
- Confidence indicators

## Adding New Strings

1. Add the key-value pair to `en.lproj/Localizable.strings`:
```
"my.new.key" = "My New String";
```

2. Add the accessor to `Localization.swift`:
```swift
enum L10n {
    enum MyCategory {
        static let newKey = NSLocalizedString("my.new.key", comment: "Description")
    }
}
```

3. Use in your code:
```swift
Text(L10n.MyCategory.newKey)
```

## Adding New Languages

To add support for additional languages (e.g., Spanish):

1. Create a new language directory:
```
PediLens/Resources/es.lproj/
```

2. Copy `Localizable.strings` to the new directory:
```bash
cp en.lproj/Localizable.strings es.lproj/
```

3. Translate all strings in `es.lproj/Localizable.strings`

4. In Xcode:
   - Select project → Info tab
   - Under "Localizations", click "+" to add Spanish
   - Select `Localizable.strings` to localize

## Best Practices

### DO:
- ✅ Use the `L10n` helper for type-safe access
- ✅ Provide meaningful comments for translators
- ✅ Use format strings for dynamic content
- ✅ Keep strings short and clear
- ✅ Group related strings together

### DON'T:
- ❌ Hardcode strings in UI code
- ❌ Concatenate localized strings
- ❌ Use string interpolation with localized strings
- ❌ Forget to add comments for context

## Testing Localization

### Test in Simulator

1. Open Settings app in simulator
2. Go to General → Language & Region
3. Change language to test translations

### Test with Xcode Scheme

1. Edit scheme (Product → Scheme → Edit Scheme)
2. Run tab → Options
3. Set "Application Language" to desired language

### Pseudo-localization

For testing UI with longer strings:

```swift
#if DEBUG
extension String {
    var pseudoLocalized: String {
        return "[\(self) ääää]"
    }
}
#endif
```

## Accessibility

All user-facing strings should be localized, including:
- VoiceOver labels
- Accessibility hints
- Accessibility values

Example:
```swift
Button(L10n.Camera.capture) {
    capturePhoto()
}
.accessibilityLabel(L10n.Accessibility.Camera.capture)
```

## HIPAA Compliance

Localized strings must maintain HIPAA compliance:
- ✅ Privacy warnings are clear in all languages
- ✅ Consent language is legally accurate
- ✅ Security messages are unambiguous

## String Keys Naming Convention

Format: `category.subcategory.identifier`

Examples:
- `camera.permission.title`
- `wound.status.active`
- `export.format.pdf`
- `sync.conflict.message`

## Pluralization

For strings that need pluralization, use `.stringsdict`:

```xml
<!-- Localizable.stringsdict -->
<key>wound.count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@wounds@</string>
    <key>wounds</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>
        <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key>
        <string>d</string>
        <key>one</key>
        <string>%d wound</string>
        <key>other</key>
        <string>%d wounds</string>
    </dict>
</dict>
```

## Resources

- [Apple Localization Guide](https://developer.apple.com/localization/)
- [NSLocalizedString Documentation](https://developer.apple.com/documentation/foundation/nslocalizedstring)
- [Internationalization Best Practices](https://developer.apple.com/internationalization/)

## Current Status

- ✅ English localization complete
- ✅ L10n helper implemented
- ✅ All UI strings categorized
- ⏳ Additional languages (future)
- ⏳ Pluralization support (as needed)
- ⏳ Region-specific formatting (as needed)

## Maintenance

When adding new features:
1. Add strings to `Localizable.strings`
2. Update `Localization.swift` helper
3. Use localized strings in UI code
4. Test with VoiceOver
5. Update this README if adding new categories
