# SecurityManager Documentation

## Overview

The `SecurityManager` class provides HIPAA-compliant encryption and security services for the PediLens application. It implements AES-256-GCM encryption with secure key storage in the iOS Keychain.

## Features

### ✅ Implemented (Task 2.1)

- **AES-256-GCM Encryption**: Industry-standard authenticated encryption
- **Secure Key Storage**: Encryption keys stored in iOS Keychain with `.whenUnlockedThisDeviceOnly` accessibility
- **Automatic Key Generation**: Keys are generated automatically on first use
- **Key Persistence**: Keys persist across app launches
- **Data Integrity**: GCM mode provides authentication, detecting any tampering
- **Thread-Safe**: Singleton pattern ensures consistent key access

### 🔜 To Be Implemented (Task 2.3)

- **Biometric Authentication**: Face ID/Touch ID integration
- **Session Timeout**: 5-minute inactivity timer
- **Re-authentication**: Required for sensitive operations

## Architecture

### Protocol

```swift
protocol SecurityManagerProtocol {
    func encryptData(_ data: Data) throws -> Data
    func decryptData(_ data: Data) throws -> Data
    func storeEncryptionKey() throws
    func retrieveEncryptionKey() throws -> Data
    func authenticateUser() async throws -> Bool
}
```

### Implementation Details

**Encryption Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **Key Size**: 256 bits (32 bytes)
- **Authentication**: Built-in authentication tag
- **Nonce**: Automatically generated per encryption operation
- **Output Format**: Combined data (nonce + ciphertext + authentication tag)

**Keychain Configuration**:
- **Service**: `com.pedilens.app.encryption`
- **Account**: `pedilens-master-key`
- **Accessibility**: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  - Key is only accessible when device is unlocked
  - Key is NOT backed up to iCloud or iTunes
  - Key is device-specific (cannot be transferred)

## Usage

### Basic Encryption/Decryption

```swift
let securityManager = SecurityManager.shared

// Encrypt sensitive data
let plaintext = "Patient medical record".data(using: .utf8)!
let encrypted = try securityManager.encryptData(plaintext)

// Decrypt data
let decrypted = try securityManager.decryptData(encrypted)
let originalText = String(data: decrypted, encoding: .utf8)
```

### Error Handling

```swift
do {
    let encrypted = try securityManager.encryptData(sensitiveData)
    // Store encrypted data
} catch SecurityError.encryptionFailed {
    // Handle encryption failure
} catch SecurityError.keyGenerationFailed {
    // Handle key generation failure
} catch {
    // Handle other errors
}
```

### Manual Key Management (Advanced)

```swift
// Generate and store a new key (replaces existing key)
try securityManager.storeEncryptionKey()

// Retrieve the current key (for advanced use cases)
let key = try securityManager.retrieveEncryptionKey()
```

## Security Properties

### Validated Properties

✅ **Property 18: Data Encryption at Rest**
- All sensitive medical data is encrypted using AES-256
- Validates Requirements 5.3, 9.1

### Encryption Guarantees

1. **Confidentiality**: Data is encrypted with AES-256, providing strong confidentiality
2. **Integrity**: GCM mode provides authentication, detecting any tampering
3. **Authenticity**: Authentication tag ensures data hasn't been modified
4. **Uniqueness**: Each encryption uses a unique nonce, preventing pattern analysis
5. **Key Security**: Keys stored in Keychain with strictest accessibility settings

## Error Types

```swift
enum SecurityError: LocalizedError {
    case keyGenerationFailed      // Failed to generate random key
    case keyStorageFailed         // Failed to store key in Keychain
    case keyRetrievalFailed       // Failed to retrieve key from Keychain
    case keyNotFound              // No key exists in Keychain
    case encryptionFailed         // Encryption operation failed
    case decryptionFailed         // Decryption or authentication failed
    case invalidData              // Invalid data format
    case authenticationFailed     // User authentication failed (future)
}
```

## Testing

### Unit Tests

Location: `PediLensTests/SecurityManagerTests.swift`

**Test Coverage**:
- ✅ Key generation and storage
- ✅ Key retrieval and persistence
- ✅ Basic encryption/decryption
- ✅ Round-trip data integrity
- ✅ Different data types (empty, unicode, binary, large)
- ✅ Tampered data detection
- ✅ Key size verification (256 bits)
- ✅ Multiple encryption uniqueness
- ✅ Key replacement behavior

### Property-Based Tests

Location: `PediLensTests/SecurityManagerPropertyTests.swift` (Task 2.2)

**Properties to Test**:
- For any data, encrypt → decrypt returns original data
- For any data, encryption produces different output each time
- For any tampered encrypted data, decryption fails
- For any key, it persists across manager instances

## HIPAA Compliance

### Requirements Satisfied

