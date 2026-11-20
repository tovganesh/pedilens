//
//  CoreMLWoundDetectionService.swift
//  PediLens
//
//  Service for detecting wound boundaries in images using CoreML and Vision framework.
//  Implements multi-wound detection, spatial clustering, and false-positive suppression
//  for boundary artifacts and non-tissue regions.
//

import Foundation
import UIKit
import Vision
import CoreML
import CoreGraphics

/// Concrete implementation of WoundDetectionService using CoreML and Vision framework
class CoreMLWoundDetectionService: WoundDetectionServiceProtocol {
    
    // MARK: - Properties
    
    /// The loaded CoreML model for wound segmentation
    private var woundModel: VNCoreMLModel?
    
    /// Confidence threshold for binary segmentation mask
    private let segmentationThreshold: Float = 0.50

    /// Minimum contour area in pixels to be considered a wound (suppresses micro-noise)
    private let minimumWoundAreaPixels: CGFloat = 80.0

    /// Douglas-Peucker simplification tolerance in mask pixels.
    /// Applied before scaling to image space so it removes staircase jaggies
    /// without eroding real shape detail, independent of mask resolution.
    private let maskSimplificationTolerance: CGFloat = 0.5
    
    // MARK: - Initialization
    
    init() {
        setupModel()
    }
    
    // MARK: - Model Setup
    
    private func setupModel() {
        // Attempt to load the compiled CoreML model from the bundle
        if let modelURL = Bundle.main.url(forResource: "WoundSegmentation", withExtension: "mlmodelc") {
            do {
                let mlModel = try MLModel(contentsOf: modelURL)
                woundModel = try VNCoreMLModel(for: mlModel)
                print("✅ CoreML WoundSegmentation model loaded successfully")
            } catch {
                print("⚠️ Failed to load CoreML model from URL: \(error.localizedDescription)")
                woundModel = createMockModel()
            }
        } else {
            print("⚠️ WoundSegmentation.mlmodelc not found in bundle, using algorithmic fallback")
            woundModel = createMockModel()
        }
    }
    
    /// Creates a mock model for development/testing when actual model is unavailable
    private func createMockModel() -> VNCoreMLModel? {
        print("ℹ️ Mock model will generate synthetic wound boundaries for testing")
        return nil
    }
    
    // MARK: - Public Methods
    
    /// Detects the primary wound boundary in an image
    func detectWoundBoundary(in image: UIImage, calibration: MeasurementCalibration?) async throws -> WoundBoundary {
        let boundaries = try await detectMultipleWoundBoundaries(in: image, calibration: calibration)
        guard let primary = boundaries.first else {
            throw WoundDetectionError.noContoursFound
        }
        return primary
    }
    
