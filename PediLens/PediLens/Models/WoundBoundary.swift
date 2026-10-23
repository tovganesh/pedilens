//
//  WoundBoundary.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import CoreGraphics

/// Method used to detect wound boundary
enum DetectionMethod: Equatable, Codable {
    /// Automatic detection using CoreML model or multi-cue computer vision
    case automatic(modelVersion: String)
    
    /// Manual boundary marking by user
    case manual
    
    /// Refined detection (automatic + user adjustments)
    case refined(originalConfidence: Float)
}

/// Represents the detected boundary of a wound in an image
struct WoundBoundary: Identifiable, Codable, Equatable {
    /// Unique identifier for the wound boundary
    var id: UUID = UUID()
    
    /// Sequential index within a multi-wound image (1, 2, 3...)
    var woundNumber: Int = 1
    
    /// Boundary polygon points in image coordinates
    let points: [CGPoint]
    
    /// Detection confidence score (0-1)
    let confidence: Float
    
    /// Bounding box containing the wound
    let boundingBox: CGRect
    
    /// Method used to detect the boundary
    let detectionMethod: DetectionMethod
    
    /// Optional clinical label (e.g. "Ulcer #1 - 1st Metatarsal")
    var label: String? = nil
    
    /// Preferred display color hex
    var colorHex: String? = nil
    
    /// Initializes a wound boundary
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - woundNumber: Sequential index
    ///   - points: Array of points defining the boundary polygon
    ///   - confidence: Detection confidence (0-1)
    ///   - boundingBox: Bounding rectangle
    ///   - detectionMethod: Method used for detection
    ///   - label: Clinical label
    ///   - colorHex: Optional color hex
    init(
        id: UUID = UUID(),
        woundNumber: Int = 1,
        points: [CGPoint],
        confidence: Float,
        boundingBox: CGRect,
        detectionMethod: DetectionMethod,
        label: String? = nil,
        colorHex: String? = nil
    ) {
        self.id = id
        self.woundNumber = woundNumber
        self.points = points
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.detectionMethod = detectionMethod
        self.label = label
        self.colorHex = colorHex
    }
}
