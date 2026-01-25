//
//  WoundDetectionServiceTests.swift
//  PediLensTests
//
//  Created by PediLens Team
//

import XCTest
@testable import PediLens

class WoundDetectionServiceTests: XCTestCase {
    
    var service: WoundDetectionService!
    
    override func setUp() {
        super.setUp()
        service = WoundDetectionService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Detection Tests
    
    func testDetectWoundBoundary_ValidImage_ReturnsWoundBoundary() async throws {
        // Given: A valid test image
        let image = createTestImage(size: CGSize(width: 400, height: 400))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Should return a valid boundary
        XCTAssertGreaterThan(boundary.points.count, 0, "Boundary should have points")
        XCTAssertGreaterThanOrEqual(boundary.confidence, 0.0, "Confidence should be >= 0")
        XCTAssertLessThanOrEqual(boundary.confidence, 1.0, "Confidence should be <= 1")
        XCTAssertNotEqual(boundary.boundingBox, .zero, "Bounding box should not be zero")
        
        if case .automatic(let version) = boundary.detectionMethod {
            XCTAssertEqual(version, "1.0", "Model version should be 1.0")
        } else {
            XCTFail("Detection method should be automatic")
        }
    }
    
    func testDetectWoundBoundary_InvalidImage_ThrowsError() async {
        // Given: An invalid image (empty)
        let image = UIImage()
        
        // When/Then: Should throw invalid image error
        do {
            _ = try await service.detectWoundBoundary(in: image, calibration: nil)
            XCTFail("Should throw error for invalid image")
        } catch WoundDetectionError.invalidImage {
            // Expected error
        } catch {
            XCTFail("Should throw invalidImage error, got \(error)")
        }
    }
    
    func testDetectWoundBoundary_WithCalibration_ReturnsWoundBoundary() async throws {
        // Given: A valid test image and calibration
        let image = createTestImage(size: CGSize(width: 400, height: 400))
        let calibration = MeasurementCalibration(
            pixelsPerMillimeter: 2.0,
            referenceObject: .ruler(lengthMM: 100),
            calibrationDate: Date()
        )
        
        // When: Detecting wound boundary with calibration
        let boundary = try await service.detectWoundBoundary(in: image, calibration: calibration)
        
        // Then: Should return a valid boundary
        XCTAssertGreaterThan(boundary.points.count, 0, "Boundary should have points")
        XCTAssertGreaterThanOrEqual(boundary.confidence, 0.0, "Confidence should be >= 0")
    }
    
    func testDetectWoundBoundary_ReturnsMinimumThreePoints() async throws {
        // Given: A valid test image
        let image = createTestImage(size: CGSize(width: 400, height: 400))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Should have at least 3 points to form a polygon
        XCTAssertGreaterThanOrEqual(boundary.points.count, 3, "Boundary should have at least 3 points")
    }
    
    func testDetectWoundBoundary_BoundingBoxContainsAllPoints() async throws {
        // Given: A valid test image
        let image = createTestImage(size: CGSize(width: 400, height: 400))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Bounding box should contain all points
        for point in boundary.points {
            XCTAssertTrue(boundary.boundingBox.contains(point), 
                         "Bounding box should contain point \(point)")
        }
    }
    
    // MARK: - Refinement Tests
    
    func testRefineDetection_WithUserAdjustments_ReturnsRefinedBoundary() {
        // Given: An original boundary and user adjustments
        let originalPoints = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 100, y: 200)
        ]
        let originalBoundary = WoundBoundary(
            points: originalPoints,
            confidence: 0.8,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let userAdjustments = [
            CGPoint(x: 150, y: 90),  // Adjust top edge
            CGPoint(x: 210, y: 150)  // Adjust right edge
        ]
        
        // When: Refining detection
        let refinedBoundary = service.refineDetection(originalBoundary, with: userAdjustments)
        
        // Then: Should return refined boundary
        XCTAssertGreaterThan(refinedBoundary.points.count, originalPoints.count, 
                            "Refined boundary should have more points")
        
        if case .refined(let originalConfidence) = refinedBoundary.detectionMethod {
            XCTAssertEqual(originalConfidence, 0.8, "Should preserve original confidence")
        } else {
            XCTFail("Detection method should be refined")
        }
    }
    