    /// Detects all distinct wound boundaries in an image
    func detectMultipleWoundBoundaries(in image: UIImage, calibration: MeasurementCalibration?) async throws -> [WoundBoundary] {
        // Check cache first
        let cacheKey = "wound_multi_\(image.hashValue)"
        if let cachedBoundaries = PerformanceOptimizer.shared.getCachedMultipleDetections(for: cacheKey) {
            print("✅ Returning cached multi-wound boundaries")
            return cachedBoundaries
        }

        // Boundaries are expressed in `image.size` (display orientation), but `cgImage`
        // holds the raw sensor-oriented pixels. Normalize so both agree before analysis.
        let orientedImage = image.orientationNormalized()
        guard let cgImage = orientedImage.cgImage else {
            throw WoundDetectionError.invalidImage
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // If real model is available, use it; otherwise use advanced algorithmic multi-wound extraction
        if let model = woundModel {
            do {
                let output = try await performVisionRequest(cgImage: cgImage, model: model)
                let coarseBoundaries = try processMultiWoundSegmentationOutput(output, originalImage: orientedImage)
                let boundaries = await refineBoundaries(coarseBoundaries, cgImage: cgImage, imageSize: orientedImage.size, model: model)

                PerformanceOptimizer.shared.cacheMultipleDetections(boundaries, for: cacheKey)

                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                print("⏱️ CoreML multi-wound detection completed in \(String(format: "%.3f", executionTime))s, found \(boundaries.count) wound(s)")

                return boundaries
            } catch WoundDetectionError.noContoursFound {
                // The model ran successfully and found no wound; don't second-guess it with the heuristic
                throw WoundDetectionError.noContoursFound
            } catch {
                print("⚠️ CoreML Vision request failed: \(error.localizedDescription), falling back to algorithmic detection")
            }
        }

        // Algorithmic multi-wound detection fallback
        print("ℹ️ Using heuristic color-based wound detection")
        let boundaries = try await detectMultipleBoundariesAlgorithmically(in: orientedImage, cgImage: cgImage)
        PerformanceOptimizer.shared.cacheMultipleDetections(boundaries, for: cacheKey)
        return boundaries
    }
    
    /// Refines an existing boundary with user adjustments
    func refineDetection(_ boundary: WoundBoundary, with userAdjustments: [CGPoint]) -> WoundBoundary {
        WoundDetectionService().refineDetection(boundary, with: userAdjustments)
    }
    
    /// Processes segmentation mask into multiple distinct wound boundaries
    private func processMultiWoundSegmentationOutput(
        _ output: ModelSegmentationOutput,
        originalImage: UIImage
    ) throws -> [WoundBoundary] {
        let imageSize = originalImage.size
        let mask = output.mask
        let maskHeight = mask.count
        guard maskHeight > 0 else { throw WoundDetectionError.noContoursFound }
        let maskWidth = mask[0].count
        
        // Find connected components in the binary segmentation mask
        let components = findConnectedComponents(in: mask)
        
        guard !components.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        var boundaries: [WoundBoundary] = []
        let scaleX = imageSize.width / CGFloat(maskWidth)
        let scaleY = imageSize.height / CGFloat(maskHeight)
        
        for (index, component) in components.enumerated() {
            guard component.pixelCount >= Int(minimumWoundAreaPixels) else { continue }
            
            // Extract perimeter contour of component (mask coordinates)
            let rawContour = extractContour(for: component)
            guard rawContour.count >= 3 else { continue }

            // Filter out border-touching false positives (sheets, garment edges)
            if touchesFrameEdge(contour: rawContour, maskWidth: maskWidth, maskHeight: maskHeight, margin: 4) {
                continue
            }

            // Simplify in mask space, then scale points to original image coordinate space
            let simplified = douglasPeucker(points: rawContour, tolerance: maskSimplificationTolerance)
                .map { pt in CGPoint(x: pt.x * scaleX, y: pt.y * scaleY) }
            guard simplified.count >= 3 else { continue }
            
            let boundingBox = calculateBoundingBox(for: simplified)
            let colorHex = AnnotatedWound.colorPalette[index % AnnotatedWound.colorPalette.count]
            
            let boundary = WoundBoundary(
                id: UUID(),
                woundNumber: boundaries.count + 1,
                points: simplified,
                confidence: output.averageConfidence,
                boundingBox: boundingBox,
                detectionMethod: .automatic(modelVersion: "CoreML-1.0"),
                label: "Wound #\(boundaries.count + 1)",
                colorHex: colorHex
            )
            boundaries.append(boundary)
        }
        
        guard !boundaries.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }
        
        return boundaries
    }
    
    // MARK: - Region-of-Interest Refinement
    
    /// Crop side relative to the wound's larger dimension. The model was trained on photos where
    /// wounds occupy a modest share of the frame; tighter crops (e.g. 1.6×, wound filling ~60%
    /// of the crop) under-segment by ~15%, while 3× keeps periwound context and traces cleanly.
    private let refinementCropMargin: CGFloat = 3.0
    
    /// Re-segments each wound on a square crop around it.
    ///
    /// The full-frame pass sees the whole photo at 256 × 256, so one mask pixel spans several
    /// millimetres on a typical photo and small ulcers are traced coarsely. Running the model
    /// again on a tight crop gives the same wound many more mask pixels. A refined outline is
    /// kept only when it is plausible; otherwise the coarse outline stands.
    private func refineBoundaries(
        _ boundaries: [WoundBoundary],
        cgImage: CGImage,
        imageSize: CGSize,
        model: VNCoreMLModel
    ) async -> [WoundBoundary] {
        var refined: [WoundBoundary] = []
        for boundary in boundaries {
            if let improved = await refineBoundary(boundary, cgImage: cgImage, imageSize: imageSize, model: model) {
                refined.append(improved)
            } else {
                refined.append(boundary)
            }
        }
        return refined
    }
    
