//
//  MeasurementCalibration.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import CoreGraphics

/// Calibration data for accurate wound measurements
struct MeasurementCalibration: Codable {
    /// Conversion ratio from pixels to millimeters
    let pixelsPerMillimeter: Double
    
    /// Type of calibration used
    let calibrationType: CalibrationType
    
    /// Accuracy level of measurements
    let accuracy: MeasurementAccuracy
    
    /// Date when calibration was performed
    let calibrationDate: Date
    
    /// Distance from camera to subject (in meters, if available)
    let captureDistance: Float?
    
    /// Angle from perpendicular (in degrees, if available)
    let captureAngle: Float?
    
    /// Additional metadata
    let metadata: [String: String]?
    
    /// Convenience: pixels per centimeter
    var pixelsPerCentimeter: Double {
        return pixelsPerMillimeter * 10.0
    }
    
    /// Initializes measurement calibration
    /// - Parameters:
    ///   - pixelsPerMillimeter: Pixel to millimeter conversion ratio
    ///   - calibrationType: Type of calibration used
    ///   - calibrationDate: When calibration was performed
    ///   - captureDistance: Optional distance from camera
    ///   - captureAngle: Optional angle from perpendicular
    ///   - metadata: Optional additional information
    init(pixelsPerMillimeter: Double,
         calibrationType: CalibrationType,
         calibrationDate: Date = Date(),
         captureDistance: Float? = nil,
         captureAngle: Float? = nil,
         metadata: [String: String]? = nil) {
        self.pixelsPerMillimeter = pixelsPerMillimeter
        self.calibrationType = calibrationType
        self.accuracy = calibrationType.accuracy
        self.calibrationDate = calibrationDate
        self.captureDistance = captureDistance
        self.captureAngle = captureAngle
        self.metadata = metadata
    }
    
    /// Creates calibration from LiDAR depth info
    static func fromLiDAR(_ depthInfo: LiDARDepthInfo) -> MeasurementCalibration {
        return MeasurementCalibration(
            pixelsPerMillimeter: Double(depthInfo.pixelsPerCentimeter) / 10.0,
            calibrationType: .lidar(depth: depthInfo.depth, confidence: depthInfo.confidence),
            captureDistance: depthInfo.depth,
            metadata: [
                "fovWidth": "\(depthInfo.fieldOfView.width)",
                "fovHeight": "\(depthInfo.fieldOfView.height)"
            ]
        )
    }
    
    /// Creates calibration from reference scale
    static func fromReferenceScale(_ scaleInfo: ReferenceScaleInfo) -> MeasurementCalibration? {
        guard let ppmm = scaleInfo.pixelsPerMillimeter else {
            return nil
        }
        
        return MeasurementCalibration(
            pixelsPerMillimeter: Double(ppmm),
            calibrationType: .referenceScale(
                objectType: scaleInfo.objectType,
                confidence: scaleInfo.confidence
            ),
            metadata: [
                "objectType": scaleInfo.objectType.rawValue,
                "boundingBox": "\(scaleInfo.boundingBox)"
            ]
        )
    }
    
    /// Creates estimated calibration (fallback)
    static func estimated(pixelsPerMillimeter: Double = 10.0) -> MeasurementCalibration {
        return MeasurementCalibration(
            pixelsPerMillimeter: pixelsPerMillimeter,
            calibrationType: .estimated,
            metadata: ["note": "Estimated calibration - use reference scale for accuracy"]
        )
    }
    
    // MARK: - Legacy Initializer
    
    /// Legacy initializer for backward compatibility
    /// - Parameters:
    ///   - pixelsPerMillimeter: Pixel to millimeter conversion ratio
    ///   - referenceObject: Optional reference object used (legacy)
    ///   - calibrationDate: When calibration was performed
    ///   - depthCalibration: Optional depth calibration data (legacy)
    init(pixelsPerMillimeter: Double,
         referenceObject: ReferenceObject?,
         calibrationDate: Date,
         depthCalibration: DepthCalibration? = nil) {
        self.pixelsPerMillimeter = pixelsPerMillimeter
        self.calibrationDate = calibrationDate
        self.captureDistance = nil
        self.captureAngle = nil
        
        // Convert legacy reference object to new calibration type
        if let refObj = referenceObject {
            switch refObj {
            case .ruler:
                self.calibrationType = .referenceScale(objectType: .ruler, confidence: 0.8)
                self.accuracy = .medium
            case .coin(let type):
                let objectType: ReferenceObjectType = type == .usQuarter ? .usQuarter : .custom
                self.calibrationType = .referenceScale(objectType: objectType, confidence: 0.7)
                self.accuracy = .medium
            case .custom:
                self.calibrationType = .referenceScale(objectType: .custom, confidence: 0.6)
                self.accuracy = .medium
            }
            self.metadata = ["legacy": "true", "referenceObject": "\(refObj)"]
        } else {
            self.calibrationType = .estimated
            self.accuracy = .low
            self.metadata = ["legacy": "true"]
        }
    }
}

// MARK: - Legacy Support

/// Reference object used for measurement calibration (legacy)
enum ReferenceObject: Codable {
    /// Standard ruler with known length
    case ruler(lengthMM: Double)
    
    /// Coin with known diameter
    case coin(type: CoinType)
    
    /// Custom reference object
    case custom(name: String, dimensionMM: Double)
}

/// Common coin types with standard dimensions (legacy)
enum CoinType: Codable {
    case usQuarter  // 24.26mm diameter
    case usDime     // 17.91mm diameter
    case usPenny    // 19.05mm diameter
    case usNickel   // 21.21mm diameter
    
    /// Diameter in millimeters
    var diameterMM: Double {
        switch self {
        case .usQuarter: return 24.26
        case .usDime: return 17.91
        case .usPenny: return 19.05
        case .usNickel: return 21.21
        }
    }
}

/// Depth calibration data for 3D measurements (legacy)
struct DepthCalibration: Codable {
    /// Scale factor to convert depth map values to millimeters
    let depthScale: Float
    
    /// Offset to apply to depth values
    let depthOffset: Float
    
    /// Confidence in depth calibration (0-1)
    let confidence: Float
    
    /// Initializes depth calibration
    /// - Parameters:
    ///   - depthScale: Scale factor for depth conversion
    ///   - depthOffset: Offset for depth values
    ///   - confidence: Calibration confidence (0-1)
    init(depthScale: Float, depthOffset: Float, confidence: Float) {
        self.depthScale = depthScale
        self.depthOffset = depthOffset
        self.confidence = confidence
    }
}
