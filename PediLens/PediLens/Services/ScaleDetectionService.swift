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
        
        // Try different detection methods in order of reliability
        if let creditCard = try await detectCreditCard(in: image) {
            print("✅ Detected credit card")
            return creditCard
        }
        
        if let quarter = try await detectUSQuarter(in: image) {
            print("✅ Detected US quarter")
            return quarter
        }
        
        if let calibrationCard = try await detectCalibrationCard(in: image) {
            print("✅ Detected calibration card")
            return calibrationCard
        }
        
        print("ℹ️ No reference scale detected")
        return nil
    }
    
    // MARK: - Detection Methods
    
    /// Detects credit card in image
    private func detectCreditCard(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Use Vision framework to detect rectangles
        let rectangles = try await detectRectangles(in: cgImage)
        
        // Filter for credit card aspect ratio (85.6mm × 53.98mm = 1.586)
        let creditCardAspectRatio: CGFloat = 1.586
        let tolerance: CGFloat = 0.15
        
        for rect in rectangles {
            let aspectRatio = rect.boundingBox.width / rect.boundingBox.height
            
            if abs(aspectRatio - creditCardAspectRatio) / creditCardAspectRatio < tolerance {
                // Convert normalized coordinates to pixel coordinates
                let pixelBox = VNImageRectForNormalizedRect(
                    rect.boundingBox,
                    cgImage.width,
                    cgImage.height
                )
                
                return ReferenceScaleInfo(
                    objectType: .creditCard,
                    boundingBox: pixelBox,
                    pixelWidth: pixelBox.width,
                    pixelHeight: pixelBox.height,
                    confidence: rect.confidence,
                    detectedDimensions: CGSize(width: 85.6, height: 53.98)
                )
            }
        }
        
        return nil
    }
    
    /// Detects US quarter in image
    private func detectUSQuarter(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Use Vision framework to detect circles
        let circles = try await detectCircles(in: cgImage)
        
        // US quarter is 24.26mm diameter
        // Look for circles that are reasonable size relative to image
        for circle in circles {
            let diameter = circle.diameter
            let imageWidth = CGFloat(cgImage.width)
            
            // Quarter should be 5-30% of image width (reasonable range)
            let sizeRatio = diameter / imageWidth
            if sizeRatio > 0.05 && sizeRatio < 0.3 {
                return ReferenceScaleInfo(
                    objectType: .usQuarter,
                    boundingBox: circle.boundingBox,
                    pixelWidth: diameter,
                    pixelHeight: diameter,
                    confidence: circle.confidence,
                    detectedDimensions: CGSize(width: 24.26, height: 24.26)
                )
            }
        }
        
        return nil
    }
    
    /// Detects calibration card in image
    private func detectCalibrationCard(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Look for QR code or specific pattern on calibration card
        let barcodes = try await detectBarcodes(in: cgImage)
        
        for barcode in barcodes {
            // Check if barcode payload contains our identifier
            if let payloadString = barcode.payloadStringValue,
               payloadString.contains("PediLens") {
                // Found our calibration card
                let pixelBox = VNImageRectForNormalizedRect(
                    barcode.boundingBox,
                    cgImage.width,
                    cgImage.height
                )
                
                return ReferenceScaleInfo(
                    objectType: .calibrationCard,
                    boundingBox: pixelBox,
                    pixelWidth: pixelBox.width,
                    pixelHeight: pixelBox.height,
                    confidence: barcode.confidence,
                    detectedDimensions: CGSize(width: 100.0, height: 100.0)
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Vision Framework Helpers
    
    /// Detects rectangles in image
    private func detectRectangles(in cgImage: CGImage) async throws -> [VNRectangleObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let rectangles = request.results as? [VNRectangleObservation] ?? []
                continuation.resume(returning: rectangles)
            }
            
            request.minimumConfidence = minimumConfidence
            request.maximumObservations = 10
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Detects circles in image
    private func detectCircles(in cgImage: CGImage) async throws -> [CircleDetection] {
        // Vision doesn't have built-in circle detection, so we use contour detection
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectContoursRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNContoursObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var circles: [CircleDetection] = []
                
                for observation in results {
                    // Check if contour is circular
                    if let circle = self.isCircular(contour: observation) {
                        circles.append(circle)
                    }
                }
                
                continuation.resume(returning: circles)
            }
            
            request.contrastAdjustment = 1.5
            request.detectsDarkOnLight = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Detects barcodes/QR codes in image
    private func detectBarcodes(in cgImage: CGImage) async throws -> [VNBarcodeObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let barcodes = request.results as? [VNBarcodeObservation] ?? []
                continuation.resume(returning: barcodes)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Checks if a contour is circular
    private func isCircular(contour: VNContoursObservation) -> CircleDetection? {
        // Get the normalized path and calculate bounding box
        guard let normalizedPath = try? contour.normalizedPath else {
            return nil
        }
        
        let boundingBox = normalizedPath.boundingBox
        
        // Check aspect ratio (circle should be ~1:1)
        let aspectRatio = boundingBox.width / boundingBox.height
        if abs(aspectRatio - 1.0) > 0.2 {
            return nil // Not circular enough
        }
        
        // Calculate diameter (average of width and height)
        let diameter = (boundingBox.width + boundingBox.height) / 2.0
        
        return CircleDetection(
            boundingBox: boundingBox,
            diameter: diameter,
            confidence: contour.confidence
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
