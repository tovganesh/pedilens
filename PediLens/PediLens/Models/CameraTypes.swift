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
import ImageIO

/// Captured media from a photo session
struct CapturedMedia {
    let photoData: Data
    let livePhotoVideoURL: URL?
    let depthData: DepthData?
    let metadata: PhotoMetadata
}

/// Pinhole camera intrinsics expressed in a display-oriented image of `referenceSize` pixels
struct CameraIntrinsics: Equatable {
    /// Focal lengths in pixels
    let fx: Double
    let fy: Double
    /// Principal point in pixels
    let cx: Double
    let cy: Double
    /// Image size the values refer to
    let referenceSize: CGSize

    /// Rescales to an image of `size` covering the same field of view
    func scaled(to size: CGSize) -> CameraIntrinsics {
        let sx = Double(size.width / referenceSize.width)
        let sy = Double(size.height / referenceSize.height)
        return CameraIntrinsics(fx: fx * sx, fy: fy * sy, cx: cx * sx, cy: cy * sy, referenceSize: size)
    }

    /// Converts sensor-oriented intrinsics to those of the image displayed with `orientation`.
    /// Returns nil for mirrored orientations, which back-camera captures don't produce.
    func oriented(_ orientation: CGImagePropertyOrientation) -> CameraIntrinsics? {
        let w = Double(referenceSize.width)
        let h = Double(referenceSize.height)
        let rotatedSize = CGSize(width: referenceSize.height, height: referenceSize.width)
        switch orientation {
        case .up:
            return self
        case .down:
            return CameraIntrinsics(fx: fx, fy: fy, cx: w - cx, cy: h - cy, referenceSize: referenceSize)
        case .right:
            // Displayed rotated 90° clockwise: raw (x, y) appears at (h - y, x)
            return CameraIntrinsics(fx: fy, fy: fx, cx: h - cy, cy: cx, referenceSize: rotatedSize)
        case .left:
            // Displayed rotated 90° counter-clockwise: raw (x, y) appears at (y, w - x)
            return CameraIntrinsics(fx: fy, fy: fx, cx: cy, cy: w - cx, referenceSize: rotatedSize)
        default:
            return nil
        }
    }
}

extension CameraIntrinsics {
    /// Reads intrinsics from AVFoundation calibration data (sensor orientation)
    init(calibrationData: AVCameraCalibrationData) {
        let matrix = calibrationData.intrinsicMatrix
        self.init(
            fx: Double(matrix.columns.0.x),
            fy: Double(matrix.columns.1.y),
            cx: Double(matrix.columns.2.x),
            cy: Double(matrix.columns.2.y),
            referenceSize: calibrationData.intrinsicMatrixReferenceDimensions
        )
    }
}

/// Depth data captured from device depth camera
struct DepthData {
    /// Depth map as a pixel buffer
    let depthMap: CVPixelBuffer
    
    /// Camera calibration data (optional as some devices/setups do not provide factory calibration)
    let calibrationData: AVCameraCalibrationData?
    
    /// Depth accuracy level
    let accuracy: DepthAccuracy

    /// Size of the display-oriented image the depth map is aligned with (in the same units as
    /// wound boundary points). The depth map covers the same field of view at lower resolution.
    /// `nil` means the depth map already shares the boundary's coordinate space.
    let referenceImageSize: CGSize?

    /// Format tag written with stored depth files: metric Float32 depth (meters), rotated to the
    /// photo's display orientation. Files without this tag predate the fix and stored raw sensor
    /// data (often 16-bit disparity) that cannot be interpreted reliably.
    static let storageFormat = "depthFloat32-displayOriented-v2"

    /// Camera intrinsics in display orientation, used to convert depth into metric scale
    let intrinsics: CameraIntrinsics?

    init(depthMap: CVPixelBuffer,
         calibrationData: AVCameraCalibrationData? = nil,
         accuracy: DepthAccuracy,
         referenceImageSize: CGSize? = nil,
         intrinsics: CameraIntrinsics? = nil) {
        self.depthMap = depthMap
        self.calibrationData = calibrationData
        self.accuracy = accuracy
        self.referenceImageSize = referenceImageSize
        self.intrinsics = intrinsics
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
