//
//  WoundBoundary.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import CoreGraphics

/// Represents the detected boundary of a wound in an image
struct WoundBoundary {
    /// Boundary polygon points in image coordinates
    let points: [CGPoint]
    
    /// Detection confidence score (0-1)
    let confidence: Float
    
    /// Bounding box containing the wound
    let boundingBox: CGRect
    
    /// Method used to detect the boundary
    let detectionMethod: DetectionMethod
    
    /// Initializes a wound boundary
    /// - Parameters:
    ///   - points: Array of points defining the boundary polygon
    ///   - confidence: Detection confidence (0-1)
    ///   - boundingBox: Bounding rectangle
    ///   - detectionMethod: Method used for detection
    init(points: [CGPoint], confidence: Float, boundingBox: CGRect, detectionMethod: DetectionMethod) {
        self.points = points
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.detectionMethod = detectionMethod
    }
}

/// Method used to detect wound boundary
enum DetectionMethod: Equatable {
    /// Automatic detection using CoreML model
    case automatic(modelVersion: String)
    
    /// Manual boundary marking by user
    case manual
    
    /// Refined detection (automatic + user adjustments)
    case refined(originalConfidence: Float)
}
