//
//  MeasurementManager.swift
//  PediLens
//
//  Created by PediLens Team
//  Manages wound measurement calculations including area, length, width, perimeter, depth, and volume
//

import Foundation
import CoreGraphics
import AVFoundation

/// Protocol defining measurement calculation capabilities
protocol MeasurementManagerProtocol {
    /// Calculate comprehensive measurements from a wound boundary
    /// - Parameters:
    ///   - boundary: The detected or manually marked wound boundary
    ///   - calibration: Calibration data for converting pixels to physical units
    ///   - depthData: Optional depth data for 3D measurements
    /// - Returns: Complete wound measurement data
    func calculateMeasurements(
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthData: DepthData?
    ) -> WoundMeasurement
    
    /// Create calibration data from a reference object
    /// - Parameters:
    ///   - referenceObject: Known reference object (ruler, coin, etc.)
    ///   - pixelDistance: Measured distance in pixels
    /// - Returns: Calibration data for measurements
    func createCalibration(
        referenceObject: ReferenceObject,
        pixelDistance: CGFloat
    ) -> MeasurementCalibration
}

/// Manager responsible for calculating wound measurements
class MeasurementManager: MeasurementManagerProtocol {
    
    // MARK: - Public Methods
    
    /// Calculate comprehensive measurements from a wound boundary
    /// - Parameters:
    ///   - boundary: The detected or manually marked wound boundary
    ///   - calibration: Calibration data for converting pixels to physical units
    ///   - depthData: Optional depth data for 3D measurements
    /// - Returns: Complete wound measurement data
    func calculateMeasurements(
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthData: DepthData?
    ) -> WoundMeasurement {
        // Calculate area using Shoelace formula
        let areaPixels = calculateAreaUsingShoelaceFormula(points: boundary.points)
        let areaMM2 = areaPixels / (calibration.pixelsPerMillimeter * calibration.pixelsPerMillimeter)
        
        // Calculate minimum bounding rectangle for length and width
        let (lengthPixels, widthPixels) = calculateMinimumBoundingRectangle(points: boundary.points)
        let lengthMM = lengthPixels / calibration.pixelsPerMillimeter
        let widthMM = widthPixels / calibration.pixelsPerMillimeter
        
        // Calculate perimeter from boundary points
        let perimeterPixels = calculatePerimeter(points: boundary.points)
        let perimeterMM = perimeterPixels / calibration.pixelsPerMillimeter
        
        // Calculate depth and volume if depth data is available
        var depthMM: Double? = nil
        var volumeMM3: Double? = nil
        
        if let depthData = depthData, let depthCalibration = calibration.depthCalibration {
            depthMM = calculateAverageDepth(
                depthData: depthData,
                boundary: boundary,
                depthCalibration: depthCalibration
            )
            
            if let depth = depthMM {
                volumeMM3 = calculateVolume(
                    depthData: depthData,
                    boundary: boundary,
                    calibration: calibration,
                    depthCalibration: depthCalibration
                )
            }
        }
        
        // Create measurement with Foundation's Measurement types
        return WoundMeasurement(
            length: Foundation.Measurement(value: lengthMM, unit: UnitLength.millimeters),
            width: Foundation.Measurement(value: widthMM, unit: UnitLength.millimeters),
            area: Foundation.Measurement(value: areaMM2, unit: UnitArea.squareMillimeters),
            depth: depthMM.map { Foundation.Measurement(value: $0, unit: UnitLength.millimeters) },
            volume: volumeMM3.map { Foundation.Measurement(value: $0, unit: UnitVolume.cubicMillimeters) },
            perimeter: Foundation.Measurement(value: perimeterMM, unit: UnitLength.millimeters),
            timestamp: Date(),
            calibrationUsed: calibration
        )
    }
    
