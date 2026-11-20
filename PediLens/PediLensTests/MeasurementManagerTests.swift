//
//  MeasurementManagerTests.swift
//  PediLensTests
//
//  Created by PediLens Team
//

import XCTest
import AVFoundation
@testable import PediLens

class MeasurementManagerTests: XCTestCase {
    
    var manager: MeasurementManager!
    
    override func setUp() {
        super.setUp()
        manager = MeasurementManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Area Calculation Tests
    
    func testCalculateMeasurements_SquareBoundary_CalculatesCorrectArea() {
        // Given: A square boundary (100x100 pixels)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        // Calibration: 1 pixel = 1 mm
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Area should be 10,000 mm² (100mm x 100mm)
        XCTAssertEqual(measurement.area.value, 10000.0, accuracy: 0.1, 
                      "Square area should be 10,000 mm²")
    }
    
    func testCalculateMeasurements_TriangleBoundary_CalculatesCorrectArea() {
        // Given: A right triangle boundary (base=100, height=100 pixels)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        // Calibration: 1 pixel = 1 mm
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Area should be 5,000 mm² (0.5 * 100mm * 100mm)
        XCTAssertEqual(measurement.area.value, 5000.0, accuracy: 0.1, 
                      "Triangle area should be 5,000 mm²")
    }
    
    func testCalculateMeasurements_WithCalibration_ScalesAreaCorrectly() {
        // Given: A square boundary (100x100 pixels)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        // Calibration: 2 pixels = 1 mm (so 100 pixels = 50 mm)
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 2.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Area should be 2,500 mm² (50mm x 50mm)
        XCTAssertEqual(measurement.area.value, 2500.0, accuracy: 0.1, 
                      "Scaled area should be 2,500 mm²")
    }
    
    // MARK: - Length and Width Tests
    
    func testCalculateMeasurements_SquareBoundary_CalculatesEqualLengthAndWidth() {
        // Given: A square boundary
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Length and width should both be 100 mm
        XCTAssertEqual(measurement.length.value, 100.0, accuracy: 0.1, 
                      "Length should be 100 mm")
        XCTAssertEqual(measurement.width.value, 100.0, accuracy: 0.1, 
                      "Width should be 100 mm")
    }
    
    func testCalculateMeasurements_RectangleBoundary_LengthGreaterThanWidth() {
        // Given: A rectangular boundary (200x100 pixels)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 200, y: 0),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 200, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Length should be 200 mm, width should be 100 mm
        XCTAssertEqual(measurement.length.value, 200.0, accuracy: 0.1, 
                      "Length should be 200 mm")
        XCTAssertEqual(measurement.width.value, 100.0, accuracy: 0.1, 
                      "Width should be 100 mm")
        XCTAssertGreaterThanOrEqual(measurement.length.value, measurement.width.value,
                                   "Length should be >= width")
    }
    
    // MARK: - Perimeter Tests
    
    func testCalculateMeasurements_SquareBoundary_CalculatesCorrectPerimeter() {
        // Given: A square boundary (100x100 pixels)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Perimeter should be 400 mm (4 * 100mm)
        XCTAssertEqual(measurement.perimeter.value, 400.0, accuracy: 0.1, 
                      "Square perimeter should be 400 mm")
    }
    
    func testCalculateMeasurements_TriangleBoundary_CalculatesCorrectPerimeter() {
        // Given: A right triangle (sides: 30, 40, 50 pixels - Pythagorean triple)
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 30, y: 0),
            CGPoint(x: 0, y: 40)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 30, height: 40),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Perimeter should be 120 mm (30 + 40 + 50)
        XCTAssertEqual(measurement.perimeter.value, 120.0, accuracy: 0.1, 
                      "Triangle perimeter should be 120 mm")
    }
    
    // MARK: - Calibration Tests
    
    func testCreateCalibration_WithRuler_CalculatesCorrectRatio() {
        // Given: A ruler reference (100mm) measured as 200 pixels
        let referenceObject = ReferenceObject.ruler(lengthMM: 100.0)
        let pixelDistance: CGFloat = 200.0
        
        // When: Creating calibration
        let calibration = manager.createCalibration(
            referenceObject: referenceObject,
            pixelDistance: pixelDistance
        )
        
        // Then: Ratio should be 2 pixels per mm
        XCTAssertEqual(calibration.pixelsPerMillimeter, 2.0, accuracy: 0.001, 
                      "Calibration ratio should be 2 pixels/mm")
        XCTAssertNotNil(calibration.referenceObject, "Reference object should be stored")
    }
    
    func testCreateCalibration_WithCoin_CalculatesCorrectRatio() {
        // Given: A US quarter (24.26mm diameter) measured as 48.52 pixels
        let referenceObject = ReferenceObject.coin(type: .usQuarter)
        let pixelDistance: CGFloat = 48.52
        
        // When: Creating calibration
        let calibration = manager.createCalibration(
            referenceObject: referenceObject,
            pixelDistance: pixelDistance
        )
        
        // Then: Ratio should be 2 pixels per mm
        XCTAssertEqual(calibration.pixelsPerMillimeter, 2.0, accuracy: 0.001, 
                      "Calibration ratio should be 2 pixels/mm")
    }
    
    func testCreateCalibration_WithCustomObject_CalculatesCorrectRatio() {
        // Given: A custom reference (50mm) measured as 100 pixels
        let referenceObject = ReferenceObject.custom(name: "Test Object", dimensionMM: 50.0)
        let pixelDistance: CGFloat = 100.0
        
        // When: Creating calibration
        let calibration = manager.createCalibration(
            referenceObject: referenceObject,
            pixelDistance: pixelDistance
        )
        
        // Then: Ratio should be 2 pixels per mm
        XCTAssertEqual(calibration.pixelsPerMillimeter, 2.0, accuracy: 0.001, 
                      "Calibration ratio should be 2 pixels/mm")
    }
    
    // MARK: - Edge Cases
    
    func testCalculateMeasurements_EmptyBoundary_ReturnsZeroMeasurements() {
        // Given: An empty boundary
        let boundary = WoundBoundary(
            points: [],
            confidence: 0.0,
            boundingBox: .zero,
            detectionMethod: .manual
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: All measurements should be zero
        XCTAssertEqual(measurement.area.value, 0.0, "Empty boundary should have zero area")
        XCTAssertEqual(measurement.length.value, 0.0, "Empty boundary should have zero length")
        XCTAssertEqual(measurement.width.value, 0.0, "Empty boundary should have zero width")
        XCTAssertEqual(measurement.perimeter.value, 0.0, "Empty boundary should have zero perimeter")
    }
    
    func testCalculateMeasurements_SinglePoint_ReturnsZeroMeasurements() {
        // Given: A boundary with a single point
        let boundary = WoundBoundary(
            points: [CGPoint(x: 50, y: 50)],
            confidence: 0.5,
            boundingBox: CGRect(x: 50, y: 50, width: 0, height: 0),
            detectionMethod: .manual
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: All measurements should be zero
        XCTAssertEqual(measurement.area.value, 0.0, "Single point should have zero area")
    }
    
    func testCalculateMeasurements_TwoPoints_ReturnsZeroArea() {
        // Given: A boundary with two points (a line)
        let boundary = WoundBoundary(
            points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)],
            confidence: 0.5,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 0),
            detectionMethod: .manual
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Area should be zero (line has no area)
        XCTAssertEqual(measurement.area.value, 0.0, "Line should have zero area")
        // But perimeter should be non-zero
        XCTAssertGreaterThan(measurement.perimeter.value, 0.0, "Line should have non-zero perimeter")
    }
    
    func testCalculateMeasurements_IrregularPolygon_CalculatesValidMeasurements() {
        // Given: An irregular polygon
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 20),
            CGPoint(x: 120, y: 80),
            CGPoint(x: 80, y: 120),
            CGPoint(x: 20, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.8,
            boundingBox: CGRect(x: 0, y: 0, width: 120, height: 120),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Should have valid positive measurements
        XCTAssertGreaterThan(measurement.area.value, 0.0, "Irregular polygon should have positive area")
        XCTAssertGreaterThan(measurement.length.value, 0.0, "Should have positive length")
        XCTAssertGreaterThan(measurement.width.value, 0.0, "Should have positive width")
        XCTAssertGreaterThan(measurement.perimeter.value, 0.0, "Should have positive perimeter")
    }
    
    // MARK: - Measurement Units Tests
    
    func testCalculateMeasurements_ReturnsCorrectUnits() {
        // Given: A simple square boundary
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Units should be correct
        XCTAssertEqual(measurement.length.unit, UnitLength.millimeters, 
                      "Length unit should be millimeters")
        XCTAssertEqual(measurement.width.unit, UnitLength.millimeters, 
                      "Width unit should be millimeters")
        XCTAssertEqual(measurement.area.unit, UnitArea.squareMillimeters, 
                      "Area unit should be square millimeters")
        XCTAssertEqual(measurement.perimeter.unit, UnitLength.millimeters, 
                      "Perimeter unit should be millimeters")
    }
    
    func testCalculateMeasurements_WithoutDepthData_DepthAndVolumeAreNil() {
        // Given: A boundary without depth data
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // When: Calculating measurements without depth data
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Depth and volume should be nil
        XCTAssertNil(measurement.depth, "Depth should be nil without depth data")
        XCTAssertNil(measurement.volume, "Volume should be nil without depth data")
    }
    
    func testCalculateMeasurements_StoresCalibrationUsed() {
        // Given: A boundary and calibration
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 2.5,
            referenceObject: .ruler(lengthMM: 100),
            calibrationDate: Date()
        )
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Then: Calibration should be stored
        XCTAssertEqual(measurement.calibrationUsed.pixelsPerMillimeter, 2.5, 
                      "Should store calibration ratio")
        XCTAssertNotNil(measurement.calibrationUsed.referenceObject, 
                       "Should store reference object")
    }
    
    func testCalculateMeasurements_SetsTimestamp() {
        // Given: A boundary
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        let beforeTime = Date()
        
        // When: Calculating measurements
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        let afterTime = Date()
        
        // Then: Timestamp should be set to current time
        XCTAssertGreaterThanOrEqual(measurement.timestamp, beforeTime, 
                                   "Timestamp should be >= before time")
        XCTAssertLessThanOrEqual(measurement.timestamp, afterTime, 
                                "Timestamp should be <= after time")
    }
    
    // MARK: - Depth and Volume Tests
    
    func testCalculateMeasurements_WithDepthData_CalculatesDepthAndVolume() {
        // Given: A 100x100 square boundary
        let points = [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 90, y: 10),
            CGPoint(x: 90, y: 90),
            CGPoint(x: 10, y: 90)
        ]
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.95,
            boundingBox: CGRect(x: 10, y: 10, width: 80, height: 80),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        // Create depth pixel buffer (100x100): rim is at 0.300m, cavity center is at 0.305m (5mm deep)
        var pixelBuffer: CVPixelBuffer?
        let width = 100
        let height = 100
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_DepthFloat32,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer = pixelBuffer else {
            XCTFail("Failed to allocate depth buffer")
            return
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                if x >= 20 && x <= 80 && y >= 20 && y <= 80 {
                    row[x] = 0.305 // 5mm cavity inside wound
                } else {
                    row[x] = 0.300 // Baseline skin level
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        let depthData = DepthData(
            depthMap: buffer,
            calibrationData: nil,
            accuracy: .absolute
        )
        
        // When: Calculating measurements with depth data
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: depthData
        )
        
        // Then: Depth and volume should be computed
        XCTAssertNotNil(measurement.depth, "Depth should not be nil when depth data is provided")
        XCTAssertNotNil(measurement.volume, "Volume should not be nil when depth data is provided")
        
        if let depth = measurement.depth {
            // Expected max depth is ~5.0 mm
            XCTAssertEqual(depth.value, 5.0, accuracy: 0.5, "Wound depth should be ~5.0 mm")
        }
        
        if let volume = measurement.volume {
            XCTAssertGreaterThan(volume.value, 0.0, "Volume should be greater than zero")
        }
    }

    // MARK: - Depth Robustness Tests

    /// Creates a DepthFloat32 buffer filled by `depthAt(x, y)` (meters)
    private func makeDepthMap(width: Int, height: Int, format: OSType = kCVPixelFormatType_DepthFloat32, depthAt: (Int, Int) -> Float32) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, nil, &pixelBuffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixelBuffer)
        if format == kCVPixelFormatType_DepthFloat32 {
            CVPixelBufferLockBaseAddress(buffer, [])
            let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<height {
                let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
                for x in 0..<width { row[x] = depthAt(x, y) }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        return buffer
    }

    private func squareBoundary(from minValue: CGFloat, to maxValue: CGFloat) -> WoundBoundary {
        let points = [
            CGPoint(x: minValue, y: minValue), CGPoint(x: maxValue, y: minValue),
            CGPoint(x: maxValue, y: maxValue), CGPoint(x: minValue, y: maxValue)
        ]
        return WoundBoundary(
            points: points,
            confidence: 0.95,
            boundingBox: CGRect(x: minValue, y: minValue, width: maxValue - minValue, height: maxValue - minValue),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
    }

    private func cavityDepthMap() throws -> CVPixelBuffer {
        try makeDepthMap(width: 100, height: 100) { x, y in
            (20...80).contains(x) && (20...80).contains(y) ? 0.305 : 0.300
        }
    }

    func testDepth_RelativeAccuracy_IsNotReportedAsMillimeters() throws {
        // Relative depth (e.g. dual-camera disparity) has no metric scale
        let depthData = DepthData(depthMap: try cavityDepthMap(), accuracy: .relative)
        let measurement = manager.calculateMeasurements(
            boundary: squareBoundary(from: 10, to: 90),
            calibration: MeasurementCalibration.estimated(pixelsPerMillimeter: 1.0),
            depthData: depthData
        )
        XCTAssertNil(measurement.depth)
        XCTAssertNil(measurement.volume)
    }

    func testDepth_UnconvertedPixelFormat_IsIgnored() throws {
        // Raw 16-bit disparity must never be reinterpreted as Float32 meters
        let disparity = try makeDepthMap(width: 100, height: 100, format: kCVPixelFormatType_DisparityFloat16) { _, _ in 0 }
        let measurement = manager.calculateMeasurements(
            boundary: squareBoundary(from: 10, to: 90),
            calibration: MeasurementCalibration.estimated(pixelsPerMillimeter: 1.0),
            depthData: DepthData(depthMap: disparity, accuracy: .absolute)
        )
        XCTAssertNil(measurement.depth)
        XCTAssertNil(measurement.volume)
    }

    func testDepth_LowerResolutionDepthMap_MapsImageCoordinates() throws {
        // Photo is 400×400 at 4 px/mm; the depth map covers the same view at 100×100.
        // Boundary 40...360 (image) corresponds to 10...90 (depth); cavity is 20...80 (depth).
        let depthData = DepthData(
            depthMap: try cavityDepthMap(),
            accuracy: .absolute,
            referenceImageSize: CGSize(width: 400, height: 400)
        )
        let measurement = manager.calculateMeasurements(
            boundary: squareBoundary(from: 40, to: 360),
            calibration: MeasurementCalibration.estimated(pixelsPerMillimeter: 4.0),
            depthData: depthData
        )
        let depth = try XCTUnwrap(measurement.depth)
        XCTAssertEqual(depth.value, 5.0, accuracy: 0.1)
    }

    func testDepth_TiltedSkin_MeasuresRecessFromFittedPlane() throws {
        // Skin slopes 0.2 mm per pixel across the frame (tilted camera / curved foot);
        // the cavity sits 4 mm below that slope. A flat baseline would mis-measure it badly.
        let depthMap = try makeDepthMap(width: 100, height: 100) { x, y in
            let skin = 0.300 + 0.0002 * Float32(x)
            return (20...80).contains(x) && (20...80).contains(y) ? skin + 0.004 : skin
        }
        let measurement = manager.calculateMeasurements(
            boundary: squareBoundary(from: 10, to: 90),
            calibration: MeasurementCalibration.estimated(pixelsPerMillimeter: 1.0),
            depthData: DepthData(depthMap: depthMap, accuracy: .absolute)
        )

        let depth = try XCTUnwrap(measurement.depth)
        XCTAssertEqual(depth.value, 4.0, accuracy: 0.1)

        // Volume = area × mean recess: 6400 mm² × (4 mm × 3721 / 6400 sampled pixels) ≈ 14,884 mm³
        let volume = try XCTUnwrap(measurement.volume)
        XCTAssertEqual(volume.value, 14_884, accuracy: 14_884 * 0.03)
    }

    // MARK: - Depth-Based Metric Scale & Tilt Tests

    /// 640×480 pinhole camera, f = 500 px, principal point at the image center
    private let testIntrinsics = CameraIntrinsics(fx: 500, fy: 500, cx: 320, cy: 240, referenceSize: CGSize(width: 640, height: 480))

    /// Depth map (320×240, half the image resolution) of the plane Z = c + a·X in camera space
    private func planeDepthMap(c: Double, a: Double) throws -> CVPixelBuffer {
        try makeDepthMap(width: 320, height: 240) { x, _ in
            // Ray through the depth pixel center, in image pixels
            let u = (Double(x) + 0.5) * 2.0
            let rayX = (u - self.testIntrinsics.cx) / self.testIntrinsics.fx
            return Float32(c / (1.0 - a * rayX))
        }
    }

    /// Image outline of a square of `sideMM` lying on the plane Z = c + a·X, centered on the optical axis
    private func projectedSquare(sideMM: Double, c: Double, a: Double) -> [CGPoint] {
        let tilt = atan(a)
        let half = sideMM / 2000.0
        // In-plane axes: e1 runs along the tilt, e2 along camera Y
        let corners = [(-half, -half), (half, -half), (half, half), (-half, half)]
        return corners.map { s, t in
            let X = s * cos(tilt)
            let Y = t
            let Z = c + s * sin(tilt)
            return CGPoint(x: testIntrinsics.fx * X / Z + testIntrinsics.cx,
                           y: testIntrinsics.fy * Y / Z + testIntrinsics.cy)
        }
    }

    private func depthData(_ map: CVPixelBuffer) -> DepthData {
        DepthData(depthMap: map, accuracy: .absolute,
                  referenceImageSize: CGSize(width: 640, height: 480),
                  intrinsics: testIntrinsics)
    }

    func testIntrinsics_Oriented_MapsPrincipalPointLikePixels() throws {
        // Sensor-oriented 4000×3000 intrinsics with an off-center principal point
        let raw = CameraIntrinsics(fx: 3000, fy: 3010, cx: 2010, cy: 1480, referenceSize: CGSize(width: 4000, height: 3000))

        // .right displays raw (x, y) at (H - y, x)
        let right = try XCTUnwrap(raw.oriented(.right))
        XCTAssertEqual(right.referenceSize, CGSize(width: 3000, height: 4000))
        XCTAssertEqual(right.cx, 3000 - 1480)
        XCTAssertEqual(right.cy, 2010)
        XCTAssertEqual(right.fx, 3010)
        XCTAssertEqual(right.fy, 3000)

        // .left displays raw (x, y) at (y, W - x)
        let left = try XCTUnwrap(raw.oriented(.left))
        XCTAssertEqual(left.cx, 1480)
        XCTAssertEqual(left.cy, 4000 - 2010)

        XCTAssertEqual(raw.oriented(.up), raw)
        XCTAssertNil(raw.oriented(.upMirrored))
    }

    func testDepthCalibration_FlatSkin_ScaleIsFocalLengthOverDistance() throws {
        let square = projectedSquare(sideMM: 20, c: 0.3, a: 0)
        let calibration = try XCTUnwrap(manager.depthCalibration(for: square, depthData: depthData(try planeDepthMap(c: 0.3, a: 0))))

        // 500 px / 300 mm
        XCTAssertEqual(calibration.pixelsPerMillimeter, 500.0 / 300.0, accuracy: 0.01)
        XCTAssertEqual(calibration.accuracy, .high)
        XCTAssertEqual(Double(try XCTUnwrap(calibration.captureDistance)), 0.3, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(calibration.surfaceTilt).angleDegrees, 0, accuracy: 0.5)

        let measurement = manager.calculateMeasurements(boundary: WoundBoundary(points: square, confidence: 1, boundingBox: .zero, detectionMethod: .manual), calibration: calibration, depthData: nil)
        XCTAssertEqual(measurement.length.value, 20, accuracy: 0.2)
        XCTAssertEqual(measurement.area.value, 400, accuracy: 4)
    }

    func testDepthCalibration_TiltedSkin_CorrectsForeshortening() throws {
        // Skin tilted 30° about the camera's vertical axis
        let slope = tan(30.0 * .pi / 180.0)
        let square = projectedSquare(sideMM: 20, c: 0.3, a: slope)
        let calibration = try XCTUnwrap(manager.depthCalibration(for: square, depthData: depthData(try planeDepthMap(c: 0.3, a: slope))))

        let tilt = try XCTUnwrap(calibration.surfaceTilt)
        XCTAssertEqual(tilt.angleDegrees, 30, accuracy: 1)
        XCTAssertEqual(abs(tilt.directionX), 1, accuracy: 0.02)

        let boundary = WoundBoundary(points: square, confidence: 1, boundingBox: .zero, detectionMethod: .manual)
        let corrected = manager.calculateMeasurements(boundary: boundary, calibration: calibration, depthData: nil)
        XCTAssertEqual(corrected.length.value, 20, accuracy: 0.6)
        XCTAssertEqual(corrected.width.value, 20, accuracy: 0.6)
        XCTAssertEqual(corrected.area.value, 400, accuracy: 400 * 0.03)

        // Without tilt correction the square reads ~13% small (cos 30° ≈ 0.87)
        let uncorrected = MeasurementCalibration(pixelsPerMillimeter: calibration.pixelsPerMillimeter, calibrationType: .estimated)
        let foreshortened = manager.calculateMeasurements(boundary: boundary, calibration: uncorrected, depthData: nil)
        XCTAssertLessThan(foreshortened.area.value, 400 * 0.9)
    }

    func testDepthCalibration_RelativeDepthOrMissingIntrinsics_ReturnsNil() throws {
        let map = try planeDepthMap(c: 0.3, a: 0)
        let square = projectedSquare(sideMM: 20, c: 0.3, a: 0)

        let relative = DepthData(depthMap: map, accuracy: .relative, referenceImageSize: CGSize(width: 640, height: 480), intrinsics: testIntrinsics)
        XCTAssertNil(manager.depthCalibration(for: square, depthData: relative))

        let noIntrinsics = DepthData(depthMap: map, accuracy: .absolute, referenceImageSize: CGSize(width: 640, height: 480))
        XCTAssertNil(manager.depthCalibration(for: square, depthData: noIntrinsics))
    }

    func testCalibration_SurfaceTilt_SurvivesCodableRoundTrip() throws {
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.6,
            calibrationType: .lidar(depth: 0.3, confidence: 0.9),
            surfaceTilt: SurfaceTilt(angleDegrees: 25, directionX: 0.6, directionY: 0.8)
        )
        let decoded = try JSONDecoder().decode(MeasurementCalibration.self, from: JSONEncoder().encode(calibration))
        XCTAssertEqual(decoded.surfaceTilt, calibration.surfaceTilt)
    }
}
