//
//  WoundBoundaryOverlay.swift
//  PediLens
//
//  Created by PediLens Team
//  Canvas-based overlay for displaying detected or traced wound boundaries.
//  Enhanced to support multiple distinct wounds with color coding,
//  numbered centroid badges, interactive selection, and delete actions.
//

import SwiftUI
import CoreGraphics

/// View that overlays wound boundaries on an image with aspect-fit coordinates
struct WoundBoundaryOverlay: View {
    let wounds: [AnnotatedWound]
    let selectedWoundID: UUID?
    let imageSize: CGSize
    let displaySize: CGSize
    var onSelectWound: ((UUID) -> Void)? = nil
    var onDeleteWound: ((AnnotatedWound) -> Void)? = nil
    
    // Backward compatibility initializer for single boundary
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
        self.onDeleteWound = nil
    }
    
    init(
        wounds: [AnnotatedWound],
        selectedWoundID: UUID? = nil,
        imageSize: CGSize,
        displaySize: CGSize,
        onSelectWound: ((UUID) -> Void)? = nil,
        onDeleteWound: ((AnnotatedWound) -> Void)? = nil
    ) {
        self.wounds = wounds
        self.selectedWoundID = selectedWoundID
        self.imageSize = imageSize
        self.displaySize = displaySize
        self.onSelectWound = onSelectWound
        self.onDeleteWound = onDeleteWound
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
                            // Shaded interior
                            let fillOpacity = isSelected ? 0.28 : 0.14
                            context.fill(path, with: .color(color.opacity(fillOpacity)))
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
                
                // 2. Centroid Label Badges & Delete Buttons
                ForEach(wounds) { wound in
                    if wound.points.count >= 3 {
                        let centroidView = fitGeometry.imageToView(wound.centroid)
                        let isSelected = selectedWoundID == wound.id
                        
                        HStack(spacing: 5) {
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
                            }
                            .buttonStyle(.plain)
                            
                            // Delete action appears on the badge when selected
                            if isSelected, let onDelete = onDeleteWound {
                                Button(action: {
                                    onDelete(wound)
                                }) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Circle().fill(Color.red))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete wound #\(wound.woundNumber)")
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
                        .position(centroidView)
                    }
                }
            }
        }
    }
}
