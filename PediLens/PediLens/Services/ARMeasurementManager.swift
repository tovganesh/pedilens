//
//  ARMeasurementManager.swift
//  PediLens
//
//  Manager for ARKit LiDAR scene depth capture and 3D wound distance tracking
//

import Foundation
import ARKit
import UIKit
import CoreVideo
import Combine

/// Status of capture distance relative to optimal range (15cm - 35cm)
enum CaptureDistanceStatus: String, Codable {
    case optimal = "Optimal (20-30cm)"
    case tooClose = "Too Close (<15cm)"
    case tooFar = "Too Far (>35cm)"
    case measuring = "Measuring..."
    case unavailable = "LiDAR Unavailable"
    
    var isOptimal: Bool {
        self == .optimal
    }
}

/// Protocol for AR measurement capabilities
protocol ARMeasurementManagerProtocol: AnyObject {
    var isLiDARAvailable: Bool { get }
    var currentDistance: Float? { get }
    var distanceStatus: CaptureDistanceStatus { get }
    func startSession()
    func pauseSession()
    func captureDepthInfo() async -> LiDARDepthInfo?
}

/// Manager responsible for ARKit LiDAR tracking, scene depth, and distance estimation
class ARMeasurementManager: NSObject, ObservableObject, ARMeasurementManagerProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var isLiDARAvailable: Bool = false
    @Published private(set) var currentDistance: Float? = nil
    @Published private(set) var distanceStatus: CaptureDistanceStatus = .measuring
    @Published private(set) var isTrackingReady: Bool = false
    
    // MARK: - Internal / Private Properties
    
    private var session: ARSession?
    private let targetOptimalMinDistance: Float = 0.15 // 15 cm
    private let targetOptimalMaxDistance: Float = 0.35 // 35 cm
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        checkLiDARAvailability()
    }
    
    deinit {
        session?.pause()
        session?.delegate = nil
    }
    
    // MARK: - Capabilities
    
    /// Checks whether the current device supports LiDAR scene depth
    func checkLiDARAvailability() {
        #if targetEnvironment(simulator)
        isLiDARAvailable = false
        distanceStatus = .unavailable
        #else
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            isLiDARAvailable = true
            distanceStatus = .measuring
        } else {
            isLiDARAvailable = false
            distanceStatus = .unavailable
        }
        #endif
    }
    
    // MARK: - Session Control
    
    /// Starts the ARSession with LiDAR scene depth semantics enabled if supported
    func startSession() {
        guard isLiDARAvailable else { return }
        
        if session == nil {
            session = ARSession()
            session?.delegate = self
        }
        
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        session?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    /// Pauses the active AR session
    func pauseSession() {
        session?.pause()
    }
    
    // MARK: - Depth Capture
    
    /// Captures a snapshot of the current LiDAR depth frame and constructs `LiDARDepthInfo`
    func captureDepthInfo() async -> LiDARDepthInfo? {
        guard isLiDARAvailable, let frame = session?.currentFrame else {
            return nil
        }
        
        return Self.extractDepthInfo(from: frame)
    }
    
    /// Pure helper to extract `LiDARDepthInfo` from an `ARFrame`
    static func extractDepthInfo(from frame: ARFrame) -> LiDARDepthInfo? {
        let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth
        guard let sceneDepth = depthData else { return nil }
        
        let depthMap = sceneDepth.depthMap
        let centerPoint = CGPoint(x: 0.5, y: 0.5)
        
        guard let depthMeters = readDepth(at: centerPoint, from: depthMap) else {
            return nil
        }
        
        // Extract confidence if available
        var confidence: Float = 0.8
        if let confidenceMap = sceneDepth.confidenceMap,
           let confValue = readConfidence(at: centerPoint, from: confidenceMap) {
            confidence = confValue
        }
        
        let imageResolution = frame.camera.imageResolution
        let intrinsics = frame.camera.intrinsics
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        
        // Horizontal and vertical field of view in meters at current depth
        let fovWidth = fx > 0 ? (depthMeters * Float(imageResolution.width)) / fx : depthMeters * 0.7
        let fovHeight = fy > 0 ? (depthMeters * Float(imageResolution.height)) / fy : depthMeters * 0.5
        
        return LiDARDepthInfo(
            depth: depthMeters,
            confidence: confidence,
            fieldOfView: CGSize(width: Double(fovWidth), height: Double(fovHeight)),
            imageSize: CGSize(width: imageResolution.width, height: imageResolution.height)
        )
    }
    
    // MARK: - Buffer Reading Utilities
    
    /// Reads depth value (in meters) at a normalized coordinate (0.0 - 1.0) from a depth CVPixelBuffer
    static func readDepth(at normalizedPoint: CGPoint, from depthMap: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }
        
        let pixelX = max(0, min(width - 1, Int(normalizedPoint.x * CGFloat(width))))
        let pixelY = max(0, min(height - 1, Int(normalizedPoint.y * CGFloat(height))))
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let pixelFormat = CVPixelBufferGetPixelFormatType(depthMap)
        
        if pixelFormat == kCVPixelFormatType_DepthFloat32 || pixelFormat == kCVPixelFormatType_DisparityFloat32 {
            let rowData = baseAddress.advanced(by: pixelY * bytesPerRow)
            let floatPtr = rowData.assumingMemoryBound(to: Float32.self)
            let depth = floatPtr[pixelX]
            return depth.isFinite && depth > 0 ? depth : nil
        } else if pixelFormat == kCVPixelFormatType_DepthFloat16 || pixelFormat == kCVPixelFormatType_DisparityFloat16 {
            let rowData = baseAddress.advanced(by: pixelY * bytesPerRow)
            let uint16Ptr = rowData.assumingMemoryBound(to: UInt16.self)
            let rawVal = uint16Ptr[pixelX]
            let floatVal = Float(Float16(bitPattern: rawVal))
            return floatVal.isFinite && floatVal > 0 ? floatVal : nil
        }
        
        return nil
    }
    
    /// Reads confidence value (0.0 to 1.0) from an ARKit confidence map
    static func readConfidence(at normalizedPoint: CGPoint, from confidenceMap: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(confidenceMap)
        let height = CVPixelBufferGetHeight(confidenceMap)
        guard width > 0, height > 0 else { return nil }
        
        let pixelX = max(0, min(width - 1, Int(normalizedPoint.x * CGFloat(width))))
        let pixelY = max(0, min(height - 1, Int(normalizedPoint.y * CGFloat(height))))
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(confidenceMap) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        let rowData = baseAddress.advanced(by: pixelY * bytesPerRow)
        let uint8Ptr = rowData.assumingMemoryBound(to: UInt8.self)
        let rawVal = uint8Ptr[pixelX]
        
        // ARKit confidence levels: 0 (low), 1 (medium), 2 (high)
        switch rawVal {
        case 0: return 0.4
        case 1: return 0.75
        case 2: return 0.95
        default: return 0.6
        }
    }
    
    /// Evaluates distance classification against optimal clinical thresholds
    static func classifyDistance(_ distance: Float) -> CaptureDistanceStatus {
        if distance < 0.15 {
            return .tooClose
        } else if distance > 0.35 {
            return .tooFar
        } else {
            return .optimal
        }
    }
}

// MARK: - ARSessionDelegate

extension ARMeasurementManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth
        guard let sceneDepth = depthData else { return }
        
        let centerPoint = CGPoint(x: 0.5, y: 0.5)
        if let depth = Self.readDepth(at: centerPoint, from: sceneDepth.depthMap) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentDistance = depth
                self.distanceStatus = Self.classifyDistance(depth)
                self.isTrackingReady = true
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async { [weak self] in
            switch camera.trackingState {
            case .normal:
                self?.isTrackingReady = true
            case .limited, .notAvailable:
                self?.isTrackingReady = false
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.distanceStatus = .unavailable
            self?.isTrackingReady = false
        }
    }
}