✅ **Encryption at Rest** (§164.312(a)(2)(iv))
- All PHI encrypted with AES-256
- Keys stored securely in iOS Keychain

✅ **Access Control** (§164.312(a)(1))
- Keys only accessible when device unlocked
- Device authentication required (iOS enforced)

✅ **Integrity Controls** (§164.312(c)(1))
- GCM authentication tag detects tampering
- Checksums for file integrity (FileStorageManager)

🔜 **Audit Controls** (§164.312(b)) - Task 17.2
- Local error logging (encrypted)
- Access logging for sensitive operations

🔜 **Person or Entity Authentication** (§164.312(d)) - Task 2.3
- Biometric authentication (Face ID/Touch ID)
- Session timeout and re-authentication

## Performance Considerations

### Benchmarks (Approximate)

- **Key Generation**: ~1ms (one-time operation)
- **Encryption (1KB)**: <1ms
- **Encryption (1MB)**: ~10-20ms
- **Decryption (1KB)**: <1ms
- **Decryption (1MB)**: ~10-20ms

### Optimization Tips

1. **Batch Operations**: Encrypt multiple small items together when possible
2. **Background Processing**: Use background queues for large data encryption
3. **Caching**: Cache decrypted data in memory when appropriate (with proper lifecycle management)
4. **Lazy Decryption**: Only decrypt data when needed for display

## Integration with Other Components

### FileStorageManager

```swift
// Encrypt before saving
let encrypted = try SecurityManager.shared.encryptData(photoData)
try FileStorageManager.shared.savePhoto(encrypted, for: sessionID)

// Decrypt after loading
let encrypted = try FileStorageManager.shared.loadPhoto(at: path)
let decrypted = try SecurityManager.shared.decryptData(encrypted)
```

### Core Data

```swift
// Encrypt sensitive attributes before saving
let patient = Patient(context: context)
patient.name = name
patient.notes = try SecurityManager.shared.encryptData(notesData)
try context.save()

// Decrypt when reading
if let encryptedNotes = patient.notes {
    let decryptedNotes = try SecurityManager.shared.decryptData(encryptedNotes)
}
```

## Best Practices

### DO ✅

- Use `SecurityManager.shared` singleton for all encryption operations
- Handle all `SecurityError` cases appropriately
- Encrypt all PHI (Protected Health Information) before storage
- Use background queues for encrypting large data
- Test encryption/decryption in your unit tests

### DON'T ❌

- Don't store plaintext PHI in Core Data or files
- Don't create multiple SecurityManager instances
- Don't ignore encryption errors
- Don't attempt to parse or modify encrypted data
- Don't store encryption keys outside the Keychain

## Future Enhancements (Roadmap)

### Task 2.3: Biometric Authentication
- LocalAuthentication framework integration
- Face ID/Touch ID support
- Passcode fallback
- Session timeout logic

### Task 18.2: Session Management
- 5-minute inactivity timer
- Automatic re-authentication
- Secure session token management

### Task 18.3: Secure Deletion
- Overwrite file data before deletion
- Secure key deletion
- Memory wiping for sensitive data

## Troubleshooting

### Common Issues

**Issue**: `keyNotFound` error on first use
- **Solution**: This is expected. The manager will automatically generate a key.

**Issue**: `decryptionFailed` after app reinstall
- **Solution**: Keys are device-specific and not backed up. Data encrypted with old key cannot be decrypted after reinstall.

**Issue**: `keyStorageFailed` error
- **Solution**: Check device is unlocked. Keychain requires device to be unlocked for this accessibility level.

**Issue**: Slow encryption performance
- **Solution**: Move encryption to background queue. Consider encrypting in chunks for very large data.

## References

### Apple Documentation
- [CryptoKit Framework](https://developer.apple.com/documentation/cryptokit)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Data Protection](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/encrypting_your_app_s_files)

### Security Standards
- [NIST AES-GCM](https://csrc.nist.gov/publications/detail/sp/800-38d/final)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)

### PediLens Documentation
- Design Document: `.kiro/specs/pedilens/design.md` (Section 6: Security and Encryption)
- Requirements: `.kiro/specs/pedilens/requirements.md` (Requirements 5.3, 9.1)
- Tasks: `.kiro/specs/pedilens/tasks.md` (Task 2.1)

## Version History

### v1.0.0 (Task 2.1) - Current
- ✅ AES-256-GCM encryption implementation
- ✅ Keychain integration with `.whenUnlockedThisDeviceOnly`
- ✅ Automatic key generation and retrieval
- ✅ Comprehensive unit tests
- ✅ Error handling and validation

### v1.1.0 (Task 2.3) - Planned
- 🔜 Biometric authentication
- 🔜 Session timeout
- 🔜 Re-authentication for sensitive operations

### v1.2.0 (Task 18) - Planned
- 🔜 Secure deletion
- 🔜 Memory wiping
- 🔜 Enhanced audit logging
