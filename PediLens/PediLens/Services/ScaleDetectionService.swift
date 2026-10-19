//
//  ScaleDetectionService.swift
//  PediLens
//
//  Created by PediLens Team
//
//  Service for detecting reference scale objects in images using Vision framework.
//  Supports calibration cards, credit cards, standard coins, and fuzzy anatomical references.
//

import Foundation
import UIKit
import Vision
import CoreGraphics

/// Extension to convert UIImage.Orientation to CGImagePropertyOrientation
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Service for detecting reference scale objects in images
class ScaleDetectionService {
    
    // MARK: - Properties
    
    /// Minimum confidence threshold for detection
    private let minimumConfidence: Float = 0.5
    
    // MARK: - Initialization
    
    init() {
        // Service is ready to use
    }
    
    // MARK: - Public Methods
    
    /// Detects reference scale or object in an image
    /// - Parameter image: Image to analyze
    /// - Returns: Reference scale information if detected
    func detectReferenceScale(in image: UIImage) async throws -> ReferenceScaleInfo? {
        print("🔍 Detecting reference scale in image...")
        
        // 1. Try Calibration Card (ground truth calibration targets with QR/Barcode)
        do {
            if let calibrationCard = try await detectCalibrationCard(in: image) {
                print("✅ Detected calibration card")
                return calibrationCard
            }
        } catch {
            print("⚠️ Calibration card detection error: \(error.localizedDescription)")
        }
        
        // 2. Try Credit Card (verified rectangular target with ISO 7810 aspect ratio 1.586)
        do {
            if let creditCard = try await detectCreditCard(in: image) {
                print("✅ Detected credit card")
                return creditCard
            }
        } catch {
            print("⚠️ Credit card detection error: \(error.localizedDescription)")
        }
        
        // 3. Try Fuzzy Anatomical Scale Detection (Foot & Great Toe, Hand & Finger)
        // IN CLINICAL FOOT ULCER PHOTOGRAPHY, PATIENT ANATOMY IS THE PRIMARY INHERENT FRAME OF REFERENCE!
        // Automatically identifies greater toe or foot breadth and applies anatomical calibration.
        do {
            if let anatomical = try await detectAnatomicalScale(in: image) {
                print("✅ Detected fuzzy anatomical scale (\(anatomical.objectType.displayName))")
                return anatomical
            }
        } catch {
            print("⚠️ Anatomical detection error: \(error.localizedDescription)")
        }
        
        // 4. Try US Quarter detection (with strict verification: non-skin, non-wound, high circularity)
        do {
            if let quarter = try await detectUSQuarter(in: image) {
                print("✅ Detected verified US quarter")
                return quarter
            }
        } catch {
            print("⚠️ Quarter detection error: \(error.localizedDescription)")
        }
        
        // 5. Try Indian 1 Rupee Coin detection (with strict verification)
        do {
            if let rupeeCoin = try await detectINROneRupee(in: image) {
                print("✅ Detected verified INR 1 Rupee coin")
                return rupeeCoin
            }
        } catch {
            print("⚠️ INR coin detection error: \(error.localizedDescription)")
        }
        
        print("ℹ️ No reference scale detected")
        return nil
    }
    
    // MARK: - Detection Methods
    
    /// Detects credit card in image (standard dimensions: 85.6mm × 53.98mm)
    func detectCreditCard(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        // Use Vision framework to detect rectangles
        let rectangles = try await detectRectangles(in: cgImage, orientation: orientation)
        
        // Filter for credit card aspect ratio (85.6mm / 53.98mm ≈ 1.586)
        let creditCardAspectRatio: CGFloat = 85.6 / 53.98
        let tolerance: CGFloat = 0.18
        
        for rect in rectangles {
            // Convert normalized coordinates to pixel coordinates
            let pixelBox = VNImageRectForNormalizedRect(
                rect.boundingBox,
                Int(pixelWidth),
                Int(pixelHeight)
            )
            
            guard pixelBox.width > 0 && pixelBox.height > 0 else { continue }
            let aspectRatio = pixelBox.width / pixelBox.height
            
            let isLandscape = abs(aspectRatio - creditCardAspectRatio) / creditCardAspectRatio < tolerance
            let isPortrait = abs(aspectRatio - (1.0 / creditCardAspectRatio)) / (1.0 / creditCardAspectRatio) < tolerance
            
            if isLandscape || isPortrait {
                let scale = image.scale > 0 ? image.scale : 1.0
                let pointsBox = CGRect(
                    x: pixelBox.origin.x / scale,
                    y: pixelBox.origin.y / scale,
                    width: pixelBox.size.width / scale,
                    height: pixelBox.size.height / scale
                )
                
                let longDimension = max(pointsBox.width, pointsBox.height)
                let shortDimension = min(pointsBox.width, pointsBox.height)
                
                return ReferenceScaleInfo(
                    objectType: .creditCard,
                    boundingBox: pointsBox,
                    pixelWidth: longDimension,
                    pixelHeight: shortDimension,
                    confidence: rect.confidence,
                    detectedDimensions: CGSize(width: 85.6, height: 53.98)
                )
            }
        }
        
        return nil
    }
    