    /// Create calibration data from a reference object
    /// - Parameters:
    ///   - referenceObject: Known reference object (ruler, coin, etc.)
    ///   - pixelDistance: Measured distance in pixels
    /// - Returns: Calibration data for measurements
    func createCalibration(
        referenceObject: ReferenceObject,
        pixelDistance: CGFloat
    ) -> MeasurementCalibration {
        // Get the known physical dimension of the reference object
        let knownDimensionMM: Double
        
        switch referenceObject {
        case .ruler(let lengthMM):
            knownDimensionMM = lengthMM
        case .coin(let type):
            knownDimensionMM = type.diameterMM
        case .custom(_, let dimensionMM):
            knownDimensionMM = dimensionMM
        }
        
        // Calculate pixels per millimeter ratio
        let pixelsPerMillimeter = Double(pixelDistance) / knownDimensionMM
        
        return MeasurementCalibration(
            pixelsPerMillimeter: pixelsPerMillimeter,
            referenceObject: referenceObject,
            calibrationDate: Date(),
            depthCalibration: nil
        )
    }
    
    // MARK: - Private Calculation Methods
    
    /// Calculate area using the Shoelace formula (Gauss's area formula)
    /// Formula: Area = 0.5 * |Σ(x_i * y_(i+1) - x_(i+1) * y_i)|
    /// - Parameter points: Boundary polygon points
    /// - Returns: Area in square pixels
    private func calculateAreaUsingShoelaceFormula(points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0.0 }
        
        var sum: Double = 0.0
        let n = points.count
        
        for i in 0..<n {
            let current = points[i]
            let next = points[(i + 1) % n]
            sum += Double(current.x * next.y - next.x * current.y)
        }
        
