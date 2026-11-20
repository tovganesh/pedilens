//
//  ScaleDetectionServiceTests.swift
//  PediLensTests
//
//  Unit tests for ScaleDetectionService
//

import XCTest
import UIKit
@testable import PediLens

class ScaleDetectionServiceTests: XCTestCase {
    
    var service: ScaleDetectionService!
    
    override func setUp() {
        super.setUp()
        service = ScaleDetectionService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Credit Card Detection Tests
    
    func testDetectCreditCard_Landscape_CalculatesAccurateRatio() async throws {
        // Credit card ratio: 85.6 / 53.98 ≈ 1.586
        // Create an image with a high-contrast rectangle matching credit card ratio
        let imageSize = CGSize(width: 800, height: 600)
        let cardWidth: CGFloat = 317.2  // ~158.6 * 2
        let cardHeight: CGFloat = 200.0 // ~100.0 * 2
        
        let image = createCardImage(imageSize: imageSize, cardSize: CGSize(width: cardWidth, height: cardHeight))
        
        let result = try await service.detectCreditCard(in: image)
        XCTAssertNotNil(result, "Credit card should be detected")
        
        if let info = result {
            XCTAssertEqual(info.objectType, .creditCard)
            XCTAssertNotNil(info.pixelsPerMillimeter)
            
            // Expected ppmm = cardWidth / 85.6 ≈ 3.705
            let expectedPpmm = cardWidth / 85.6
            if let ppmm = info.pixelsPerMillimeter {
                XCTAssertEqual(Double(ppmm), Double(expectedPpmm), accuracy: 0.5)
            }
        }
    }
    
    func testDetectCreditCard_Portrait_CalculatesAccurateRatio() async throws {
        // Vertical credit card: 53.98mm width by 85.6mm height
        let imageSize = CGSize(width: 600, height: 800)
        let cardWidth: CGFloat = 200.0
        let cardHeight: CGFloat = 317.2
        
        let image = createCardImage(imageSize: imageSize, cardSize: CGSize(width: cardWidth, height: cardHeight))
        
        let result = try await service.detectCreditCard(in: image)
        XCTAssertNotNil(result, "Portrait credit card should be detected")
        
        if let info = result {
            XCTAssertEqual(info.objectType, .creditCard)
            // Long dimension (317.2) should align with 85.6mm
            let expectedPpmm = cardHeight / 85.6
            if let ppmm = info.pixelsPerMillimeter {
                XCTAssertEqual(Double(ppmm), Double(expectedPpmm), accuracy: 0.5)
            }
        }
    }
    
    // MARK: - US Quarter Detection Tests
    
    func testDetectUSQuarter_CircleDetected_CalculatesAccurateRatio() async throws {
        // Canvas: 600x600, Quarter: 120px diameter (~20% of min dimension)
        let imageSize = CGSize(width: 600, height: 600)
        let diameter: CGFloat = 120.0
        let image = createCircleImage(imageSize: imageSize, diameter: diameter)
        
        let result = try await service.detectUSQuarter(in: image)
        XCTAssertNotNil(result, "US Quarter circle should be detected")
        
        if let info = result {
            XCTAssertEqual(info.objectType, .usQuarter)
            XCTAssertNotNil(info.pixelsPerMillimeter)
            
            // Quarter is 24.26mm
            let expectedPpmm = diameter / 24.26
            if let ppmm = info.pixelsPerMillimeter {
                XCTAssertEqual(Double(ppmm), Double(expectedPpmm), accuracy: 1.0)
            }
        }
    }
    
    // MARK: - Negative & Edge Case Tests
    
    func testDetectReferenceScale_BlankImage_ReturnsNil() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let blankImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        
        let result = try await service.detectReferenceScale(in: blankImage)
        XCTAssertNil(result, "No reference scale should be found on a blank canvas")
    }
    
    func testDetectReferenceScale_EmptyImage_ReturnsNil() async throws {
        let emptyImage = UIImage()
        let result = try await service.detectReferenceScale(in: emptyImage)
        XCTAssertNil(result, "Empty UIImage has no cgImage, should return nil")
    }
    
    // MARK: - ReferenceScaleInfo Math & Calibration Conversion
    
    func testReferenceScaleInfo_PixelsPerMillimeter_MathCorrectness() {
        let info = ReferenceScaleInfo(
            objectType: .usQuarter,
            boundingBox: CGRect(x: 50, y: 50, width: 242.6, height: 242.6),
            pixelWidth: 242.6,
            pixelHeight: 242.6,
            confidence: 0.95,
            detectedDimensions: CGSize(width: 24.26, height: 24.26)
        )
        
        // 242.6 px / 24.26 mm = 10.0 px/mm
        XCTAssertNotNil(info.pixelsPerMillimeter)
        XCTAssertEqual(Double(info.pixelsPerMillimeter!), 10.0, accuracy: 0.001)
        
        // 10.0 px/mm * 10 = 100.0 px/cm
        XCTAssertNotNil(info.pixelsPerCentimeter)
        XCTAssertEqual(Double(info.pixelsPerCentimeter!), 100.0, accuracy: 0.001)
    }
    