    private func refineBoundary(
        _ boundary: WoundBoundary,
        cgImage: CGImage,
        imageSize: CGSize,
        model: VNCoreMLModel
    ) async -> WoundBoundary? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        
        // Boundaries are in image points; crops are taken in pixels
        let pixelsPerPoint = CGFloat(cgImage.width) / imageSize.width
        let box = boundary.boundingBox
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // Square crop (the model expects undistorted content), shifted to stay inside the image
        let side = (max(box.width, box.height) * refinementCropMargin * pixelsPerPoint).rounded(.up)
        guard side >= 16, side < min(imageWidth, imageHeight) * 0.8 else {
            // Large wounds already have ample resolution in the full-frame pass
            return nil
        }
        let originX = min(max(0, box.midX * pixelsPerPoint - side / 2), imageWidth - side).rounded(.down)
        let originY = min(max(0, box.midY * pixelsPerPoint - side / 2), imageHeight - side).rounded(.down)
        let cropRect = CGRect(x: originX, y: originY, width: side, height: side)
        
        guard let crop = cgImage.cropping(to: cropRect),
              let output = try? await performVisionRequest(cgImage: crop, model: model),
              let maskWidth = output.mask.first?.count, maskWidth > 0 else {
            return nil
        }
        let maskHeight = output.mask.count
        let maskToPoints = CGSize(
            width: cropRect.width / CGFloat(maskWidth) / pixelsPerPoint,
            height: cropRect.height / CGFloat(maskHeight) / pixelsPerPoint
        )
        let cropOriginPoints = CGPoint(x: cropRect.minX / pixelsPerPoint, y: cropRect.minY / pixelsPerPoint)
        
        // Pick the component centered within the coarse wound's box (other wounds may share the crop)
        let candidates = findConnectedComponents(in: output.mask).filter { component in
            guard component.pixelCount >= Int(minimumWoundAreaPixels) else { return false }
            let centroid = component.pixels.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
            let center = CGPoint(
                x: cropOriginPoints.x + (centroid.x / CGFloat(component.pixelCount) + 0.5) * maskToPoints.width,
                y: cropOriginPoints.y + (centroid.y / CGFloat(component.pixelCount) + 0.5) * maskToPoints.height
            )
            return box.contains(center)
        }
        guard let component = candidates.max(by: { $0.pixelCount < $1.pixelCount }) else { return nil }
        
        let contour = extractContour(for: component)
        // A wound running off the crop edge is not fully captured; keep the coarse outline
        guard contour.count >= 3,
              !touchesFrameEdge(contour: contour, maskWidth: maskWidth, maskHeight: maskHeight, margin: 2) else {
            return nil
        }
        
        let points = douglasPeucker(points: contour, tolerance: maskSimplificationTolerance).map { point in
            CGPoint(
                x: cropOriginPoints.x + point.x * maskToPoints.width,
                y: cropOriginPoints.y + point.y * maskToPoints.height
            )
        }
        guard points.count >= 3 else { return nil }
        
        // Reject outlines that disagree wildly with the coarse pass
        let coarseArea = polygonArea(boundary.points)
        let refinedArea = polygonArea(points)
        guard coarseArea > 0, (0.5...2.0).contains(refinedArea / coarseArea) else {
            print("⚠️ Discarding refined outline for wound #\(boundary.woundNumber): area ratio \(String(format: "%.2f", refinedArea / max(coarseArea, 1)))")
            return nil
        }
        
