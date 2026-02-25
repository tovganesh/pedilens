//
//  CalibrationType.swift
//  PediLens
//
//  Defines calibration methods for wound measurements
//

import Foundation
import CoreGraphics

/// Accuracy level for measurements
enum MeasurementAccuracy: String, Codable {
    case high      // ±1-2mm (LiDAR)
    case medium    // ±2-5mm (Reference scale)
    case low       // ±10-20mm (Estimated)
    
    var description: String {
        switch self {
        case .high:
            return "High accuracy (±1-2mm)"
        case .medium:
            return "Medium accuracy (±2-5mm)"
        case .low:
            return "Low accuracy (±10-20mm)"
        }
    }
    
    var errorMargin: Float {
        switch self {
        case .high: return 0.2    // 2mm
        case .medium: return 0.5  // 5mm
        case .low: return 2.0     // 20mm
        }
    }
}

/// Type of calibration used for measurements
enum CalibrationType: Codable {
    case lidar(depth: Float, confidence: Float)
    case referenceScale(objectType: ReferenceObjectType, confidence: Float)
    case estimated
    
    var accuracy: MeasurementAccuracy {
        switch self {
        case .lidar:
            return .high
        case .referenceScale:
            return .medium
        case .estimated:
            return .low
        }
    }
    
    var displayName: String {
        switch self {
        case .lidar(let depth, _):
            return "LiDAR (depth: \(String(format: "%.1f", depth * 100))cm)"
        case .referenceScale(let type, _):
            return "Reference Scale (\(type.displayName))"
        case .estimated:
            return "Estimated"
        }
    }
    
    var icon: String {
        switch self {
        case .lidar:
            return "camera.metering.center.weighted"
        case .referenceScale:
            return "ruler"
        case .estimated:
            return "questionmark.circle"
        }
    }
}

/// Types of reference objects that can be used for calibration
enum ReferenceObjectType: String, Codable {
    case ruler          // Standard ruler with markings
    case usQuarter      // US Quarter (24.26mm diameter)
    case creditCard     // Credit card (85.6mm × 53.98mm)
    case calibrationCard // Printed calibration card
    case custom         // User-defined reference
    
    var displayName: String {
        switch self {
        case .ruler:
            return "Ruler"
        case .usQuarter:
            return "US Quarter"
        case .creditCard:
            return "Credit Card"
        case .calibrationCard:
            return "Calibration Card"
        case .custom:
            return "Custom Reference"
        }
    }
    
    /// Known dimensions in millimeters
    var knownDimensions: CGSize? {
        switch self {
        case .usQuarter:
            return CGSize(width: 24.26, height: 24.26)
        case .creditCard:
            return CGSize(width: 85.6, height: 53.98)
        case .calibrationCard:
            return CGSize(width: 100.0, height: 100.0) // 10cm × 10cm
        case .ruler, .custom:
            return nil // Variable or user-defined
        }
    }
}

/// Information about detected reference scale
struct ReferenceScaleInfo {
    let objectType: ReferenceObjectType
    let boundingBox: CGRect
    let pixelWidth: CGFloat
    let pixelHeight: CGFloat
    let confidence: Float
    let detectedDimensions: CGSize? // In mm
    
    /// Calculate pixels per millimeter
    var pixelsPerMillimeter: CGFloat? {
        guard let knownDimensions = objectType.knownDimensions else {
            return nil
        }
        
        // Use width for calibration (more reliable than height)
        return pixelWidth / knownDimensions.width
    }
    
    /// Calculate pixels per centimeter
    var pixelsPerCentimeter: CGFloat? {
        guard let ppmm = pixelsPerMillimeter else {
            return nil
        }
        return ppmm * 10.0
    }
}

/// Information about LiDAR depth measurement
struct LiDARDepthInfo {
    let depth: Float              // Distance in meters
    let confidence: Float         // 0.0 to 1.0
    let fieldOfView: CGSize       // FOV at measured depth (in meters)
    let imageSize: CGSize         // Image dimensions in pixels
    
    /// Calculate pixels per centimeter based on depth
    var pixelsPerCentimeter: CGFloat {
        // Calculate horizontal FOV in centimeters
        let fovWidthCm = fieldOfView.width * 100.0
        
        // Pixels per cm = image width / FOV width
        return imageSize.width / CGFloat(fovWidthCm)
    }
}
