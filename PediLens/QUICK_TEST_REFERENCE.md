# PediLens Quick Test Reference Card

## 🚀 Quick Start (5 Minutes)

1. **Build & Install**
   ```bash
   cd PediLens
   open PediLens.xcodeproj
   # In Xcode: Select physical device → Product → Run (⌘R)
   ```

2. **First Test Scenario**
   - Launch app → Select "Doctor" role
   - Create patient: "Test Patient" / ID: "TP001"
   - Create wound: "Left foot, plantar surface"
   - Capture photo → Review detection → Save
   - View timeline → Export as PDF

3. **Document Issues**
   - Screenshot any problems
   - Note device model and iOS version
   - Use MANUAL_TESTING_CHECKLIST.md

## 📋 Critical Tests (Must Pass)

| # | Test | Expected Result |
|---|------|----------------|
| 1 | Camera launches | Camera preview appears |
| 2 | Photo captures | Photo saved and displayed |
| 3 | Detection runs | Boundary appears on wound |
| 4 | Measurements calculate | Area/length/width shown |
| 5 | Data persists | Records remain after restart |
| 6 | Auth required | Face ID/Touch ID prompts |
| 7 | Export works | PDF created successfully |
| 8 | VoiceOver works | All elements have labels |

## 🔴 Red Flags (Stop & Report)

- ❌ App crashes during normal use
- ❌ Data loss after app restart
- ❌ Security can be bypassed
- ❌ Photos are poor quality
- ❌ Measurements wildly inaccurate
- ❌ Sync causes data corruption
- ❌ VoiceOver doesn't work
- ❌ Performance unacceptably slow

## 📱 Test Devices Needed

**Minimum:**
- iPhone 12 Pro+ (with LiDAR) - iOS 16.0+
- iPhone 11 (without LiDAR) - iOS 16.0+

**Ideal:**
- Multiple iPhone models
- Multiple iOS versions (16.0, 17.x, 18.x)
- Different screen sizes

## 🧪 Test Scenarios (30 min each)

### Scenario 1: Doctor Workflow
```
1. Select Doctor role
2. Create 3 patients
3. Create wound for each patient
4. Capture photos with calibration
5. Add notes and measurements
6. Search for specific patient
7. Export patient data as PDF
```

### Scenario 2: Patient Workflow
```
1. Select Patient role
2. Create wound record
3. Capture initial photo
4. Add note: "Day 1"
5. Capture follow-up photo
6. Add note: "Day 7 - improved"
7. View timeline comparison
8. Export for doctor
```

### Scenario 3: Offline Mode
```
1. Enable Airplane Mode
2. Create wound record
3. Capture multiple photos
4. Add measurements and notes
5. Verify all data saved
6. Disable Airplane Mode
7. Enable iCloud sync
8. Verify data syncs
```

### Scenario 4: Security
```
1. Launch app (auth prompt)
2. Deny authentication
3. Verify app doesn't proceed
4. Authenticate successfully
5. Leave idle 5+ minutes
6. Return (re-auth required)
7. Export data (HIPAA warning)
8. Test anonymization
```

### Scenario 5: Accessibility
```
1. Enable VoiceOver
2. Navigate entire app
3. Capture photo with VoiceOver
4. Disable VoiceOver
5. Enable Voice Control
6. Navigate with voice
7. Increase text size to max
8. Verify UI adapts
```

## 🐛 Issue Reporting Template

```
Title: [Brief description]
Severity: Critical | Major | Minor

Steps to Reproduce:
1. 
2. 
3. 

Expected: [What should happen]
Actual: [What actually happened]

Device: iPhone [model]
iOS: [version]
Build: [version]

Screenshot: [Attach if available]
```

## ✅ Test Checklist Progress

Track your progress:

- [ ] Camera System (15 tests)
- [ ] Wound Detection (11 tests)
- [ ] Measurements (16 tests)
- [ ] Storage (15 tests)
- [ ] Sync (16 tests)
- [ ] Export (16 tests)
- [ ] Security (13 tests)
- [ ] User Roles (14 tests)
- [ ] Patient Mgmt (13 tests)
- [ ] Wound Records (11 tests)
- [ ] Timeline (13 tests)
- [ ] Accessibility (16 tests)
- [ ] Error Handling (16 tests)
- [ ] Performance (11 tests)
- [ ] Multi-Device (7 tests)

**Total: 200+ test cases**

## 📚 Full Documentation

- **MANUAL_TESTING_CHECKLIST.md** - Complete test cases
- **MANUAL_TESTING_GUIDE.md** - Detailed instructions
- **TASK_21.4_MANUAL_TESTING_STATUS.md** - Status tracking

## 🎯 Success Criteria

Ready for release when:
- ✅ All critical/major issues resolved
- ✅ Core workflows work without errors
- ✅ Security verified
- ✅ Accessibility works
- ✅ Performance acceptable
- ✅ Multi-device compatible

## 💡 Testing Tips

1. **Test on real devices** (not Simulator)
2. **Document everything** (screenshots, notes)
3. **Reproduce issues** before reporting
4. **Test positive AND negative** cases
5. **Think like a user** (realistic workflows)
6. **Be thorough** (don't skip steps)
7. **Communicate clearly** (actionable feedback)
8. **Retest fixes** (verify and check for regressions)

## ⏱️ Time Estimates

- **Quick smoke test:** 30 minutes
- **Core functionality:** 4-6 hours
- **Full test suite:** 40-60 hours
- **Recommended schedule:** 7 days

## 📞 Questions?

- Review requirements.md for specifications
- Review design.md for technical details
- Check TASK_21_TEST_RESULTS.md for automated results
- Consult development team for clarifications

---

**Last Updated:** January 30, 2026  
**Version:** 1.0
