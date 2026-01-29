//
//  UncalibratedMeasurementWarningPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for uncalibrated measurement warning
//  Feature: pedilens, Property 36: Uncalibrated Measurement Warning
//  Validates: Requirements 12.5
//

import XCTest
@testable import PediLens

class UncalibratedMeasurementWarningPropertyTests: XCTestCase {
    
    // MARK: - Property 36: Uncalibrated Measurement Warning
    
    /// Property 36: Uncalibrated Measurement Warning
    /// For any measurement taken without calibration data, a warning SHALL be displayed
    /// indicating measurements are estimates.
    /// Validates: Requirements 12.5
    func testUncalibratedMeasurementWarningProperty() {
        let iterations = 100
        
        for _ in 0..<iterations {
            let hasReferenceObject = Bool.random()
            
            // Create a calibration with or without reference object
            let calibration: MeasurementCalibration
            
            if hasReferenceObject {
                // Calibrated measurement
                calibration = MeasurementCalibration(
                    pixelsPerMillimeter: 2.0,
                    referenceObject: .ruler(lengthMM: 100.0),
                    calibrationDate: Date(),
                    depthCalibration: nil
                )
            } else {
                // Uncalibrated measurement
                calibration = MeasurementCalibration(
                    pixelsPerMillimeter: 1.0,
                    referenceObject: nil,
                    calibrationDate: Date(),
                    depthCalibration: nil
                )
            }
            
            // Create a wound measurement
            let measurement = WoundMeasurement(
                length: Foundation.Measurement(value: 10.0, unit: UnitLength.millimeters),
                width: Foundation.Measurement(value: 5.0, unit: UnitLength.millimeters),
                area: Foundation.Measurement(value: 50.0, unit: UnitArea.squareMillimeters),
                depth: nil,
                volume: nil,
                perimeter: Foundation.Measurement(value: 30.0, unit: UnitLength.millimeters),
                timestamp: Date(),
                calibrationUsed: calibration
            )
            
            // Property: Warning is needed if and only if there's no reference object
            let needsWarning = measurement.needsCalibrationWarning
            let isCalibrated = calibration.isCalibrated
            
            XCTAssertEqual(needsWarning, !isCalibrated, 
                          "Warning needed: \(needsWarning), Is calibrated: \(isCalibrated)")
        }
    }
    
    /// Test that calibration with reference object is considered calibrated
    func testCalibrationWithReferenceObjectIsCalibrated() {
        let iterations = 100
        
        for _ in 0..<iterations {
            let lengthMM = Double.random(in: 1.0...1000.0)
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 2.0,
                referenceObject: .ruler(lengthMM: lengthMM),
                calibrationDate: Date(),
                depthCalibration: nil
            )
            
            XCTAssertTrue(calibration.isCalibrated, 
                         "Calibration with reference object should be calibrated")
        }
    }
    
    /// Test that calibration without reference object is not calibrated
    func testCalibrationWithoutReferenceObjectIsNotCalibrated() {
        let iterations = 100
        
        for _ in 0..<iterations {
            let pixelsPerMM = Double.random(in: 0.1...10.0)
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: pixelsPerMM,
                referenceObject: nil,
                calibrationDate: Date(),
                depthCalibration: nil
            )
            
            XCTAssertFalse(calibration.isCalibrated, 
                          "Calibration without reference object should not be calibrated")
        }
    }
    
    /// Test that measurements with different reference object types are all calibrated
    func testAllReferenceObjectTypesAreCalibrated() {
        let iterations = 100
        
        for _ in 0..<iterations {
            // Create calibration with different reference object types
            let referenceObjects: [ReferenceObject] = [
                .ruler(lengthMM: 100.0),
                .coin(type: .usQuarter),
                .custom(name: "Test Object", dimensionMM: 50.0)
            ]
            
            let referenceObject = referenceObjects.randomElement()!
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 2.0,
                referenceObject: referenceObject,
                calibrationDate: Date(),
                depthCalibration: nil
            )
            
            XCTAssertTrue(calibration.isCalibrated, 
                         "All reference object types should result in calibrated measurements")
        }
    }
    
    /// Test that warning state is consistent across measurement lifecycle
    func testWarningStateConsistency() {
        let iterations = 100
        
        for _ in 0..<iterations {
            let hasCalibration = Bool.random()
            let checkCount = Int.random(in: 1...10)
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 2.0,
                referenceObject: hasCalibration ? .ruler(lengthMM: 100.0) : nil,
                calibrationDate: Date(),
                depthCalibration: nil
            )
            
            let measurement = WoundMeasurement(
                length: Foundation.Measurement(value: 10.0, unit: UnitLength.millimeters),
                width: Foundation.Measurement(value: 5.0, unit: UnitLength.millimeters),
                area: Foundation.Measurement(value: 50.0, unit: UnitArea.squareMillimeters),
                depth: nil,
                volume: nil,
                perimeter: Foundation.Measurement(value: 30.0, unit: UnitLength.millimeters),
                timestamp: Date(),
                calibrationUsed: calibration
            )
            
            // Check warning state multiple times - should be consistent
            let expectedWarning = !hasCalibration
            
            for _ in 0..<checkCount {
                XCTAssertEqual(measurement.needsCalibrationWarning, expectedWarning,
                              "Warning state should remain consistent across multiple checks")
            }
        }
    }
    
    /// Test Core Data measurement entity calibration check
    func testCoreDataMeasurementCalibrationCheck() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create calibration with reference object
        let calibratedCalibration = MeasurementCalibration(
            pixelsPerMillimeter: 2.0,
            referenceObject: .ruler(lengthMM: 100.0),
            calibrationDate: Date(),
            depthCalibration: nil
        )
        
        // Create calibration without reference object
        let uncalibratedCalibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date(),
            depthCalibration: nil
        )
        
        // Encode calibrations
        let encoder = JSONEncoder()
        guard let calibratedData = try? encoder.encode(calibratedCalibration),
              let uncalibratedData = try? encoder.encode(uncalibratedCalibration) else {
            XCTFail("Failed to encode calibration data")
            return
        }
        
        // Create measurements
        let calibratedMeasurement = Measurement.create(
            in: context,
            lengthMM: 10.0,
            widthMM: 5.0,
            areaMM2: 50.0,
            perimeterMM: 30.0,
            boundaryPoints: Data(),
            calibrationData: calibratedData,
            detectionConfidence: 0.8
        )
        
        let uncalibratedMeasurement = Measurement.create(
            in: context,
            lengthMM: 10.0,
            widthMM: 5.0,
            areaMM2: 50.0,
            perimeterMM: 30.0,
            boundaryPoints: Data(),
            calibrationData: uncalibratedData,
            detectionConfidence: 0.8
        )
        
        // Verify calibration status
        XCTAssertTrue(calibratedMeasurement.hasCalibration, "Measurement with reference object should be calibrated")
        XCTAssertFalse(uncalibratedMeasurement.hasCalibration, "Measurement without reference object should not be calibrated")
    }
    
    /// Test that warning is displayed for measurements without calibration data at all
    func testWarningForMeasurementWithNoCalibrationData() {
        let context = PersistenceController.preview.container.viewContext
        
        // Create measurement with empty calibration data
        let measurement = Measurement.create(
            in: context,
            lengthMM: 10.0,
            widthMM: 5.0,
            areaMM2: 50.0,
            perimeterMM: 30.0,
            boundaryPoints: Data(),
            calibrationData: Data(), // Empty data
            detectionConfidence: 0.8
        )
        
        // Should not be calibrated
        XCTAssertFalse(measurement.hasCalibration, "Measurement with empty calibration data should not be calibrated")
    }
}
