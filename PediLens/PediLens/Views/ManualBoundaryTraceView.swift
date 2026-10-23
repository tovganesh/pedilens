//
//  ManualBoundaryTraceView.swift
//  PediLens
//
//  Created by PediLens Team
//  Interactive manual wound boundary tracing and editing tool.
//  Upgraded to support multi-wound tracing, interactive vertex handles,
//  per-wound color distinction, synchronous pan & zoom, and floating precision loupe magnifier.
//

import SwiftUI
import CoreGraphics

/// View allowing manual tracing, vertex manipulation, and editing of multiple wound boundaries
struct ManualBoundaryTraceView: View {
    
    let image: UIImage
    let existingWounds: [AnnotatedWound]?
    let existingBoundary: WoundBoundary?
    let onCompleteMultiple: (([AnnotatedWound]) -> Void)?
    let onComplete: (([CGPoint]) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    // Multi-wound state
    @State private var wounds: [AnnotatedWound] = []
    @State private var activeWoundIndex: Int = 0
    @State private var woundIndexToDelete: Int?
    @State private var showingDeleteConfirmation: Bool = false
    
    // Active wound editing state
    @State private var points: [CGPoint] = []
    @State private var selectedPointIndex: Int?
    @State private var isClosed: Bool = true
    @State private var isDraggingPoint: Bool = false
    
    // Zoom & Pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Loupe Magnification state
    @State private var showLoupe: Bool = false
    @State private var loupeScreenLocation: CGPoint = .zero
    @State private var loupeCanvasPoint: CGPoint = .zero
    
    // Display coordinates
    @State private var imageSize: CGSize = .zero
    
    // Active wound accessor
    private var activeWound: AnnotatedWound? {
        guard activeWoundIndex >= 0 && activeWoundIndex < wounds.count else { return nil }
        return wounds[activeWoundIndex]
    }
    
    private var activeColor: Color {
        activeWound?.displayColor ?? .green
    }
    
    init(
        image: UIImage,
        existingWounds: [AnnotatedWound]? = nil,
        existingBoundary: WoundBoundary? = nil,
        onCompleteMultiple: (([AnnotatedWound]) -> Void)? = nil,
        onComplete: (([CGPoint]) -> Void)? = nil
    ) {
        self.image = image
        self.existingWounds = existingWounds
        self.existingBoundary = existingBoundary
        self.onCompleteMultiple = onCompleteMultiple
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Unified Zoomable & Pannable Canvas Container:
                    // Image, wound polygon outlines, and control point handles ALL reside together,
                    // ensuring boundaries and handles move and scale in exact 1:1 synchrony with the photo.
                    ZStack {
                        // Base Image with Aspect-Fit
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        
                        // Draw inactive wounds and active wound boundary path
                        Canvas { context, size in
                            let fitGeometry = AspectFitGeometry(imageSize: image.size, containerSize: size)
                            
                            // 1. Draw inactive wounds as background reference
                            for (index, wound) in wounds.enumerated() {
                                guard index != activeWoundIndex, wound.points.count >= 2 else { continue }
                                var inactivePath = Path()
                                inactivePath.move(to: fitGeometry.imageToView(wound.points[0]))
                                for pt in wound.points.dropFirst() {
                                    inactivePath.addLine(to: fitGeometry.imageToView(pt))
                                }
                                if wound.points.count > 2 {
                                    inactivePath.closeSubpath()
                                    context.fill(inactivePath, with: .color(wound.displayColor.opacity(0.12)))
                                }
                                context.stroke(
                                    inactivePath,
                                    with: .color(wound.displayColor.opacity(0.65)),
                                    lineWidth: max(1.0, 1.5 / scale)
                                )
                            }
                            
                            // 2. Draw active wound path
                            guard points.count >= 2 else { return }
                            var activePath = Path()
                            let firstViewPoint = fitGeometry.imageToView(points[0])
                            activePath.move(to: firstViewPoint)
                            
                            for point in points.dropFirst() {
                                let viewPoint = fitGeometry.imageToView(point)
                                activePath.addLine(to: viewPoint)
                            }
                            
                            if isClosed && points.count > 2 {
                                activePath.closeSubpath()
                                // Semi-transparent fill
                                context.fill(activePath, with: .color(activeColor.opacity(0.25)))
                            }
                            
                            context.stroke(
                                activePath,
                                with: .color(activeColor),
                                lineWidth: max(1.5, 2.5 / scale)
                            )
                        }
                        .allowsHitTesting(false)
                        
                        // Interactive Control Points on active wound
                        controlPointsOverlay(size: geometry.size)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                },
                            DragGesture()
                                .onChanged { value in
                                    guard !isDraggingPoint else { return }
                                    let maxOffsetX = max(0, (geometry.size.width * (scale - 1)) / 2) + 200
                                    let maxOffsetY = max(0, (geometry.size.height * (scale - 1)) / 2) + 200
                                    let newW = lastOffset.width + value.translation.width
                                    let newH = lastOffset.height + value.translation.height
                                    offset = CGSize(
                                        width: min(max(newW, -maxOffsetX), maxOffsetX),
                                        height: min(max(newH, -maxOffsetY), maxOffsetY)
                                    )
                                }
                                .onEnded { _ in
                                    guard !isDraggingPoint else { return }
                                    lastOffset = offset
                                }
                        )
                    )
                    
