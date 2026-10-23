//
//  WoundBoundaryOverlay.swift
//  PediLens
//
//  Visual overlay for wound boundary rendering on captured images
//  Enhanced to support multiple wounds, selection focus, and clinical centroid tags
//

import SwiftUI

/// Wound boundary overlay view supporting single and multiple wounds
struct WoundBoundaryOverlay: View {
    let wounds: [AnnotatedWound]
    let selectedWoundID: UUID?
    let imageSize: CGSize
    let displaySize: CGSize
    let onSelectWound: ((UUID) -> Void)?
    
    // Convenience init for backward compatibility with single WoundBoundary
    init(
        boundary: WoundBoundary,
        imageSize: CGSize,
        displaySize: CGSize
    ) {
        let wound = AnnotatedWound(
            id: boundary.id,
            woundNumber: boundary.woundNumber,
            label: boundary.label,
            points: boundary.points,
            confidence: boundary.confidence,
            colorHex: boundary.colorHex
        )
        self.wounds = [wound]
        self.selectedWoundID = wound.id
        self.imageSize = imageSize
        self.displaySize = displaySize
        self.onSelectWound = nil
    }
    
    init(
        wounds: [AnnotatedWound],
        selectedWoundID: UUID? = nil,
        imageSize: CGSize,
        displaySize: CGSize,
        onSelectWound: ((UUID) -> Void)? = nil
    ) {
        self.wounds = wounds
        self.selectedWoundID = selectedWoundID
        self.imageSize = imageSize
        self.displaySize = displaySize
        self.onSelectWound = onSelectWound
    }
    
    var body: some View {
        GeometryReader { geometry in
            let fitGeometry = AspectFitGeometry(imageSize: imageSize, containerSize: geometry.size)
            
            ZStack {
                // 1. Boundary Paths Canvas
                Canvas { context, size in
                    let canvasFit = AspectFitGeometry(imageSize: imageSize, containerSize: size)
                    
                    for wound in wounds {
                        guard wound.points.count >= 2 else { continue }
                        let isSelected = selectedWoundID == wound.id
                        let color = wound.displayColor
                        
                        var path = Path()
                        path.move(to: canvasFit.imageToView(wound.points[0]))
                        for pt in wound.points.dropFirst() {
                            path.addLine(to: canvasFit.imageToView(pt))
                        }
                        
                        if wound.points.count > 2 {
                            path.closeSubpath()
                            // Semi-transparent fill
                            context.fill(path, with: .color(color.opacity(isSelected ? 0.32 : 0.18)))
                        }
                        
                        if isSelected {
                            // High-contrast glow border for active wound
                            context.stroke(path, with: .color(.white), lineWidth: 4.5)
                            context.stroke(path, with: .color(color), lineWidth: 3.0)
                        } else {
                            context.stroke(path, with: .color(color), lineWidth: 2.2)
                        }
                    }
                }
                .allowsHitTesting(false)
                
                // 2. Centroid Label Badges
                ForEach(wounds) { wound in
                    if wound.points.count >= 3 {
                        let centroidView = fitGeometry.imageToView(wound.centroid)
                        let isSelected = selectedWoundID == wound.id
                        
                        Button(action: {
                            onSelectWound?(wound.id)
                        }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(wound.displayColor)
                                    .frame(width: 8, height: 8)
                                
                                Text("#\(wound.woundNumber)")
                                    .font(.caption2.weight(.bold))
                                
                                if wound.areaMM2 > 0 {
                                    Text(String(format: "%.1f cm²", wound.areaCM2))
                                        .font(.system(size: 9, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                Material.ultraThinMaterial,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? wound.displayColor : Color.white.opacity(0.6), lineWidth: isSelected ? 2 : 1)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        .position(centroidView)
                    }
                }
            }
        }
    }
}
