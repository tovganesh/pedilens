//
//  CameraTypes.swift
//  PediLens
//
//  Shared types for camera and measurement systems
//

import Foundation
import AVFoundation
import CoreLocation
import CoreMedia

/// Captured media from a photo session
struct CapturedMedia {
    let photoData: Data
    let livePhotoVideoURL: URL?
    let depthData: DepthData?
    let metadata: PhotoMetadata
}

/// Depth data captured from device depth camera
struct DepthData {
    /// Depth map as a pixel buffer
    let depthMap: CVPixelBuffer
    
    /// Camera calibration data (optional as some devices/setups do not provide factory calibration)
    let calibrationData: AVCameraCalibrationData?
    
    /// Depth accuracy level
    let accuracy: DepthAccuracy
    
    init(depthMap: CVPixelBuffer, calibrationData: AVCameraCalibrationData? = nil, accuracy: DepthAccuracy) {
        self.depthMap = depthMap
        self.calibrationData = calibrationData
        self.accuracy = accuracy
    }
}

/// Depth measurement accuracy levels
enum DepthAccuracy {
    case relative
    case absolute
}

/// Metadata associated with a captured photo
struct PhotoMetadata {
    let timestamp: Date
    let location: CLLocation?
    let deviceModel: String
    let cameraSettings: CameraSettings
}

/// Camera settings used during capture
struct CameraSettings {
    let iso: Float
    let exposureDuration: CMTime
    let aperture: Float
    let focalLength: Float
}
