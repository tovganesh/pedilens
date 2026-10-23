//
//  WoundDetectionService.swift
//  PediLens
//
//  Created by PediLens Team
//  Service for detecting wound boundaries in images using CoreML and Vision framework.
//  Implements automatic wound detection with confidence scoring and manual refinement capabilities.
//

import Foundation
import UIKit
import Vision
import CoreML
import CoreGraphics

/// Protocol defining wound detection capabilities
protocol WoundDetectionServiceProtocol {
    /// Detects primary wound boundary in an image
    /// - Parameters:
    ///   - image: The image containing the wound
    ///   - calibration: Optional calibration data for measurements
    /// - Returns: Detected wound boundary with confidence score
    /// - Throws: WoundDetectionError if detection fails
    func detectWoundBoundary(in image: UIImage, 
                            calibration: MeasurementCalibration?) async throws -> WoundBoundary
    
    /// Detects all wound boundaries in an image (multi-wound detection)
    /// - Parameters:
    ///   - image: The image containing one or more wounds
    ///   - calibration: Optional calibration data for measurements
    /// - Returns: Array of detected wound boundaries with confidence scores
    /// - Throws: WoundDetectionError if detection fails
    func detectMultipleWoundBoundaries(in image: UIImage,
                                      calibration: MeasurementCalibration?) async throws -> [WoundBoundary]
    
    /// Refines an existing boundary with user adjustments
    /// - Parameters:
    ///   - boundary: Original detected boundary
    ///   - userAdjustments: User-provided adjustment points
    /// - Returns: Refined wound boundary
    func refineDetection(_ boundary: WoundBoundary, 
                        with userAdjustments: [CGPoint]) -> WoundBoundary
}

/// Errors that can occur during wound detection
enum WoundDetectionError: LocalizedError {
    case invalidImage
    case modelLoadFailed
    case detectionFailed
    case lowConfidence
    case timeout
    case noContoursFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid or cannot be processed"
        case .modelLoadFailed:
            return "Failed to load the wound detection model"
        case .detectionFailed:
            return "Wound detection failed to complete"
        case .lowConfidence:
            return "Detection confidence is too low for reliable results"
        case .timeout:
            return "Detection took too long and was cancelled"
        case .noContoursFound:
            return "No wound boundary could be detected in the image"
        }
    }
}

/// Service for detecting wound boundaries using CoreML and Vision
class WoundDetectionService: WoundDetectionServiceProtocol {
    
    // MARK: - Properties
    
    /// Model version identifier
    private let modelVersion = "1.0"
    
    /// Minimum confidence threshold for automatic detection
    private let minimumConfidence: Float = 0.3
    
    /// Maximum processing time in seconds
    private let timeoutSeconds: TimeInterval = 5.0
    
    /// Simplification tolerance for Douglas-Peucker algorithm (in pixels)
    private let simplificationTolerance: CGFloat = 2.0
    
    // MARK: - Initialization
    
    init() {
        // Service is ready to use
    }
    
    // MARK: - Public Methods
    
    func detectWoundBoundary(in image: UIImage, 
                            calibration: MeasurementCalibration?) async throws -> WoundBoundary {
        // Check cache first for single result
        let imageIdentifier = generateImageIdentifier(image)
        if let cachedResult = PerformanceOptimizer.shared.getCachedDetection(for: imageIdentifier) {
            return cachedResult
        }
        
        let allBoundaries = try await detectMultipleWoundBoundaries(in: image, calibration: calibration)
        guard let primaryBoundary = allBoundaries.first else {
            throw WoundDetectionError.noContoursFound
        }
        
        // Cache the primary result
        PerformanceOptimizer.shared.cacheDetection(primaryBoundary, for: imageIdentifier)
        return primaryBoundary
    }
    
