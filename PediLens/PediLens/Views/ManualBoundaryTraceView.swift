//
//  ManualBoundaryTraceView.swift
//  PediLens
//
//  Manual boundary tracing view with continuous draw and point-by-point adjustment modes
//

import SwiftUI

/// Manual boundary tracing view
struct ManualBoundaryTraceView: View {
    let image: UIImage
    let existingBoundary: WoundBoundary?
    let onComplete: ([CGPoint]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var tracePoints: [CGPoint] = []
    @State private var imageSize: CGSize = .zero
    @State private var currentDragLocation: CGPoint?
    @State private var selectedPointIndex: Int?
    @State private var tracingMode: TracingMode = .continuous
    @State private var isDraggingPoint = false
    @State private var pointDragLocation: CGPoint?
    
    enum TracingMode {
        case continuous  // Drag to trace
        case pointByPoint  // Tap to add points
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Display image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            GeometryReader { imageGeometry in
                                Color.clear.onAppear {
                                    imageSize = imageGeometry.size
                                }
                            }
                        )
                    
                    // Draw traced points and lines
                    Canvas { context, size in
                        guard !tracePoints.isEmpty else { return }
                        
                        // Use correct aspect-fit transformation
                        let geometry = AspectFitGeometry(imageSize: image.size, containerSize: size)
                        
                        var path = Path()
                        let firstScaled = geometry.imageToView(tracePoints[0])
                        path.move(to: firstScaled)
                        
                        for point in tracePoints.dropFirst() {
                            let scaledPoint = geometry.imageToView(point)
                            path.addLine(to: scaledPoint)
                        }
                        
                        // Close path if we have enough points
                        if tracePoints.count > 2 {
                            path.closeSubpath()
                        }
                        
                        // Draw the path
                        context.stroke(
                            path,
                            with: .color(.orange),
                            lineWidth: 3
                        )
                        
                        // Draw points with different styles for selected/unselected
                        for (index, point) in tracePoints.enumerated() {
                            let scaledPoint = geometry.imageToView(point)
                            
                            let isSelected = selectedPointIndex == index
                            let pointSize: CGFloat = isSelected ? 16 : 10
                            let pointColor: Color = isSelected ? .blue : .orange
                            
                            // Outer circle (white background)
                            let outerCircle = Circle()
                                .path(in: CGRect(
                                    x: scaledPoint.x - pointSize/2 - 2,
                                    y: scaledPoint.y - pointSize/2 - 2,
                                    width: pointSize + 4,
                                    height: pointSize + 4
                                ))
                            context.fill(outerCircle, with: .color(.white))
                            
                            // Inner circle (colored)
                            let circle = Circle()
                                .path(in: CGRect(
                                    x: scaledPoint.x - pointSize/2,
                                    y: scaledPoint.y - pointSize/2,
                                    width: pointSize,
                                    height: pointSize
                                ))
                            context.fill(circle, with: .color(pointColor))
                            
                            // Point number label for point-by-point mode
                            if tracingMode == .pointByPoint {
                                let text = Text("\(index + 1)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                context.draw(text, at: scaledPoint)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        tracingMode == .continuous ?
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentDragLocation = value.location
                                addTracePoint(at: value.location, in: geometry.size)
                            }
                            .onEnded { _ in
                                currentDragLocation = nil
                            } :
                        nil
                    )
                    .onTapGesture { location in
                        if tracingMode == .pointByPoint {
                            handleTap(at: location, in: geometry.size)
                        }
                    }
                    
                    // Overlay for draggable points
                    ForEach(Array(tracePoints.enumerated()), id: \.offset) { index, point in
                        DraggablePoint(
                            point: point,
                            index: index,
                            imageSize: image.size,
                            viewSize: geometry.size,
                            isSelected: selectedPointIndex == index,
                            onDrag: { newPoint in
                                updatePoint(at: index, to: newPoint)
                            },
                            onSelect: {
                                selectedPointIndex = index
                            },
                            onDragStart: { location in
                                isDraggingPoint = true
                                pointDragLocation = location
                            },
                            onDragChange: { location in
                                pointDragLocation = location
                            },
                            onDragEnd: {
                                isDraggingPoint = false
                                pointDragLocation = nil
                            }
                        )
                    }
                }
                
                // Zoomed preview loupe - show in continuous mode OR when dragging a point in point-by-point mode
                if let dragLocation = (tracingMode == .continuous ? currentDragLocation : (isDraggingPoint ? pointDragLocation : nil)) {
                    ZoomedPreviewLoupe(
                        image: image,
                        touchLocation: dragLocation,
                        viewSize: geometry.size,
                        imageSize: imageSize
                    )
                    .zIndex(1000) // Ensure it's on top of everything
                }
            }
            .navigationTitle("Trace Wound Boundary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        completeTrace()
                    }
                    .disabled(tracePoints.count < 3)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom toolbar with controls
                HStack(spacing: 12) {
                    // Mode toggle
                    Picker("Mode", selection: $tracingMode) {
                        Image(systemName: "scribble").tag(TracingMode.continuous)
                        Image(systemName: "circle.grid.cross").tag(TracingMode.pointByPoint)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                    
                    Spacer()
                    
                    // Point count
                    Text("\(tracePoints.count) pts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)
                    
                    Spacer()
                    
                    // Undo button
                    Button(action: undoLastPoint) {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(tracePoints.isEmpty)
                    .buttonStyle(.bordered)
                    
                    // Clear button
                    Button(action: clearTrace) {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(tracePoints.isEmpty)
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            // Load existing boundary if available
            if let boundary = existingBoundary {
                tracePoints = boundary.points
            }
        }
        .onChange(of: tracingMode) { _ in
            // Deselect point when switching modes
            selectedPointIndex = nil
        }
    }
    
    private func handleTap(at location: CGPoint, in viewSize: CGSize) {
        // Convert from view coordinates to image coordinates using aspect-fit transformation
        let geometry = AspectFitGeometry(imageSize: image.size, containerSize: viewSize)
        let imagePoint = geometry.viewToImage(location)
        
        // Check if tapping near an existing point (within 20 pixels in image space)
        for (index, point) in tracePoints.enumerated() {
            let distance = sqrt(pow(imagePoint.x - point.x, 2) + pow(imagePoint.y - point.y, 2))
            if distance < 20 {
                selectedPointIndex = index
                return
            }
        }
        
        // Otherwise, add new point
        tracePoints.append(imagePoint)
        selectedPointIndex = tracePoints.count - 1
    }
    
    private func addTracePoint(at location: CGPoint, in viewSize: CGSize) {
        // Convert from view coordinates to image coordinates using aspect-fit transformation
        let geometry = AspectFitGeometry(imageSize: image.size, containerSize: viewSize)
        let imagePoint = geometry.viewToImage(location)
        
        // Only add if it's not too close to the last point
        if let lastPoint = tracePoints.last {
            let distance = sqrt(pow(imagePoint.x - lastPoint.x, 2) + pow(imagePoint.y - lastPoint.y, 2))
            if distance < 5 { // Minimum distance threshold
                return
            }
        }
        
        tracePoints.append(imagePoint)
    }
    
    private func updatePoint(at index: Int, to newPoint: CGPoint) {
        guard index < tracePoints.count else { return }
        tracePoints[index] = newPoint
    }
    
    private func clearTrace() {
        tracePoints.removeAll()
        selectedPointIndex = nil
    }
    
    private func undoLastPoint() {
        if !tracePoints.isEmpty {
            if let selected = selectedPointIndex, selected == tracePoints.count - 1 {
                selectedPointIndex = nil
            }
            tracePoints.removeLast()
        }
    }
    
    private func completeTrace() {
        guard tracePoints.count >= 3 else { return }
        onComplete(tracePoints)
        dismiss()
    }
}

/// Draggable point overlay
struct DraggablePoint: View {
    let point: CGPoint
    let index: Int
    let imageSize: CGSize
    let viewSize: CGSize
    let isSelected: Bool
    let onDrag: (CGPoint) -> Void
    let onSelect: () -> Void
    let onDragStart: (CGPoint) -> Void
    let onDragChange: (CGPoint) -> Void
    let onDragEnd: () -> Void
    
    var body: some View {
        // Use correct aspect-fit transformation
        let geometry = AspectFitGeometry(imageSize: imageSize, containerSize: viewSize)
        let displayPoint = geometry.imageToView(point)
        
        Circle()
            .fill(Color.blue.opacity(0.01)) // Nearly transparent but still interactive
            .frame(width: 44, height: 44)
            .position(displayPoint)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation == .zero {
                            // Just started dragging
                            onDragStart(value.location)
                        } else {
                            onDragChange(value.location)
                        }
                        onSelect()
                        // Convert view location to image coordinates
                        let newImagePoint = geometry.viewToImage(value.location)
                        onDrag(newImagePoint)
                    }
                    .onEnded { _ in
                        onDragEnd()
                    }
            )
    }
}

/// Zoomed preview loupe that shows magnified area under finger
struct ZoomedPreviewLoupe: View {
    let image: UIImage
    let touchLocation: CGPoint
    let viewSize: CGSize
    let imageSize: CGSize
    
    private let loupeSize: CGFloat = 140
    private let zoomFactor: CGFloat = 1.5
    private let offsetAboveFinger: CGFloat = 160
    
    var body: some View {
        VStack {
            Spacer()
            
            ZStack {
                // Loupe background
                Circle()
                    .fill(Color.white)
                    .frame(width: loupeSize, height: loupeSize)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Border
                Circle()
                    .stroke(Color.orange, lineWidth: 3)
                    .frame(width: loupeSize, height: loupeSize)
                
                // Zoomed image content
                if let croppedImage = getCroppedZoomedImage() {
                    Image(uiImage: croppedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: loupeSize - 6, height: loupeSize - 6)
                        .clipShape(Circle())
                }
                
                // Crosshair at center
                ZStack {
                    // Horizontal line
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 20, height: 2)
                    
                    // Vertical line
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: 20)
                    
                    // Center dot
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: loupeSize, height: loupeSize)
            .position(
                x: adjustedLoupeX,
                y: touchLocation.y - offsetAboveFinger
            )
            
            Spacer()
        }
        .allowsHitTesting(false)
    }
    
    /// Adjust loupe X position to keep it on screen
    private var adjustedLoupeX: CGFloat {
        let halfLoupe = loupeSize / 2
        let minX = halfLoupe + 20
        let maxX = viewSize.width - halfLoupe - 20
        
        return min(max(touchLocation.x, minX), maxX)
    }
    
    /// Get cropped and zoomed portion of image around touch point
    private func getCroppedZoomedImage() -> UIImage? {
        // Convert touch location to image coordinates
        let scaleX = image.size.width / viewSize.width
        let scaleY = image.size.height / viewSize.height
        
        let imagePoint = CGPoint(
            x: touchLocation.x * scaleX,
            y: touchLocation.y * scaleY
        )
        
        // Calculate crop region in image coordinates
        let cropSize = loupeSize / zoomFactor
        let cropRect = CGRect(
            x: imagePoint.x - cropSize / 2,
            y: imagePoint.y - cropSize / 2,
            width: cropSize,
            height: cropSize
        )
        
        // Ensure crop rect is within image bounds
        let boundedRect = CGRect(
            x: max(0, min(cropRect.origin.x, image.size.width - cropSize)),
            y: max(0, min(cropRect.origin.y, image.size.height - cropSize)),
            width: min(cropSize, image.size.width),
            height: min(cropSize, image.size.height)
        )
        
        // Crop the image
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: boundedRect) else {
            return nil
        }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
