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
        // Undo surface-tilt foreshortening for planar metrics
        let planarPoints = rectifiedPoints(boundary.points, for: calibration)
        
        // Calculate area using Shoelace formula
        let areaPixels = calculateAreaUsingShoelaceFormula(points: planarPoints)
        let areaMM2 = areaPixels / (calibration.pixelsPerMillimeter * calibration.pixelsPerMillimeter)
        
        // Calculate minimum bounding rectangle for length and width
        let (lengthPixels, widthPixels) = calculateMinimumBoundingRectangle(points: planarPoints)
        let lengthMM = lengthPixels / calibration.pixelsPerMillimeter
        let widthMM = widthPixels / calibration.pixelsPerMillimeter
        
        // Calculate perimeter from boundary points
        let perimeterPixels = calculatePerimeter(points: planarPoints)
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
        let planarPoints = rectifiedPoints(boundary.points, for: calibration)
        
        let areaPixels = calculateAreaUsingShoelaceFormula(points: planarPoints)
        let areaMM2 = areaPixels / (calibration.pixelsPerMillimeter * calibration.pixelsPerMillimeter)
        
        let (lengthPixels, widthPixels) = calculateMinimumBoundingRectangle(points: planarPoints)
        let lengthMM = lengthPixels / calibration.pixelsPerMillimeter
        let widthMM = widthPixels / calibration.pixelsPerMillimeter
        
        let perimeterPixels = calculatePerimeter(points: planarPoints)
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
    
    /// Derives a metric calibration from absolute depth and camera intrinsics, without any
    /// reference object.
    ///
    /// Fits a plane to the skin around the wound in camera space (meters), then:
    /// - scale: image pixels per mm at the wound = focal length (px) / distance to the skin plane (mm)
    /// - tilt: angle between the plane normal and the camera axis, plus its image direction
    /// - Parameters:
    ///   - points: Wound outline in image coordinates (display orientation)
    ///   - depthData: Absolute depth aligned to the image, with intrinsics and reference image size
    /// - Returns: Calibration, or nil when depth is relative, sparse, or lacks intrinsics
    func depthCalibration(for points: [CGPoint], depthData: DepthData) -> MeasurementCalibration? {
        guard depthData.accuracy == .absolute,
              points.count >= 3,
              let imageSize = depthData.referenceImageSize, imageSize.width > 0, imageSize.height > 0,
              let intrinsics = depthData.intrinsics?.scaled(to: imageSize),
              intrinsics.fx > 0, intrinsics.fy > 0 else {
            return nil
        }
        
        let depthMap = depthData.depthMap
        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else { return nil }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0, let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size
        
        let scaleX = Double(width) / Double(imageSize.width)
        let scaleY = Double(height) / Double(imageSize.height)
        let polygon = points.map { CGPoint(x: Double($0.x) * scaleX, y: Double($0.y) * scaleY) }
        
        func depth(atX x: Int, y: Int) -> Double? {
            let z = Double(floatBuffer[y * floatsPerRow + x])
            return z > 0 && z.isFinite ? z : nil
        }
        
        let xs = polygon.map { Double($0.x) }
        let ys = polygon.map { Double($0.y) }
        guard let polyMinX = xs.min(), let polyMaxX = xs.max(),
              let polyMinY = ys.min(), let polyMaxY = ys.max() else { return nil }
        
        // Rough distance from the wound region, to size the periwound band in pixels
        let regionMinX = max(0, Int(polyMinX)), regionMaxX = min(width - 1, Int(polyMaxX))
        let regionMinY = max(0, Int(polyMinY)), regionMaxY = min(height - 1, Int(polyMaxY))
        guard regionMinX <= regionMaxX, regionMinY <= regionMaxY else { return nil }
        var regionDepths: [Double] = []
        for y in regionMinY...regionMaxY {
            for x in regionMinX...regionMaxX {
                if let z = depth(atX: x, y: y) { regionDepths.append(z) }
            }
        }
        guard !regionDepths.isEmpty else { return nil }
        let roughDistanceMM = percentile(regionDepths, 0.5) * 1000.0
        let depthPixelsPerMM = intrinsics.fx / roughDistanceMM * (scaleX + scaleY) / 2.0
        let bandInner = 2.0 * depthPixelsPerMM
        let bandOuter = max(bandInner + 1.5, 6.0 * depthPixelsPerMM)
        
        // Back-project periwound skin samples to camera space (meters)
        var skinSamples: [DepthSample] = []
        let startX = max(0, Int((polyMinX - bandOuter).rounded(.down)))
        let endX = min(width - 1, Int((polyMaxX + bandOuter).rounded(.up)))
        let startY = max(0, Int((polyMinY - bandOuter).rounded(.down)))
        let endY = min(height - 1, Int((polyMaxY + bandOuter).rounded(.up)))
        guard startX <= endX, startY <= endY else { return nil }
        
        for y in startY...endY {
            for x in startX...endX {
                guard let z = depth(atX: x, y: y) else { continue }
                let point = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                guard !isPointInPolygon(point: point, polygon: polygon) else { continue }
                let distance = distanceToPolygonEdge(point: point, polygon: polygon)
                guard distance >= bandInner && distance <= bandOuter else { continue }
                
                let u = Double(point.x) / scaleX
                let v = Double(point.y) / scaleY
                skinSamples.append(DepthSample(
                    x: (u - intrinsics.cx) / intrinsics.fx * z,
                    y: (v - intrinsics.cy) / intrinsics.fy * z,
                    z: z
                ))
            }
        }
        
        // Skin plane Z = a·X + b·Y + c in camera space
        guard skinSamples.count >= 12, let plane = fitRobustPlane(to: skinSamples) else { return nil }
        
        // Distance to the skin plane along the ray through the wound centroid
        let centroidU = points.reduce(0.0) { $0 + Double($1.x) } / Double(points.count)
        let centroidV = points.reduce(0.0) { $0 + Double($1.y) } / Double(points.count)
        let rayX = (centroidU - intrinsics.cx) / intrinsics.fx
        let rayY = (centroidV - intrinsics.cy) / intrinsics.fy
        let denominator = 1.0 - plane.a * rayX - plane.b * rayY
        guard denominator > 0 else { return nil }
        let distanceMeters = plane.c / denominator
        guard distanceMeters > 0.05, distanceMeters < 2.0 else { return nil }
        
        // Pixels per mm for a surface facing the camera at that distance
        let focalLength = (intrinsics.fx + intrinsics.fy) / 2.0
        let pixelsPerMillimeter = focalLength / (distanceMeters * 1000.0)
        
        // Tilt: normal (-a, -b, 1) vs camera axis; the surface recedes along the gradient (a, b)
        let gradient = (plane.a * plane.a + plane.b * plane.b).squareRoot()
        let tiltDegrees = atan(gradient) * 180.0 / .pi
        let tilt = SurfaceTilt(
            angleDegrees: tiltDegrees,
            directionX: gradient > 1e-6 ? plane.a / gradient : 1.0,
            directionY: gradient > 1e-6 ? plane.b / gradient : 0.0
        )
        
        return MeasurementCalibration(
            pixelsPerMillimeter: pixelsPerMillimeter,
            calibrationType: .lidar(depth: Float(distanceMeters), confidence: 0.9),
            captureDistance: Float(distanceMeters),
            captureAngle: Float(tiltDegrees),
            metadata: [
                "calibrationMethod": "depthIntrinsics",
                "distanceMM": String(format: "%.1f", distanceMeters * 1000.0),
                "tiltDegrees": String(format: "%.1f", tiltDegrees)
            ],
            surfaceTilt: tilt
        )
    }
    
    /// Maximum tilt corrected; beyond this, foreshortening is too severe to undo reliably
    private static let maximumCorrectableTiltDegrees = 60.0
    
    /// Undoes foreshortening of a tilted skin surface by stretching the outline along the
    /// direction the surface recedes, by 1 / cos(tilt). This is the local affine rectification
    /// of the skin plane, accurate when the wound is small relative to camera distance.
    private func rectifiedPoints(_ points: [CGPoint], for calibration: MeasurementCalibration) -> [CGPoint] {
        guard let tilt = calibration.surfaceTilt, tilt.angleDegrees > 0.5, points.count >= 3 else { return points }
        
        let angle = min(tilt.angleDegrees, Self.maximumCorrectableTiltDegrees) * .pi / 180.0
        let stretch = 1.0 / cos(angle) - 1.0
        let centerX = points.reduce(0.0) { $0 + Double($1.x) } / Double(points.count)
        let centerY = points.reduce(0.0) { $0 + Double($1.y) } / Double(points.count)
        
        return points.map { point in
            let dx = Double(point.x) - centerX
            let dy = Double(point.y) - centerY
            let along = dx * tilt.directionX + dy * tilt.directionY
            return CGPoint(
                x: Double(point.x) + stretch * along * tilt.directionX,
                y: Double(point.y) + stretch * along * tilt.directionY
            )
        }
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
    ///
    /// Depth is measured relative to the surrounding skin: a plane is fitted to depth samples
    /// in a periwound band (2–6 mm outside the boundary), so foot curvature and camera tilt
    /// don't masquerade as wound depth. Values are along the camera axis, which approximates
    /// depth normal to the skin when the camera is roughly perpendicular to the wound.
    /// - Parameters:
    ///   - boundary: Wound boundary polygon (image coordinates)
    ///   - calibration: Calibration data (image pixels per mm)
    ///   - depthData: Metric depth map (meters), aligned with the display-oriented image
    ///   - areaMM2: Previously calculated surface area
    /// - Returns: (depthMM: 95th-percentile recess below the skin plane, volumeMM3)
    private func calculateDepthAndVolume(
        boundary: WoundBoundary,
        calibration: MeasurementCalibration,
        depthData: DepthData,
        areaMM2: Double
    ) -> (depthMM: Double?, volumeMM3: Double?) {
        // Relative depth (e.g. dual-camera disparity) has no metric scale
        guard depthData.accuracy == .absolute,
              boundary.points.count >= 3,
              calibration.pixelsPerMillimeter > 0 else {
            return (nil, nil)
        }
        
        let depthMap = depthData.depthMap
        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else {
            return (nil, nil)
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0, let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return (nil, nil)
        }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatsPerRow = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size
        
        // Map boundary (image coordinates) into depth-map pixels; the depth map covers the
        // same field of view at lower resolution
        let referenceSize = depthData.referenceImageSize ?? CGSize(width: width, height: height)
        guard referenceSize.width > 0, referenceSize.height > 0 else { return (nil, nil) }
        let scaleX = Double(width) / Double(referenceSize.width)
        let scaleY = Double(height) / Double(referenceSize.height)
        let polygon = boundary.points.map { CGPoint(x: Double($0.x) * scaleX, y: Double($0.y) * scaleY) }
        
        // Periwound band, in depth pixels
        let depthPixelsPerMM = calibration.pixelsPerMillimeter * (scaleX + scaleY) / 2.0
        let bandInner = 2.0 * depthPixelsPerMM
        let bandOuter = max(bandInner + 1.5, 6.0 * depthPixelsPerMM)
        
        let xs = polygon.map { Double($0.x) }
        let ys = polygon.map { Double($0.y) }
        guard let polyMinX = xs.min(), let polyMaxX = xs.max(),
              let polyMinY = ys.min(), let polyMaxY = ys.max() else { return (nil, nil) }
        let startX = max(0, Int((polyMinX - bandOuter).rounded(.down)))
        let endX = min(width - 1, Int((polyMaxX + bandOuter).rounded(.up)))
        let startY = max(0, Int((polyMinY - bandOuter).rounded(.down)))
        let endY = min(height - 1, Int((polyMaxY + bandOuter).rounded(.up)))
        guard startX <= endX, startY <= endY else { return (nil, nil) }
        
        var woundSamples: [DepthSample] = []
        var periwoundSamples: [DepthSample] = []
        
        for y in startY...endY {
            for x in startX...endX {
                let z = Double(floatBuffer[y * floatsPerRow + x])
                guard z > 0, z.isFinite else { continue }
                
                // Sample at the pixel center
                let point = CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let sample = DepthSample(x: Double(point.x), y: Double(point.y), z: z)
                if isPointInPolygon(point: point, polygon: polygon) {
                    woundSamples.append(sample)
                } else {
                    let distance = distanceToPolygonEdge(point: point, polygon: polygon)
                    if distance >= bandInner && distance <= bandOuter {
                        periwoundSamples.append(sample)
                    }
                }
            }
        }
        
        guard woundSamples.count >= 4, periwoundSamples.count >= 12,
              let skinPlane = fitRobustPlane(to: periwoundSamples) else {
            return (nil, nil)
        }
        
        // Depth below the skin plane in mm (positive = recessed, further from the camera).
        // Raised tissue (negative) contributes no cavity depth or volume.
        let recessMM = woundSamples.map { max(0.0, ($0.z - skinPlane.z(atX: $0.x, y: $0.y)) * 1000.0) }
        
        // 95th percentile rejects isolated noisy depth pixels that would dominate a raw maximum
        let depthMM = percentile(recessMM, 0.95)
        
        // Volume: mean recess over the wound footprint times its surface area
        let meanRecessMM = recessMM.reduce(0.0, +) / Double(recessMM.count)
        let volumeMM3 = areaMM2 * meanRecessMM
        
        return (depthMM, volumeMM3)
    }
    
    /// A depth sample in depth-map pixel coordinates; `z` is distance from the camera in meters
    private struct DepthSample {
        let x: Double
        let y: Double
        let z: Double
    }
    
    /// Plane z = a·x + b·y + c in depth-map pixel coordinates
    private struct DepthPlane {
        let a: Double
        let b: Double
        let c: Double
        
        func z(atX x: Double, y: Double) -> Double {
            a * x + b * y + c
        }
    }
    
    /// Least-squares plane fit, refit once after discarding outliers (hair, shadows, wound edge spill)
    private func fitRobustPlane(to samples: [DepthSample]) -> DepthPlane? {
        guard let initial = fitPlane(to: samples) else { return nil }
        
        let residuals = samples.map { abs($0.z - initial.z(atX: $0.x, y: $0.y)) }
        // Median absolute deviation, scaled to approximate a standard deviation
        let sigma = 1.4826 * percentile(residuals, 0.5)
        guard sigma > 0 else { return initial }
        
        let inliers = zip(samples, residuals).filter { $0.1 <= 2.5 * sigma }.map { $0.0 }
        guard inliers.count >= 12 else { return initial }
        return fitPlane(to: inliers) ?? initial
    }
    
    /// Ordinary least-squares fit of z = a·x + b·y + c (solves the 3×3 normal equations)
    private func fitPlane(to samples: [DepthSample]) -> DepthPlane? {
        guard samples.count >= 3 else { return nil }
        
        // Center coordinates for numerical stability
        let n = Double(samples.count)
        let meanX = samples.reduce(0.0) { $0 + $1.x } / n
        let meanY = samples.reduce(0.0) { $0 + $1.y } / n
        let meanZ = samples.reduce(0.0) { $0 + $1.z } / n
        
        var sxx = 0.0, sxy = 0.0, syy = 0.0, sxz = 0.0, syz = 0.0
        for s in samples {
            let dx = s.x - meanX, dy = s.y - meanY, dz = s.z - meanZ
            sxx += dx * dx; sxy += dx * dy; syy += dy * dy
            sxz += dx * dz; syz += dy * dz
        }
        
        let determinant = sxx * syy - sxy * sxy
        let a: Double
        let b: Double
        if abs(determinant) > 1e-9 {
            a = (sxz * syy - syz * sxy) / determinant
            b = (syz * sxx - sxz * sxy) / determinant
        } else {
            // Degenerate (e.g. collinear samples): fall back to a flat plane
            a = 0
            b = 0
        }
        return DepthPlane(a: a, b: b, c: meanZ - a * meanX - b * meanY)
    }
    
    /// Shortest distance from a point to the polygon's edges
    private func distanceToPolygonEdge(point: CGPoint, polygon: [CGPoint]) -> Double {
        var minDistance = Double.infinity
        for i in 0..<polygon.count {
            let a = polygon[i]
            let b = polygon[(i + 1) % polygon.count]
            let abx = Double(b.x - a.x), aby = Double(b.y - a.y)
            let apx = Double(point.x - a.x), apy = Double(point.y - a.y)
            let lengthSquared = abx * abx + aby * aby
            let t = lengthSquared > 0 ? min(1, max(0, (apx * abx + apy * aby) / lengthSquared)) : 0
            let dx = apx - t * abx, dy = apy - t * aby
            minDistance = min(minDistance, (dx * dx + dy * dy).squareRoot())
        }
        return minDistance
    }
    
    /// Linear-interpolated percentile (0...1) of the values
    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let position = p * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(sorted.count - 1, lower + 1)
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
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
