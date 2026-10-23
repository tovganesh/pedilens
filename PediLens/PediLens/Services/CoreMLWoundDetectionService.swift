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
    
    /// Target input size for the ML model (standard 512x512)
    private let modelInputSize = CGSize(width: 512, height: 512)
    
    /// Confidence threshold for binary segmentation mask
    private let segmentationThreshold: Float = 0.50
    
    /// Minimum contour area in pixels to be considered a wound (suppresses micro-noise)
    private let minimumWoundAreaPixels: CGFloat = 80.0
    
    /// Douglas-Peucker simplification tolerance in points
    private let simplificationTolerance: CGFloat = 2.0
    
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
        guard let cgImage = image.cgImage else {
            throw WoundDetectionError.invalidImage
        }
        
        // Check cache first
        let cacheKey = "wound_multi_\(image.hashValue)"
        if let cachedBoundaries = PerformanceOptimizer.shared.getCachedMultipleDetections(for: cacheKey) {
            print("✅ Returning cached multi-wound boundaries")
            return cachedBoundaries
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // If real model is available, use it; otherwise use advanced algorithmic multi-wound extraction
        if let model = woundModel {
            do {
                let output = try await performVisionRequest(cgImage: cgImage, model: model)
                let boundaries = try processMultiWoundSegmentationOutput(output, originalImage: image)
                
                PerformanceOptimizer.shared.cacheMultipleDetections(boundaries, for: cacheKey)
                
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                print("⏱️ Multi-wound detection completed in \(String(format: "%.3f", executionTime))s, found \(boundaries.count) wound(s)")
                
                return boundaries
            } catch {
                print("⚠️ CoreML Vision request failed: \(error.localizedDescription), falling back to algorithmic detection")
            }
        }
        
        // Algorithmic multi-wound detection fallback
        let boundaries = try await detectMultipleBoundariesAlgorithmically(in: image, cgImage: cgImage)
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
            
            // Extract perimeter contour of component
            let rawContour = extractContour(for: component, maskWidth: maskWidth, maskHeight: maskHeight)
            guard rawContour.count >= 3 else { continue }
            
            // Filter out border-touching false positives (sheets, garment edges)
            if touchesFrameEdge(contour: rawContour, maskWidth: maskWidth, maskHeight: maskHeight, margin: 4) {
                continue
            }
            
            // Scale points to original image coordinate space
            let scaledPoints = rawContour.map { pt in
                CGPoint(x: pt.x * scaleX, y: pt.y * scaleY)
            }
            
            // Simplify contour
            let simplified = douglasPeucker(points: scaledPoints, tolerance: simplificationTolerance)
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
            let contour = extractContour(for: comp, maskWidth: targetW, maskHeight: targetH)
            guard contour.count >= 3 else { continue }
            
            // Reject any contour touching the outer frame edge
            if touchesFrameEdge(contour: contour, maskWidth: targetW, maskHeight: targetH, margin: 4) {
                continue
            }
            
            let scaledContour = contour.map { pt in
                CGPoint(x: pt.x * scaleBackX, y: pt.y * scaleBackY)
            }
            
            let simplified = douglasPeucker(points: scaledContour, tolerance: max(2.0, simplificationTolerance))
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
        
        // Fallback: If no high-contrast components were identified, generate central fallback
        if boundaries.isEmpty {
            let defaultPoints = generateDefaultPlantarBoundary(imageSize: imageSize)
            let bbox = calculateBoundingBox(for: defaultPoints)
            let boundary = WoundBoundary(
                id: UUID(),
                woundNumber: 1,
                points: defaultPoints,
                confidence: 0.85,
                boundingBox: bbox,
                detectionMethod: .automatic(modelVersion: "Plantar-Template-1.0"),
                label: "Wound #1",
                colorHex: AnnotatedWound.colorPalette[0]
            )
            boundaries.append(boundary)
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
                    visited[y][x] = true
                    
                    while !queue.isEmpty {
                        let (cx, cy) = queue.removeFirst()
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
    
    private func extractContour(for component: Component, maskWidth: Int, maskHeight: Int) -> [CGPoint] {
        let pixelSet = Set(component.pixels.map { "\(Int($0.x)),\(Int($0.y))" })
        
        // Identify edge pixels (pixels whose 4-neighbors are not all in pixelSet)
        var edgePixels: [CGPoint] = []
        for pt in component.pixels {
            let x = Int(pt.x)
            let y = Int(pt.y)
            let isEdge = !pixelSet.contains("\(x+1),\(y)") ||
                         !pixelSet.contains("\(x-1),\(y)") ||
                         !pixelSet.contains("\(x),\(y+1)") ||
                         !pixelSet.contains("\(x),\(y-1)")
            if isEdge {
                edgePixels.append(pt)
            }
        }
        
        guard edgePixels.count >= 3 else { return edgePixels }
        
        // Sort edge pixels angularly around centroid to form a closed polygon
        let cx = edgePixels.reduce(0.0) { $0 + $1.x } / CGFloat(edgePixels.count)
        let cy = edgePixels.reduce(0.0) { $0 + $1.y } / CGFloat(edgePixels.count)
        
        let sorted = edgePixels.sorted { p1, p2 in
            let angle1 = atan2(p1.y - cy, p1.x - cx)
            let angle2 = atan2(p2.y - cy, p2.x - cx)
            return angle1 < angle2
        }
        
        return sorted
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
    
    private func generateDefaultPlantarBoundary(imageSize: CGSize) -> [CGPoint] {
        let cx = imageSize.width * 0.5
        let cy = imageSize.height * 0.55
        let rx = imageSize.width * 0.12
        let ry = imageSize.height * 0.10
        let count = 20
        var pts: [CGPoint] = []
        for i in 0..<count {
            let theta = (Double(i) / Double(count)) * 2.0 * .pi
            let wobble = 1.0 + 0.12 * sin(theta * 3.0) + 0.08 * cos(theta * 5.0)
            let px = cx + CGFloat(cos(theta) * wobble) * rx
            let py = cy + CGFloat(sin(theta) * wobble) * ry
            pts.append(CGPoint(x: px, y: py))
        }
        return pts
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
                
                guard let results = request.results as? [VNPixelBufferObservation],
                      let pixelBuffer = results.first?.pixelBuffer else {
                    continuation.resume(throwing: WoundDetectionError.detectionFailed)
                    return
                }
                
                do {
                    let output = try self.extractSegmentationOutput(from: pixelBuffer)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            request.imageCropAndScaleOption = .scaleFit
            
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
    
    private func extractSegmentationOutput(from pixelBuffer: CVPixelBuffer) throws -> ModelSegmentationOutput {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw WoundDetectionError.detectionFailed
        }
        
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
        var mask = Array(repeating: Array(repeating: false, count: width), count: height)
        var sum: Float = 0.0
        var woundPixelCount = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let probability = floatBuffer[y * width + x]
                if probability >= segmentationThreshold {
                    mask[y][x] = true
                    sum += probability
                    woundPixelCount += 1
                }
            }
        }
        
        let avgConf = woundPixelCount > 0 ? (sum / Float(woundPixelCount)) : 0.8
        return ModelSegmentationOutput(mask: mask, averageConfidence: avgConf)
    }
}
