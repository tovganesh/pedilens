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
    private let simplificationTolerance: CGFloat = 0.5  // Reduced from 2.0 for better detail
    
    // MARK: - Initialization
    
    init() {
        loadCoreMLModel()
    }
    
    /// Attempts to load the CoreML model from the app bundle
    private func loadCoreMLModel() {
        // Try to load WoundSegmentation.mlmodel from bundle
        guard let modelURL = Bundle.main.url(forResource: "WoundSegmentation", withExtension: "mlmodelc") else {
            print("⚠️ CoreML model not found in bundle. Using fallback detection.")
            print("   Searched for: WoundSegmentation.mlmodelc")
            print("   Bundle path: \(Bundle.main.bundlePath)")
            return
        }
        
        print("📦 Found CoreML model at: \(modelURL.path)")
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            self.visionModel = try VNCoreMLModel(for: mlModel)
            print("✅ CoreML wound detection model loaded successfully")
            print("   Model version: \(modelVersion)")
            print("   Model path: \(modelURL.lastPathComponent)")
        } catch {
            print("⚠️ Failed to load CoreML model: \(error.localizedDescription)")
            print("   Error details: \(error)")
            print("   Using fallback detection method")
        }
    }
    
    // MARK: - Public Methods
    
    func detectWoundBoundary(in image: UIImage, 
                            calibration: MeasurementCalibration?) async throws -> WoundBoundary {
        
        // Use CoreML model if available, otherwise fall back
        if isModelAvailable {
            print("🤖 Using CoreML model for wound detection")
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
        
        let maskHeight = segmentationMask.count
        let maskWidth = segmentationMask.isEmpty ? 0 : segmentationMask[0].count
        print("🔍 Segmentation mask size: \(maskWidth)x\(maskHeight)")
        
        // Extract contours from segmentation mask
        let contours = extractContours(from: segmentationMask)
        
        guard !contours.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        print("📍 Found \(contours.count) contour(s)")
        for (index, contour) in contours.enumerated() {
            print("   Contour \(index): \(contour.count) points")
        }
        
        // Select the largest contour as the wound boundary
        // (smaller contours are likely noise or artifacts)
        guard let largestContour = contours.max(by: { $0.count < $1.count }) else {
            throw WoundDetectionError.noContoursFound
        }
        
        print("🎯 Selected largest contour with \(largestContour.count) points")
        print("   Mask size: \(maskWidth)x\(maskHeight)")
        print("   Original image size: \(image.size)")
        
        // Simplify contour
        let simplifiedContour = douglasPeucker(points: largestContour, tolerance: simplificationTolerance)
        
        print("✂️ Simplified to \(simplifiedContour.count) points")
        
        // IMPORTANT: Scale points from mask coordinates (256x256) to original image size
        // The Vision framework resizes the image to the model's input size (256x256)
        let maskSize = CGSize(width: maskWidth, height: maskHeight)
        let scaledContour = scalePoints(
            simplifiedContour,
            from: maskSize,  // Scale from mask size (256x256)
            to: image.size   // To original image size
        )
        
        print("📏 Scaled contour from \(maskSize) to \(image.size):")
        if let first = scaledContour.first, let last = scaledContour.last {
            print("   First point: (\(first.x), \(first.y))")
            print("   Last point: (\(last.x), \(last.y))")
        }
        
        // Calculate confidence
        let confidence = calculateConfidence(for: scaledContour, imageSize: image.size)
        
        guard confidence >= minimumConfidence else {
            throw WoundDetectionError.lowConfidence
        }
        
        // Calculate bounding box
        let boundingBox = calculateBoundingBox(for: scaledContour)
        
        print("✅ CoreML detection complete:")
        print("   Points detected: \(scaledContour.count)")
        print("   Confidence: \(String(format: "%.2f", confidence * 100))%")
        print("   Bounding box: \(boundingBox)")
        
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
        
        print("🔮 Performing Vision CoreML request...")
        print("   Image size: \(cgImage.width)x\(cgImage.height)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    print("❌ Vision request error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                // Process results
                guard let results = request.results else {
                    print("❌ No results from Vision request")
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    return
                }
                
                print("📦 Received \(results.count) result(s) from Vision")
                
                // Log result types
                for (index, result) in results.enumerated() {
                    print("   Result \(index): \(type(of: result))")
                }
                
                // Extract segmentation mask from results
                if let pixelBufferObservation = results.first as? VNPixelBufferObservation {
                    print("✅ Processing VNPixelBufferObservation")
                    let mask = self.convertPixelBufferToMask(pixelBufferObservation.pixelBuffer)
                    continuation.resume(returning: mask)
                } else if let coreMLFeatureValue = results.first as? VNCoreMLFeatureValueObservation {
                    print("✅ Processing VNCoreMLFeatureValueObservation")
                    // Handle different output formats
                    if let multiArray = coreMLFeatureValue.featureValue.multiArrayValue {
                        print("   Found MultiArray output")
                        let mask = self.convertMultiArrayToMask(multiArray)
                        continuation.resume(returning: mask)
                    } else {
                        print("❌ No MultiArray in feature value")
                        continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    }
                } else {
                    print("❌ Unexpected result type: \(type(of: results.first))")
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                }
            }
            
            // Configure request
            request.imageCropAndScaleOption = .scaleFill
            print("   Crop/scale option: scaleFill")
            
            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("❌ Failed to perform Vision request: \(error.localizedDescription)")
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
        print("📊 MultiArray shape: \(shape)")
        
        // Handle different output shapes from CoreML model
        // Common shapes: [1, 256, 256, 1], [1, 1, 256, 256], [256, 256, 1]
        var height = 0
        var width = 0
        
        if shape.count == 4 {
            // [batch, height, width, channels] or [batch, channels, height, width]
            if shape[1] == 1 {
                // [1, 1, height, width] - channels first
                height = shape[2]
                width = shape[3]
            } else if shape[3] == 1 {
                // [1, height, width, 1] - channels last
                height = shape[1]
                width = shape[2]
            } else {
                // Assume [batch, channels, height, width]
                height = shape[2]
                width = shape[3]
            }
        } else if shape.count == 3 {
            // [batch, height, width] or [height, width, channels]
            if shape[0] == 1 {
                // [1, height, width]
                height = shape[1]
                width = shape[2]
            } else if shape[2] == 1 {
                // [height, width, 1]
                height = shape[0]
                width = shape[1]
            } else {
                // Assume [batch, height, width]
                height = shape[1]
                width = shape[2]
            }
        } else if shape.count == 2 {
            // [height, width]
            height = shape[0]
            width = shape[1]
        }
        
        print("📐 Interpreted dimensions: \(width)x\(height)")
        
        guard height > 0 && width > 0 else {
            print("⚠️ Invalid dimensions from MultiArray")
            return []
        }
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        var positiveCount = 0
        var minValue: Float = Float.infinity
        var maxValue: Float = -Float.infinity
        var sumValue: Float = 0
        
        // Extract values and apply threshold
        for y in 0..<height {
            for x in 0..<width {
                // Calculate index based on shape
                let index: Int
                if shape.count == 4 {
                    if shape[1] == 1 {
                        // [1, 1, height, width]
                        index = y * width + x
                    } else if shape[3] == 1 {
                        // [1, height, width, 1]
                        index = y * width + x
                    } else {
                        // [batch, channels, height, width]
                        index = y * width + x
                    }
                } else if shape.count == 3 {
                    if shape[0] == 1 {
                        // [1, height, width]
                        index = y * width + x
                    } else if shape[2] == 1 {
                        // [height, width, 1]
                        index = y * width + x
                    } else {
                        index = y * width + x
                    }
                } else {
                    // [height, width]
                    index = y * width + x
                }
                
                let value = multiArray[index].floatValue
                minValue = min(minValue, value)
                maxValue = max(maxValue, value)
                sumValue += value
                
                let isWound = value > 0.5 // Threshold for wound class
                mask[y][x] = isWound
                if isWound {
                    positiveCount += 1
                }
            }
        }
        
        let totalPixels = height * width
        let woundPercentage = Float(positiveCount) / Float(totalPixels) * 100.0
        let meanValue = sumValue / Float(totalPixels)
        
        print("📊 Value stats: min=\(String(format: "%.3f", minValue)), max=\(String(format: "%.3f", maxValue)), mean=\(String(format: "%.3f", meanValue))")
        print("🎯 Wound pixels: \(positiveCount)/\(totalPixels) (\(String(format: "%.1f", woundPercentage))%)")
        
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
    
    /// Extracts contours from a binary segmentation mask
    private func extractContours(from mask: [[Bool]]) -> [[CGPoint]] {
        guard !mask.isEmpty, !mask[0].isEmpty else {
            print("⚠️ Empty mask provided to extractContours")
            return []
        }
        
        let height = mask.count
        let width = mask[0].count
        print("🔍 Extracting contours from \(width)x\(height) mask")
        
        var contours: [[CGPoint]] = []
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        
        // Find contours using boundary tracing
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] && !visited[y][x] && isBoundaryPixel(x: x, y: y, mask: mask) {
                    let contour = traceContour(startX: x, startY: y, mask: mask, visited: &visited)
                    if contour.count >= 3 {
                        contours.append(contour)
                        print("   Found contour with \(contour.count) points")
                    }
                }
            }
        }
        
        print("✅ Extracted \(contours.count) contours")
        return contours
    }
    
    /// Checks if a pixel is on the boundary of a segmented region
    private func isBoundaryPixel(x: Int, y: Int, mask: [[Bool]]) -> Bool {
        let height = mask.count
        let width = mask[0].count
        
        // Check 8-connected neighbors
        let neighbors = [
            (x-1, y-1), (x, y-1), (x+1, y-1),
            (x-1, y),             (x+1, y),
            (x-1, y+1), (x, y+1), (x+1, y+1)
        ]
        
        for (nx, ny) in neighbors {
            if nx < 0 || nx >= width || ny < 0 || ny >= height {
                return true // Edge of image
            }
            if !mask[ny][nx] {
                return true // Adjacent to background
            }
        }
        
        return false
    }
    
    /// Traces a contour starting from a boundary pixel
    private func traceContour(startX: Int, startY: Int, mask: [[Bool]], visited: inout [[Bool]]) -> [CGPoint] {
        var contour: [CGPoint] = []
        var x = startX
        var y = startY
        
        // Simple contour tracing
        let maxPoints = 1000 // Prevent infinite loops
        var count = 0
        
        while count < maxPoints {
            if visited[y][x] {
                break
            }
            
            visited[y][x] = true
            contour.append(CGPoint(x: x, y: y))
            
            // Find next boundary pixel (8-connected)
            var found = false
            let directions = [
                (1, 0), (1, 1), (0, 1), (-1, 1),
                (-1, 0), (-1, -1), (0, -1), (1, -1)
            ]
            
            for (dx, dy) in directions {
                let nx = x + dx
                let ny = y + dy
                
                if nx >= 0 && nx < mask[0].count && ny >= 0 && ny < mask.count &&
                   mask[ny][nx] && !visited[ny][nx] && isBoundaryPixel(x: nx, y: ny, mask: mask) {
                    x = nx
                    y = ny
                    found = true
                    break
                }
            }
            
            if !found {
                break
            }
            
            count += 1
        }
        
        return contour
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
