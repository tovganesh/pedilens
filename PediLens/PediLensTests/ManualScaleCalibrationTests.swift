//
//  ManualScaleCalibrationTests.swift
//  PediLensTests
//
//  Tests for manual scale calibration, interactive calipers, and scale persistence.
//

import XCTest
import CoreGraphics
@testable import PediLens

class ManualScaleCalibrationTests: XCTestCase {
    
    // MARK: - Manual Calibration Factory Tests
    
    func testManualCalibrationFactory_CalculatesAccuratePixelsPerMM() {
        let pixelDistance: CGFloat = 242.6
        let referenceLengthMM: Double = 24.26 // US Quarter diameter
        let pixelsPerMM = Double(pixelDistance) / referenceLengthMM // 10.0 px/mm
        
        let calibration = MeasurementCalibration.manual(
            pixelsPerMillimeter: pixelsPerMM,
            referenceType: .usQuarter,
            referenceLengthMM: referenceLengthMM,
            pixelDistance: Double(pixelDistance),
            notes: "Caliper pins placed on quarter coin outer edges"
        )
        
        XCTAssertEqual(calibration.calibrationType, CalibrationType.referenceScale(objectType: .usQuarter, confidence: 1.0))
        XCTAssertEqual(calibration.accuracy, .medium)
        XCTAssertTrue(calibration.isUserCalibrated)
        XCTAssertEqual(Double(calibration.pixelsPerMillimeter), 10.0, accuracy: 0.001)
        XCTAssertEqual(Double(calibration.pixelsPerCentimeter), 100.0, accuracy: 0.01)
        
        // Metadata validation
        XCTAssertEqual(calibration.metadata?["referenceType"], ReferenceObjectType.usQuarter.displayName)
        XCTAssertEqual(calibration.metadata?["calibrationMethod"], "manualCalipers")
        XCTAssertEqual(calibration.metadata?["referenceLengthMM"], "24.26")
        XCTAssertEqual(calibration.metadata?["pixelDistance"], String(format: "%.2f", pixelDistance))
        XCTAssertEqual(calibration.metadata?["notes"], "Caliper pins placed on quarter coin outer edges")
    }
    
    func testCalibrationType_IsUserCalibrated_Distinction() {
        let userCal = MeasurementCalibration.manual(
            pixelsPerMillimeter: 12.5,
            referenceType: .ruler,
            referenceLengthMM: 10.0,
            pixelDistance: 125.0
        )
        XCTAssertTrue(userCal.isUserCalibrated)
        
        let estimatedCal = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
        XCTAssertFalse(estimatedCal.isUserCalibrated)
        
        let scaleInfo = ReferenceScaleInfo(
            objectType: .creditCard,
            boundingBox: CGRect(x: 100, y: 100, width: 200, height: 126),
            pixelWidth: 200.0,
            pixelHeight: 126.0,
            confidence: 0.95,
            detectedDimensions: CGSize(width: 85.6, height: 53.98)
        )
        let autoCal = MeasurementCalibration.fromReferenceScale(scaleInfo)!
        XCTAssertFalse(autoCal.isUserCalibrated)
        XCTAssertEqual(autoCal.calibrationType, CalibrationType.referenceScale(objectType: .creditCard, confidence: 0.95))
    }
    
    // MARK: - Serialization Round-trip Tests
    
    func testManualCalibration_CodableRoundTrip_PreservesAllFields() throws {
        let original = MeasurementCalibration.manual(
            pixelsPerMillimeter: 15.34,
            referenceType: .creditCard,
            referenceLengthMM: 85.6,
            pixelDistance: 1313.1,
            notes: "Card aligned horizontally"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MeasurementCalibration.self, from: data)
        
        XCTAssertEqual(decoded.calibrationType, original.calibrationType)
        XCTAssertEqual(decoded.accuracy, original.accuracy)
        XCTAssertEqual(decoded.pixelsPerMillimeter, original.pixelsPerMillimeter, accuracy: 0.0001)
        XCTAssertEqual(decoded.pixelsPerCentimeter, original.pixelsPerCentimeter, accuracy: 0.001)
        XCTAssertEqual(decoded.metadata?["referenceType"], ReferenceObjectType.creditCard.displayName)
        XCTAssertEqual(decoded.metadata?["calibrationMethod"], "manualCalipers")
        XCTAssertTrue(decoded.isUserCalibrated)
    }
    
    // MARK: - Recalibration Measurement Recalculation Tests
    
    func testRecalculateMeasurements_WithRecalibratedScale_UpdatesDimensions() {
        let manager = MeasurementManager()
        
        // 100x100 square wound
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 1.0,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .manual
        )
        
        // Initial estimate: 10 px/mm -> length = 10mm (1.0cm)
        let initialCalibration = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
        let initialMeasurements = manager.calculateMeasurements(boundary: boundary, calibration: initialCalibration, depthData: nil)
        XCTAssertEqual(initialMeasurements.length.value, 10.0, accuracy: 0.5)
        
        // Recalibrate with manual calipers: 20 px/mm -> length = 5mm (0.5cm)
        let recalibrated = MeasurementCalibration.manual(
            pixelsPerMillimeter: 20.0,
            referenceType: .custom,
            referenceLengthMM: 10.0,
            pixelDistance: 200.0
        )
        let updatedMeasurements = manager.calculateMeasurements(boundary: boundary, calibration: recalibrated, depthData: nil)
        XCTAssertEqual(updatedMeasurements.length.value, 5.0, accuracy: 0.25)
        XCTAssertEqual(updatedMeasurements.calibrationUsed.calibrationType, CalibrationType.referenceScale(objectType: .custom, confidence: 1.0))
        XCTAssertTrue(updatedMeasurements.calibrationUsed.isUserCalibrated)
    }
}
