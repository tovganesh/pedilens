//
//  WoundBoundaryOverlay.swift
//  PediLens
//
//  Visual overlay for wound boundary rendering on captured images
//

import SwiftUI

/// Wound boundary overlay view
struct WoundBoundaryOverlay: View {
    let boundary: WoundBoundary
    let imageSize: CGSize
    let displaySize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Use correct aspect-fit transformation
            let geometry = AspectFitGeometry(imageSize: imageSize, containerSize: size)
            
            // Create path from boundary points
            var path = Path()
            
            if let firstPoint = boundary.points.first {
                let scaledFirst = geometry.imageToView(firstPoint)
                path.move(to: scaledFirst)
                
                for point in boundary.points.dropFirst() {
                    let scaledPoint = geometry.imageToView(point)
                    path.addLine(to: scaledPoint)
                }
                
                path.closeSubpath()
            }
            
            // Draw the boundary
            context.stroke(
                path,
                with: .color(.green),
                lineWidth: 2
            )
            
            // Draw semi-transparent fill
            context.fill(
                path,
                with: .color(.green.opacity(0.2))
            )
        }
    }
}
