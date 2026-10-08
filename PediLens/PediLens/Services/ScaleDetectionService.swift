//
//  ScaleDetectionService.swift
//  PediLens
//
//  Service for detecting reference scales and objects in images
//  for accurate measurement calibration
//

import Foundation
import UIKit
import Vision
import CoreImage
import ImageIO

// MARK: - Orientation Helper

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Service for detecting reference scales in images
class ScaleDetectionService {
    
    // MARK: - Properties
    
    /// Minimum confidence threshold for detection
    private let minimumConfidence: Float = 0.6
    
    // MARK: - Public Methods
    
    /// Detects reference scale or object in an image
    /// - Parameter image: Image to analyze
    /// - Returns: Reference scale information if detected
    func detectReferenceScale(in image: UIImage) async throws -> ReferenceScaleInfo? {
        print("🔍 Detecting reference scale in image...")
        
        // Try credit card detection
        do {
            if let creditCard = try await detectCreditCard(in: image) {
                print("✅ Detected credit card")
                return creditCard
            }
        } catch {
            print("⚠️ Credit card detection error: \(error.localizedDescription)")
        }
        
        // Try quarter detection
        do {
            if let quarter = try await detectUSQuarter(in: image) {
                print("✅ Detected US quarter")
                return quarter
            }
        } catch {
            print("⚠️ Quarter detection error: \(error.localizedDescription)")
        }
        
        // Try calibration card detection
        do {
            if let calibrationCard = try await detectCalibrationCard(in: image) {
                print("✅ Detected calibration card")
                return calibrationCard
            }
        } catch {
            print("⚠️ Calibration card detection error: \(error.localizedDescription)")
        }
        
        print("ℹ️ No reference scale detected")
        return nil
    }
    
    // MARK: - Detection Methods
    
    /// Detects credit card in image (standard dimensions: 85.6mm × 53.98mm)
    func detectCreditCard(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        // Use Vision framework to detect rectangles
        let rectangles = try await detectRectangles(in: cgImage, orientation: orientation)
        
        // Filter for credit card aspect ratio (85.6mm / 53.98mm ≈ 1.586)
        let creditCardAspectRatio: CGFloat = 85.6 / 53.98
        let tolerance: CGFloat = 0.18
        
        for rect in rectangles {
            // Convert normalized coordinates to pixel coordinates
            let pixelBox = VNImageRectForNormalizedRect(
                rect.boundingBox,
                Int(pixelWidth),
                Int(pixelHeight)
            )
            
            guard pixelBox.width > 0 && pixelBox.height > 0 else { continue }
            let aspectRatio = pixelBox.width / pixelBox.height
            
            let isLandscape = abs(aspectRatio - creditCardAspectRatio) / creditCardAspectRatio < tolerance
            let isPortrait = abs(aspectRatio - (1.0 / creditCardAspectRatio)) / (1.0 / creditCardAspectRatio) < tolerance
            
            if isLandscape || isPortrait {
                // Convert pixel box to point space matching image.size
                let scale = image.scale > 0 ? image.scale : 1.0
                let pointsBox = CGRect(
                    x: pixelBox.origin.x / scale,
                    y: pixelBox.origin.y / scale,
                    width: pixelBox.size.width / scale,
                    height: pixelBox.size.height / scale
                )
                
                // Align long dimension with knownDimensions.width (85.6mm)
                // and short dimension with knownDimensions.height (53.98mm)
                let longDimension = max(pointsBox.width, pointsBox.height)
                let shortDimension = min(pointsBox.width, pointsBox.height)
                
                return ReferenceScaleInfo(
                    objectType: .creditCard,
                    boundingBox: pointsBox,
                    pixelWidth: longDimension,
                    pixelHeight: shortDimension,
                    confidence: rect.confidence,
                    detectedDimensions: CGSize(width: 85.6, height: 53.98)
                )
            }
        }
        
        return nil
    }
    
    /// Detects US quarter in image (standard diameter: 24.26mm)
    func detectUSQuarter(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        
        // Use Vision framework to detect circles via contours
        let circles = try await detectCircles(in: cgImage, orientation: orientation, pixelSize: pixelSize)
        
        let minDimension = min(pixelWidth, pixelHeight)
        guard minDimension > 0 else { return nil }
        
        // Quarter should be 3% to 45% of image minimum dimension
        let quarterCandidates = circles.filter { circle in
            let sizeRatio = circle.diameter / minDimension
            return sizeRatio >= 0.03 && sizeRatio <= 0.45
        }
        
        // Select candidate with highest confidence
        guard let bestCircle = quarterCandidates.max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }
        
