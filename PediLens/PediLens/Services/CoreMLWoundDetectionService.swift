//
//  CoreMLWoundDetectionService.swift
//  PediLens
//
//  Enhanced wound detection service using trained CoreML model
//  Falls back to mock detection if model is not available
//

import Foundation
import UIKit
import Vision
import CoreML
import CoreGraphics

/// Enhanced wound detection service that uses CoreML model when available
class CoreMLWoundDetectionService: WoundDetectionServiceProtocol {
    
    // MARK: - Properties
    
    /// CoreML model for wound segmentation
    private var visionModel: VNCoreMLModel?
    
    /// Whether a trained model is available
    private var isModelAvailable: Bool {
        return visionModel != nil
    }
    
    /// Fallback service for when model is not available
    private let fallbackService = WoundDetectionService()
    
    /// Model version identifier
    private let modelVersion = "1.0"
    
    /// Minimum confidence threshold
    private let minimumConfidence: Float = 0.3
    
    /// Simplification tolerance for Douglas-Peucker algorithm
    private let simplificationTolerance: CGFloat = 2.0
    
    // MARK: - Initialization
    
    init() {
        loadCoreMLModel()
    }
    
    /// Attempts to load the CoreML model from the app bundle
    private func loadCoreMLModel() {
        // Try to load WoundSegmentation.mlmodel from bundle
        guard let modelURL = Bundle.main.url(forResource: "WoundSegmentation", withExtension: "mlmodelc") else {
            print("⚠️ CoreML model not found in bundle. Using fallback detection.")
            return
        }
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            self.visionModel = try VNCoreMLModel(for: mlModel)
            print("✅ CoreML wound detection model loaded successfully")
        } catch {
            print("⚠️ Failed to load CoreML model: \(error.localizedDescription)")
            print("   Using fallback detection method")
        }
    }
    
    // MARK: - Public Methods
    
    func detectWoundBoundary(in image: UIImage, 
                            calibration: MeasurementCalibration?) async throws -> WoundBoundary {
        
        // Use CoreML model if available, otherwise fall back
        if isModelAvailable {
            return try await detectWithCoreML(image: image, calibration: calibration)
        } else {
            print("ℹ️ Using fallback detection (no CoreML model)")
            return try await fallbackService.detectWoundBoundary(in: image, calibration: calibration)
        }
    }
    
    func refineDetection(_ boundary: WoundBoundary, 
                        with userAdjustments: [CGPoint]) -> WoundBoundary {
        return fallbackService.refineDetection(boundary, with: userAdjustments)
    }
    
    // MARK: - CoreML Detection
    
    /// Performs wound detection using the CoreML model
    private func detectWithCoreML(image: UIImage, 
                                 calibration: MeasurementCalibration?) async throws -> WoundBoundary {
        
        guard let visionModel = visionModel else {
            throw WoundDetectionError.modelLoadFailed
        }
        
        guard let cgImage = image.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        // Resize image for model inference
        let resizedImage = await PerformanceOptimizer.shared.resizeImageForMLInference(image)
        guard let resizedCGImage = resizedImage.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        // Perform Vision request
        let segmentationMask = try await performVisionRequest(
            cgImage: resizedCGImage,
            model: visionModel
        )
        
        // Extract contours from segmentation mask
        let contours = extractContours(from: segmentationMask)
        
        guard !contours.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        // Select largest contour as wound boundary
        let largestContour = contours.max(by: { $0.count < $1.count }) ?? []
        
        // Simplify contour
        let simplifiedContour = douglasPeucker(points: largestContour, tolerance: simplificationTolerance)
        
        // Scale points back to original image size
        let scaledContour = scalePoints(
            simplifiedContour,
            from: resizedImage.size,
            to: image.size
        )
        
        // Calculate confidence
        let confidence = calculateConfidence(for: scaledContour, imageSize: image.size)
        
        guard confidence >= minimumConfidence else {
            throw WoundDetectionError.lowConfidence
        }
        
        // Calculate bounding box
        let boundingBox = calculateBoundingBox(for: scaledContour)
        
        return WoundBoundary(
            points: scaledContour,
            confidence: confidence,
            boundingBox: boundingBox,
            detectionMethod: .automatic(modelVersion: modelVersion)
        )
    }
    
    /// Performs Vision CoreML request
    private func performVisionRequest(cgImage: CGImage, 
                                     model: VNCoreMLModel) async throws -> [[Bool]] {
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Process results
                guard let results = request.results else {
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    return
                }
                
                // Extract segmentation mask from results
                if let pixelBufferObservation = results.first as? VNPixelBufferObservation {
                    let mask = self.convertPixelBufferToMask(pixelBufferObservation.pixelBuffer)
                    continuation.resume(returning: mask)
                } else if let coreMLFeatureValue = results.first as? VNCoreMLFeatureValueObservation {
                    // Handle different output formats
                    if let multiArray = coreMLFeatureValue.featureValue.multiArrayValue {
                        let mask = self.convertMultiArrayToMask(multiArray)
                        continuation.resume(returning: mask)
                    } else {
                        continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    }
                } else {
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                }
            }
            
            // Configure request
            request.imageCropAndScaleOption = .scaleFill
            
            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Converts CVPixelBuffer to boolean mask
    private func convertPixelBufferToMask(_ pixelBuffer: CVPixelBuffer) -> [[Bool]] {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return []
        }
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x
                let pixel = baseAddress.load(fromByteOffset: pixelOffset, as: UInt8.self)
                mask[y][x] = pixel > 128 // Threshold for wound class
            }
        }
        
        return mask
    }
    
    /// Converts MLMultiArray to boolean mask
    private func convertMultiArrayToMask(_ multiArray: MLMultiArray) -> [[Bool]] {
        let shape = multiArray.shape.map { $0.intValue }
        
        // Assuming shape is [1, height, width] or [height, width, 1]
        let height = shape.count >= 2 ? shape[shape.count - 2] : 0
        let width = shape.count >= 1 ? shape[shape.count - 1] : 0
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let value = multiArray[index].floatValue
                mask[y][x] = value > 0.5 // Threshold for wound class
            }
        }
        
        return mask
    }
    
    /// Scales points from one image size to another
    private func scalePoints(_ points: [CGPoint], from sourceSize: CGSize, to targetSize: CGSize) -> [CGPoint] {
        guard sourceSize != targetSize else { return points }
        
        let scaleX = targetSize.width / sourceSize.width
        let scaleY = targetSize.height / sourceSize.height
        
        return points.map { point in
            CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
    }
    
    // MARK: - Helper Methods (reused from WoundDetectionService)
    
    private func extractContours(from mask: [[Bool]]) -> [[CGPoint]] {
        return fallbackService.extractContours(from: mask)
    }
    
    private func douglasPeucker(points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        let firstPoint = points.first!
        let lastPoint = points.last!
        
        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(point: points[i], lineStart: firstPoint, lineEnd: lastPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        if maxDistance > tolerance {
            let leftSegment = douglasPeucker(points: Array(points[0...maxIndex]), tolerance: tolerance)
            let rightSegment = douglasPeucker(points: Array(points[maxIndex..<points.count]), tolerance: tolerance)
            return leftSegment + rightSegment.dropFirst()
        } else {
            return [firstPoint, lastPoint]
        }
    }
    
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            return distance(from: point, to: lineStart)
        }
        
        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        let denominator = sqrt(dx * dx + dy * dy)
        
        return numerator / denominator
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateConfidence(for contour: [CGPoint], imageSize: CGSize) -> Float {
        guard contour.count >= 3 else { return 0.0 }
        
        let pointCountScore = min(Float(contour.count) / 100.0, 1.0)
        
        var segmentLengths: [CGFloat] = []
        for i in 0..<contour.count {
            let nextIndex = (i + 1) % contour.count
            let length = distance(from: contour[i], to: contour[nextIndex])
            segmentLengths.append(length)
        }
        
        let avgLength = segmentLengths.reduce(0, +) / CGFloat(segmentLengths.count)
        let variance = segmentLengths.map { pow($0 - avgLength, 2) }.reduce(0, +) / CGFloat(segmentLengths.count)
        let smoothnessScore = Float(1.0 / (1.0 + variance / 100.0))
        
        let boundingBox = calculateBoundingBox(for: contour)
        let areaRatio = (boundingBox.width * boundingBox.height) / (imageSize.width * imageSize.height)
        let sizeScore = Float(areaRatio > 0.01 && areaRatio < 0.5 ? 1.0 : 0.5)
        
        let confidence = (pointCountScore * 0.3 + smoothnessScore * 0.4 + sizeScore * 0.3)
        
        return min(max(confidence, 0.0), 1.0)
    }
    
    private func calculateBoundingBox(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y
        
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        let epsilon: CGFloat = 0.001
        
        return CGRect(
            x: minX,
            y: minY,
            width: (maxX - minX) + epsilon,
            height: (maxY - minY) + epsilon
        )
    }
}

// MARK: - Extension to make methods accessible

extension WoundDetectionService {
    func extractContours(from mask: [[Bool]]) -> [[CGPoint]] {
        guard !mask.isEmpty, !mask[0].isEmpty else { return [] }
        
        let height = mask.count
        let width = mask[0].count
        
        var contours: [[CGPoint]] = []
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] && !visited[y][x] && isBoundaryPixel(x: x, y: y, mask: mask) {
                    let contour = traceContour(startX: x, startY: y, mask: mask, visited: &visited)
                    if contour.count >= 3 {
                        contours.append(contour)
                    }
                }
            }
        }
        
        return contours
    }
}
