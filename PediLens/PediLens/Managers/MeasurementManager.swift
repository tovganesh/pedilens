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
    
    /// Calculate individual annotated wound metrics from a wound boundary
    func calculateAnnotatedWound(
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthData: DepthData?,
        existing: AnnotatedWound?
    ) -> AnnotatedWound
    
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
        
        if let depthData = depthData {
            let (calculatedDepth, calculatedVolume) = calculateDepthAndVolume(
                boundary: boundary,
                calibration: calibration,
                depthData: depthData,
                areaMM2: areaMM2
            )
            depthMM = calculatedDepth
            volumeMM3 = calculatedVolume
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
    
    /// Calculates individual annotated wound metrics from a wound boundary
    func calculateAnnotatedWound(
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthData: DepthData?,
        existing: AnnotatedWound? = nil
    ) -> AnnotatedWound {
        let areaPixels = calculateAreaUsingShoelaceFormula(points: boundary.points)
        let areaMM2 = areaPixels / (calibration.pixelsPerMillimeter * calibration.pixelsPerMillimeter)
        
        let (lengthPixels, widthPixels) = calculateMinimumBoundingRectangle(points: boundary.points)
        let lengthMM = lengthPixels / calibration.pixelsPerMillimeter
        let widthMM = widthPixels / calibration.pixelsPerMillimeter
        
        let perimeterPixels = calculatePerimeter(points: boundary.points)
        let perimeterMM = perimeterPixels / calibration.pixelsPerMillimeter
        
        var depthMM: Double = 0.0
        var volumeMM3: Double = 0.0
        if let depthData = depthData {
            let (calcDepth, calcVol) = calculateDepthAndVolume(
                boundary: boundary,
                calibration: calibration,
                depthData: depthData,
                areaMM2: areaMM2
            )
            depthMM = calcDepth ?? 0.0
            volumeMM3 = calcVol ?? 0.0
        }
        
        let isAdjusted = boundary.detectionMethod == .manual || (existing?.isManuallyAdjusted ?? false)
        
        return AnnotatedWound(
            id: existing?.id ?? boundary.id,
            woundNumber: boundary.woundNumber,
            label: existing?.label ?? boundary.label ?? "Wound #\(boundary.woundNumber)",
            anatomicalLocation: existing?.anatomicalLocation ?? "1st Metatarsal Head (Plantar)",
            stageWagner: existing?.stageWagner ?? "Grade 1 - Superficial Ulcer",
            tissueType: existing?.tissueType ?? "Granulation (Erythematous)",
            exudate: existing?.exudate ?? "Scant / Minimal",
            periwoundCondition: existing?.periwoundCondition ?? "Intact",
            notes: existing?.notes ?? "",
            points: boundary.points,
            confidence: boundary.confidence,
            isManuallyAdjusted: isAdjusted,
            colorHex: existing?.colorHex ?? boundary.colorHex,
            lengthMM: lengthMM,
            widthMM: widthMM,
            areaMM2: areaMM2,
            perimeterMM: perimeterMM,
            depthMM: depthMM,
            volumeMM3: volumeMM3
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
    private func calculateAreaUsingShoelaceFormula(points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0.0 }
        
        var sum: Double = 0.0
        let count = points.count
        
        for i in 0..<count {
            let current = points[i]
            let next = points[(i + 1) % count]
            
            sum += Double(current.x * next.y) - Double(next.x * current.y)
        }
        
        return abs(sum) / 2.0
    }
    
    /// Calculate minimum bounding rectangle using rotating calipers algorithm
    /// Returns: (length, width) where length >= width
    private func calculateMinimumBoundingRectangle(points: [CGPoint]) -> (length: Double, width: Double) {
        guard points.count >= 3 else { return (0.0, 0.0) }
        
        // First compute convex hull to reduce search space
        let hull = computeConvexHull(points: points)
        guard hull.count >= 3 else {
            // Fallback to axis-aligned bounding box
            return calculateAxisAlignedBoundingBox(points: points)
        }
        
        var minArea = Double.infinity
        var bestLength: Double = 0.0
        var bestWidth: Double = 0.0
        
        // Test each edge of the convex hull as an orientation
        for i in 0..<hull.count {
            let p1 = hull[i]
            let p2 = hull[(i + 1) % hull.count]
            
            // Calculate edge angle
            let edgeVector = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
            let angle = atan2(edgeVector.y, edgeVector.x)
            
            // Project all hull points onto the rotated coordinate system
            var minX = Double.infinity
            var maxX = -Double.infinity
            var minY = Double.infinity
            var maxY = -Double.infinity
            
            let cosAngle = cos(-angle)
            let sinAngle = sin(-angle)
            
            for point in hull {
                // Rotate point
                let rotatedX = Double(point.x) * Double(cosAngle) - Double(point.y) * Double(sinAngle)
                let rotatedY = Double(point.x) * Double(sinAngle) + Double(point.y) * Double(cosAngle)
                
                minX = min(minX, rotatedX)
                maxX = max(maxX, rotatedX)
                minY = min(minY, rotatedY)
                maxY = max(maxY, rotatedY)
            }
            
            let width = maxX - minX
            let height = maxY - minY
            let area = width * height
            
            // Keep the bounding box with minimum area
            if area < minArea {
                minArea = area
                // Convention: length is the larger dimension, width is smaller
                bestLength = max(width, height)
                bestWidth = min(width, height)
            }
        }
        
        return (bestLength, bestWidth)
    }
    
    /// Compute 2D convex hull using Monotone Chain algorithm (Andrew's algorithm)
    /// Time complexity: O(n log n)
    private func computeConvexHull(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 3 else { return points }
        
        // Sort points lexicographically by x, then y
        let sortedPoints = points.sorted { p1, p2 in
            if p1.x != p2.x {
                return p1.x < p2.x
            }
            return p1.y < p2.y
        }
        
        // Build lower hull
        var lower: [CGPoint] = []
        for point in sortedPoints {
            while lower.count >= 2 && crossProduct(p1: lower[lower.count - 2], p2: lower[lower.count - 1], p3: point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        
        // Build upper hull
        var upper: [CGPoint] = []
        for point in sortedPoints.reversed() {
            while upper.count >= 2 && crossProduct(p1: upper[upper.count - 2], p2: upper[upper.count - 1], p3: point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        
        // Remove last point of each half because it's repeated at the beginning of the other half
        lower.removeLast()
        upper.removeLast()
        
        return lower + upper
    }
    
    /// 2D cross product of OA and OB vectors
    /// Returns positive for counter-clockwise turn, negative for clockwise, 0 for collinear
    private func crossProduct(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGFloat {
        return (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
    }
    
    /// Fallback: Calculate axis-aligned bounding box
    private func calculateAxisAlignedBoundingBox(points: [CGPoint]) -> (length: Double, width: Double) {
        guard !points.isEmpty else { return (0.0, 0.0) }
        
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
        
        let width = Double(maxX - minX)
        let height = Double(maxY - minY)
        
        return (max(width, height), min(width, height))
    }
    
    /// Calculate perimeter from boundary polygon points
    private func calculatePerimeter(points: [CGPoint]) -> Double {
        guard points.count >= 2 else { return 0.0 }
        
        var perimeter: Double = 0.0
        let count = points.count
        
        for i in 0..<count {
            let current = points[i]
            let next = points[(i + 1) % count]
            
            let dx = Double(next.x - current.x)
            let dy = Double(next.y - current.y)
            let segmentLength = sqrt(dx * dx + dy * dy)
            
            perimeter += segmentLength
        }
        
        return perimeter
    }
    
    /// Calculate depth and volume from depth data
    /// - Parameters:
    ///   - boundary: Wound boundary polygon
    ///   - calibration: Calibration data
    ///   - depthData: Depth map from TrueDepth/LiDAR
    ///   - areaMM2: Previously calculated surface area
    /// - Returns: (maxDepthMM, volumeMM3)
    private func calculateDepthAndVolume(
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthData: DepthData,
        areaMM2: Double
    ) -> (depthMM: Double?, volumeMM3: Double?) {
        let depthMap = depthData.depthMap
        
        // Lock depth map for reading
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return (nil, nil)
        }
        
        // Get surrounding healthy tissue reference plane (periwound skin)
        let referenceDepth = calculatePeriwoundReferencePlane(
            boundary: boundary,
            depthMap: depthMap,
            width: width,
            height: height,
            baseAddress: baseAddress
        )
        
        guard let baselineDepth = referenceDepth else {
            return (nil, nil)
        }
        
        // Sample depth values inside the wound boundary
        var maxDepth: Double = 0.0
        var depthSum: Double = 0.0
        var sampledPoints = 0
        
        // Bounding box for sampling
        let boundingBox = boundary.boundingBox
        let startX = max(0, Int(boundingBox.minX))
        let endX = min(width - 1, Int(boundingBox.maxX))
        let startY = max(0, Int(boundingBox.minY))
        let endY = min(height - 1, Int(boundingBox.maxY))
        
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
        
        // Sample points inside boundary
        for y in startY...endY {
            for x in startX...endX {
                let point = CGPoint(x: x, y: y)
                
                // Check if point is inside wound polygon
                if isPointInPolygon(point: point, polygon: boundary.points) {
                    let depthValue = Double(floatBuffer[y * floatsPerRow + x])
                    
                    // Depth value is distance from camera in meters
                    // Wound bed should be further from camera than healthy skin (larger depth value)
                    if depthValue > 0 && depthValue.isFinite {
                        let relativeDepthMeters = depthValue - baselineDepth
                        
                        // Convert to millimeters (1 meter = 1000 mm)
                        let relativeDepthMM = relativeDepthMeters * 1000.0
                        
                        // Only consider points that are deeper than the reference plane
                        if relativeDepthMM > 0 {
                            maxDepth = max(maxDepth, relativeDepthMM)
                            depthSum += relativeDepthMM
                            sampledPoints += 1
                        }
                    }
                }
            }
        }
        
        guard sampledPoints > 0 else {
            return (nil, nil)
        }
        
        // Calculate average depth
        let averageDepthMM = depthSum / Double(sampledPoints)
        
        // Calculate volume: V = Area * Average Depth (Riemann sum approximation)
        let volumeMM3 = areaMM2 * averageDepthMM
        
        return (maxDepth, volumeMM3)
    }
    
    /// Calculate the reference plane depth from healthy skin surrounding the wound
    private func calculatePeriwoundReferencePlane(
        boundary: WoundBoundary,
        depthMap: CVPixelBuffer,
        width: Int,
        height: Int,
        baseAddress: UnsafeMutableRawPointer
    ) -> Double? {
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.size
        
        var referenceDepths: [Double] = []
        
        // Sample points in a band around the wound boundary (5-10mm margin)
        // For simplicity, sample points just outside the boundary polygon
        let marginPixels: CGFloat = 20.0 // Roughly 2mm at 10 px/mm
        
        for point in boundary.points {
            // Sample points in normal directions outward from boundary
            let offsetPoints = [
                CGPoint(x: point.x + marginPixels, y: point.y),
                CGPoint(x: point.x - marginPixels, y: point.y),
                CGPoint(x: point.x, y: point.y + marginPixels),
                CGPoint(x: point.x, y: point.y - marginPixels)
            ]
            
            for offsetPoint in offsetPoints {
                let x = Int(offsetPoint.x)
                let y = Int(offsetPoint.y)
                
                // Ensure point is within bounds and not inside the wound
                if x >= 0 && x < width && y >= 0 && y < height {
                    if !isPointInPolygon(point: offsetPoint, polygon: boundary.points) {
                        let depth = Double(floatBuffer[y * floatsPerRow + x])
                        if depth > 0 && depth.isFinite {
                            referenceDepths.append(depth)
                        }
                    }
                }
            }
        }
        
        guard !referenceDepths.isEmpty else { return nil }
        
        // Use median to be robust against outliers
        referenceDepths.sort()
        let medianIndex = referenceDepths.count / 2
        return referenceDepths[medianIndex]
    }
    
    /// Test if a point is inside a polygon using ray casting algorithm
    private func isPointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            
            if ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside.toggle()
            }
            
            j = i
        }
        
        return inside
    }
}


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


extension WoundMeasurement {
    var formattedArea: String {
        let cm2 = area.converted(to: .squareCentimeters).value
        return String(format: "%.2f cm²", cm2)
    }
    
    var formattedLength: String {
        let mm = length.converted(to: .millimeters).value
        return String(format: "%.1f mm", mm)
    }
    
    var formattedWidth: String {
        let mm = width.converted(to: .millimeters).value
        return String(format: "%.1f mm", mm)
    }
    
    var formattedPerimeter: String {
        let mm = perimeter.converted(to: .millimeters).value
        return String(format: "%.1f mm", mm)
    }
    
    var formattedDepth: String? {
        guard let depth = depth else { return nil }
        let mm = depth.converted(to: .millimeters).value
        return String(format: "%.1f mm", mm)
    }
    
    var formattedVolume: String? {
        guard let volume = volume else { return nil }
        let mm3 = volume.converted(to: .cubicMillimeters).value
        let cm3 = mm3 / 1000.0
        return String(format: "%.2f cm³", cm3)
    }
}
