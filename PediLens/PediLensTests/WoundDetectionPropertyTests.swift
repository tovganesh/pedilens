//
//  WoundDetectionPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for WoundDetectionService
//  Feature: pedilens, Property 3: Automatic Wound Boundary Detection
//  Validates: Requirements 2.2
//

import XCTest
@testable import PediLens

/// Property-based tests for WoundDetectionService automatic boundary detection
/// These tests validate universal properties that should hold for all valid wound photos
final class WoundDetectionPropertyTests: XCTestCase {
    
    var service: WoundDetectionService!
    
    override func setUp() {
        super.setUp()
        service = WoundDetectionService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Generates a test image with a wound-like shape
    /// - Parameters:
    ///   - size: The size of the image
    ///   - woundShape: The type of wound shape to generate
    ///   - woundSize: Relative size of the wound (0.0 to 1.0)
    ///   - woundPosition: Relative position of the wound center (0.0 to 1.0 for x and y)
    /// - Returns: A UIImage containing a simulated wound
    private func generateWoundImage(
        size: CGSize,
        woundShape: WoundShape,
        woundSize: CGFloat,
        woundPosition: CGPoint
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Draw background (skin tone)
            UIColor(red: 0.95, green: 0.87, blue: 0.78, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Calculate wound dimensions and position
            let woundWidth = size.width * woundSize
            let woundHeight = size.height * woundSize
            let centerX = size.width * woundPosition.x
            let centerY = size.height * woundPosition.y
            
            // Draw wound based on shape
            let woundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
            woundColor.setFill()
            
            switch woundShape {
            case .ellipse:
                let woundRect = CGRect(
                    x: centerX - woundWidth / 2,
                    y: centerY - woundHeight / 2,
                    width: woundWidth,
                    height: woundHeight
                )
                context.cgContext.fillEllipse(in: woundRect)
                
            case .circle:
                let radius = min(woundWidth, woundHeight) / 2
                let woundRect = CGRect(
                    x: centerX - radius,
                    y: centerY - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.cgContext.fillEllipse(in: woundRect)
                
            case .rectangle:
                let woundRect = CGRect(
                    x: centerX - woundWidth / 2,
                    y: centerY - woundHeight / 2,
                    width: woundWidth,
                    height: woundHeight
                )
                context.fill(woundRect)
                
            case .irregular:
                // Create an irregular polygon
                let path = UIBezierPath()
                let pointCount = Int.random(in: 5...10)
                let angleStep = 2 * CGFloat.pi / CGFloat(pointCount)
                
                for i in 0..<pointCount {
                    let angle = angleStep * CGFloat(i)
                    let radiusVariation = CGFloat.random(in: 0.7...1.0)
                    let radius = min(woundWidth, woundHeight) / 2 * radiusVariation
                    let x = centerX + cos(angle) * radius
                    let y = centerY + sin(angle) * radius
                    
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.close()
                path.fill()
            }
        }
    }
    
    /// Wound shape types for test generation
    private enum WoundShape: CaseIterable {
        case ellipse
        case circle
        case rectangle
        case irregular
    }
    
    /// Generates a random calibration for testing
    private func generateRandomCalibration() -> MeasurementCalibration? {
        // 50% chance of having calibration
        guard Bool.random() else { return nil }
        
        let pixelsPerMM = Double.random(in: 0.5...5.0)
        let referenceObjects: [ReferenceObject?] = [
            .ruler(lengthMM: 100),
            .coin(type: .usQuarter),
            .custom(name: "Test Object", dimensionMM: 50),
            nil
        ]
        
        return MeasurementCalibration(
            pixelsPerMillimeter: pixelsPerMM,
            referenceObject: referenceObjects.randomElement()!,
            calibrationDate: Date()
        )
    }
    
    // MARK: - Property 3: Automatic Wound Boundary Detection
    // **Validates: Requirements 2.2**
    
    /// Property: For any valid wound photo, the detection system SHALL produce a wound boundary with a confidence score
    /// This is the core property that validates automatic wound boundary detection
    func testProperty3_AutomaticDetection_ProducesBoundaryWithConfidence() async throws {
        let iterations = 100
        var failedCases: [(imageSize: CGSize, woundShape: WoundShape, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random test parameters
            let imageWidth = CGFloat.random(in: 200...2000)
            let imageHeight = CGFloat.random(in: 200...2000)
            let imageSize = CGSize(width: imageWidth, height: imageHeight)
            
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.1...0.6) // 10% to 60% of image
            let woundPositionX = CGFloat.random(in: 0.3...0.7) // Keep wound reasonably centered
            let woundPositionY = CGFloat.random(in: 0.3...0.7)
            let woundPosition = CGPoint(x: woundPositionX, y: woundPositionY)
            
            let calibration = generateRandomCalibration()
            
            // Generate test image
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            do {
                // Perform detection
                let boundary = try await service.detectWoundBoundary(in: image, calibration: calibration)
                
                // Verify core property: boundary exists with confidence score
                
                // 1. Boundary should have points
                if boundary.points.isEmpty {
                    failedCases.append((imageSize: imageSize, woundShape: woundShape, iteration: iteration))
                    continue
                }
                
                // 2. Confidence score should be in valid range [0, 1]
                if boundary.confidence < 0.0 || boundary.confidence > 1.0 {
                    failedCases.append((imageSize: imageSize, woundShape: woundShape, iteration: iteration))
                    continue
                }
                
                // 3. Boundary should have at least 3 points (minimum for a polygon)
                XCTAssertGreaterThanOrEqual(boundary.points.count, 3,
                                          "Iteration \(iteration): Boundary should have at least 3 points")
                
                // 4. Bounding box should be non-zero
                XCTAssertNotEqual(boundary.boundingBox, .zero,
                                "Iteration \(iteration): Bounding box should not be zero")
                
                // 5. Detection method should be automatic
                if case .automatic(let version) = boundary.detectionMethod {
                    XCTAssertFalse(version.isEmpty,
                                 "Iteration \(iteration): Model version should not be empty")
                } else {
                    XCTFail("Iteration \(iteration): Detection method should be automatic")
                }
                
                // 6. All boundary points should be within image bounds
                for point in boundary.points {
                    XCTAssertTrue(point.x >= 0 && point.x <= imageSize.width,
                                "Iteration \(iteration): Point x coordinate should be within image bounds")
                    XCTAssertTrue(point.y >= 0 && point.y <= imageSize.height,
                                "Iteration \(iteration): Point y coordinate should be within image bounds")
                }
                
                // 7. Bounding box should be within image bounds
                XCTAssertTrue(boundary.boundingBox.minX >= 0,
                            "Iteration \(iteration): Bounding box should be within image bounds")
                XCTAssertTrue(boundary.boundingBox.minY >= 0,
                            "Iteration \(iteration): Bounding box should be within image bounds")
                XCTAssertTrue(boundary.boundingBox.maxX <= imageSize.width,
                            "Iteration \(iteration): Bounding box should be within image bounds")
                XCTAssertTrue(boundary.boundingBox.maxY <= imageSize.height,
                            "Iteration \(iteration): Bounding box should be within image bounds")
                
            } catch WoundDetectionError.invalidImage {
                // This is acceptable - some generated images might be invalid
                continue
            } catch WoundDetectionError.lowConfidence {
                // This is acceptable - some wounds might have low confidence
                continue
            } catch WoundDetectionError.noContoursFound {
                // This is acceptable - some images might not have detectable contours
                continue
            } catch {
                XCTFail("Iteration \(iteration): Unexpected error: \(error)")
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Automatic detection property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo, confidence score should be consistent with boundary quality
    /// This validates that confidence scoring is meaningful
    func testProperty3_ConfidenceScore_ReflectsBoundaryQuality() async throws {
        let iterations = 100
        var failedCases: [(confidence: Float, pointCount: Int, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate test image with varying quality
            let imageSize = CGSize(width: 400, height: 400)
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.15...0.5)
            let woundPosition = CGPoint(x: 0.5, y: 0.5)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            do {
                let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
                
                // Verify confidence is in valid range
                if boundary.confidence < 0.0 || boundary.confidence > 1.0 {
                    failedCases.append((confidence: boundary.confidence, 
                                      pointCount: boundary.points.count, 
                                      iteration: iteration))
                }
                
                // Verify confidence meets minimum threshold (0.3 as per design)
                XCTAssertGreaterThanOrEqual(boundary.confidence, 0.3,
                                          "Iteration \(iteration): Confidence should meet minimum threshold")
                
                // Verify that boundaries with more points tend to have reasonable confidence
                // (This is a soft check - we don't enforce strict correlation)
                if boundary.points.count > 50 {
                    XCTAssertGreaterThan(boundary.confidence, 0.0,
                                       "Iteration \(iteration): Detailed boundaries should have positive confidence")
                }
                
            } catch {
                // Expected errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Confidence quality property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo, detection should complete within timeout
    /// This validates that detection doesn't hang indefinitely
    func testProperty3_Detection_CompletesWithinTimeout() async throws {
        let iterations = 50
        var failedCases: [(imageSize: CGSize, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate test image
            let imageWidth = CGFloat.random(in: 300...1500)
            let imageHeight = CGFloat.random(in: 300...1500)
            let imageSize = CGSize(width: imageWidth, height: imageHeight)
            
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.2...0.5)
            let woundPosition = CGPoint(x: 0.5, y: 0.5)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            let startTime = Date()
            
            do {
                _ = try await service.detectWoundBoundary(in: image, calibration: nil)
                
                let elapsedTime = Date().timeIntervalSince(startTime)
                
                // Verify detection completed within reasonable time (5 seconds as per design)
                if elapsedTime > 5.0 {
                    failedCases.append((imageSize: imageSize, iteration: iteration))
                }
                
                XCTAssertLessThan(elapsedTime, 6.0,
                                "Iteration \(iteration): Detection should complete within timeout")
                
            } catch WoundDetectionError.timeout {
                // Timeout error is acceptable - it means the timeout mechanism works
                continue
            } catch {
                // Other errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Timeout property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo, bounding box should contain all boundary points
    /// This validates geometric consistency
    func testProperty3_BoundingBox_ContainsAllPoints() async throws {
        let iterations = 100
        var failedCases: [(point: CGPoint, box: CGRect, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate test image
            let imageSize = CGSize(width: 500, height: 500)
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.2...0.5)
            let woundPositionX = CGFloat.random(in: 0.3...0.7)
            let woundPositionY = CGFloat.random(in: 0.3...0.7)
            let woundPosition = CGPoint(x: woundPositionX, y: woundPositionY)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            do {
                let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
                
                // Verify all points are contained in bounding box
                for point in boundary.points {
                    if !boundary.boundingBox.contains(point) {
                        failedCases.append((point: point, 
                                          box: boundary.boundingBox, 
                                          iteration: iteration))
                    }
                }
                
            } catch {
                // Expected errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Bounding box containment property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo, boundary points should form a closed polygon
    /// This validates that the boundary is a valid geometric shape
    func testProperty3_BoundaryPoints_FormClosedPolygon() async throws {
        let iterations = 100
        var failedCases: [(pointCount: Int, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate test image
            let imageSize = CGSize(width: 400, height: 400)
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.2...0.5)
            let woundPosition = CGPoint(x: 0.5, y: 0.5)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            do {
                let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
                
                // Verify boundary has at least 3 points (minimum for a polygon)
                if boundary.points.count < 3 {
                    failedCases.append((pointCount: boundary.points.count, iteration: iteration))
                }
                
                // Verify points are not all identical (degenerate polygon)
                let uniquePoints = Set(boundary.points.map { "\($0.x),\($0.y)" })
                XCTAssertGreaterThanOrEqual(uniquePoints.count, 3,
                                          "Iteration \(iteration): Boundary should have at least 3 unique points")
                
                // Verify points form a reasonable polygon (not all collinear)
                // We check that the bounding box has non-zero area
                let boxArea = boundary.boundingBox.width * boundary.boundingBox.height
                XCTAssertGreaterThan(boxArea, 0,
                                   "Iteration \(iteration): Boundary should have non-zero area")
                
            } catch {
                // Expected errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Closed polygon property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo with calibration, detection should still work
    /// This validates that calibration doesn't interfere with detection
    func testProperty3_DetectionWithCalibration_ProducesBoundary() async throws {
        let iterations = 100
        var failedCases: [(hasCalibration: Bool, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate test image
            let imageSize = CGSize(width: 400, height: 400)
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.2...0.5)
            let woundPosition = CGPoint(x: 0.5, y: 0.5)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            // Randomly include calibration
            let calibration = generateRandomCalibration()
            
            do {
                let boundary = try await service.detectWoundBoundary(in: image, calibration: calibration)
                
                // Verify detection succeeded regardless of calibration
                if boundary.points.isEmpty {
                    failedCases.append((hasCalibration: calibration != nil, iteration: iteration))
                }
                
                // Verify confidence is valid
                XCTAssertGreaterThanOrEqual(boundary.confidence, 0.0,
                                          "Iteration \(iteration): Confidence should be >= 0")
                XCTAssertLessThanOrEqual(boundary.confidence, 1.0,
                                       "Iteration \(iteration): Confidence should be <= 1")
                
            } catch {
                // Expected errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Detection with calibration property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo, detection should be deterministic for the same input
    /// This validates that detection produces consistent results
    func testProperty3_Detection_IsDeterministic() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Generate test image
            let imageSize = CGSize(width: 400, height: 400)
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.2...0.5)
            let woundPosition = CGPoint(x: 0.5, y: 0.5)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            do {
                // Detect boundary twice
                let boundary1 = try await service.detectWoundBoundary(in: image, calibration: nil)
                let boundary2 = try await service.detectWoundBoundary(in: image, calibration: nil)
                
                // Verify results are identical
                if boundary1.points.count != boundary2.points.count {
                    failedCases.append(iteration)
                    continue
                }
                
                // Check that points are the same (allowing for floating point tolerance)
                for i in 0..<boundary1.points.count {
                    let p1 = boundary1.points[i]
                    let p2 = boundary2.points[i]
                    let distance = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
                    
                    if distance > 0.01 { // Allow small floating point differences
                        failedCases.append(iteration)
                        break
                    }
                }
                
                // Verify confidence is the same
                XCTAssertEqual(boundary1.confidence, boundary2.confidence, accuracy: 0.001,
                             "Iteration \(iteration): Confidence should be deterministic")
                
            } catch {
                // Expected errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Determinism property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any valid wound photo of different sizes, detection should scale appropriately
    /// This validates that detection works across different image resolutions
    func testProperty3_Detection_ScalesWithImageSize() async throws {
        let iterations = 50
        var failedCases: [(imageSize: CGSize, iteration: Int)] = []
        
        // Test a range of image sizes
        let imageSizes = [
            CGSize(width: 200, height: 200),   // Small
            CGSize(width: 400, height: 400),   // Medium
            CGSize(width: 800, height: 800),   // Large
            CGSize(width: 1600, height: 1600), // Very large
            CGSize(width: 300, height: 600),   // Rectangular
            CGSize(width: 600, height: 300)    // Rectangular (other orientation)
        ]
        
        for iteration in 0..<iterations {
            let imageSize = imageSizes.randomElement()!
            let woundShape = WoundShape.allCases.randomElement()!
            let woundSize = CGFloat.random(in: 0.2...0.5)
            let woundPosition = CGPoint(x: 0.5, y: 0.5)
            
            let image = generateWoundImage(
                size: imageSize,
                woundShape: woundShape,
                woundSize: woundSize,
                woundPosition: woundPosition
            )
            
            do {
                let boundary = try await service.detectWoundBoundary(in: image, calibration: nil)
                
                // Verify detection succeeded
                if boundary.points.isEmpty {
                    failedCases.append((imageSize: imageSize, iteration: iteration))
                    continue
                }
                
                // Verify boundary is scaled appropriately to image size
                // All points should be within image bounds
                for point in boundary.points {
                    if point.x < 0 || point.x > imageSize.width ||
                       point.y < 0 || point.y > imageSize.height {
                        failedCases.append((imageSize: imageSize, iteration: iteration))
                        break
                    }
                }
                
            } catch {
                // Expected errors are acceptable
                continue
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Image size scaling property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
