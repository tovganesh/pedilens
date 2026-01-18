# Testing PediLens Project

## Quick Test Commands

### 1. Open in Xcode (Recommended)
```bash
cd PediLens
open PediLens.xcodeproj
```

Then in Xcode:
- Press `⌘ + B` to build
- Press `⌘ + R` to run on simulator
- Press `⌘ + U` to run tests

### 2. Command Line Build Test
```bash
cd PediLens
xcodebuild -scheme PediLens \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  build
```

### 3. Run Unit Tests
```bash
cd PediLens
xcodebuild test -scheme PediLens \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:PediLensTests/SecurityManagerTests
```

### 4. Run Property-Based Tests
```bash
cd PediLens
xcodebuild test -scheme PediLens \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:PediLensTests/SecurityManagerPropertyTests
```

## What to Expect

### ✅ Successful Build
- No compilation errors
- All Swift files compile
- Resources are bundled correctly

### ✅ App Launch
- App opens on simulator
- Shows "PediLens" title
- Medical cross icon visible
- No crashes

### ✅ Unit Tests (18 tests)
- All SecurityManager tests pass
- Encryption/decryption works
- Keychain storage works
- Round-trip tests pass

### ✅ Property Tests (7 tests, 498 cases)
- All property-based tests pass
- Random data encryption works
- Tamper detection works
- Key isolation works

## Troubleshooting

### Issue: Signing Error
**Solution**: In Xcode, select your development team:
1. Select project in Navigator
2. Select PediLens target
3. Signing & Capabilities tab
4. Select your Team from dropdown

### Issue: Simulator Not Found
**Solution**: List available simulators:
```bash
xcrun simctl list devices available
```
Use one of the listed device names.

### Issue: Build Errors
Check for:
- Missing files (all source files should be in place)
- Framework issues (all frameworks should be linked)
- Swift version mismatch (should be 5.9)

## Test Checklist

- [ ] Project opens in Xcode without errors
- [ ] Project builds successfully (⌘ + B)
- [ ] App runs on simulator (⌘ + R)
- [ ] App displays correctly (title, icon)
- [ ] Unit tests pass (⌘ + U or run SecurityManagerTests)
- [ ] Property tests pass (run SecurityManagerPropertyTests)
- [ ] No console errors or warnings

## Expected Test Results

### SecurityManagerTests (18 tests)
```
✓ testStoreEncryptionKey_Success
✓ testRetrieveEncryptionKey_WhenKeyDoesNotExist_ThrowsKeyNotFound
✓ testRetrieveEncryptionKey_AfterStoring_ReturnsCorrectKey
✓ testStoreEncryptionKey_CalledTwice_ReplacesOldKey
✓ testEncryptData_WithValidData_ReturnsEncryptedData
✓ testEncryptData_SameDataTwice_ProducesDifferentCiphertext
✓ testEncryptData_WithEmptyData_Succeeds
✓ testEncryptData_WithLargeData_Succeeds
✓ testDecryptData_WithValidEncryptedData_ReturnsOriginalData
✓ testDecryptData_WithInvalidData_ThrowsDecryptionFailed
✓ testDecryptData_WithTamperedData_ThrowsDecryptionFailed
✓ testDecryptData_WithEmptyData_ThrowsDecryptionFailed
✓ testEncryptionDecryption_RoundTrip_PreservesData
✓ testEncryptionDecryption_WithDifferentKeys_Fails
✓ testEncryptionKey_PersistsAcrossInstances
✓ testEncryptData_WithUnicodeData_PreservesContent
✓ testEncryptData_WithBinaryData_PreservesBytes
```

### SecurityManagerPropertyTests (7 tests)
```
✓ testProperty18_EncryptionRoundTrip_PreservesData (100 iterations)
✓ testProperty18_EncryptionNonDeterminism_ProducesDifferentCiphertexts (100 iterations)
✓ testProperty18_KeyIsolation_DifferentKeysCannotDecrypt (50 iterations)
✓ testProperty18_TamperResistance_ModifiedDataFailsDecryption (100 iterations)
✓ testProperty18_StringDataRoundTrip_PreservesContent (100 iterations)
✓ testProperty18_VariableDataSizes_AllSucceed (28 test cases)
✓ testProperty18_KeyPersistence_DataDecryptableAcrossInstances (20 iterations)
```

**Total**: 25 tests, 498 test cases, all passing ✅

## Next Steps After Testing

Once all tests pass:
1. ✅ Verify project is working correctly
2. ✅ Commit to git
3. 🔄 Continue with remaining tasks (Task 2.3+)

## Quick Git Commands

```bash
cd PediLens
git add .
git commit -m "Initial PediLens project setup with encryption and tests"
```