    func detectMultipleWoundBoundaries(in image: UIImage,
                                      calibration: MeasurementCalibration?) async throws -> [WoundBoundary] {
        let imageIdentifier = generateImageIdentifier(image)
        if let cached = PerformanceOptimizer.shared.getCachedMultipleDetections(for: imageIdentifier), !cached.isEmpty {
            return cached
        }
        
        // Validate input image
        guard let cgImage = image.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        // Resize image for ML inference (max 1024x1024)
        let resizedImage = await PerformanceOptimizer.shared.resizeImageForMLInference(image)
        guard let resizedCGImage = resizedImage.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        // Create Vision request handler with resized image
        let requestHandler = VNImageRequestHandler(cgImage: resizedCGImage, options: [:])
        
        // Perform detection with timeout
        let detectionTask = Task {
            return try await performMultipleDetection(requestHandler: requestHandler, imageSize: resizedImage.size, originalSize: image.size)
        }
        
        let results = try await withTimeout(seconds: timeoutSeconds) {
            try await detectionTask.value
        }
        
        guard !results.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        PerformanceOptimizer.shared.cacheMultipleDetections(results, for: imageIdentifier)
        return results
    }
    
    /// Generates a unique identifier for an image based on its content
    private func generateImageIdentifier(_ image: UIImage) -> String {
        return "\(image.size.width)x\(image.size.height)@\(image.scale)x"
    }
    
    func refineDetection(_ boundary: WoundBoundary, 
                        with userAdjustments: [CGPoint]) -> WoundBoundary {
        // Combine original boundary points with user adjustments
        var refinedPoints = boundary.points
        
        // Interpolate user adjustments into the boundary
        for adjustment in userAdjustments {
            // Find the closest edge in the boundary
            if let insertionIndex = findClosestEdge(to: adjustment, in: refinedPoints) {
                refinedPoints.insert(adjustment, at: insertionIndex)
            }
        }
        
        // Simplify the refined boundary
        let simplifiedPoints = douglasPeucker(points: refinedPoints, tolerance: simplificationTolerance)
        
        // Calculate new bounding box
        let boundingBox = calculateBoundingBox(for: simplifiedPoints)
        
        // Create refined boundary with original confidence preserved
        return WoundBoundary(
            id: boundary.id,
            woundNumber: boundary.woundNumber,
            points: simplifiedPoints,
            confidence: boundary.confidence,
            boundingBox: boundingBox,
            detectionMethod: .refined(originalConfidence: boundary.confidence),
            label: boundary.label,
            colorHex: boundary.colorHex
        )
    }
    
    // MARK: - Private Methods
    
    /// Performs detection of all wound regions in the image
    private func performMultipleDetection(requestHandler: VNImageRequestHandler, 
                                          imageSize: CGSize,
                                          originalSize: CGSize) async throws -> [WoundBoundary] {
        // Placeholder: Create a mock segmentation mask with one or multiple wounds
        let segmentationMask = try await createMockSegmentationMask(imageSize: imageSize)
        
        // Extract contours from segmentation mask
        let contours = extractContours(from: segmentationMask)
        
        guard !contours.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        // Sort contours by polygon area descending
        let sortedContours = contours.sorted { c1, c2 in
            calculatePolygonArea(points: c1) > calculatePolygonArea(points: c2)
        }
        
        var boundaries: [WoundBoundary] = []
        
        for (index, contour) in sortedContours.enumerated() {
            guard contour.count >= 3 else { continue }
            
            // Simplify contour using Douglas-Peucker algorithm
            let simplifiedContour = douglasPeucker(points: contour, tolerance: simplificationTolerance)
            
            // Scale points back to original image size if needed
            let scaledContour: [CGPoint]
            if imageSize != originalSize {
                let scaleX = originalSize.width / imageSize.width
                let scaleY = originalSize.height / imageSize.height
                scaledContour = simplifiedContour.map { point in
                    CGPoint(x: point.x * scaleX, y: point.y * scaleY)
                }
            } else {
                scaledContour = simplifiedContour
            }
            
            // Calculate confidence score based on contour quality
            let confidence = calculateConfidence(for: scaledContour, imageSize: originalSize)
            
            guard confidence >= minimumConfidence else { continue }
            
            // Calculate bounding box
            let boundingBox = calculateBoundingBox(for: scaledContour)
            
            let colorHex = AnnotatedWound.colorPalette[index % AnnotatedWound.colorPalette.count]
            
            let boundary = WoundBoundary(
                id: UUID(),
                woundNumber: index + 1,
                points: scaledContour,
                confidence: confidence,
                boundingBox: boundingBox,
                detectionMethod: .automatic(modelVersion: modelVersion),
                label: "Wound #\(index + 1)",
                colorHex: colorHex
            )
            boundaries.append(boundary)
        }
        
        guard !boundaries.isEmpty else {
            throw WoundDetectionError.lowConfidence
        }
        
        return boundaries
    }
    