    /// Detects US quarter in image (standard diameter: 24.26mm)
    /// Enforces non-skin and non-wound tissue verification to prevent ulcers from being mistaken for coins.
    func detectUSQuarter(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        
        // Use Vision framework to detect circles via contours
        let circles = try await detectCircles(in: cgImage, orientation: orientation, pixelSize: pixelSize)
        
        let minDimension = min(pixelWidth, pixelHeight)
        guard minDimension > 0 else { return nil }
        
        // Quarter should be 3% to 35% of image minimum dimension and have non-tissue appearance
        let quarterCandidates = circles.filter { circle in
            let sizeRatio = circle.diameter / minDimension
            guard sizeRatio >= 0.03 && sizeRatio <= 0.35 else { return false }
            return Self.isNonTissueCircle(circle: circle, in: cgImage)
        }
        
        guard let bestCircle = quarterCandidates.max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }
        
        let scale = image.scale > 0 ? image.scale : 1.0
        let pointsBox = CGRect(
            x: bestCircle.boundingBox.origin.x / scale,
            y: bestCircle.boundingBox.origin.y / scale,
            width: bestCircle.boundingBox.size.width / scale,
            height: bestCircle.boundingBox.size.height / scale
        )
        let diameterInPoints = bestCircle.diameter / scale
        
