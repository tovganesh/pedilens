//
//  AnnotatedWound.swift
//  PediLens
//
//  Created by PediLens Team
//  Model representing an individually annotated and measured wound lesion
//

import Foundation
import CoreGraphics
import SwiftUI

/// Represents an individually annotated and measured wound lesion within a capture session
public struct AnnotatedWound: Identifiable, Codable, Equatable {
    public var id: UUID
    public var woundNumber: Int
    public var label: String
    public var anatomicalLocation: String
    public var stageWagner: String
    public var tissueType: String
    public var exudate: String
    public var periwoundCondition: String
    public var notes: String
    public var points: [CGPoint]
    public var confidence: Float
    public var isManuallyAdjusted: Bool
    public var colorHex: String
    
    // Physical measurements (calculated via scale calibration and optional depth)
    public var lengthMM: Double
    public var widthMM: Double
    public var areaMM2: Double
    public var perimeterMM: Double
    public var depthMM: Double
    public var volumeMM3: Double
    
    public init(
        id: UUID = UUID(),
        woundNumber: Int,
        label: String? = nil,
        anatomicalLocation: String = "1st Metatarsal Head (Plantar)",
        stageWagner: String = "Grade 1 - Superficial Ulcer",
        tissueType: String = "Granulation (Erythematous)",
        exudate: String = "Scant / Minimal",
        periwoundCondition: String = "Intact",
        notes: String = "",
        points: [CGPoint] = [],
        confidence: Float = 1.0,
        isManuallyAdjusted: Bool = false,
        colorHex: String? = nil,
        lengthMM: Double = 0.0,
        widthMM: Double = 0.0,
        areaMM2: Double = 0.0,
        perimeterMM: Double = 0.0,
        depthMM: Double = 0.0,
        volumeMM3: Double = 0.0
    ) {
        self.id = id
        self.woundNumber = woundNumber
        self.label = label ?? "Wound #\(woundNumber)"
        self.anatomicalLocation = anatomicalLocation
        self.stageWagner = stageWagner
        self.tissueType = tissueType
        self.exudate = exudate
        self.periwoundCondition = periwoundCondition
        self.notes = notes
        self.points = points
        self.confidence = confidence
        self.isManuallyAdjusted = isManuallyAdjusted
        let paletteIndex = max(0, woundNumber - 1) % AnnotatedWound.colorPalette.count
        self.colorHex = colorHex ?? AnnotatedWound.colorPalette[paletteIndex]
        self.lengthMM = lengthMM
        self.widthMM = widthMM
        self.areaMM2 = areaMM2
        self.perimeterMM = perimeterMM
        self.depthMM = depthMM
        self.volumeMM3 = volumeMM3
    }
    
    /// Standard high-contrast clinical color palette for differentiating multiple wounds
    public static let colorPalette: [String] = [
        "#10B981", // Emerald / Green (#1)
        "#F59E0B", // Amber / Warm Orange (#2)
        "#06B6D4", // Cyan (#3)
        "#8B5CF6", // Purple / Violet (#4)
        "#EC4899", // Magenta / Pink (#5)
        "#3B82F6", // Blue (#6)
        "#EF4444"  // Red (#7)
    ]
    
    public var displayColor: Color {
        Color(hex: colorHex) ?? .green
    }
    
    public var boundingBox: CGRect {
        guard !points.isEmpty else { return .zero }
        let minX = points.map { $0.x }.min() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0
        return CGRect(x: minX, y: minY, width: max(1.0, maxX - minX), height: max(1.0, maxY - minY))
    }
    
    public var centroid: CGPoint {
        guard !points.isEmpty else { return .zero }
        let totalX = points.reduce(0.0) { $0 + $1.x }
        let totalY = points.reduce(0.0) { $0 + $1.y }
        return CGPoint(x: totalX / CGFloat(points.count), y: totalY / CGFloat(points.count))
    }
    
    public var areaCM2: Double {
        areaMM2 / 100.0
    }
    
    public var lengthCM: Double {
        lengthMM / 10.0
    }
    
    public var widthCM: Double {
        widthMM / 10.0
    }
    
