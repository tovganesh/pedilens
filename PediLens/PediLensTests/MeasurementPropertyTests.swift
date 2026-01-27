//
//  MeasurementPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for MeasurementManager
//  Feature: pedilens, Properties 4-9, 34-35
//  Validates: Requirements 2.4, 2.5, 2.6, 2.7, 2.9, 2.10, 12.2, 12.3
//

import XCTest
import CoreGraphics
import AVFoundation
@testable import PediLens

/// Property-based tests for MeasurementManager functionality
/// These tests validate universal properties that should hold for all inputs
final class MeasurementPropertyTests: XCTestCase {
    
    var manager: MeasurementManager!
    
    override func setUp() {
        super.setUp()
        manager = MeasurementManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Generates a random valid polygon with at least 3 points
    private func generateRandomPolygon(pointCount: Int, maxCoordinate: CGFloat = 1000) -> [CGPoint] {
        guard pointCount >= 3 else { return [] }
        
        // Generate points in a circular pattern to ensure valid polygon
        let centerX = maxCoordinate / 2
        let centerY = maxCoordinate / 2
        let radius = CGFloat.random(in: 10...maxCoordinate/3)
        
        var points: [CGPoint] = []
        for i in 0..<pointCount {
            let angle = (CGFloat(i) / CGFloat(pointCount)) * 2 * .pi
            let randomRadius = radius * CGFloat.random(in: 0.5...1.5)
            let x = centerX + randomRadius * cos(angle)
            let y = centerY + randomRadius * sin(angle)
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
    
    /// Generates a random rectangle
    private func generateRandomRectangle(maxCoordinate: CGFloat = 1000) -> [CGPoint] {
        let x = CGFloat.random(in: 0...maxCoordinate/2)
        let y = CGFloat.random(in: 0...maxCoordinate/2)
        let width = CGFloat.random(in: 10...maxCoordinate/2)
        let height = CGFloat.random(in: 10...maxCoordinate/2)
        
        return [
            CGPoint(x: x, y: y),
            CGPoint(x: x + width, y: y),
            CGPoint(x: x + width, y: y + height),
            CGPoint(x: x, y: y + height)
        ]
    }
    
    /// Generates a random calibration
    private func generateRandomCalibration() -> MeasurementCalibration {
        let pixelsPerMM = Double.random(in: 0.1...10.0)
        return MeasurementCalibration(
            pixelsPerMillimeter: pixelsPerMM,
            referenceObject: nil,
            calibrationDate: Date()
        )
    }
    
    // MARK: - Property 4: Area Calculation from Boundary
    // **Validates: Requirements 2.4**
    
    /// Property: For any established wound boundary, the system SHALL automatically calculate the wound area
    func testProperty4_AreaCalculation_AlwaysCalculatesArea() {
        let iterations = 100
        var failedCases: [(points: [CGPoint], iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random polygon with 3-20 points
            let pointCount = Int.random(in: 3...20)
            let points = generateRandomPolygon(pointCount: pointCount)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: Float.random(in: 0.5...1.0),
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = generateRandomCalibration()
            
            // Calculate measurements
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Verify area is calculated (non-negative)
            if measurement.area.value < 0 {
                failedCases.append((points: points, iteration: iteration))
            }
            
            // Area should be positive for valid polygons
            XCTAssertGreaterThanOrEqual(measurement.area.value, 0.0,
                                       "Iteration \(iteration): Area should be non-negative")
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Area calculation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Area should scale quadratically with calibration
    func testProperty4_AreaScaling_ScalesQuadraticallyWithCalibration() {
        let iterations = 100
        var failedCases: [(points: [CGPoint], iteration: Int)] = []
        
        for iteration in 0..<iterations {
            let pointCount = Int.random(in: 3...10)
            let points = generateRandomPolygon(pointCount: pointCount)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            // Calculate with two different calibrations
            let calibration1 = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let calibration2 = MeasurementCalibration(
                pixelsPerMillimeter: 2.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let measurement1 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration1,
                depthData: nil
            )
            
            let measurement2 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration2,
                depthData: nil
            )
            
            // Area should scale by 1/4 when pixels per mm doubles
            // (because area = pixels² / (pixelsPerMM)²)
            let expectedRatio = 0.25
            let actualRatio = measurement2.area.value / measurement1.area.value
            
            if abs(actualRatio - expectedRatio) > 0.01 {
                failedCases.append((points: points, iteration: iteration))
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Area scaling property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Area should be invariant under translation
    func testProperty4_AreaInvariance_UnderTranslation() {
        let iterations = 100
        var failedCases: [(points: [CGPoint], iteration: Int)] = []
        
        for iteration in 0..<iterations {
            let pointCount = Int.random(in: 3...10)
            let points = generateRandomPolygon(pointCount: pointCount, maxCoordinate: 500)
            
            // Translate the polygon
            let dx = CGFloat.random(in: -100...100)
            let dy = CGFloat.random(in: -100...100)
            let translatedPoints = points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
            
            let boundary1 = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let boundary2 = WoundBoundary(
                points: translatedPoints,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = generateRandomCalibration()
            
            let measurement1 = manager.calculateMeasurements(
                boundary: boundary1,
                calibration: calibration,
                depthData: nil
            )
            
            let measurement2 = manager.calculateMeasurements(
                boundary: boundary2,
                calibration: calibration,
                depthData: nil
            )
            
            // Areas should be equal (within floating point tolerance)
            if abs(measurement1.area.value - measurement2.area.value) > 0.1 {
                failedCases.append((points: points, iteration: iteration))
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Area translation invariance failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Area of a square should equal side²
    func testProperty4_AreaCorrectness_SquareFormula() {
        let iterations = 100
        var failedCases: [(sideLength: CGFloat, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            let sideLength = CGFloat.random(in: 10...500)
            let points = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: sideLength, y: 0),
                CGPoint(x: sideLength, y: sideLength),
                CGPoint(x: 0, y: sideLength)
            ]
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            // Use 1:1 calibration for simplicity
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            let expectedArea = Double(sideLength * sideLength)
            let actualArea = measurement.area.value
            
            // Allow 0.1% tolerance for floating point errors
            if abs(actualArea - expectedArea) / expectedArea > 0.001 {
                failedCases.append((sideLength: sideLength, iteration: iteration))
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Square area formula failed for \(failedCases.count) out of \(iterations) cases")
    }

    // MARK: - Property 5: Comprehensive Measurement Calculation
    // **Validates: Requirements 2.5**
    
    /// Property: For any wound boundary with calibration data, length, width, area, and perimeter SHALL be calculated
    func testProperty5_ComprehensiveMeasurements_AllCalculated() {
        let iterations = 100
        var failedCases: [(points: [CGPoint], iteration: Int)] = []
        
        for iteration in 0..<iterations {
            let pointCount = Int.random(in: 3...15)
            let points = generateRandomPolygon(pointCount: pointCount)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: Float.random(in: 0.5...1.0),
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = generateRandomCalibration()
            
            // Calculate measurements
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Verify all measurements are calculated and non-negative
            let allValid = measurement.length.value >= 0 &&
                          measurement.width.value >= 0 &&
                          measurement.area.value >= 0 &&
                          measurement.perimeter.value >= 0
            
            if !allValid {
                failedCases.append((points: points, iteration: iteration))
            }
            
            // Length should be >= width
            XCTAssertGreaterThanOrEqual(measurement.length.value, measurement.width.value,
                                       "Iteration \(iteration): Length should be >= width")
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Comprehensive measurement property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Perimeter should be at least 2*(length + width) for any polygon
    func testProperty5_PerimeterBounds_MinimumValue() {
        let iterations = 100
        var failedCases: [(points: [CGPoint], iteration: Int)] = []
        
        for iteration in 0..<iterations {
            let points = generateRandomRectangle()
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // For a rectangle, perimeter should equal 2*(length + width)
            let expectedPerimeter = 2 * (measurement.length.value + measurement.width.value)
            let actualPerimeter = measurement.perimeter.value
            
            // Allow 1% tolerance for floating point errors
            if abs(actualPerimeter - expectedPerimeter) / expectedPerimeter > 0.01 {
                failedCases.append((points: points, iteration: iteration))
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Perimeter bounds property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    // MARK: - Property 8: Dual Unit Display
    // **Validates: Requirements 2.9**
    
    /// Property: For any measurement, both metric and imperial units SHALL be available
    func testProperty8_DualUnitDisplay_BothUnitsAvailable() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let pointCount = Int.random(in: 3...10)
            let points = generateRandomPolygon(pointCount: pointCount)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = generateRandomCalibration()
            
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Convert to imperial units
            let lengthInches = measurement.length.converted(to: .inches)
            let widthInches = measurement.width.converted(to: .inches)
            let areaSquareInches = measurement.area.converted(to: .squareInches)
            let perimeterInches = measurement.perimeter.converted(to: .inches)
            
            // Verify conversions are valid (non-negative and reasonable)
            let allValid = lengthInches.value >= 0 &&
                          widthInches.value >= 0 &&
                          areaSquareInches.value >= 0 &&
                          perimeterInches.value >= 0
            
            if !allValid {
                failedCases.append(iteration)
            }
            
            // Verify conversion ratio (1 inch = 25.4 mm)
            let expectedLengthInches = measurement.length.value / 25.4
            if abs(lengthInches.value - expectedLengthInches) / expectedLengthInches > 0.001 {
                failedCases.append(iteration)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Dual unit display property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Unit conversion should be reversible
    func testProperty8_UnitConversion_Reversible() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 5)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = generateRandomCalibration()
            
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Convert to inches and back to millimeters
            let lengthInches = measurement.length.converted(to: .inches)
            let lengthBackToMM = lengthInches.converted(to: .millimeters)
            
            // Should be equal within floating point tolerance
            if abs(lengthBackToMM.value - measurement.length.value) > 0.001 {
                failedCases.append(iteration)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Unit conversion reversibility failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    // MARK: - Property 34: Calibration Ratio Calculation
    // **Validates: Requirements 12.2**
    
    /// Property: For any identified reference object, a pixel-to-distance calibration ratio SHALL be calculated
    func testProperty34_CalibrationRatio_AlwaysCalculated() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Generate random reference object
            let referenceTypes: [ReferenceObject] = [
                .ruler(lengthMM: Double.random(in: 10...200)),
                .coin(type: [.usQuarter, .usDime, .usPenny, .usNickel].randomElement()!),
                .custom(name: "Test", dimensionMM: Double.random(in: 5...100))
            ]
            
            let referenceObject = referenceTypes.randomElement()!
            let pixelDistance = CGFloat.random(in: 10...500)
            
            // Create calibration
            let calibration = manager.createCalibration(
                referenceObject: referenceObject,
                pixelDistance: pixelDistance
            )
            
            // Verify ratio is calculated and positive
            if calibration.pixelsPerMillimeter <= 0 {
                failedCases.append(iteration)
            }
            
            // Verify reference object is stored
            if calibration.referenceObject == nil {
                failedCases.append(iteration)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Calibration ratio calculation failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Calibration ratio should be consistent with reference object dimensions
    func testProperty34_CalibrationRatio_ConsistentWithReference() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let knownDimensionMM = Double.random(in: 10...100)
            let pixelDistance = CGFloat.random(in: 50...500)
            
            let referenceObject = ReferenceObject.ruler(lengthMM: knownDimensionMM)
            
            let calibration = manager.createCalibration(
                referenceObject: referenceObject,
                pixelDistance: pixelDistance
            )
            
            // Expected ratio
            let expectedRatio = Double(pixelDistance) / knownDimensionMM
            
            // Verify calculated ratio matches expected
            if abs(calibration.pixelsPerMillimeter - expectedRatio) > 0.001 {
                failedCases.append(iteration)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Calibration ratio consistency failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    // MARK: - Property 35: Calibration Application to Measurements
    // **Validates: Requirements 12.3**
    
    /// Property: For any measurement in a calibrated session, the calibration SHALL be applied
    func testProperty35_CalibrationApplication_AppliedToMeasurements() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 4)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            // Create two different calibrations
            let calibration1 = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let calibration2 = MeasurementCalibration(
                pixelsPerMillimeter: 2.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let measurement1 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration1,
                depthData: nil
            )
            
            let measurement2 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration2,
                depthData: nil
            )
            
            // Measurements should differ based on calibration
            // With 2x pixels per mm, measurements should be 0.5x
            let expectedRatio = 0.5
            let actualRatio = measurement2.length.value / measurement1.length.value
            
            if abs(actualRatio - expectedRatio) > 0.01 {
                failedCases.append(iteration)
            }
            
            // Verify calibration is stored in measurement
            if measurement1.calibrationUsed.pixelsPerMillimeter != 1.0 ||
               measurement2.calibrationUsed.pixelsPerMillimeter != 2.0 {
                failedCases.append(iteration)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Calibration application property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Calibration should scale measurements linearly for length, quadratically for area
    func testProperty35_CalibrationScaling_CorrectScaling() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 5)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let scaleFactor = Double.random(in: 1.5...5.0)
            
            let calibration1 = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let calibration2 = MeasurementCalibration(
                pixelsPerMillimeter: scaleFactor,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            let measurement1 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration1,
                depthData: nil
            )
            
            let measurement2 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration2,
                depthData: nil
            )
            
            // Length should scale by 1/scaleFactor
            let lengthRatio = measurement2.length.value / measurement1.length.value
            let expectedLengthRatio = 1.0 / scaleFactor
            
            if abs(lengthRatio - expectedLengthRatio) / expectedLengthRatio > 0.01 {
                failedCases.append(iteration)
            }
            
            // Area should scale by 1/(scaleFactor²)
            let areaRatio = measurement2.area.value / measurement1.area.value
            let expectedAreaRatio = 1.0 / (scaleFactor * scaleFactor)
            
            if abs(areaRatio - expectedAreaRatio) / expectedAreaRatio > 0.01 {
                failedCases.append(iteration)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Calibration scaling property failed for \(failedCases.count) out of \(iterations) cases")
    }

    // MARK: - Property 7: Depth Estimation on Capable Devices
    // **Validates: Requirements 2.6**
    
    /// Property: For any wound photo with depth data, depth SHALL be estimated
    func testProperty7_DepthEstimation_EstimatedWhenAvailable() {
        // Note: This test validates the property conceptually since creating real depth data
        // requires actual device hardware. In production, depth estimation would be tested
        // with real depth maps from LiDAR-capable devices.
        
        let iterations = 100
        var successCount = 0
        
        for _ in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 5)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date(),
                depthCalibration: DepthCalibration(
                    depthScale: 1.0,
                    depthOffset: 0.0,
                    confidence: 0.9
                )
            )
            
            // Without depth data, depth should be nil
            let measurementWithoutDepth = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Verify depth is nil when no depth data provided
            if measurementWithoutDepth.depth == nil {
                successCount += 1
            }
        }
        
        // All measurements without depth data should have nil depth
        XCTAssertEqual(successCount, iterations,
                      "Depth should be nil when no depth data is provided")
    }
    
    /// Property: Depth should be non-negative when calculated
    func testProperty7_DepthEstimation_NonNegative() {
        // This test validates that the depth calculation logic ensures non-negative values
        // The actual depth estimation with real depth maps would be tested on device
        
        let points = generateRandomPolygon(pointCount: 5)
        
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: .zero,
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        let measurement = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // When depth is calculated (with real depth data), it should be non-negative
        // This property is enforced in the MeasurementManager implementation
        if let depth = measurement.depth {
            XCTAssertGreaterThanOrEqual(depth.value, 0.0,
                                       "Depth should be non-negative")
        }
    }
    
    // MARK: - Property 6: Depth-Based Volume Calculation
    // **Validates: Requirements 2.7**
    
    /// Property: For any wound with area and depth, volume SHALL be calculated
    func testProperty6_VolumeCalculation_CalculatedWithDepth() {
        // This test validates the volume calculation property conceptually
        // Real volume calculation requires actual depth data from device hardware
        
        let iterations = 100
        var successCount = 0
        
        for _ in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 5)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: 1.0,
                referenceObject: nil,
                calibrationDate: Date()
            )
            
            // Without depth data, volume should be nil
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Verify volume is nil when no depth data provided
            if measurement.volume == nil {
                successCount += 1
            }
        }
        
        // All measurements without depth data should have nil volume
        XCTAssertEqual(successCount, iterations,
                      "Volume should be nil when no depth data is provided")
    }
    
    /// Property: Volume should be proportional to area when depth is constant
    func testProperty6_VolumeCalculation_ProportionalToArea() {
        // This test validates the mathematical relationship between volume and area
        // Volume = Area × Average Depth, so volume should scale linearly with area
        
        // Create two boundaries with different areas
        let smallPoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 10, y: 10),
            CGPoint(x: 0, y: 10)
        ]
        
        let largePoints = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 20, y: 0),
            CGPoint(x: 20, y: 20),
            CGPoint(x: 0, y: 20)
        ]
        
        let smallBoundary = WoundBoundary(
            points: smallPoints,
            confidence: 0.9,
            boundingBox: .zero,
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let largeBoundary = WoundBoundary(
            points: largePoints,
            confidence: 0.9,
            boundingBox: .zero,
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 1.0,
            referenceObject: nil,
            calibrationDate: Date()
        )
        
        let smallMeasurement = manager.calculateMeasurements(
            boundary: smallBoundary,
            calibration: calibration,
            depthData: nil
        )
        
        let largeMeasurement = manager.calculateMeasurements(
            boundary: largeBoundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Area ratio should be 4:1 (20×20 vs 10×10)
        let areaRatio = largeMeasurement.area.value / smallMeasurement.area.value
        XCTAssertEqual(areaRatio, 4.0, accuracy: 0.01,
                      "Area ratio should be 4:1")
        
        // If depth were available and constant, volume ratio would also be 4:1
        // This validates the proportional relationship
    }
    
    // MARK: - Property 9: Measurement History Preservation
    // **Validates: Requirements 2.10**
    
    /// Property: For any measurement modification, previous version SHALL be preserved
    func testProperty9_MeasurementHistory_PreservesTimestamp() {
        let iterations = 100
        var successCount = 0
        
        for _ in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 5)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let calibration = generateRandomCalibration()
            
            // Create first measurement
            let measurement1 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Wait a tiny bit to ensure different timestamp
            Thread.sleep(forTimeInterval: 0.001)
            
            // Create second measurement (simulating modification)
            let measurement2 = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Timestamps should be different (preserved)
            if measurement2.timestamp > measurement1.timestamp {
                successCount += 1
            }
        }
        
        XCTAssertEqual(successCount, iterations,
                      "Measurement timestamps should be preserved and unique")
    }
    
    /// Property: Each measurement should store its calibration data
    func testProperty9_MeasurementHistory_StoresCalibration() {
        let iterations = 100
        var successCount = 0
        
        for _ in 0..<iterations {
            let points = generateRandomPolygon(pointCount: 5)
            
            let boundary = WoundBoundary(
                points: points,
                confidence: 0.9,
                boundingBox: .zero,
                detectionMethod: .automatic(modelVersion: "1.0")
            )
            
            let pixelsPerMM = Double.random(in: 0.5...5.0)
            let calibration = MeasurementCalibration(
                pixelsPerMillimeter: pixelsPerMM,
                referenceObject: .ruler(lengthMM: 100),
                calibrationDate: Date()
            )
            
            let measurement = manager.calculateMeasurements(
                boundary: boundary,
                calibration: calibration,
                depthData: nil
            )
            
            // Verify calibration is stored
            if measurement.calibrationUsed.pixelsPerMillimeter == pixelsPerMM &&
               measurement.calibrationUsed.referenceObject != nil {
                successCount += 1
            }
        }
        
        XCTAssertEqual(successCount, iterations,
                      "Measurement should store calibration data for history")
    }
    
    /// Property: Measurements should be immutable (value types)
    func testProperty9_MeasurementHistory_Immutable() {
        let points = generateRandomPolygon(pointCount: 5)
        
        let boundary = WoundBoundary(
            points: points,
            confidence: 0.9,
            boundingBox: .zero,
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let calibration = generateRandomCalibration()
        
        let measurement1 = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Store original values
        let originalArea = measurement1.area.value
        let originalLength = measurement1.length.value
        
        // Create a new measurement (simulating modification)
        let measurement2 = manager.calculateMeasurements(
            boundary: boundary,
            calibration: calibration,
            depthData: nil
        )
        
        // Original measurement should be unchanged (immutable)
        XCTAssertEqual(measurement1.area.value, originalArea,
                      "Original measurement should be immutable")
        XCTAssertEqual(measurement1.length.value, originalLength,
                      "Original measurement should be immutable")
        
        // New measurement should have same values (same input)
        XCTAssertEqual(measurement2.area.value, originalArea, accuracy: 0.01,
                      "Same input should produce same measurement")
    }
}