                    // Precision Loupe Magnifier (positioned in screen coordinates above finger)
                    if showLoupe {
                        LoupeView(
                            sourceImage: image,
                            touchLocation: loupeScreenLocation,
                            sourcePoint: loupeCanvasPoint,
                            imageSize: geometry.size,
                            points: points,
                            activeColor: activeColor
                        )
                    }
                    
                    // Multi-Wound Top Toolbar / Selector
                    VStack {
                        woundSelectionBar
                        Spacer()
                        
                        // Floating Reset View control when zoomed or panned
                        if scale > 1.05 || abs(offset.width) > 10 || abs(offset.height) > 10 {
                            HStack {
                                Button(action: resetZoomAndPan) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text(String(format: "%.1fx", scale))
                                            .font(.caption.weight(.semibold))
                                        Text("Reset View")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(18)
                                    .foregroundColor(.white)
                                    .shadow(radius: 3)
                                }
                                .transition(.opacity.combined(with: .scale))
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                }
                .coordinateSpace(name: "ContainerSpace")
                .navigationTitle(activeWound?.label ?? "Trace Wounds")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save All") {
                            saveAndDismiss()
                        }
                        .font(.body.weight(.semibold))
                        .disabled(wounds.isEmpty && points.isEmpty)
                    }
                }
                .alert("Delete Wound?", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        if let idx = woundIndexToDelete {
                            deleteWound(at: idx)
                            woundIndexToDelete = nil
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        woundIndexToDelete = nil
                    }
                } message: {
                    Text("Are you sure you want to remove this traced wound boundary?")
                }
                .onAppear {
                    setupInitialWounds()
                }
            }
        }
    }
    
    // MARK: - Multi-Wound Tab / Selector Bar
    
    private var woundSelectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<wounds.count, id: \.self) { index in
                    let wound = wounds[index]
                    let isCurrent = (index == activeWoundIndex)
                    
                    Button(action: {
                        switchActiveWound(to: index)
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(wound.displayColor)
                                .frame(width: 8, height: 8)
                            
                            Text(wound.label)
                                .font(.caption.weight(isCurrent ? .bold : .medium))
                                .foregroundColor(isCurrent ? .white : .primary)
                            
                            if wounds.count > 1 {
                                Button(action: {
                                    woundIndexToDelete = index
                                    showingDeleteConfirmation = true
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isCurrent ? .white.opacity(0.8) : .secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(wound.label)")
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isCurrent ? wound.displayColor : Color.secondary.opacity(0.15)
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                
                // Add new wound button
                Button(action: {
                    addNewWound()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Wound")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Interactive Points Overlay
    
    private func controlPointsOverlay(size: CGSize) -> some View {
        let fitGeometry = AspectFitGeometry(imageSize: image.size, containerSize: size)
        
        return ZStack {
            ForEach(0..<points.count, id: \.self) { index in
                let point = points[index]
                let viewPoint = fitGeometry.imageToView(point)
                let isSelected = (selectedPointIndex == index)
                
                Circle()
                    .fill(isSelected ? .white : activeColor)
                    .frame(
                        width: (isSelected ? 18 : 12) / scale,
                        height: (isSelected ? 18 : 12) / scale
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: (isSelected ? 3 : 1.5) / scale)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 3 / scale)
                    .position(viewPoint)
                    .contentShape(Circle().inset(by: -12 / scale))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("ContainerSpace"))
                            .onChanged { value in
                                isDraggingPoint = true
                                selectedPointIndex = index
                                showLoupe = true
                                
                                // Map touch position in ContainerSpace back into unscaled, unoffset canvas coordinates:
                                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                                let canvasPoint = CGPoint(
                                    x: center.x + (value.location.x - offset.width - center.x) / scale,
                                    y: center.y + (value.location.y - offset.height - center.y) / scale
                                )
                                
                                loupeScreenLocation = value.location
                                loupeCanvasPoint = canvasPoint
                                
                                let imagePoint = fitGeometry.viewToImage(canvasPoint)
                                points[index] = CGPoint(
                                    x: max(0, min(image.size.width, imagePoint.x)),
                                    y: max(0, min(image.size.height, imagePoint.y))
                                )
                            }
                            .onEnded { _ in
                                isDraggingPoint = false
                                showLoupe = false
                                saveActivePointsToWound()
                            }
                    )
            }
        }
    }
    
    // MARK: - Multi-Wound State Handlers
    
    private func resetZoomAndPan() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    private func setupInitialWounds() {
        if let existing = existingWounds, !existing.isEmpty {
            wounds = existing
            activeWoundIndex = 0
            points = existing[0].points
        } else if let boundary = existingBoundary, !boundary.points.isEmpty {
            let singleWound = AnnotatedWound(
                woundNumber: 1,
                label: "Wound #1",
                points: boundary.points,
                isManuallyAdjusted: true,
                colorHex: AnnotatedWound.colorPalette[0]
            )
            wounds = [singleWound]
            activeWoundIndex = 0
            points = boundary.points
        } else {
            // Create default initial wound circle at image center
            let defaultPoints = generateDefaultCirclePoints(center: CGPoint(x: image.size.width / 2, y: image.size.height / 2), radius: min(image.size.width, image.size.height) * 0.15)
            let defaultWound = AnnotatedWound(
                woundNumber: 1,
                label: "Wound #1",
                points: defaultPoints,
                isManuallyAdjusted: true,
                colorHex: AnnotatedWound.colorPalette[0]
            )
            wounds = [defaultWound]
            activeWoundIndex = 0
            points = defaultPoints
        }
    }
    
    private func saveActivePointsToWound() {
        guard activeWoundIndex >= 0 && activeWoundIndex < wounds.count else { return }
        wounds[activeWoundIndex].points = points
        wounds[activeWoundIndex].isManuallyAdjusted = true
    }
    
    private func switchActiveWound(to newIndex: Int) {
        guard newIndex >= 0 && newIndex < wounds.count, newIndex != activeWoundIndex else { return }
        saveActivePointsToWound()
        activeWoundIndex = newIndex
        points = wounds[newIndex].points
        selectedPointIndex = nil
    }
    
    private func addNewWound() {
        saveActivePointsToWound()
        let newNumber = wounds.count + 1
        let colorIdx = (newNumber - 1) % AnnotatedWound.colorPalette.count
        
        // Offset center slightly to not overlap existing wound completely
        let offsetX = CGFloat((newNumber % 3) - 1) * (image.size.width * 0.15)
        let offsetY = CGFloat((newNumber / 3) - 1) * (image.size.height * 0.15)
        let center = CGPoint(
            x: max(image.size.width * 0.2, min(image.size.width * 0.8, (image.size.width * 0.5) + offsetX)),
            y: max(image.size.height * 0.2, min(image.size.height * 0.8, (image.size.height * 0.5) + offsetY))
        )
        
        let newPoints = generateDefaultCirclePoints(center: center, radius: min(image.size.width, image.size.height) * 0.12)
        let newWound = AnnotatedWound(
            woundNumber: newNumber,
            label: "Wound #\(newNumber)",
            points: newPoints,
            isManuallyAdjusted: true,
            colorHex: AnnotatedWound.colorPalette[colorIdx]
        )
        
        wounds.append(newWound)
        activeWoundIndex = wounds.count - 1
        points = newPoints
    }
    
    private func deleteWound(at index: Int) {
        guard wounds.count > 1 else { return }
        wounds.remove(at: index)
        if activeWoundIndex >= wounds.count {
            activeWoundIndex = wounds.count - 1
        }
        points = wounds[activeWoundIndex].points
    }
    
    private func generateDefaultCirclePoints(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        var circlePoints: [CGPoint] = []
        let pointCount = 16
        for i in 0..<pointCount {
            let angle = (CGFloat(i) / CGFloat(pointCount)) * 2 * .pi
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            circlePoints.append(CGPoint(x: max(0, min(image.size.width, x)), y: max(0, min(image.size.height, y))))
        }
        return circlePoints
    }
    
    private func saveAndDismiss() {
        saveActivePointsToWound()
        if let onCompleteMultiple = onCompleteMultiple {
            onCompleteMultiple(wounds)
        } else if let onComplete = onComplete {
            // Backward compatibility with single wound callback
            onComplete(wounds.first?.points ?? points)
        }
        dismiss()
    }
}

/// Precision Loupe Magnifier View
struct LoupeView: View {
    let sourceImage: UIImage
    let touchLocation: CGPoint
    let sourcePoint: CGPoint
    let imageSize: CGSize
    let points: [CGPoint]
    let activeColor: Color
    
    private let loupeSize: CGFloat = 110
    private let magnification: CGFloat = 2.0
    
    private var loupeY: CGFloat {
        touchLocation.y < 120 ? touchLocation.y + 80 : touchLocation.y - 80
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: loupeSize, height: loupeSize)
                .overlay(
                    GeometryReader { geo in
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            
                            // Draw magnified portion of image centered around sourcePoint
                            context.translateBy(x: center.x, y: center.y)
                            context.scaleBy(x: magnification, y: magnification)
                            context.translateBy(x: -sourcePoint.x, y: -sourcePoint.y)
                            
                            let fitGeometry = AspectFitGeometry(imageSize: sourceImage.size, containerSize: imageSize)
                            let rect = CGRect(origin: fitGeometry.offset, size: fitGeometry.displayedSize)
                            context.draw(Image(uiImage: sourceImage), in: rect)
                        }
                    }
                )
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(activeColor, lineWidth: 3)
                )
                // Crosshair at center of loupe
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 1, height: 16)
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 16, height: 1)
                    }
                )
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                .position(x: touchLocation.x, y: loupeY)
                .allowsHitTesting(false)
        }
    }
}