    func testMeasurementCalibration_FromReferenceScale_Conversion() {
        let info = ReferenceScaleInfo(
            objectType: .creditCard,
            boundingBox: CGRect(x: 10, y: 10, width: 856.0, height: 539.8),
            pixelWidth: 856.0,
            pixelHeight: 539.8,
            confidence: 0.90,
            detectedDimensions: CGSize(width: 85.6, height: 53.98)
        )
        
        let calibration = MeasurementCalibration.fromReferenceScale(info)
        XCTAssertNotNil(calibration)
        XCTAssertEqual(calibration?.pixelsPerMillimeter ?? 0, 10.0, accuracy: 0.001)
        
        if case .referenceScale(let objType, let confidence) = calibration?.calibrationType {
            XCTAssertEqual(objType, .creditCard)
            XCTAssertEqual(confidence, 0.90, accuracy: 0.001)
        } else {
            XCTFail("Calibration type should be .referenceScale")
        }
    }
    
    // MARK: - Orientation & Geometry Regression Tests

    func testDetectUSQuarter_EXIFRotatedNonSquareImage_DetectsCircle() async throws {
        // Camera captures store sensor-oriented pixels plus an orientation tag. Detection
        // must not mix raw pixel dimensions with display-oriented Vision coordinates,
        // which would stretch the circle by 4:3 and fail the circularity check.
        let diameter: CGFloat = 120.0
        // Off-center in raw pixels so a wrong orientation mapping moves the reported box
        let raw = createCircleImage(imageSize: CGSize(width: 800, height: 600), diameter: diameter, center: CGPoint(x: 250, y: 200), scale: 1)
        let tagged = try XCTUnwrap(raw.cgImage.map { UIImage(cgImage: $0, scale: 1, orientation: .right) })
        XCTAssertEqual(tagged.size, CGSize(width: 600, height: 800))

        let result = try await service.detectUSQuarter(in: tagged)
        let info = try XCTUnwrap(result, "Quarter should be detected in an EXIF-rotated image")
        let ppmm = try XCTUnwrap(info.pixelsPerMillimeter)
        XCTAssertEqual(Double(ppmm), Double(diameter / 24.26), accuracy: 0.5)

        // .right displays raw (x, y) at (rawHeight - y, x): (250, 200) -> (400, 250),
        // reported in display (top-left origin) coordinates
        XCTAssertEqual(Double(info.boundingBox.midX), 400, accuracy: 15)
        XCTAssertEqual(Double(info.boundingBox.midY), 250, accuracy: 15)
    }

    func testDetectCreditCard_RotatedCard_UsesCornerDistances() async throws {
        // A card rotated 20° has a larger axis-aligned bounding box than its true size.
        let cardSize = CGSize(width: 317.2, height: 200.0)
        let image = createCardImage(imageSize: CGSize(width: 800, height: 800), cardSize: cardSize, rotation: .pi / 9, scale: 1)

        let result = try await service.detectCreditCard(in: image)
        let info = try XCTUnwrap(result, "Rotated credit card should be detected")
        let ppmm = try XCTUnwrap(info.pixelsPerMillimeter)

        // True scale is 317.2 / 85.6 ≈ 3.71 px/mm; the bounding box would give ≈ 4.28
        XCTAssertEqual(Double(ppmm), Double(cardSize.width / 85.6), accuracy: 0.15)
    }

    func testCalibrationAccuracy_AnatomicalReferencesAreLowAccuracy() {
        XCTAssertEqual(CalibrationType.referenceScale(objectType: .adultHallux, confidence: 0.85).accuracy, .low)
        XCTAssertEqual(CalibrationType.referenceScale(objectType: .adultForefoot, confidence: 0.85).accuracy, .low)
        XCTAssertEqual(CalibrationType.referenceScale(objectType: .creditCard, confidence: 0.9).accuracy, .medium)
        XCTAssertEqual(CalibrationType.referenceScale(objectType: .usQuarter, confidence: 0.9).accuracy, .medium)
    }

    // MARK: - Helpers

    private func createCardImage(imageSize: CGSize, cardSize: CGSize, rotation: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))

            let cg = ctx.cgContext
            cg.translateBy(x: imageSize.width / 2, y: imageSize.height / 2)
            cg.rotate(by: rotation)
            UIColor.black.setFill()
            cg.fill(CGRect(x: -cardSize.width / 2, y: -cardSize.height / 2, width: cardSize.width, height: cardSize.height))
        }
    }

    private func createCircleImage(imageSize: CGSize, diameter: CGFloat, center: CGPoint, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            UIColor.black.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
        }
    }

    private func createCardImage(imageSize: CGSize, cardSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            
            // Draw high-contrast black rectangle centered
            UIColor.black.setFill()
            let originX = (imageSize.width - cardSize.width) / 2.0
            let originY = (imageSize.height - cardSize.height) / 2.0
            ctx.fill(CGRect(x: originX, y: originY, width: cardSize.width, height: cardSize.height))
        }
    }
    
    private func createCircleImage(imageSize: CGSize, diameter: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
            
            // Draw high-contrast black circle centered
            UIColor.black.setFill()
            let originX = (imageSize.width - diameter) / 2.0
            let originY = (imageSize.height - diameter) / 2.0
            ctx.cgContext.fillEllipse(in: CGRect(x: originX, y: originY, width: diameter, height: diameter))
        }
    }
}