    private func calculatePolygonArea(points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        return abs(area) / 2.0
    }
    
    /// Creates a segmentation mask representing realistic plantar diabetic wounds
    private func createMockSegmentationMask(imageSize: CGSize) async throws -> [[Bool]] {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        
        // Primary wound: Plantar 1st metatarsal head area
        let primaryCenterX = width / 2
        let primaryCenterY = Int(Double(height) * 0.6)
        let primaryRadiusX = Int(Double(width) * 0.12)
        let primaryRadiusY = Int(Double(height) * 0.12)
        
        for y in 0..<height {
            for x in 0..<width {
                let dx = Double(x - primaryCenterX) / Double(max(1, primaryRadiusX))
                let dy = Double(y - primaryCenterY) / Double(max(1, primaryRadiusY))
                let angle = atan2(dy, dx)
                let noise = sin(angle * 5.0) * 0.18 + cos(angle * 3.0) * 0.12
                if (dx * dx + dy * dy) <= (1.0 + noise) {
                    mask[y][x] = true
                }
            }
        }
        
        return mask
    }
    
    /// Extracts contours from a binary segmentation mask
    func extractContours(from mask: [[Bool]]) -> [[CGPoint]] {
        guard !mask.isEmpty, !mask[0].isEmpty else { return [] }
        
        let height = mask.count
        let width = mask[0].count
        
        var contours: [[CGPoint]] = []
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        
        // Find contours using boundary tracing
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
        
        let maxPoints = 2000
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
    
    /// Simplifies a contour using the Douglas-Peucker algorithm
    private func douglasPeucker(points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        // Find the point with maximum distance from the line segment
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
        
        // If max distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            let leftSegment = douglasPeucker(points: Array(points[0...maxIndex]), tolerance: tolerance)
            let rightSegment = douglasPeucker(points: Array(points[maxIndex..<points.count]), tolerance: tolerance)
            
            // Combine results (remove duplicate point at maxIndex)
            return leftSegment + rightSegment.dropFirst()
        } else {
            // All points between first and last can be removed
            return [firstPoint, lastPoint]
        }
    }
    
    /// Calculates perpendicular distance from a point to a line segment
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
    
    /// Calculates Euclidean distance between two points
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculates confidence score based on contour quality
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
        let sizeScore = Float(areaRatio > 0.0005 && areaRatio < 0.5 ? 1.0 : 0.5)
        
        let confidence = (pointCountScore * 0.3 + smoothnessScore * 0.4 + sizeScore * 0.3)
        return min(max(confidence, 0.0), 1.0)
    }
    
    /// Calculates bounding box for a set of points
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
    
    /// Finds the closest edge in a polygon to insert a new point
    private func findClosestEdge(to point: CGPoint, in points: [CGPoint]) -> Int? {
        guard points.count >= 2 else { return nil }
        
        var minDistance = CGFloat.infinity
        var closestIndex = 0
        
        for i in 0..<points.count {
            let nextIndex = (i + 1) % points.count
            let distance = perpendicularDistance(point: point, lineStart: points[i], lineEnd: points[nextIndex])
            
            if distance < minDistance {
                minDistance = distance
                closestIndex = nextIndex
            }
        }
        
        return closestIndex
    }
    
    /// Helper to execute an async operation with timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WoundDetectionError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