        return WoundBoundary(
            id: boundary.id,
            woundNumber: boundary.woundNumber,
            points: points,
            confidence: output.averageConfidence,
            boundingBox: calculateBoundingBox(for: points),
            detectionMethod: boundary.detectionMethod,
            label: boundary.label,
            colorHex: boundary.colorHex
        )
    }
    
    private func polygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for i in 0..<points.count {
            let a = points[i], b = points[(i + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }
    
    // MARK: - Algorithmic Multi-Wound Detection Fallback
    
    /// Performs computer vision and erythema/tissue contrast analysis to detect multiple ulcers
    private func detectMultipleBoundariesAlgorithmically(
        in image: UIImage,
        cgImage: CGImage
    ) async throws -> [WoundBoundary] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let boundaries = try self.analyzeImageForWoundRegions(cgImage: cgImage, imageSize: image.size)
                    continuation.resume(returning: boundaries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func analyzeImageForWoundRegions(cgImage: CGImage, imageSize: CGSize) throws -> [WoundBoundary] {
        let width = cgImage.width
        let height = cgImage.height
        
        // Downsample for fast raster analysis (max dimension 512)
        let maxDim: CGFloat = 512.0
        let scale = min(1.0, maxDim / max(CGFloat(width), CGFloat(height)))
        let targetW = max(32, Int(CGFloat(width) * scale))
        let targetH = max(32, Int(CGFloat(height) * scale))
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw WoundDetectionError.invalidImage
        }
        
        var pixelData = [UInt8](repeating: 0, count: targetW * targetH * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: targetW,
            height: targetH,
            bitsPerComponent: 8,
            bytesPerRow: targetW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw WoundDetectionError.detectionFailed
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
        
        // Binary mask of ulcerous erythema/slough tissue pixels
        var woundMask = Array(repeating: Array(repeating: false, count: targetW), count: targetH)
        
        // Frame edge margin to discard border shadows, garments, or bed sheets
        let edgeMarginX = max(4, Int(Double(targetW) * 0.035))
        let edgeMarginY = max(4, Int(Double(targetH) * 0.035))
        
        for y in edgeMarginY..<(targetH - edgeMarginY) {
            for x in edgeMarginX..<(targetW - edgeMarginX) {
                let offset = (y * targetW + x) * 4
                let r = Float(pixelData[offset])
                let g = Float(pixelData[offset + 1])
                let b = Float(pixelData[offset + 2])
                
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                
                // Exclude very dark shadows/black coats (luminance < 35) or washed out highlights (> 245)
                guard luminance > 35 && luminance < 245 else { continue }
                
                // Diabetic ulcer tissue heuristics:
                // 1. Erythema / granulation: Red dominance over green and blue with elevated contrast
                let isErythematous = (r > 75) && (r - g > 25) && (r - b > 30) && (r / max(1.0, (g + b) * 0.5) > 1.35)
                
                // 2. Fibrin / slough / ulcer base: Yellowish pale necrotic base (high R and G, lower B)
                let isSlough = (r > 130) && (g > 105) && (b < 100) && (r - b > 45) && (abs(r - g) < 55)
                
                // 3. Central crater deep ulceration: Darker reddish ulcer cavity
                let isDeepCrater = (r > 55) && (r < 140) && (r - g > 18) && (r - b > 18) && (luminance < 110)
                
                if isErythematous || isSlough || isDeepCrater {
                    woundMask[y][x] = true
                }
            }
        }
        
        // Connected component labeling on woundMask
        let components = findConnectedComponents(in: woundMask)
        
        // Minimum pixel area at downsampled resolution (e.g. at 512, at least 45 pixels)
        let minCompPixels = max(35, Int(Double(targetW * targetH) * 0.0003))
        let validComponents = components.filter { $0.pixelCount >= minCompPixels }
        
        // Sort descending by area
        let sorted = validComponents.sorted { $0.pixelCount > $1.pixelCount }
        
        var boundaries: [WoundBoundary] = []
        let scaleBackX = imageSize.width / CGFloat(targetW)
        let scaleBackY = imageSize.height / CGFloat(targetH)
        
        // Take up to top 6 distinct lesions
        for (idx, comp) in sorted.prefix(6).enumerated() {
            let contour = extractContour(for: comp)
            guard contour.count >= 3 else { continue }

            // Reject any contour touching the outer frame edge
            if touchesFrameEdge(contour: contour, maskWidth: targetW, maskHeight: targetH, margin: 4) {
                continue
            }

            let simplified = douglasPeucker(points: contour, tolerance: maskSimplificationTolerance)
                .map { pt in CGPoint(x: pt.x * scaleBackX, y: pt.y * scaleBackY) }
            guard simplified.count >= 3 else { continue }
            
            let bbox = calculateBoundingBox(for: simplified)
            let colorHex = AnnotatedWound.colorPalette[idx % AnnotatedWound.colorPalette.count]
            
            let woundNumber = boundaries.count + 1
            let boundary = WoundBoundary(
                id: UUID(),
                woundNumber: woundNumber,
                points: simplified,
                confidence: Float(comp.confidence),
                boundingBox: bbox,
                detectionMethod: .automatic(modelVersion: "Heuristic-CV-2.0"),
                label: "Wound #\(woundNumber)",
                colorHex: colorHex
            )
            boundaries.append(boundary)
        }
        
        // Never fabricate a boundary: report failure so the user can trace manually
        guard !boundaries.isEmpty else {
            throw WoundDetectionError.noContoursFound
        }

        return boundaries
    }
    
    // MARK: - Frame Edge Filtering
    
    /// Checks if a contour touches or comes within margin pixels of the outer image border
    private func touchesFrameEdge(contour: [CGPoint], maskWidth: Int, maskHeight: Int, margin: Int) -> Bool {
        let m = CGFloat(margin)
        let w = CGFloat(maskWidth) - m
        let h = CGFloat(maskHeight) - m
        return contour.contains { pt in
            pt.x <= m || pt.x >= w || pt.y <= m || pt.y >= h
        }
    }
    
    // MARK: - Connected Component Analysis
    
    private struct Component {
        var pixels: [CGPoint]
        var pixelCount: Int { pixels.count }
        var confidence: Double
    }
    
    private func findConnectedComponents(in mask: [[Bool]]) -> [Component] {
        let height = mask.count
        guard height > 0 else { return [] }
        let width = mask[0].count
        
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        var components: [Component] = []
        
        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] && !visited[y][x] {
                    // Flood fill / BFS
                    var compPixels: [CGPoint] = []
                    var queue: [(Int, Int)] = [(x, y)]
                    var head = 0
                    visited[y][x] = true

                    // Index-based dequeue keeps BFS linear (removeFirst is O(n))
                    while head < queue.count {
                        let (cx, cy) = queue[head]
                        head += 1
                        compPixels.append(CGPoint(x: cx, y: cy))
                        
                        let neighbors = [
                            (cx + 1, cy), (cx - 1, cy),
                            (cx, cy + 1), (cx, cy - 1)
                        ]
                        
                        for (nx, ny) in neighbors {
                            if nx >= 0 && nx < width && ny >= 0 && ny < height {
                                if mask[ny][nx] && !visited[ny][nx] {
                                    visited[ny][nx] = true
                                    queue.append((nx, ny))
                                }
                            }
                        }
                    }
                    
                    if compPixels.count >= 20 {
                        let conf = min(0.96, 0.70 + Double(compPixels.count) / Double(width * height) * 5.0)
                        components.append(Component(pixels: compPixels, confidence: conf))
                    }
                }
            }
        }
        
        return components
    }
    
    // MARK: - Contour Extraction & Simplification
    
    /// Traces the outer boundary of a 4-connected component as an ordered, closed polygon.
    ///
    /// Walks the pixel-edge ("crack") boundary clockwise with the region always on the
    /// right-hand side, so concave shapes are followed correctly and interior holes are
    /// ignored. Each emitted vertex is the midpoint of a boundary edge, which chamfers
    /// the pixel staircase: the enclosed area closely matches the pixel count and the
    /// perimeter is not inflated by stair-stepping.
    /// - Returns: Polygon in mask coordinates, where pixel (x, y) spans [x, x+1] × [y, y+1].
    private func extractContour(for component: Component) -> [CGPoint] {
        guard !component.pixels.isEmpty else { return [] }

        // Rasterize the component into a local grid padded by one pixel on each side
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for pt in component.pixels {
            minX = min(minX, Int(pt.x)); maxX = max(maxX, Int(pt.x))
            minY = min(minY, Int(pt.y)); maxY = max(maxY, Int(pt.y))
        }
        let originX = minX - 1
        let originY = minY - 1
        let gridW = maxX - minX + 3
        let gridH = maxY - minY + 3
        var grid = [Bool](repeating: false, count: gridW * gridH)
        for pt in component.pixels {
            grid[(Int(pt.y) - originY) * gridW + (Int(pt.x) - originX)] = true
        }
        func inside(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < gridW && y >= 0 && y < gridH && grid[y * gridW + x]
        }

        // Start at the top-left corner of the first pixel in row-major order. Its top
        // edge is guaranteed to be on the outer boundary.
        guard let startIndex = grid.firstIndex(of: true) else { return [] }
        let startX = startIndex % gridW
        let startY = startIndex / gridW

        // Directions: 0 = +x (right), 1 = +y (down), 2 = -x (left), 3 = -y (up)
        let stepX = [1, 0, -1, 0]
        let stepY = [0, 1, 0, -1]

        var vx = startX, vy = startY, dir = 0
        var contour: [CGPoint] = []
        let maxSteps = 4 * (gridW + 1) * (gridH + 1)

        for _ in 0..<maxSteps {
            // Emit midpoint of the edge being traversed, converted back to mask coordinates
            contour.append(CGPoint(
                x: CGFloat(vx + originX) + CGFloat(stepX[dir]) * 0.5,
                y: CGFloat(vy + originY) + CGFloat(stepY[dir]) * 0.5
            ))
            vx += stepX[dir]
            vy += stepY[dir]

            // The two pixels ahead of vertex (vx, vy), on the left and right of travel
            let aheadLeft: Bool
            let aheadRight: Bool
            switch dir {
            case 0: aheadLeft = inside(vx, vy - 1); aheadRight = inside(vx, vy)
            case 1: aheadLeft = inside(vx, vy); aheadRight = inside(vx - 1, vy)
            case 2: aheadLeft = inside(vx - 1, vy); aheadRight = inside(vx - 1, vy - 1)
            default: aheadLeft = inside(vx - 1, vy - 1); aheadRight = inside(vx, vy - 1)
            }

            if !aheadRight {
                dir = (dir + 1) % 4      // Region falls away: turn right
            } else if aheadLeft {
                dir = (dir + 3) % 4      // Region blocks the way: turn left
            }                            // Otherwise continue straight

            if vx == startX && vy == startY && dir == 0 {
                break
            }
        }

        return contour
    }
    
    private func douglasPeucker(points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        var maxDistance: CGFloat = 0
        var maxIndex = 0
        let first = points.first!
        let last = points.last!
        
        for i in 1..<(points.count - 1) {
            let dist = perpendicularDistance(point: points[i], lineStart: first, lineEnd: last)
            if dist > maxDistance {
                maxDistance = dist
                maxIndex = i
            }
        }
        
        if maxDistance > tolerance {
            let left = douglasPeucker(points: Array(points[0...maxIndex]), tolerance: tolerance)
            let right = douglasPeucker(points: Array(points[maxIndex..<points.count]), tolerance: tolerance)
            return left + right.dropFirst()
        } else {
            return [first, last]
        }
    }
    
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        if dx == 0 && dy == 0 {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        let num = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        let den = hypot(dx, dy)
        return num / den
    }
    
    private func calculateBoundingBox(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))
    }
    
    // MARK: - Vision & CoreML Helpers
    
    private func performVisionRequest(cgImage: CGImage, model: VNCoreMLModel) async throws -> ModelSegmentationOutput {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    print("❌ Vision request error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    // The bundled model emits a MultiArray (1 × 256 × 256 × 1), which Vision
                    // surfaces as a feature-value observation. Image-output models surface as
                    // pixel-buffer observations; support both.
                    if let multiArray = (request.results?.first as? VNCoreMLFeatureValueObservation)?
                        .featureValue.multiArrayValue {
                        continuation.resume(returning: try self.extractSegmentationOutput(from: multiArray))
                    } else if let pixelBuffer = (request.results?.first as? VNPixelBufferObservation)?.pixelBuffer {
                        continuation.resume(returning: try self.extractSegmentationOutput(from: pixelBuffer))
                    } else {
                        print("❌ Unexpected CoreML result type: \(String(describing: request.results?.first))")
                        continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // The model was trained on images stretched to 256 × 256 (no letterboxing), so the
            // mask maps linearly onto the full image: mask x/y ∝ image x/y.
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private struct ModelSegmentationOutput {
        let mask: [[Bool]]
        let averageConfidence: Float
    }
    
    /// Thresholds a probability map into a binary mask, tracking mean wound-pixel confidence
    private func buildSegmentationOutput(width: Int, height: Int, probability: (Int, Int) -> Float) -> ModelSegmentationOutput {
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        var sum: Float = 0.0
        var woundPixelCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let p = probability(x, y)
                if p >= segmentationThreshold {
                    mask[y][x] = true
                    sum += p
                    woundPixelCount += 1
                }
            }
        }
        
        let avgConf = woundPixelCount > 0 ? (sum / Float(woundPixelCount)) : 0.0
        return ModelSegmentationOutput(mask: mask, averageConfidence: avgConf)
    }
    
    /// Reads a segmentation probability map from a MultiArray output.
    /// Accepts any layout whose non-singleton dimensions are exactly (height, width),
    /// e.g. NHWC [1, H, W, 1], NCHW [1, 1, H, W], or [H, W].
    private func extractSegmentationOutput(from multiArray: MLMultiArray) throws -> ModelSegmentationOutput {
        let shape = multiArray.shape.map { $0.intValue }
        let strides = multiArray.strides.map { $0.intValue }
        let spatialDims = shape.indices.filter { shape[$0] > 1 }
        guard spatialDims.count == 2 else {
            print("❌ Unsupported segmentation output shape: \(shape)")
            throw WoundDetectionError.detectionFailed
        }
        
        let height = shape[spatialDims[0]]
        let width = shape[spatialDims[1]]
        let strideY = strides[spatialDims[0]]
        let strideX = strides[spatialDims[1]]
        
        switch multiArray.dataType {
        case .float32:
            let pointer = multiArray.dataPointer.assumingMemoryBound(to: Float32.self)
            return buildSegmentationOutput(width: width, height: height) { x, y in
                pointer[y * strideY + x * strideX]
            }
        case .double:
            let pointer = multiArray.dataPointer.assumingMemoryBound(to: Double.self)
            return buildSegmentationOutput(width: width, height: height) { x, y in
                Float(pointer[y * strideY + x * strideX])
            }
        default:
            // Slower generic path (e.g. Float16 outputs)
            return buildSegmentationOutput(width: width, height: height) { x, y in
                var index = [NSNumber](repeating: 0, count: shape.count)
                index[spatialDims[0]] = NSNumber(value: y)
                index[spatialDims[1]] = NSNumber(value: x)
                return multiArray[index].floatValue
            }
        }
    }
    
    /// Reads a segmentation probability map from an image-type output
    private func extractSegmentationOutput(from pixelBuffer: CVPixelBuffer) throws -> ModelSegmentationOutput {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw WoundDetectionError.detectionFailed
        }
        
        switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
        case kCVPixelFormatType_OneComponent32Float:
            return buildSegmentationOutput(width: width, height: height) { x, y in
                baseAddress.load(fromByteOffset: y * bytesPerRow + x * MemoryLayout<Float32>.size, as: Float32.self)
            }
        case kCVPixelFormatType_OneComponent8:
            return buildSegmentationOutput(width: width, height: height) { x, y in
                Float(baseAddress.load(fromByteOffset: y * bytesPerRow + x, as: UInt8.self)) / 255.0
            }
        default:
            print("❌ Unsupported segmentation pixel format: \(CVPixelBufferGetPixelFormatType(pixelBuffer))")
            throw WoundDetectionError.detectionFailed
        }
    }
}