        let scale = image.scale > 0 ? image.scale : 1.0
        let pointsBox = CGRect(
            x: bestCircle.boundingBox.origin.x / scale,
            y: bestCircle.boundingBox.origin.y / scale,
            width: bestCircle.boundingBox.size.width / scale,
            height: bestCircle.boundingBox.size.height / scale
        )
        let diameterInPoints = bestCircle.diameter / scale
        
        return ReferenceScaleInfo(
            objectType: .usQuarter,
            boundingBox: pointsBox,
            pixelWidth: diameterInPoints,
            pixelHeight: diameterInPoints,
            confidence: bestCircle.confidence,
            detectedDimensions: CGSize(width: 24.26, height: 24.26)
        )
    }
    
    /// Detects calibration card in image
    func detectCalibrationCard(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        // Look for QR code or barcode on calibration card
        let barcodes = try await detectBarcodes(in: cgImage, orientation: orientation)
        
        for barcode in barcodes {
            if let payloadString = barcode.payloadStringValue,
               payloadString.contains("PediLens") {
                let pixelBox = VNImageRectForNormalizedRect(
                    barcode.boundingBox,
                    Int(pixelWidth),
                    Int(pixelHeight)
                )
                
                let scale = image.scale > 0 ? image.scale : 1.0
                let pointsBox = CGRect(
                    x: pixelBox.origin.x / scale,
                    y: pixelBox.origin.y / scale,
                    width: pixelBox.size.width / scale,
                    height: pixelBox.size.height / scale
                )
                
                return ReferenceScaleInfo(
                    objectType: .calibrationCard,
                    boundingBox: pointsBox,
                    pixelWidth: pointsBox.width,
                    pixelHeight: pointsBox.height,
                    confidence: barcode.confidence,
                    detectedDimensions: CGSize(width: 100.0, height: 100.0)
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Vision Framework Helpers
    
    /// Detects rectangles in image
    private func detectRectangles(in cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> [VNRectangleObservation] {
        let minConf = self.minimumConfidence
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectRectanglesRequest()
            request.minimumConfidence = minConf
            request.maximumObservations = 10
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            return (request.results as? [VNRectangleObservation]) ?? []
        }.value
    }
    
    /// Detects circles in image
    private func detectCircles(in cgImage: CGImage, orientation: CGImagePropertyOrientation, pixelSize: CGSize) async throws -> [CircleDetection] {
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectContoursRequest()
            request.contrastAdjustment = 1.5
            request.detectsDarkOnLight = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            
            guard let results = request.results as? [VNContoursObservation] else {
                return []
            }
            
            var circles: [CircleDetection] = []
            for observation in results {
                for index in 0..<observation.contourCount {
                    guard let contour = try? observation.contour(at: index) else { continue }
                    if let circle = Self.isCircular(contour: contour, pixelSize: pixelSize, baseConfidence: observation.confidence) {
                        circles.append(circle)
                    }
                }
            }
            return circles
        }.value
    }
    
    /// Detects barcodes/QR codes in image
    private func detectBarcodes(in cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> [VNBarcodeObservation] {
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            return (request.results as? [VNBarcodeObservation]) ?? []
        }.value
    }
    
    /// Checks if a contour is circular in pixel coordinates
    private static func isCircular(contour: VNContour, pixelSize: CGSize, baseConfidence: Float) -> CircleDetection? {
        // Need at least 8 points to form a polygon approximation of a circle
        guard contour.pointCount >= 8 else { return nil }
        
        let pixelBox = VNImageRectForNormalizedRect(
            contour.normalizedPath.boundingBox,
            Int(pixelSize.width),
            Int(pixelSize.height)
        )
        
        guard pixelBox.width > 0 && pixelBox.height > 0 else { return nil }
        
        // Aspect ratio in true pixel coordinates
        let aspectRatio = pixelBox.width / pixelBox.height
        guard abs(aspectRatio - 1.0) <= 0.25 else {
            return nil
        }
        
        // Minimum diameter threshold (in pixels)
        let diameter = (pixelBox.width + pixelBox.height) / 2.0
        guard diameter >= 15.0 else {
            return nil
        }
        
        let circularityScore = Float(max(0.0, 1.0 - Double(abs(aspectRatio - 1.0)) * 4.0))
        let confidence = baseConfidence * circularityScore
        
        return CircleDetection(
            boundingBox: pixelBox,
            diameter: diameter,
            confidence: confidence
        )
    }
}

// MARK: - Helper Structures

/// Information about detected circle
struct CircleDetection {
    let boundingBox: CGRect
    let diameter: CGFloat
    let confidence: Float
}
