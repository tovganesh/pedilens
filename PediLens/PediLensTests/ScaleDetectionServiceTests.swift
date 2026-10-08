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
    
    // MARK: - Helpers
    
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
