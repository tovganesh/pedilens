#!/bin/bash

# Script to run each test suite individually and collect results

SCHEME="PediLens"
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6"
OUTPUT_FILE="test_suite_results.txt"

# Clear previous results
> "$OUTPUT_FILE"

# Get list of all test classes
TEST_CLASSES=$(xcodebuild -scheme "$SCHEME" -showBuildSettings 2>/dev/null | grep "TEST_HOST" | head -1 | awk '{print $3}')

# List of test suites to run
SUITES=(
    "CameraHDRPropertyTests"
    "CameraManagerTests"
    "CameraManualControlsTests"
    "CameraMaxResolutionPropertyTests"
    "CameraMultiFormatPropertyTests"
    "CaptureSessionLocationPropertyTests"
    "CaptureSessionManagerTests"
    "CaptureSessionMetadataPropertyTests"
    "CaptureSessionTimestampPropertyTests"
    "CoreDataEntityExtensionsTests"
    "CoreDataOfflinePropertyTests"
    "DataValidationPropertyTests"
    "FileStorageManagerTests"
    "MeasurementManagerTests"
    "MeasurementPropertyTests"
    "PatientIdentificationPropertyTests"
    "PatientManagerTests"
    "PatientRecordDisplayPropertyTests"
    "PatientRecordFilteringPropertyTests"
    "PatientSearchPropertyTests"
    "PersistenceControllerTests"
    "SecurityManagerPropertyTests"
    "SecurityManagerTests"
    "TimelineChronologicalOrderPropertyTests"
    "TimelineDateRangeFilteringPropertyTests"
    "TimelineEntryCompletenessPropertyTests"
    "UserManagerTests"
    "UserRolePropertyTests"
    "WoundDetectionPropertyTests"
    "WoundDetectionServiceTests"
    "WoundManagerTests"
    "WoundRecordCreationPropertyTests"
    "WoundRecordDeletionPropertyTests"
    "WoundSizeChangePropertyTests"
)

echo "Running test suites individually..." | tee -a "$OUTPUT_FILE"
echo "======================================" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

PASSED=0
FAILED=0
CRASHED=0

for suite in "${SUITES[@]}"; do
    echo "Testing: $suite" | tee -a "$OUTPUT_FILE"
    
    # Run the test with timeout
    timeout 60 xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:"PediLensTests/$suite" \
        2>&1 | grep -E "(TEST SUCCEEDED|TEST FAILED|passed|failed|error:)" | tail -5 >> "$OUTPUT_FILE"
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ PASSED" | tee -a "$OUTPUT_FILE"
        ((PASSED++))
    elif [ $EXIT_CODE -eq 124 ]; then
        echo "⏱️  TIMEOUT/CRASHED" | tee -a "$OUTPUT_FILE"
        ((CRASHED++))
    else
        echo "❌ FAILED" | tee -a "$OUTPUT_FILE"
        ((FAILED++))
    fi
    
    echo "" | tee -a "$OUTPUT_FILE"
done

echo "======================================" | tee -a "$OUTPUT_FILE"
echo "Summary:" | tee -a "$OUTPUT_FILE"
echo "  Passed: $PASSED" | tee -a "$OUTPUT_FILE"
echo "  Failed: $FAILED" | tee -a "$OUTPUT_FILE"
echo "  Crashed/Timeout: $CRASHED" | tee -a "$OUTPUT_FILE"
echo "  Total: ${#SUITES[@]}" | tee -a "$OUTPUT_FILE"
echo "======================================" | tee -a "$OUTPUT_FILE"