    func testRefineDetection_EmptyAdjustments_ReturnsSimilarBoundary() {
        // Given: An original boundary with no adjustments
        let originalPoints = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 100, y: 200)
        ]
        let originalBoundary = WoundBoundary(
            points: originalPoints,
            confidence: 0.8,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        // When: Refining with no adjustments
        let refinedBoundary = service.refineDetection(originalBoundary, with: [])
        
        // Then: Should return similar boundary (possibly simplified)
        XCTAssertGreaterThanOrEqual(refinedBoundary.points.count, 2, 
                                   "Refined boundary should have at least 2 points")
        
        if case .refined(let originalConfidence) = refinedBoundary.detectionMethod {
            XCTAssertEqual(originalConfidence, 0.8, "Should preserve original confidence")
        } else {
            XCTFail("Detection method should be refined")
        }
    }
    
    func testRefineDetection_UpdatesBoundingBox() {
        // Given: An original boundary and user adjustments that extend beyond original box
        let originalPoints = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 100, y: 200)
        ]
        let originalBoundary = WoundBoundary(
            points: originalPoints,
            confidence: 0.8,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let userAdjustments = [
            CGPoint(x: 250, y: 150)  // Extends beyond original bounding box
        ]
        
        // When: Refining detection
        let refinedBoundary = service.refineDetection(originalBoundary, with: userAdjustments)
        
        // Then: Bounding box should be updated to contain all points
        for point in refinedBoundary.points {
            XCTAssertTrue(refinedBoundary.boundingBox.contains(point), 
                         "Updated bounding box should contain point \(point)")
        }
    }
    
    // MARK: - Edge Cases
    
    func testDetectWoundBoundary_SmallImage_ReturnsValidBoundary() async throws {
        // Given: A small image
        let image = createTestImage(size: CGSize(width: 100, height: 100))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Should still return a valid boundary
        XCTAssertGreaterThan(boundary.points.count, 0, "Should detect boundary in small image")
    }
    
    func testDetectWoundBoundary_LargeImage_ReturnsValidBoundary() async throws {
        // Given: A large image
        let image = createTestImage(size: CGSize(width: 2000, height: 2000))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Should return a valid boundary
        XCTAssertGreaterThan(boundary.points.count, 0, "Should detect boundary in large image")
    }
    
    func testRefineDetection_TriangleBoundary_HandlesCorrectly() {
        // Given: A triangular boundary (minimum valid polygon)
        let originalPoints = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 150, y: 200)
        ]
        let originalBoundary = WoundBoundary(
            points: originalPoints,
            confidence: 0.7,
            boundingBox: CGRect(x: 100, y: 100, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
        
        let userAdjustments = [CGPoint(x: 150, y: 150)]
        
        // When: Refining detection
        let refinedBoundary = service.refineDetection(originalBoundary, with: userAdjustments)
        
        // Then: Should handle triangle correctly
        XCTAssertGreaterThanOrEqual(refinedBoundary.points.count, 3, 
                                   "Should maintain at least 3 points for valid polygon")
    }
    
    // MARK: - Confidence Score Tests
    
    func testDetectWoundBoundary_ConfidenceInValidRange() async throws {
        // Given: A valid test image
        let image = createTestImage(size: CGSize(width: 400, height: 400))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Confidence should be in valid range [0, 1]
        XCTAssertGreaterThanOrEqual(boundary.confidence, 0.0, "Confidence should be >= 0")
        XCTAssertLessThanOrEqual(boundary.confidence, 1.0, "Confidence should be <= 1")
    }
    
    func testDetectWoundBoundary_MeetsMinimumConfidence() async throws {
        // Given: A valid test image
        let image = createTestImage(size: CGSize(width: 400, height: 400))
        
        // When: Detecting wound boundary
        let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
        
        // Then: Confidence should meet minimum threshold (0.3)
        XCTAssertGreaterThanOrEqual(boundary.confidence, 0.3, 
                                   "Confidence should meet minimum threshold")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw a white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw a red ellipse in the center (simulating a wound)
            UIColor.red.setFill()
            let ellipseRect = CGRect(
                x: size.width * 0.25,
                y: size.height * 0.25,
                width: size.width * 0.5,
                height: size.height * 0.5
            )
            context.cgContext.fillEllipse(in: ellipseRect)
        }
    }
}
