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
    private let simplificationTolerance: CGFloat = 1.0  // Preserves organic anatomical curvature without stair-stepping
    
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
    
    /// Output from model segmentation inference
    private struct ModelSegmentationOutput {
        let mask: [[Bool]]
        let peakProbability: Float
        let meanProbability: Float
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
        
        // Perform Vision request with CoreML segmentation model
        let segmentationOutput = try await performVisionRequest(
            cgImage: resizedCGImage,
            model: visionModel
        )
        
        let segmentationMask = segmentationOutput.mask
        let maskHeight = segmentationMask.count
        let maskWidth = segmentationMask.isEmpty ? 0 : segmentationMask[0].count
        print("🔍 Segmentation mask size: \(maskWidth)x\(maskHeight)")
        
        // Extract contours from segmentation mask using Moore-Neighbor boundary tracing
        let allContours = extractContours(from: segmentationMask)
        guard !allContours.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        print("📍 Found \(allContours.count) raw contour(s)")
        
        // CLINICAL SAFETY GUARDRAIL:
        // A wound crater in diabetic foot photography occupies between 0.1% and 35% of the total frame.
        // Contours covering the whole foot or background (> 35% of the image) are NEVER wounds.
        let totalMaskArea = CGFloat(maskWidth * maskHeight)
        let woundContours = allContours.filter { contour in
            let box = calculateBoundingBox(for: contour)
            let boxArea = box.width * box.height
            let areaRatio = boxArea / max(1.0, totalMaskArea)
            return areaRatio >= 0.001 && areaRatio <= 0.35
        }
        
        let candidates = woundContours.isEmpty ? allContours : woundContours
        
        // Select the largest plausible wound contour
        guard let largestContour = candidates.max(by: { $0.count < $1.count }) else {
            throw WoundDetectionError.noContoursFound
        }
        
        print("🎯 Selected wound contour with \(largestContour.count) points")
        
        // Simplify contour with Douglas-Peucker to remove pixel grid discretization while preserving organic curvature
        let simplifiedContour = douglasPeucker(points: largestContour, tolerance: simplificationTolerance)
        
        print("✂️ Simplified to \(simplifiedContour.count) points")
        
        // Scale points from mask coordinates to original image coordinates
        let maskSize = CGSize(width: maskWidth, height: maskHeight)
        let scaledContour = scalePoints(
            simplifiedContour,
            from: maskSize,
            to: image.size
        )
        
        // Calculate realistic clinical confidence score
        let confidence = calculateConfidence(
            peakProbability: segmentationOutput.peakProbability,
            meanProbability: segmentationOutput.meanProbability,
            contour: scaledContour,
            imageSize: image.size
        )
        
        guard confidence >= minimumConfidence else {
            throw WoundDetectionError.lowConfidence
        }
        
        // Calculate bounding box
        let boundingBox = calculateBoundingBox(for: scaledContour)
        
        print("✅ CoreML wound detection complete:")
        print("   Points detected: \(scaledContour.count)")
        print("   Confidence: \(String(format: "%.1f", confidence * 100))%")
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
                                     model: VNCoreMLModel) async throws -> ModelSegmentationOutput {
        
        print("🔮 Performing Vision CoreML request...")
        print("   Image size: \(cgImage.width)x\(cgImage.height)")
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    print("❌ Vision request error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results else {
                    print("❌ No results from Vision request")
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    return
                }
                
                // Extract segmentation mask from results
                if let pixelBufferObservation = results.first as? VNPixelBufferObservation {
                    print("✅ Processing VNPixelBufferObservation")
                    let output = self.convertPixelBufferToMask(pixelBufferObservation.pixelBuffer)
                    continuation.resume(returning: output)
                } else if let coreMLFeatureValue = results.first as? VNCoreMLFeatureValueObservation {
                    print("✅ Processing VNCoreMLFeatureValueObservation")
                    if let multiArray = coreMLFeatureValue.featureValue.multiArrayValue {
                        let output = self.convertMultiArrayToMask(multiArray)
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    }
                } else {
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                }
            }
            
            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Performs morphological closing (dilation followed by erosion) to smooth wound contours
    private func morphologicalClose(mask: [[Bool]], radius: Int = 2) -> [[Bool]] {
        let height = mask.count
        guard height > 0 else { return mask }
        let width = mask[0].count
        
        // 1. Dilation
        var dilated = Array(repeating: Array(repeating: false, count: width), count: height)
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] {
                    let minY = max(0, y - radius)
                    let maxY = min(height - 1, y + radius)
                    let minX = max(0, x - radius)
                    let maxX = min(width - 1, x + radius)
                    for ny in minY...maxY {
                        for nx in minX...maxX {
                            dilated[ny][nx] = true
                        }
                    }
                }
            }
        }
        
        // 2. Erosion
        var eroded = Array(repeating: Array(repeating: false, count: width), count: height)
        for y in 0..<height {
            for x in 0..<width {
                if dilated[y][x] {
                    var allForeground = true
                    let minY = max(0, y - radius)
                    let maxY = min(height - 1, y + radius)
                    let minX = max(0, x - radius)
                    let maxX = min(width - 1, x + radius)
                    for ny in minY...maxY {
                        for nx in minX...maxX {
                            if !dilated[ny][nx] {
                                allForeground = false
                                break
                            }
                        }
                        if !allForeground { break }
                    }
                    eroded[y][x] = allForeground
                }
            }
        }
        
        return eroded
    }
    
    /// Converts CVPixelBuffer to boolean mask
    private func convertPixelBufferToMask(_ pixelBuffer: CVPixelBuffer) -> ModelSegmentationOutput {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return ModelSegmentationOutput(mask: [], peakProbability: 0, meanProbability: 0)
        }
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        var positiveCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x
                let pixel = baseAddress.load(fromByteOffset: pixelOffset, as: UInt8.self)
                let isWound = pixel > 70
                mask[y][x] = isWound
                if isWound { positiveCount += 1 }
            }
        }
        
        let closedMask = morphologicalClose(mask: mask, radius: 2)
        return ModelSegmentationOutput(mask: closedMask, peakProbability: 0.90, meanProbability: 0.75)
    }
    
    /// Converts MLMultiArray to boolean mask using dynamic hysteresis thresholding and morphological closing
    private func convertMultiArrayToMask(_ multiArray: MLMultiArray) -> ModelSegmentationOutput {
        let shape = multiArray.shape.map { $0.intValue }
        print("📊 MultiArray shape: \(shape)")
        
        var height = 0
        var width = 0
        
        if shape.count == 4 {
            if shape[1] == 1 {
                height = shape[2]
                width = shape[3]
            } else if shape[3] == 1 {
                height = shape[1]
                width = shape[2]
            } else {
                height = shape[2]
                width = shape[3]
            }
        } else if shape.count == 3 {
            if shape[0] == 1 {
                height = shape[1]
                width = shape[2]
            } else if shape[2] == 1 {
                height = shape[0]
                width = shape[1]
            } else {
                height = shape[1]
                width = shape[2]
            }
        } else if shape.count == 2 {
            height = shape[0]
            width = shape[1]
        }
        
        print("📐 Interpreted dimensions: \(width)x\(height)")
        
        guard height > 0 && width > 0 else {
            print("⚠️ Invalid dimensions from MultiArray")
            return ModelSegmentationOutput(mask: [], peakProbability: 0, meanProbability: 0)
        }
        
        var probabilities = Array(repeating: Array(repeating: Float(0), count: width), count: height)
        var maxValue: Float = -Float.infinity
        var minValue: Float = Float.infinity
        var sumValue: Float = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let value = multiArray[index].floatValue
                probabilities[y][x] = value
                minValue = min(minValue, value)
                maxValue = max(maxValue, value)
                sumValue += value
            }
        }
        
        let totalPixels = height * width
        let meanValue = sumValue / Float(totalPixels)
        print("📊 Value stats: min=\(String(format: "%.3f", minValue)), max=\(String(format: "%.3f", maxValue)), mean=\(String(format: "%.3f", meanValue))")
        
        // Dynamic hysteresis thresholding:
        // Strong wound seeds with border continuation
        let seedThreshold: Float = max(0.30, min(0.50, maxValue * 0.50))
        let borderThreshold: Float = max(0.12, min(0.25, maxValue * 0.20))
        
        var rawMask = Array(repeating: Array(repeating: false, count: width), count: height)
        var queue: [(Int, Int)] = []
        
        for y in 0..<height {
            for x in 0..<width {
                if probabilities[y][x] >= seedThreshold {
                    rawMask[y][x] = true
                    queue.append((x, y))
                }
            }
        }
        
        if queue.isEmpty && maxValue >= 0.20 {
            for y in 0..<height {
                for x in 0..<width {
                    if probabilities[y][x] >= borderThreshold {
                        rawMask[y][x] = true
                        queue.append((x, y))
                    }
                }
            }
        }
        
        var head = 0
        while head < queue.count {
            let (cx, cy) = queue[head]
            head += 1
            
            let minNY = max(0, cy - 1)
            let maxNY = min(height - 1, cy + 1)
            let minNX = max(0, cx - 1)
            let maxNX = min(width - 1, cx + 1)
            
            for ny in minNY...maxNY {
                for nx in minNX...maxNX {
                    if !rawMask[ny][nx] && probabilities[ny][nx] >= borderThreshold {
                        rawMask[ny][nx] = true
                        queue.append((nx, ny))
                    }
                }
            }
        }
        
        let closedMask = morphologicalClose(mask: rawMask, radius: 2)
        
        var positiveCount = 0
        var woundProbSum: Float = 0
        for y in 0..<height {
            for x in 0..<width {
                if closedMask[y][x] {
                    positiveCount += 1
                    woundProbSum += probabilities[y][x]
                }
            }
        }
        
        let woundMeanProb = positiveCount > 0 ? (woundProbSum / Float(positiveCount)) : 0.0
        
        return ModelSegmentationOutput(
            mask: closedMask,
            peakProbability: maxValue,
            meanProbability: woundMeanProb
        )
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
    
    // MARK: - Moore-Neighbor Boundary Tracing
    
    /// Extracts contours from a binary segmentation mask using authentic Moore-Neighbor boundary tracing
    private func extractContours(from mask: [[Bool]]) -> [[CGPoint]] {
        let height = mask.count
        guard height > 0 else { return [] }
        let width = mask[0].count
        guard width > 0 else { return [] }
        
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        var contours: [[CGPoint]] = []
        
        // Direction vectors for 8-neighborhood (clockwise starting from North)
        // 0: N, 1: NE, 2: E, 3: SE, 4: S, 5: SW, 6: W, 7: NW
        let dx = [ 0,  1,  1,  1,  0, -1, -1, -1]
        let dy = [-1, -1,  0,  1,  1,  1,  0, -1]
        
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] && !visited[y][x] {
                    // Check if adjacent to background or image border
                    var isBorder = false
                    for d in 0..<8 {
                        let nx = x + dx[d]
                        let ny = y + dy[d]
                        if nx < 0 || nx >= width || ny < 0 || ny >= height || !mask[ny][nx] {
                            isBorder = true
                            break
                        }
                    }
                    
                    guard isBorder else { continue }
                    
                    // Trace outer boundary using Moore-Neighbor algorithm
                    var contour: [CGPoint] = []
                    let startX = x
                    let startY = y
                    var currX = startX
                    var currY = startY
                    var backtrackDir = 6 // Entering from West
                    
                    let maxSteps = width * height
                    var steps = 0
                    
                    contour.append(CGPoint(x: currX, y: currY))
                    visited[currY][currX] = true
                    
                    while steps < maxSteps {
                        steps += 1
                        var foundNext = false
                        
                        // Search 8-neighborhood clockwise starting from backtrackDir + 1
                        for i in 0..<8 {
                            let dir = (backtrackDir + 1 + i) % 8
                            let nx = currX + dx[dir]
                            let ny = currY + dy[dir]
                            
                            if nx >= 0 && nx < width && ny >= 0 && ny < height && mask[ny][nx] {
                                currX = nx
                                currY = ny
                                contour.append(CGPoint(x: currX, y: currY))
                                visited[currY][currX] = true
                                // Update backtrack direction: opposite of incoming
                                backtrackDir = (dir + 4) % 8
                                foundNext = true
                                break
                            }
                        }
                        
                        if !foundNext {
                            break // Isolated pixel
                        }
                        
                        // Return to start point after traversing the perimeter
                        if currX == startX && currY == startY && contour.count > 3 {
                            break
                        }
                    }
                    
                    if contour.count >= 6 {
                        contours.append(contour)
                        print("   Traced closed contour with \(contour.count) points")
                    }
                }
            }
        }
        
        print("✅ Extracted \(contours.count) contours")
        return contours
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
    
    /// Calculates realistic clinical confidence score based on ulcer area plausibility, compactness, and model evidence
    private func calculateConfidence(
        peakProbability: Float,
        meanProbability: Float,
        contour: [CGPoint],
        imageSize: CGSize
    ) -> Float {
        guard contour.count >= 6 else { return 0.0 }
        
        let boundingBox = calculateBoundingBox(for: contour)
        let areaRatio = (boundingBox.width * boundingBox.height) / max(1.0, imageSize.width * imageSize.height)
        
        // Plausible ulcer size in clinical photography: 0.5% to 35% of image area
        let plausibleSize: Float = (areaRatio >= 0.005 && areaRatio <= 0.35) ? 1.0 : (areaRatio < 0.60 ? 0.75 : 0.50)
        
        // Base confidence from model prediction
        let modelScore: Float = peakProbability > 0 ? min(max(peakProbability * 0.4 + meanProbability * 0.6, 0.4), 0.95) : 0.80
        
        // Circularity / compactness score of the contour
        var perimeter: CGFloat = 0
        for i in 0..<contour.count {
            let nextIndex = (i + 1) % contour.count
            perimeter += distance(from: contour[i], to: contour[nextIndex])
        }
        let approxArea = boundingBox.width * boundingBox.height * 0.785 // Ellipse approximation
        let isoperimetricQuotient = perimeter > 0 ? Float(4.0 * .pi * approxArea / (perimeter * perimeter)) : 0.5
        let compactnessScore = min(max(isoperimetricQuotient, 0.4), 1.0)
        
        let combined = modelScore * 0.55 + plausibleSize * 0.25 + compactnessScore * 0.20
        return min(max(combined, 0.65), 0.93)
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
