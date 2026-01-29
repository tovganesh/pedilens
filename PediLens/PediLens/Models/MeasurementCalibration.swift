//
//  MeasurementCalibration.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation

/// Calibration data for accurate wound measurements
struct MeasurementCalibration: Codable {
    /// Conversion ratio from pixels to millimeters
    let pixelsPerMillimeter: Double
    
    /// Reference object used for calibration (if any)
    let referenceObject: ReferenceObject?
    
    /// Date when calibration was performed
    let calibrationDate: Date
    
    /// Depth calibration data (if available)
    let depthCalibration: DepthCalibration?
    
    /// Initializes measurement calibration
    /// - Parameters:
    ///   - pixelsPerMillimeter: Pixel to millimeter conversion ratio
    ///   - referenceObject: Optional reference object used
    ///   - calibrationDate: When calibration was performed
    ///   - depthCalibration: Optional depth calibration data
    init(pixelsPerMillimeter: Double, 
         referenceObject: ReferenceObject? = nil,
         calibrationDate: Date,
         depthCalibration: DepthCalibration? = nil) {
        self.pixelsPerMillimeter = pixelsPerMillimeter
        self.referenceObject = referenceObject
        self.calibrationDate = calibrationDate
        self.depthCalibration = depthCalibration
    }
}

/// Reference object used for measurement calibration
enum ReferenceObject: Codable {
    /// Standard ruler with known length
    case ruler(lengthMM: Double)
    
    /// Coin with known diameter
    case coin(type: CoinType)
    
    /// Custom reference object
    case custom(name: String, dimensionMM: Double)
}

/// Common coin types with standard dimensions
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

/// Depth calibration data for 3D measurements
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
