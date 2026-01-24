//
//  CameraManager.swift
//  PediLens
//
//  Camera capture manager using AVFoundation
//  Requirements: 1.1, 11.1
//

import Foundation
import AVFoundation
import CoreLocation
import UIKit

// MARK: - Camera Errors

enum CameraError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case captureSessionNotRunning
    case captureFailed(Error)
    case deviceConfigurationFailed
    case unsupportedDevice
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied. Please enable camera access in Settings."
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case .captureSessionNotRunning:
            return "Camera session is not running. Please start the session first."
        case .captureFailed(let error):
            return "Photo capture failed: \(error.localizedDescription)"
        case .deviceConfigurationFailed:
            return "Failed to configure camera device."
        case .unsupportedDevice:
            return "This device does not support the required camera features."
        }
    }
}

// MARK: - Supporting Types

struct CapturedMedia {
    let photoData: Data
    let livePhotoVideoURL: URL?
    let depthData: DepthData?
    let metadata: PhotoMetadata
}

struct DepthData {
    let depthMap: CVPixelBuffer
    let calibrationData: AVCameraCalibrationData
    let accuracy: DepthAccuracy
}

enum DepthAccuracy {
    case relative
    case absolute
}

struct PhotoMetadata {
    let timestamp: Date
    let location: CLLocation?
    let deviceModel: String
    let cameraSettings: CameraSettings
}

struct CameraSettings {
    let iso: Float
    let exposureDuration: CMTime
    let aperture: Float
    let focalLength: Float
}

// MARK: - Camera Manager Protocol

protocol CameraManagerProtocol {
    func startSession() async throws
    func stopSession()
    func capturePhoto(livePhotoEnabled: Bool) async throws -> CapturedMedia
    func captureDepthData() async throws -> DepthData?
    func setFocusPoint(_ point: CGPoint) async
    func setExposure(_ value: Float) async
    var isSessionRunning: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer? { get }
}

// MARK: - Camera Manager Implementation

@MainActor
class CameraManager: NSObject, CameraManagerProtocol {
    
    // MARK: - Properties
    
    private let captureSession = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDevice: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoCaptureDelegate: PhotoCaptureDelegate?
    private let sessionQueue = DispatchQueue(label: "com.pedilens.camera.session")
    
    var isSessionRunning: Bool {
        return captureSession.isRunning
    }
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
    // MARK: - Session Management
    