    public var perimeterCM: Double {
        perimeterMM / 10.0
    }
    
    public var depthCM: Double {
        depthMM / 10.0
    }
    
    public var volumeCM3: Double {
        volumeMM3 / 1000.0
    }
}

// MARK: - Multi-Wound Payload & CoreData Serialization

/// Payload container for serializing multiple wound annotations into Core Data binary attributes
public struct MultiWoundPayload: Codable {
    public var version: Int = 2
    public var wounds: [AnnotatedWound]
    
    public init(wounds: [AnnotatedWound]) {
        self.version = 2
        self.wounds = wounds
    }
    
    /// Encodes a list of annotated wounds into JSON Data
    public static func encode(_ wounds: [AnnotatedWound]) -> Data? {
        let payload = MultiWoundPayload(wounds: wounds)
        return try? JSONEncoder().encode(payload)
    }
    
    /// Decodes a list of annotated wounds with robust fallback for legacy single-contour [CGPoint] payloads
    public static func decode(from data: Data) -> [AnnotatedWound]? {
        // Attempt decoding structured MultiWoundPayload
        if let payload = try? JSONDecoder().decode(MultiWoundPayload.self, from: data), !payload.wounds.isEmpty {
            return payload.wounds
        }
        
        // Fallback: Attempt decoding an array of AnnotatedWound directly
        if let directList = try? JSONDecoder().decode([AnnotatedWound].self, from: data), !directList.isEmpty {
            return directList
        }
        
        // Legacy Fallback: Attempt decoding single [CGPoint] array
        if let legacyPoints = try? JSONDecoder().decode([CGPoint].self, from: data), !legacyPoints.isEmpty {
            let legacyWound = AnnotatedWound(
                woundNumber: 1,
                label: "Wound #1",
                anatomicalLocation: "Primary Lesion",
                points: legacyPoints,
                confidence: 1.0,
                isManuallyAdjusted: false
            )
            return [legacyWound]
        }
        
        return nil
    }
}

// MARK: - Clinical Annotation Presets

public struct ClinicalAnnotationPresets {
    public static let anatomicalLocations: [String] = [
        "1st Metatarsal Head (Plantar)",
        "5th Metatarsal Head (Plantar)",
        "2nd-4th Metatarsal Area",
        "Great Toe / Hallux (Plantar)",
        "Great Toe / Hallux (Dorsal)",
        "Lesser Toe Tip / Interdigital",
        "Midfoot / Plantar Arch",
        "Lateral Midfoot",
        "Medial Midfoot",
        "Heel / Calcaneus",
        "Dorsal Foot / Instep",
        "Medial Malleolus",
        "Lateral Malleolus",
        "Other"
    ]
    
    public static let wagnerGrades: [String] = [
        "Grade 0 - Pre-ulcerative lesion / intact skin",
        "Grade 1 - Superficial ulcer (no tendon/bone)",
        "Grade 2 - Deep ulcer to tendon, capsule, or bone",
        "Grade 3 - Deep ulcer with abscess / osteomyelitis",
        "Grade 4 - Localized gangrene (forefoot / toe)",
        "Grade 5 - Extensive gangrene of entire foot"
    ]
    
    public static let tissueTypes: [String] = [
        "Granulation (Erythematous / Healthy Bed)",
        "Slough / Fibrinous (Yellow / Soft)",
        "Necrotic / Eschar (Black / Brown Hard)",
        "Epithelializing (Pink Advancing Margin)",
        "Hyperkeratotic Border / Callus",
        "Mixed (Granulation + Slough)"
    ]
    
    public static let exudateLevels: [String] = [
        "None / Dry",
        "Scant / Minimal",
        "Moderate Serous",
        "Moderate Serosanguineous",
        "Heavy Serosanguineous",
        "Purulent / Infected"
    ]
    
    public static let periwoundConditions: [String] = [
        "Intact / Normal",
        "Callused / Hyperkeratotic",
        "Macerated (White / Soft)",
        "Erythematous (Red / Inflamed)",
        "Indurated (Firm / Edematous)",
        "Eczematous / Scaling"
    ]
}

// MARK: - Color Hex Extension

extension Color {
    public init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
