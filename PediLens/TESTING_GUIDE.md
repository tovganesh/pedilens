# PediLens Testing Guide

## ✅ Recommended: Test in Xcode

The easiest and most reliable way to test the project is through Xcode:

### Step 1: Open Project
```bash
cd PediLens
open PediLens.xcodeproj
```

### Step 2: Configure Signing
1. In Xcode, select the **PediLens** project in the Navigator (left panel)
2. Select the **PediLens** target
3. Go to **Signing & Capabilities** tab
4. Under **Signing**, select your **Team** from the dropdown
5. Ensure "Automatically manage signing" is checked

### Step 3: Select Simulator
1. At the top of Xcode, click the device selector (next to the scheme)
2. Choose any iPhone simulator (e.g., "iPhone 16 Pro")

### Step 4: Build the Project
- Press **⌘ + B** (or Product → Build)
- Wait for build to complete
- Check for any errors in the Issue Navigator

### Step 5: Run the App
- Press **⌘ + R** (or Product → Run)
- The simulator will launch
- The PediLens app should open showing:
  - "PediLens" title
  - Medical cross icon (⚕️)
  - Clean interface

### Step 6: Run Tests
- Press **⌘ + U** (or Product → Test)
- This will run all tests:
  - **SecurityManagerTests** (18 unit tests)
  - **SecurityManagerPropertyTests** (7 property tests, 498 cases)
- View results in the Test Navigator (⌘ + 6)

## Expected Test Results

### ✅ All Tests Should Pass

**SecurityManagerTests** (18 tests):
- Key generation and storage
- Encryption/decryption
- Round-trip preservation
- Tamper detection
- Unicode and binary data handling

**SecurityManagerPropertyTests** (7 tests, 498 cases):
- Property 18: Data Encryption at Rest
- 100+ iterations per property
- Random data generation
- Comprehensive coverage

## What You Should See

### 1. Successful Build
```
Build Succeeded
```
- No red errors
- Maybe some yellow warnings (acceptable)
- Build time: ~30-60 seconds first time

### 2. App Launch
- Simulator opens automatically
- PediLens app launches
- Shows initial ContentView with:
  - App name: "PediLens"
  - Icon: Medical cross
  - Clean white background

### 3. Test Results
```
Test Suite 'All tests' passed
    Executed 25 tests, with 0 failures (0 unexpected)
```

## Troubleshooting

### Issue: "No Team Selected"
**Symptom**: Build fails with signing error
**Solution**:
1. Select project → PediLens target
2. Signing & Capabilities tab
3. Select your Apple ID team
4. Or create a free Apple Developer account

### Issue: "Simulator Not Available"
**Symptom**: Can't select a simulator
**Solution**:
1. Xcode → Settings → Platforms
2. Download iOS simulator if needed
3. Or use Xcode → Window → Devices and Simulators
4. Add a new simulator

### Issue: Build Errors
**Symptom**: Red errors in Issue Navigator
**Solution**:
1. Check error messages
2. Common fixes:
   - Clean Build Folder (⌘ + Shift + K)
   - Restart Xcode
   - Delete Derived Data (Xcode → Settings → Locations)

### Issue: Tests Fail
**Symptom**: Some tests show red X
**Solution**:
1. Check test output in Test Navigator
2. Look for specific error messages
3. Common causes:
   - Keychain access issues (run on simulator, not device)
   - Timing issues (rare, re-run tests)

## Manual Testing Checklist

After automated tests pass, manually verify:

### App Launch
- [ ] App opens without crash
- [ ] UI displays correctly
- [ ] No console errors

### Core Data
- [ ] Check console for "Core Data store loaded" message
- [ ] No Core Data errors

### File Storage
- [ ] App creates Documents/PediLens directory
- [ ] No file system errors

### Localization
- [ ] Strings display in English
- [ ] No missing localization warnings

## Performance Check

### Build Time
- **First build**: 30-60 seconds (normal)
- **Incremental builds**: 5-15 seconds (normal)
- **Clean build**: 30-60 seconds (normal)

### Test Execution
- **Unit tests**: 1-2 seconds
- **Property tests**: 5-10 seconds (498 test cases)
- **Total**: ~10-15 seconds

### App Launch
- **Simulator launch**: 10-30 seconds (first time)
- **App launch**: 1-2 seconds
- **Total**: ~15-35 seconds

## Verification Commands (Optional)

If you want to verify from command line after Xcode testing:

### Check Project Structure
```bash
cd PediLens
xcodebuild -list
```

### Check Build Settings
```bash
xcodebuild -showBuildSettings -scheme PediLens | grep -i "bundle\|version\|deployment"
```

### View Test Classes
```bash
xcodebuild -scheme PediLens -showTestPlans
```

## Success Criteria

✅ **Project opens in Xcode without errors**
✅ **Build succeeds (⌘ + B)**
✅ **App runs on simulator (⌘ + R)**
✅ **All 25 tests pass (⌘ + U)**
✅ **No crashes or console errors**
✅ **UI displays correctly**

## Next Steps After Successful Testing

Once all tests pass:

1. **Commit to Git**
```bash
cd PediLens
git add .
git commit -m "Initial PediLens setup - Tasks 1, 2.1, 2.2 complete"
```

2. **Review Completed Work**
- Task 1: Project structure ✅
- Task 2.1: SecurityManager ✅
- Task 2.2: Property tests ✅
- Localization setup ✅
- XcodeGen configuration ✅

3. **Continue Development**
- Task 2.3: Biometric authentication
- Task 2.4: Authentication property tests
- Task 3+: File storage, Core Data, Camera, etc.

## Getting Help

If you encounter issues:

1. **Check Console Output**
   - Xcode → View → Debug Area → Show Debug Area
   - Look for error messages

2. **Check Issue Navigator**
   - Xcode → View → Navigators → Show Issue Navigator (⌘ + 5)
   - Review all errors and warnings

3. **Check Test Navigator**
   - Xcode → View → Navigators → Show Test Navigator (⌘ + 6)
   - See which tests failed and why

4. **Review Documentation**
   - `TASK_1_COMPLETION.md` - Project setup details
   - `TASK_2.1_COMPLETION.md` - SecurityManager details
   - `TASK_2.2_COMPLETION.md` - Property test details
   - `XCODEGEN_SETUP_COMPLETE.md` - Project generation details

## Summary

**Recommended Testing Flow**:
1. Open in Xcode ✅
2. Configure signing ✅
3. Build (⌘ + B) ✅
4. Run (⌘ + R) ✅
5. Test (⌘ + U) ✅
6. Verify results ✅

**Expected Outcome**: All green checkmarks, no errors, app runs smoothly!

---

**Ready to test?** Open `PediLens.xcodeproj` in Xcode and press ⌘ + B to build!