        return ReferenceScaleInfo(
            objectType: .usQuarter,
            boundingBox: pointsBox,
            pixelWidth: diameterInPoints,
            pixelHeight: diameterInPoints,
            confidence: bestCircle.confidence,
            detectedDimensions: CGSize(width: 24.26, height: 24.26)
        )
    }
    
    /// Detects calibration card in image
    func detectCalibrationCard(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        // Look for QR code or barcode on calibration card
        let barcodes = try await detectBarcodes(in: cgImage, orientation: orientation)
        
        for barcode in barcodes {
            if let payloadString = barcode.payloadStringValue,
               payloadString.contains("PediLens") {
                let pixelBox = VNImageRectForNormalizedRect(
                    barcode.boundingBox,
                    Int(pixelWidth),
                    Int(pixelHeight)
                )
                
                let scale = image.scale > 0 ? image.scale : 1.0
                let pointsBox = CGRect(
                    x: pixelBox.origin.x / scale,
                    y: pixelBox.origin.y / scale,
                    width: pixelBox.size.width / scale,
                    height: pixelBox.size.height / scale
                )
                
                return ReferenceScaleInfo(
                    objectType: .calibrationCard,
                    boundingBox: pointsBox,
                    pixelWidth: pointsBox.width,
                    pixelHeight: pointsBox.height,
                    confidence: barcode.confidence,
                    detectedDimensions: CGSize(width: 100.0, height: 100.0)
                )
            }
        }
        
        return nil
    }
    
    /// Detects INR 1 Rupee coin in image (standard diameter: 20.00mm)
    func detectINROneRupee(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)
        
        let circles = try await detectCircles(in: cgImage, orientation: orientation, pixelSize: pixelSize)
        
        let minDimension = min(pixelWidth, pixelHeight)
        guard minDimension > 0 else { return nil }
        
        let coinCandidates = circles.filter { circle in
            let sizeRatio = circle.diameter / minDimension
            guard sizeRatio >= 0.02 && sizeRatio <= 0.35 else { return false }
            return Self.isNonTissueCircle(circle: circle, in: cgImage)
        }
        
        guard let bestCircle = coinCandidates.max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }
        
        let scale = image.scale > 0 ? image.scale : 1.0
        let pointsBox = CGRect(
            x: bestCircle.boundingBox.origin.x / scale,
            y: bestCircle.boundingBox.origin.y / scale,
            width: bestCircle.boundingBox.size.width / scale,
            height: bestCircle.boundingBox.size.height / scale
        )
        let diameterInPoints = bestCircle.diameter / scale
        
        return ReferenceScaleInfo(
            objectType: .inrOneRupee,
            boundingBox: pointsBox,
            pixelWidth: diameterInPoints,
            pixelHeight: diameterInPoints,
            confidence: bestCircle.confidence,
            detectedDimensions: CGSize(width: 20.00, height: 20.00)
        )
    }
    
    /// Detects anatomical scale reference in image (foot anatomy, great toe, or hand/finger) based on standard adult anthropometry
    func detectAnatomicalScale(in image: UIImage) async throws -> ReferenceScaleInfo? {
        // Priority 1: Foot anatomy & Great Toe detection (primary clinical subject for PediLens)
        if let footScale = try await detectFootAnatomy(in: image) {
            return footScale
        }
        
        // Priority 2: Clinician or patient finger detection
        if let fingerScale = try await detectHandOrFinger(in: image) {
            return fingerScale
        }
        
        return nil
    }
    
    /// Detects hand or finger in image using Vision human hand pose
    func detectHandOrFinger(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 2
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty else {
                return nil
            }
            
            for observation in observations {
                if let pip = try? observation.recognizedPoint(.indexPIP),
                   let dip = try? observation.recognizedPoint(.indexDIP),
                   pip.confidence > 0.4, dip.confidence > 0.4 {
                    
                    let p1 = CGPoint(x: pip.location.x * pixelWidth, y: (1 - pip.location.y) * pixelHeight)
                    let p2 = CGPoint(x: dip.location.x * pixelWidth, y: (1 - dip.location.y) * pixelHeight)
                    let dx = p2.x - p1.x
                    let dy = p2.y - p1.y
                    let pixelDist = sqrt(dx * dx + dy * dy)
                    
                    if pixelDist > 15 {
                        let scale = image.scale > 0 ? image.scale : 1.0
                        let spanInPoints = pixelDist / scale
                        let box = CGRect(
                            x: min(p1.x, p2.x) / scale - 10,
                            y: min(p1.y, p2.y) / scale - 10,
                            width: (abs(dx) + 20) / scale,
                            height: (abs(dy) + 20) / scale
                        )
                        return ReferenceScaleInfo(
                            objectType: .adultFinger,
                            boundingBox: box,
                            pixelWidth: spanInPoints,
                            pixelHeight: spanInPoints,
                            confidence: Float((pip.confidence + dip.confidence) / 2.0),
                            detectedDimensions: CGSize(width: 18.0, height: 18.0)
                        )
                    }
                }
            }
            return nil
        }.value
    }
    
    /// Detects human foot anatomy and automatically identifies the Great Toe (Hallux) or Forefoot breadth
    func detectFootAnatomy(in image: UIImage) async throws -> ReferenceScaleInfo? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        return try await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            
            var detectedBox: CGRect? = nil
            var detectedPixelBuffer: CVPixelBuffer? = nil
            var confidence: Float = 0.75
            
            // Attempt 1: Person/Limb segmentation (available iOS 15+)
            let segmentationRequest = VNGeneratePersonSegmentationRequest()
            segmentationRequest.qualityLevel = .balanced
            
            if (try? handler.perform([segmentationRequest])) != nil,
               let observation = segmentationRequest.results?.first {
                let pixelBuffer = observation.pixelBuffer
                if let maskBox = Self.extractBoundingBox(from: pixelBuffer, minCoverage: 0.08, maxCoverage: 0.95) {
                    detectedBox = maskBox
                    detectedPixelBuffer = pixelBuffer
                    confidence = 0.85
                }
            }
            
            // Attempt 2: Attention-based saliency (available iOS 13+)
            if detectedBox == nil {
                let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
                if (try? handler.perform([saliencyRequest])) != nil,
                   let saliencyResult = saliencyRequest.results?.first,
                   let salientObjects = saliencyResult.salientObjects,
                   let primarySalient = salientObjects.max(by: { ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height) }) {
                    
                    let coverage = primarySalient.boundingBox.width * primarySalient.boundingBox.height
                    if coverage >= 0.08 && coverage <= 0.92 {
                        detectedBox = primarySalient.boundingBox
                        confidence = 0.70
                    }
                }
            }
            
            guard let normBox = detectedBox else { return nil }
            
            // Convert normalized box to pixel coordinates
            let pixelBox = VNImageRectForNormalizedRect(normBox, Int(pixelWidth), Int(pixelHeight))
            guard pixelBox.width > 40 && pixelBox.height > 40 else { return nil }
            
            let scale = image.scale > 0 ? image.scale : 1.0
            
            // ATTEMPT GREAT TOE (HALLUX) IDENTIFICATION:
            // The Great Toe is the widest distal digit lobe (standard adult breadth: 26.0mm / 2.6cm).
            // In foot photography, it occupies approximately 20% to 35% of the transverse forefoot width.
            if let pixelBuffer = detectedPixelBuffer,
               let toeWidthInPixels = Self.detectGreatToeWidth(from: pixelBuffer, footBox: pixelBox) {
                
                let toePoints = toeWidthInPixels / scale
                let halluxBox = CGRect(
                    x: pixelBox.origin.x / scale,
                    y: pixelBox.origin.y / scale,
                    width: toePoints,
                    height: toePoints
                )
                
                print("🦶 Automatically identified Great Toe (Hallux): \(toeWidthInPixels) px wide (~26mm)")
                return ReferenceScaleInfo(
                    objectType: .adultHallux,
                    boundingBox: halluxBox,
                    pixelWidth: toePoints,
                    pixelHeight: toePoints,
                    confidence: confidence,
                    detectedDimensions: CGSize(width: 26.0, height: 26.0)
                )
            }
            
            // FOREFOOT BREADTH FALLBACK:
            // The transverse breadth across the metatarsal heads / ball of the foot (standard adult: 98.0mm / 9.8cm)
            let transverseBreadth = min(pixelBox.width, pixelBox.height)
            let pointsBox = CGRect(
                x: pixelBox.origin.x / scale,
                y: pixelBox.origin.y / scale,
                width: pixelBox.size.width / scale,
                height: pixelBox.size.height / scale
            )
            let breadthInPoints = transverseBreadth / scale
            
            print("🦶 Automatically identified Forefoot breadth: \(transverseBreadth) px wide (~98mm)")
            return ReferenceScaleInfo(
                objectType: .adultForefoot,
                boundingBox: pointsBox,
                pixelWidth: breadthInPoints,
                pixelHeight: breadthInPoints,
                confidence: confidence,
                detectedDimensions: CGSize(width: 98.0, height: 98.0)
            )
        }.value
    }
    
    /// Analyzes the distal margin of the foot mask to isolate the Great Toe (Hallux) breadth
    private static func detectGreatToeWidth(from pixelBuffer: CVPixelBuffer, footBox: CGRect) -> CGFloat? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let forefootBreadth = min(footBox.width, footBox.height)
        guard forefootBreadth > 50 else { return nil }
        
        // Scan the distal 25% margin of the segmented foot where the toe digits reside
        // In Vision orientation, Y=0 is top of image in pixel buffer coordinates
        let scanStart = max(0, Int(footBox.minY))
        let scanEnd = min(height - 1, Int(footBox.minY + footBox.height * 0.30))
        guard scanEnd > scanStart else { return nil }
        
        var maxLobeWidth = 0
        
        for y in scanStart...scanEnd {
            let rowOffset = y * bytesPerRow
            var currentRun = 0
            
            for x in 0..<width {
                let pixel = baseAddress.load(fromByteOffset: rowOffset + x, as: UInt8.self)
                if pixel > 64 {
                    currentRun += 1
                } else {
                    if currentRun > maxLobeWidth {
                        maxLobeWidth = currentRun
                    }
                    currentRun = 0
                }
            }
            if currentRun > maxLobeWidth {
                maxLobeWidth = currentRun
            }
        }
        
        // Great toe breadth is typically 20% to 35% of the total forefoot breadth
        let candidateWidth = CGFloat(maxLobeWidth)
        let ratio = candidateWidth / forefootBreadth
        if ratio >= 0.18 && ratio <= 0.38 && candidateWidth >= 15.0 {
            return candidateWidth
        }
        
        return nil
    }
    
    // MARK: - Vision Framework Helpers
    
    /// Detects rectangles in image
    private func detectRectangles(in cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> [VNRectangleObservation] {
        let minConf = self.minimumConfidence
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectRectanglesRequest()
            request.minimumConfidence = minConf
            request.maximumObservations = 10
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            return (request.results as? [VNRectangleObservation]) ?? []
        }.value
    }
    
    /// Detects circles in image
    private func detectCircles(in cgImage: CGImage, orientation: CGImagePropertyOrientation, pixelSize: CGSize) async throws -> [CircleDetection] {
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectContoursRequest()
            request.contrastAdjustment = 1.5
            request.detectsDarkOnLight = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            
            guard let results = request.results as? [VNContoursObservation] else {
                return []
            }
            
            var circles: [CircleDetection] = []
            for observation in results {
                for index in 0..<observation.contourCount {
                    guard let contour = try? observation.contour(at: index) else { continue }
                    if let circle = Self.isCircular(contour: contour, pixelSize: pixelSize, baseConfidence: observation.confidence) {
                        circles.append(circle)
                    }
                }
            }
            return circles
        }.value
    }
    
    /// Detects barcodes/QR codes in image
    private func detectBarcodes(in cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> [VNBarcodeObservation] {
        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            return (request.results as? [VNBarcodeObservation]) ?? []
        }.value
    }
    
    /// Extracts normalized bounding box of foreground pixels from CVPixelBuffer mask
    private static func extractBoundingBox(from pixelBuffer: CVPixelBuffer, minCoverage: Float, maxCoverage: Float) -> CGRect? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var foregroundCount = 0
        
        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let pixel = baseAddress.load(fromByteOffset: rowOffset + x, as: UInt8.self)
                if pixel > 64 {
                    foregroundCount += 1
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        
        let total = width * height
        guard total > 0 else { return nil }
        let coverage = Float(foregroundCount) / Float(total)
        guard coverage >= minCoverage && coverage <= maxCoverage else { return nil }
        guard maxX > minX && maxY > minY else { return nil }
        
        return CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(height - maxY) / CGFloat(height),
            width: CGFloat(maxX - minX) / CGFloat(width),
            height: CGFloat(maxY - minY) / CGFloat(height)
        )
    }
    
    /// Checks if a contour is circular in pixel coordinates with strict thresholding
    private static func isCircular(contour: VNContour, pixelSize: CGSize, baseConfidence: Float) -> CircleDetection? {
        guard contour.pointCount >= 10 else { return nil }
        
        let pixelBox = VNImageRectForNormalizedRect(
            contour.normalizedPath.boundingBox,
            Int(pixelSize.width),
            Int(pixelSize.height)
        )
        
        guard pixelBox.width > 0 && pixelBox.height > 0 else { return nil }
        
        let aspectRatio = pixelBox.width / pixelBox.height
        // Strict circularity constraint (within 12% of perfect 1.0 circle)
        guard abs(aspectRatio - 1.0) <= 0.12 else {
            return nil
        }
        
        let diameter = (pixelBox.width + pixelBox.height) / 2.0
        guard diameter >= 18.0 else {
            return nil
        }
        
        let circularityScore = Float(max(0.0, 1.0 - Double(abs(aspectRatio - 1.0)) * 6.0))
        let confidence = baseConfidence * circularityScore
        
        return CircleDetection(
            boundingBox: pixelBox,
            diameter: diameter,
            confidence: confidence
        )
    }
    
    /// Verifies that a detected circle does NOT contain skin or wound tissue (ulcer craters are not coins!)
    private static func isNonTissueCircle(circle: CircleDetection, in cgImage: CGImage) -> Bool {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else { return false }
        
        let midX = Int(circle.boundingBox.midX)
        let midY = Int(circle.boundingBox.midY)
        guard midX >= 0 && midX < width && midY >= 0 && midY < height else { return false }
        
        // Sample center pixel
        var pixelData = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return true }
        
        context.draw(cgImage, in: CGRect(x: -midX, y: -midY, width: width, height: height))
        
        let r = Float(pixelData[0])
        let g = Float(pixelData[1])
        let b = Float(pixelData[2])
        
        // Granulation / blood ulcer crater check: high red dominance
        if r >= 60.0 && (r / max(g, 1.0) >= 1.20) && (r / max(b, 1.0) >= 1.25) {
            return false // This is a wound crater, NOT a coin!
        }
        
        // Plantar skin tone check: typical skin chroma
        if r > g && g > b && (r - g >= 15.0) && (g - b >= 10.0) && r >= 100.0 {
            return false // This is skin tissue, NOT a coin!
        }
        
        return true
    }
}

// MARK: - Helper Structures

/// Information about detected circle
struct CircleDetection {
    let boundingBox: CGRect
    let diameter: CGFloat
    let confidence: Float
}