    func startSession() async throws {
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            break
        case .notDetermined:
            // Request permission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw CameraError.permissionDenied
            }
        case .denied, .restricted:
            throw CameraError.permissionDenied
        @unknown default:
            throw CameraError.permissionDenied
        }
        
        // Configure session on background queue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.cameraUnavailable)
                    return
                }
                
                do {
                    try self.configureSession()
                    self.captureSession.startRunning()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    // MARK: - Session Configuration
    
    private func configureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Set session preset for highest quality
        captureSession.sessionPreset = .photo
        
        // Get the best camera device
        guard let videoDevice = getBestCameraDevice() else {
            throw CameraError.cameraUnavailable
        }
        
        self.videoDevice = videoDevice
        
        // Configure camera device for HDR and low light
        // Requirements: 11.2, 11.3
        try configureDeviceForHDRAndLowLight(videoDevice)
        
        // Create device input
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        
        // Add input to session
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        } else {
            throw CameraError.deviceConfigurationFailed
        }
        
        // Create and configure photo output
        let photoOutput = AVCapturePhotoOutput()
        
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
            
            // Configure photo output for highest quality
            photoOutput.isHighResolutionCaptureEnabled = true
            
            // Enable depth data capture if available
            if photoOutput.isDepthDataDeliverySupported {
                photoOutput.isDepthDataDeliveryEnabled = true
            }
            
            // Enable Live Photo capture if available
            // Requirements: 1.2, 11.4
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
            }
            
            // Configure for maximum quality
            photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            throw CameraError.deviceConfigurationFailed
        }
    }
    
    private func configureDeviceForHDRAndLowLight(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        // Enable HDR video mode if available (Requirement 11.2)
        // This enables the device to capture in HDR mode
        if device.activeFormat.isVideoHDRSupported {
            device.automaticallyAdjustsVideoHDREnabled = true
        }
        
        // Configure for low light performance (Requirement 11.3)
        // Enable low light boost if available
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
        
        // Set exposure mode to continuous auto exposure for better low light handling
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        
        // Set white balance to continuous auto for better color accuracy in various lighting
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        
        // Enable subject area change monitoring for better focus in low light
        device.isSubjectAreaChangeMonitoringEnabled = true
    }
    
    private func getBestCameraDevice() -> AVCaptureDevice? {
        // Try to get the best available camera
        // Priority: Triple camera > Dual camera > Wide angle > Default
        
        if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            return device
        }
        
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return device
        }
        
        if let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            return device
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        
        return AVCaptureDevice.default(for: .video)
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(livePhotoEnabled: Bool) async throws -> CapturedMedia {
        guard isSessionRunning else {
            throw CameraError.captureSessionNotRunning
        }
        
        guard let photoOutput = photoOutput else {
            throw CameraError.deviceConfigurationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.cameraUnavailable)
                    return
                }
                
                // Create photo settings
                let photoSettings = AVCapturePhotoSettings()
                
                // Set highest quality format
                if let photoCodec = photoOutput.availablePhotoCodecTypes.first {
                    photoSettings.photoQualityPrioritization = .quality
                }
                
                // Enable depth data if available
                if photoOutput.isDepthDataDeliverySupported {
                    photoSettings.isDepthDataDeliveryEnabled = true
                }
                
                // Configure Live Photo if requested and supported
                if livePhotoEnabled && photoOutput.isLivePhotoCaptureSupported {
                    let livePhotoMovieFileName = UUID().uuidString
                    let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
                    photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
                }
                
                // Enable HDR if available (Requirement 11.2)
                // HDR is automatically enabled when using quality prioritization
                // on devices that support it. We can optionally use ProRAW for even better quality.
                if photoOutput.isAppleProRAWSupported,
                   let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                    // Create settings with ProRAW format for maximum quality HDR
                    let rawPhotoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
                    rawPhotoSettings.photoQualityPrioritization = .quality
                    
                    // Note: For this implementation, we'll use standard photo settings
                    // ProRAW can be enabled in a future enhancement for professional use
                }
                
                // Enable auto flash mode to help with low light
                if photoOutput.supportedFlashModes.contains(.auto) {
                    photoSettings.flashMode = .auto
                }
                
                // Enable automatic Night Mode in low light (Requirement 11.3)
                // photoSettings.photoQualityPrioritization = .quality enables automatic Night Mode
                // when the device detects low light conditions
                photoSettings.photoQualityPrioritization = .quality
                
                // Enable auto virtual device fusion for multi-camera devices
                if #available(iOS 17.0, *) {
                    photoSettings.isAutoVirtualDeviceFusionEnabled = true
                }
                
                // Enable preview photo format for HDR preview
                if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
                    photoSettings.previewPhotoFormat = [
                        kCVPixelBufferPixelFormatTypeKey as String: photoSettings.availablePreviewPhotoPixelFormatTypes.first!
                    ]
                }
                
                // Create capture delegate
                let delegate = PhotoCaptureDelegate(continuation: continuation)
                self.photoCaptureDelegate = delegate
                
                // Capture photo
                photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
            }
        }
    }
    
    func captureDepthData() async throws -> DepthData? {
        // Depth data is captured as part of photo capture
        // This method is for future enhancement if separate depth capture is needed
        return nil
    }
    
    // MARK: - Camera Controls
    
    func setFocusPoint(_ point: CGPoint) async {
        guard let device = videoDevice else { return }
        
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    
                    if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                        device.focusPointOfInterest = point
                        device.focusMode = .autoFocus
                    }
                    
                    if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                        device.exposurePointOfInterest = point
                        device.exposureMode = .autoExpose
                    }
                    
                    device.unlockForConfiguration()
                } catch {
                    print("Error setting focus point: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    func setExposure(_ value: Float) async {
        guard let device = videoDevice else { return }
        
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                do {
                    try device.lockForConfiguration()
                    
                    if device.isExposureModeSupported(.custom) {
                        let clampedValue = max(device.minExposureTargetBias, min(value, device.maxExposureTargetBias))
                        device.setExposureTargetBias(clampedValue, completionHandler: nil)
                    }
                    
                    device.unlockForConfiguration()
                } catch {
                    print("Error setting exposure: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: CheckedContinuation<CapturedMedia, Error>
    private var photoData: Data?
    private var livePhotoVideoURL: URL?
    private var depthData: DepthData?
    
    init(continuation: CheckedContinuation<CapturedMedia, Error>) {
        self.continuation = continuation
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            continuation.resume(throwing: CameraError.captureFailed(error))
            return
        }
        
        // Get photo data
        guard let photoData = photo.fileDataRepresentation() else {
            continuation.resume(throwing: CameraError.captureFailed(NSError(domain: "CameraManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get photo data"])))
            return
        }
        
        self.photoData = photoData
        
        // Get depth data if available
        if let depthDataMap = photo.depthData {
            let depthPixelBuffer = depthDataMap.depthDataMap
            let calibrationData = depthDataMap.cameraCalibrationData
            let accuracy: DepthAccuracy = depthDataMap.depthDataAccuracy == .absolute ? .absolute : .relative
            
            self.depthData = DepthData(
                depthMap: depthPixelBuffer,
                calibrationData: calibrationData!,
                accuracy: accuracy
            )
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.livePhotoVideoURL = outputFileURL
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            continuation.resume(throwing: CameraError.captureFailed(error))
            return
        }
        
        guard let photoData = self.photoData else {
            continuation.resume(throwing: CameraError.captureFailed(NSError(domain: "CameraManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo data not available"])))
            return
        }
        
        // Create metadata
        let metadata = PhotoMetadata(
            timestamp: Date(),
            location: nil, // Location will be added by the caller if available
            deviceModel: UIDevice.current.model,
            cameraSettings: CameraSettings(
                iso: 0, // Will be populated from actual camera settings
                exposureDuration: CMTime.zero,
                aperture: 0,
                focalLength: 0
            )
        )
        
        // Create captured media
        let capturedMedia = CapturedMedia(
            photoData: photoData,
            livePhotoVideoURL: livePhotoVideoURL,
            depthData: depthData,
            metadata: metadata
        )
        
        continuation.resume(returning: capturedMedia)
    }
}
