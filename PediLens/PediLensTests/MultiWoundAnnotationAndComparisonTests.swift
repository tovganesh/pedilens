//
//  MultiWoundAnnotationAndComparisonTests.swift
//  PediLensTests
//
//  Tests for multi-wound detection, annotation persistence,
//  backward compatibility, and clinical metrics calculation.
//

import XCTest
import CoreGraphics
import UIKit
@testable import PediLens

final class MultiWoundAnnotationAndComparisonTests: XCTestCase {
    
    // MARK: - Payload Encoding & Decoding Tests
    
    func testMultiWoundPayload_EncodeAndDecode_PreservesAllClinicalAttributes() throws {
        let wound1 = AnnotatedWound(
            id: UUID(),
            woundNumber: 1,
            label: "Medial Plantar Ulcer",
            anatomicalLocation: "1st Metatarsal Head (Plantar)",
            stageWagner: "Grade 2",
            tissueType: "Granulation (70%), Slough (30%)",
            exudate: "Moderate Serosanguinous",
            periwoundCondition: "Hyperkeratotic rim / Callused",
            notes: "Probe to bone negative. Edges well-defined.",
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 10), CGPoint(x: 50, y: 50), CGPoint(x: 10, y: 50)],
            confidence: 0.94,
            isManuallyAdjusted: false,
            colorHex: "#FF3B30",
            lengthMM: 40.0,
            widthMM: 40.0,
            areaMM2: 1600.0,
            perimeterMM: 160.0,
            depthMM: 2.5,
            volumeMM3: 4000.0
        )
        
        let wound2 = AnnotatedWound(
            id: UUID(),
            woundNumber: 2,
            label: "Lateral Plantar Ulcer",
            anatomicalLocation: "5th Metatarsal Base (Plantar)",
            stageWagner: "Grade 1",
            tissueType: "Slough (60%), Granulation (40%)",
            exudate: "Minimal Serous",
            periwoundCondition: "Erythematous halo",
            notes: "Superficial ulceration with maceration.",
            points: [CGPoint(x: 100, y: 100), CGPoint(x: 130, y: 100), CGPoint(x: 130, y: 130), CGPoint(x: 100, y: 130)],
            confidence: 0.88,
            isManuallyAdjusted: true,
            colorHex: "#34C759",
            lengthMM: 30.0,
            widthMM: 30.0,
            areaMM2: 900.0,
            perimeterMM: 120.0,
            depthMM: 1.0,
            volumeMM3: 900.0
        )
        
        let originalWounds = [wound1, wound2]
        guard let encodedData = MultiWoundPayload.encode(originalWounds) else {
            XCTFail("Encoding should succeed")
            return
        }
        
        let decodedWounds = MultiWoundPayload.decode(from: encodedData)
        XCTAssertNotNil(decodedWounds, "Decoding should succeed")
        XCTAssertEqual(decodedWounds?.count, 2, "Should decode exactly 2 wounds")
        
        // Verify wound 1
        let d1 = decodedWounds![0]
        XCTAssertEqual(d1.id, wound1.id)
        XCTAssertEqual(d1.woundNumber, 1)
        XCTAssertEqual(d1.label, "Medial Plantar Ulcer")
        XCTAssertEqual(d1.anatomicalLocation, "1st Metatarsal Head (Plantar)")
        XCTAssertEqual(d1.stageWagner, "Grade 2")
        XCTAssertEqual(d1.tissueType, "Granulation (70%), Slough (30%)")
        XCTAssertEqual(d1.exudate, "Moderate Serosanguinous")
        XCTAssertEqual(d1.periwoundCondition, "Hyperkeratotic rim / Callused")
        XCTAssertEqual(d1.notes, "Probe to bone negative. Edges well-defined.")
        XCTAssertEqual(d1.areaMM2, 1600.0)
        XCTAssertEqual(d1.depthMM, 2.5)
        XCTAssertEqual(d1.colorHex, "#FF3B30")
        XCTAssertEqual(d1.points.count, 4)
        
        // Verify wound 2
        let d2 = decodedWounds![1]
        XCTAssertEqual(d2.id, wound2.id)
        XCTAssertEqual(d2.woundNumber, 2)
        XCTAssertEqual(d2.label, "Lateral Plantar Ulcer")
        XCTAssertEqual(d2.stageWagner, "Grade 1")
        XCTAssertEqual(d2.isManuallyAdjusted, true)
        XCTAssertEqual(d2.colorHex, "#34C759")
    }
    
    func testMultiWoundPayload_BackwardCompatibility_DecodesLegacyPointsArray() throws {
        // Given: Legacy raw [CGPoint] encoded data
        let legacyPoints = [
            CGPoint(x: 20, y: 20),
            CGPoint(x: 80, y: 20),
            CGPoint(x: 80, y: 80),
            CGPoint(x: 20, y: 80)
        ]
        let legacyData = try JSONEncoder().encode(legacyPoints)
        
        // When: Decoding with MultiWoundPayload
        let wounds = MultiWoundPayload.decode(from: legacyData)
        
        // Then: Should fall back seamlessly to single AnnotatedWound
        XCTAssertNotNil(wounds, "Legacy data should successfully decode")
        XCTAssertEqual(wounds?.count, 1, "Should construct exactly 1 AnnotatedWound from legacy data")
        
        let primary = wounds![0]
        XCTAssertEqual(primary.woundNumber, 1)
        XCTAssertEqual(primary.label, "Wound #1")
        XCTAssertEqual(primary.points.count, 4)
        XCTAssertEqual(primary.points[0], CGPoint(x: 20, y: 20))
        XCTAssertEqual(primary.points[2], CGPoint(x: 80, y: 80))
    }
    
    // MARK: - WoundDetectionService Multi-Wound Detection Tests
    
    func testDetectMultipleWoundBoundaries_ReturnsMultipleBoundaries() async throws {
        let service = WoundDetectionService()
        
        // Create an image with two distinct high-contrast circular spots (synthetic multi-wound test)
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            XCTFail("Could not create graphics context")
            return
        }
        
        // Background: healthy skin tone
        ctx.setFillColor(UIColor(red: 0.95, green: 0.82, blue: 0.75, alpha: 1.0).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        // Spot 1: Medial Ulcer (dark red crater)
        ctx.setFillColor(UIColor(red: 0.65, green: 0.12, blue: 0.12, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: 70, y: 70, width: 90, height: 90))
        
        // Spot 2: Lateral Ulcer (dark red crater)
        ctx.setFillColor(UIColor(red: 0.60, green: 0.10, blue: 0.10, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: 240, y: 220, width: 80, height: 80))
        
        let multiWoundImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        let calibration = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
        let boundaries = try await service.detectMultipleWoundBoundaries(in: multiWoundImage, calibration: calibration)
        
        // Then: Should detect at least 1 valid boundary and not fail
        XCTAssertFalse(boundaries.isEmpty, "Should detect wound boundaries")
        for (idx, b) in boundaries.enumerated() {
            XCTAssertEqual(b.woundNumber, idx + 1, "Wound number should be 1-indexed")
            XCTAssertGreaterThanOrEqual(b.confidence, 0.0)
            XCTAssertLessThanOrEqual(b.confidence, 1.0)
            XCTAssertGreaterThan(b.points.count, 2, "Polygon must have >= 3 vertices")
        }
    }
    
    // MARK: - MeasurementManager calculateAnnotatedWound Tests
    
    func testCalculateAnnotatedWound_ComputesPhysicalDimensionsCorrectly() {
        let manager = MeasurementManager()
        
        // 100 x 50 pixel rectangle
        // At 10 px/mm calibration:
        // width = 50px / 10 = 5mm, length = 100px / 10 = 10mm
        // area = 100 * 50 = 5000 px^2 => 5000 / 100 = 50 mm^2 = 0.5 cm^2
        // perimeter = 2 * (100 + 50) = 300px => 30mm
        let rectPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 50),
            CGPoint(x: 0, y: 50)
        ]
        
        let boundary = WoundBoundary(
            id: UUID(),
            woundNumber: 1,
            points: rectPoints,
            confidence: 0.95,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 50),
            detectionMethod: .automatic(modelVersion: "1.0"),
            label: "Test Ulcer",
            colorHex: "#FF3B30"
        )
        
        let calibration = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
        let annotated = manager.calculateAnnotatedWound(boundary: boundary, calibration: calibration, depthData: nil)
        
        XCTAssertEqual(annotated.woundNumber, 1)
        XCTAssertEqual(annotated.label, "Test Ulcer")
        XCTAssertEqual(annotated.colorHex, "#FF3B30")
        
        // Area checks: 5000 / 100 = 50.0 mm^2
        XCTAssertEqual(annotated.areaMM2, 50.0, accuracy: 1.0)
        XCTAssertEqual(annotated.areaCM2, 0.5, accuracy: 0.05)
        
        // Dimensions
        XCTAssertEqual(annotated.lengthMM, 10.0, accuracy: 0.5)
        XCTAssertEqual(annotated.widthMM, 5.0, accuracy: 0.5)
        XCTAssertEqual(annotated.perimeterMM, 30.0, accuracy: 0.5)
    }
    
    // MARK: - Cumulative Summation Tests
    
    func testCumulativeWoundMetrics_SumsAreaAndVolumeAcrossMultipleWounds() {
        let w1 = AnnotatedWound(
            woundNumber: 1,
            points: [],
            lengthMM: 15.0,
            widthMM: 10.0,
            areaMM2: 150.0,
            perimeterMM: 50.0,
            depthMM: 2.0,
            volumeMM3: 300.0
        )
        
        let w2 = AnnotatedWound(
            woundNumber: 2,
            points: [],
            lengthMM: 10.0,
            widthMM: 8.0,
            areaMM2: 80.0,
            perimeterMM: 36.0,
            depthMM: 1.5,
            volumeMM3: 120.0
        )
        
        let wounds = [w1, w2]
        
        let totalAreaMM2 = wounds.reduce(0.0) { $0 + $1.areaMM2 }
        let maxLengthMM = wounds.map { $0.lengthMM }.max() ?? 0.0
        let maxWidthMM = wounds.map { $0.widthMM }.max() ?? 0.0
        let totalPerimeterMM = wounds.reduce(0.0) { $0 + $1.perimeterMM }
        let maxDepthMM = wounds.map { $0.depthMM }.max() ?? 0.0
        let totalVolumeMM3 = wounds.reduce(0.0) { $0 + $1.volumeMM3 }
        
        XCTAssertEqual(totalAreaMM2, 230.0, accuracy: 0.001)
        XCTAssertEqual(maxLengthMM, 15.0, accuracy: 0.001)
        XCTAssertEqual(maxWidthMM, 10.0, accuracy: 0.001)
        XCTAssertEqual(totalPerimeterMM, 86.0, accuracy: 0.001)
        XCTAssertEqual(maxDepthMM, 2.0, accuracy: 0.001)
        XCTAssertEqual(totalVolumeMM3, 420.0, accuracy: 0.001)
    }
}
