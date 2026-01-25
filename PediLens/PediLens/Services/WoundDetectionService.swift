//
//  WoundDetectionService.swift
//  PediLens
//
//  Created by PediLens Team
//
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
    /// Detects wound boundary in an image
    /// - Parameters:
    ///   - image: The image containing the wound
    ///   - calibration: Optional calibration data for measurements
    /// - Returns: Detected wound boundary with confidence score
    /// - Throws: WoundDetectionError if detection fails
    func detectWoundBoundary(in image: UIImage, 
                            calibration: MeasurementCalibration?) async throws -> WoundBoundary
    
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
        // Validate input image
        guard let cgImage = image.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        // Create Vision request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // For now, we'll use a placeholder segmentation approach since we don't have a trained model
        // In production, this would load a CoreML model trained for wound segmentation
        // let model = try loadCoreMLModel()
        // let visionModel = try VNCoreMLModel(for: model)
        
        // Perform detection with timeout
        let detectionTask = Task {
            return try await performDetection(requestHandler: requestHandler, imageSize: image.size)
        }
        
        // Wait for detection with timeout
        let result = try await withTimeout(seconds: timeoutSeconds) {
            try await detectionTask.value
        }
        
        return result
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
            points: simplifiedPoints,
            confidence: boundary.confidence,
            boundingBox: boundingBox,
            detectionMethod: .refined(originalConfidence: boundary.confidence)
        )
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual wound detection
    private func performDetection(requestHandler: VNImageRequestHandler, 
                                 imageSize: CGSize) async throws -> WoundBoundary {
        // NOTE: In a production app, this would use a trained CoreML model for semantic segmentation
        // For now, we'll create a placeholder implementation that demonstrates the structure
        
        // In production, you would:
        // 1. Load the CoreML model
        // 2. Create a VNCoreMLRequest
        // 3. Process the image through the model
        // 4. Extract the segmentation mask
        // 5. Find contours in the mask
        // 6. Simplify contours using Douglas-Peucker
        
        // Placeholder: Create a mock segmentation mask
        let segmentationMask = try await createMockSegmentationMask(imageSize: imageSize)
        
        // Extract contours from segmentation mask
        let contours = extractContours(from: segmentationMask)
        
        guard !contours.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        // Select the largest contour as the wound boundary
        let largestContour = contours.max(by: { $0.count < $1.count }) ?? []
        
        // Simplify contour using Douglas-Peucker algorithm
        let simplifiedContour = douglasPeucker(points: largestContour, tolerance: simplificationTolerance)
        
        // Calculate confidence score based on contour quality
        let confidence = calculateConfidence(for: simplifiedContour, imageSize: imageSize)
        
        // Check if confidence meets minimum threshold
        guard confidence >= minimumConfidence else {
            throw WoundDetectionError.lowConfidence
        }
        
        // Calculate bounding box
        let boundingBox = calculateBoundingBox(for: simplifiedContour)
        
        return WoundBoundary(
            points: simplifiedContour,
            confidence: confidence,
            boundingBox: boundingBox,
            detectionMethod: .automatic(modelVersion: modelVersion)
        )
    }
    
    /// Creates a mock segmentation mask for demonstration
    /// In production, this would come from the CoreML model output
    private func createMockSegmentationMask(imageSize: CGSize) async throws -> [[Bool]] {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        
        // Create a mock elliptical wound in the center of the image
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        
        let centerX = width / 2
        let centerY = height / 2
        let radiusX = width / 4
        let radiusY = height / 6
        
        for y in 0..<height {
            for x in 0..<width {
                let dx = Double(x - centerX) / Double(radiusX)
                let dy = Double(y - centerY) / Double(radiusY)
                if (dx * dx + dy * dy) <= 1.0 {
                    mask[y][x] = true
                }
            }
        }
        
        return mask
    }
    
    /// Extracts contours from a binary segmentation mask
    private func extractContours(from mask: [[Bool]]) -> [[CGPoint]] {
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
        
        // Simple contour tracing - in production, use Moore-Neighbor or similar algorithm
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
        
        // Handle degenerate case where line segment is a point
        if dx == 0 && dy == 0 {
            return distance(from: point, to: lineStart)
        }
        
        // Calculate perpendicular distance using cross product
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
        
        // Factors that contribute to confidence:
        // 1. Number of points (more points = more detail = higher confidence)
        // 2. Contour smoothness (less jagged = higher confidence)
        // 3. Relative size (reasonable wound size = higher confidence)
        
        let pointCountScore = min(Float(contour.count) / 100.0, 1.0)
        
        // Calculate smoothness (lower variance in segment lengths = smoother)
        var segmentLengths: [CGFloat] = []
        for i in 0..<contour.count {
            let nextIndex = (i + 1) % contour.count
            let length = distance(from: contour[i], to: contour[nextIndex])
            segmentLengths.append(length)
        }
        
        let avgLength = segmentLengths.reduce(0, +) / CGFloat(segmentLengths.count)
        let variance = segmentLengths.map { pow($0 - avgLength, 2) }.reduce(0, +) / CGFloat(segmentLengths.count)
        let smoothnessScore = Float(1.0 / (1.0 + variance / 100.0))
        
        // Calculate size score (wound should be reasonable size relative to image)
        let boundingBox = calculateBoundingBox(for: contour)
        let areaRatio = (boundingBox.width * boundingBox.height) / (imageSize.width * imageSize.height)
        let sizeScore = Float(areaRatio > 0.01 && areaRatio < 0.5 ? 1.0 : 0.5)
        
        // Weighted average of scores
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
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
    
    /// Executes an async operation with a timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WoundDetectionError.timeout
            }
            
            // Return first result (either completion or timeout)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