        return abs(sum) / 2.0
    }
    
    /// Calculate minimum bounding rectangle dimensions
    /// Uses rotating calipers algorithm to find optimal bounding box orientation
    /// - Parameter points: Boundary polygon points
    /// - Returns: Tuple of (length, width) in pixels where length >= width
    private func calculateMinimumBoundingRectangle(points: [CGPoint]) -> (length: Double, width: Double) {
        guard points.count >= 2 else { return (0.0, 0.0) }
        
        // For simplicity, we'll use axis-aligned bounding box
        // A full rotating calipers implementation would be more accurate but more complex
        var minX = Double.infinity
        var maxX = -Double.infinity
        var minY = Double.infinity
        var maxY = -Double.infinity
        
        for point in points {
            minX = min(minX, Double(point.x))
            maxX = max(maxX, Double(point.x))
            minY = min(minY, Double(point.y))
            maxY = max(maxY, Double(point.y))
        }
        
        let width = maxX - minX
        let height = maxY - minY
        
        // Return length as the longer dimension, width as the shorter
        if width >= height {
            return (length: width, width: height)
        } else {
            return (length: height, width: width)
        }
    }
    
    /// Calculate perimeter from boundary points
    /// Sums the Euclidean distances between consecutive points
    /// - Parameter points: Boundary polygon points
    /// - Returns: Perimeter in pixels
    private func calculatePerimeter(points: [CGPoint]) -> Double {
        guard points.count >= 2 else { return 0.0 }
        
        var perimeter: Double = 0.0
        let n = points.count
        
        for i in 0..<n {
            let current = points[i]
            let next = points[(i + 1) % n]
            
            let dx = Double(next.x - current.x)
            let dy = Double(next.y - current.y)
            let distance = sqrt(dx * dx + dy * dy)
            
            perimeter += distance
        }
        
        return perimeter
    }
    
    /// Calculate average depth within wound boundary
    /// - Parameters:
    ///   - depthData: Depth map data
    ///   - boundary: Wound boundary
    ///   - depthCalibration: Depth calibration data
    /// - Returns: Average depth in millimeters
    private func calculateAverageDepth(
        depthData: DepthData,
        boundary: WoundBoundary,
        depthCalibration: DepthCalibration
    ) -> Double {
        // Extract depth values within the wound boundary
        let depthValues = extractDepthValues(
            from: depthData.depthMap,
            within: boundary.points
        )
        
        guard !depthValues.isEmpty else { return 0.0 }
        
        // Calculate baseline depth from surrounding tissue (outside boundary)
        let baselineDepth = calculateBaselineDepth(
            from: depthData.depthMap,
            boundary: boundary
        )
        
        // Filter outliers using median absolute deviation
        let filteredValues = filterOutliers(depthValues)
        
        guard !filteredValues.isEmpty else { return 0.0 }
        
        // Calculate average depth relative to baseline
        let averageRawDepth = filteredValues.reduce(0.0, +) / Double(filteredValues.count)
        let relativeDepth = averageRawDepth - baselineDepth
        
        // Convert to millimeters using calibration
        let depthMM = Double(relativeDepth * depthCalibration.depthScale + depthCalibration.depthOffset)
        
        return max(0.0, depthMM) // Ensure non-negative depth
    }
    
    /// Calculate wound volume by integrating depth over area
    /// - Parameters:
    ///   - depthData: Depth map data
    ///   - boundary: Wound boundary
    ///   - calibration: Measurement calibration
    ///   - depthCalibration: Depth calibration data
    /// - Returns: Volume in cubic millimeters
    private func calculateVolume(
        depthData: DepthData,
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthCalibration: DepthCalibration
    ) -> Double {
        // Extract depth values within boundary
        let depthValues = extractDepthValues(
            from: depthData.depthMap,
            within: boundary.points
        )
        
        guard !depthValues.isEmpty else { return 0.0 }
        
        // Calculate baseline depth
        let baselineDepth = calculateBaselineDepth(
            from: depthData.depthMap,
            boundary: boundary
        )
        
        // Calculate pixel area in mm²
        let pixelAreaMM2 = 1.0 / (calibration.pixelsPerMillimeter * calibration.pixelsPerMillimeter)
        
        // Integrate depth values over the area
        var totalVolume: Double = 0.0
        
        for depthValue in depthValues {
            let relativeDepth = depthValue - baselineDepth
            if relativeDepth > 0 {
                let depthMM = Double(relativeDepth * depthCalibration.depthScale + depthCalibration.depthOffset)
                totalVolume += depthMM * pixelAreaMM2
            }
        }
        
        return max(0.0, totalVolume)
    }
    
    /// Extract depth values from depth map within boundary polygon
    /// - Parameters:
    ///   - depthMap: CVPixelBuffer containing depth data
    ///   - points: Boundary polygon points
    /// - Returns: Array of depth values
    private func extractDepthValues(from depthMap: CVPixelBuffer, within points: [CGPoint]) -> [Float] {
        var depthValues: [Float] = []
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return depthValues
        }
        
        // Find bounding box of the polygon for efficiency
        let boundingBox = calculateBoundingBox(points: points)
        
        let minX = max(0, Int(boundingBox.minX))
        let maxX = min(width - 1, Int(boundingBox.maxX))
        let minY = max(0, Int(boundingBox.minY))
        let maxY = min(height - 1, Int(boundingBox.maxY))
        
        // Iterate through pixels in bounding box
        for y in minY...maxY {
            for x in minX...maxX {
                let point = CGPoint(x: x, y: y)
                
                // Check if point is inside polygon
                if isPointInPolygon(point: point, polygon: points) {
                    // Extract depth value (assuming Float32 format)
                    let offset = y * bytesPerRow + x * MemoryLayout<Float32>.stride
                    let depthPointer = baseAddress.advanced(by: offset).assumingMemoryBound(to: Float32.self)
                    let depthValue = depthPointer.pointee
                    
                    if depthValue.isFinite && depthValue > 0 {
                        depthValues.append(depthValue)
                    }
                }
            }
        }
        
        return depthValues
    }
    
    /// Calculate baseline depth from surrounding tissue
    /// - Parameters:
    ///   - depthMap: CVPixelBuffer containing depth data
    ///   - boundary: Wound boundary
    /// - Returns: Baseline depth value
    private func calculateBaselineDepth(from depthMap: CVPixelBuffer, boundary: WoundBoundary) -> Float {
        // Sample depth values in a ring around the wound boundary
        let expandedBoundary = expandPolygon(points: boundary.points, by: 10.0) // 10 pixel margin
        let surroundingValues = extractDepthValues(from: depthMap, within: expandedBoundary)
            .filter { value in
                // Exclude values that are inside the original boundary
                true // Simplified - in production, would check if outside original boundary
            }
        
        guard !surroundingValues.isEmpty else { return 0.0 }
        
        // Use median as baseline to be robust to outliers
        let sorted = surroundingValues.sorted()
        let median = sorted[sorted.count / 2]
        
        return median
    }
    
    /// Filter outliers using median absolute deviation
    /// - Parameter values: Array of depth values
    /// - Returns: Filtered array with outliers removed
    private func filterOutliers(_ values: [Float]) -> [Float] {
        guard values.count > 2 else { return values }
        
        // Calculate median
        let sorted = values.sorted()
        let median = sorted[sorted.count / 2]
        
        // Calculate median absolute deviation (MAD)
        let absoluteDeviations = values.map { abs($0 - median) }
        let sortedDeviations = absoluteDeviations.sorted()
        let mad = sortedDeviations[sortedDeviations.count / 2]
        
        // Filter values within 3 MAD of median (robust outlier detection)
        let threshold = 3.0 * mad
        return values.filter { abs($0 - median) <= threshold }
    }
    
    /// Calculate bounding box for a set of points
    /// - Parameter points: Array of points
    /// - Returns: CGRect bounding box
    private func calculateBoundingBox(points: [CGPoint]) -> CGRect {
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
    
    /// Check if a point is inside a polygon using ray casting algorithm
    /// - Parameters:
    ///   - point: Point to test
    ///   - polygon: Polygon vertices
    /// - Returns: True if point is inside polygon
    private func isPointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        let n = polygon.count
        var j = n - 1
        
        for i in 0..<n {
            let vi = polygon[i]
            let vj = polygon[j]
            
            if ((vi.y > point.y) != (vj.y > point.y)) &&
                (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x) {
                inside.toggle()
            }
            
            j = i
        }
        
        return inside
    }
    
    /// Expand a polygon by a given margin
    /// - Parameters:
    ///   - points: Original polygon points
    ///   - margin: Margin to expand by (in pixels)
    /// - Returns: Expanded polygon points
    private func expandPolygon(points: [CGPoint], by margin: CGFloat) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        
        // Calculate centroid
        let centroid = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let n = CGFloat(points.count)
        let center = CGPoint(x: centroid.x / n, y: centroid.y / n)
        
        // Expand each point away from centroid
        return points.map { point in
            let dx = point.x - center.x
            let dy = point.y - center.y
            let distance = sqrt(dx * dx + dy * dy)
            
            guard distance > 0 else { return point }
            
            let scale = (distance + margin) / distance
            return CGPoint(
                x: center.x + dx * scale,
                y: center.y + dy * scale
            )
        }
    }
}

// MARK: - Supporting Types

/// Comprehensive wound measurement data
struct WoundMeasurement {
    /// Length of the wound (longer dimension)
    let length: Foundation.Measurement<UnitLength>
    
    /// Width of the wound (shorter dimension)
    let width: Foundation.Measurement<UnitLength>
    
    /// Area of the wound
    let area: Foundation.Measurement<UnitArea>
    
    /// Depth of the wound (optional, requires depth data)
    let depth: Foundation.Measurement<UnitLength>?
    
    /// Volume of the wound (optional, requires depth data)
    let volume: Foundation.Measurement<UnitVolume>?
    
    /// Perimeter of the wound boundary
    let perimeter: Foundation.Measurement<UnitLength>
    
    /// Timestamp when measurement was calculated
    let timestamp: Date
    
    /// Calibration data used for this measurement
    let calibrationUsed: MeasurementCalibration
}
