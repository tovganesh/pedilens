//
//  ManualBoundaryTraceView.swift
//  PediLens
//
//  Created by PediLens Team
//  Allows clinicians to manually trace wound boundaries with precision loupe magnification,
//  multi-wound management, and individual wound editing.
//

import SwiftUI
import CoreGraphics

/// Interactive manual boundary tracing view supporting multiple wounds
struct ManualBoundaryTraceView: View {
    let image: UIImage
    var existingWounds: [AnnotatedWound]?
    var existingBoundary: WoundBoundary?
    var onCompleteMultiple: (([AnnotatedWound]) -> Void)?
    var onComplete: (([CGPoint]) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    // Multi-wound state
    @State private var wounds: [AnnotatedWound] = []
    @State private var activeWoundIndex: Int = 0
    
    // Active wound editing state
    @State private var points: [CGPoint] = []
    @State private var selectedPointIndex: Int?
    @State private var isClosed: Bool = true
    
    // Zoom & Pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Loupe Magnification state
    @State private var showLoupe: Bool = false
    @State private var loupeLocation: CGPoint = .zero
    
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
                    
                    // Draw inactive wounds and active wound
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
                            context.stroke(inactivePath, with: .color(wound.displayColor.opacity(0.65)), lineWidth: 1.5)
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
                        
                        context.stroke(activePath, with: .color(activeColor), lineWidth: 2.5)
                    }
                    .allowsHitTesting(false)
                    
                    // Interactive Control Points on active wound
                    controlPointsOverlay(size: geometry.size)
                    
                    // Precision Loupe Magnifier
                    if showLoupe {
                        LoupeView(
                            sourceImage: image,
                            touchLocation: loupeLocation,
                            imageSize: imageSize,
                            points: points,
                            activeColor: activeColor
                        )
                    }
                    
                    // Multi-Wound Bottom Toolbar / Selector
                    VStack {
                        woundSelectionBar
                        Spacer()
                    }
                }
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
                                    deleteWound(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(isCurrent ? .white.opacity(0.8) : .secondary)
                                }
                                .buttonStyle(.plain)
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
    
    @ViewBuilder
    private func controlPointsOverlay(size: CGSize) -> some View {
        let fitGeometry = AspectFitGeometry(imageSize: image.size, containerSize: size)
        
        ForEach(0..<points.count, id: \.self) { idx in
            let viewPoint = fitGeometry.imageToView(points[idx])
            let isSelected = selectedPointIndex == idx
            
            Circle()
                .fill(isSelected ? .white : activeColor)
                .frame(width: isSelected ? 18 : 12, height: isSelected ? 18 : 12)
                .overlay(
                    Circle()
                        .stroke(isSelected ? activeColor : .white, lineWidth: 2)
                )
                .position(viewPoint)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            selectedPointIndex = idx
                            showLoupe = true
                            loupeLocation = value.location
                            
                            // Map drag position back to image coordinate space
                            let newImagePoint = fitGeometry.viewToImage(value.location)
                            let clampedX = max(0, min(image.size.width, newImagePoint.x))
                            let clampedY = max(0, min(image.size.height, newImagePoint.y))
                            points[idx] = CGPoint(x: clampedX, y: clampedY)
                        }
                        .onEnded { _ in
                            showLoupe = false
                            selectedPointIndex = nil
                            saveActivePointsToWound()
                        }
                )
        }
    }
    
    // MARK: - Wound Management Logic
    
    private func setupInitialWounds() {
        if let existing = existingWounds, !existing.isEmpty {
            wounds = existing
            activeWoundIndex = 0
            points = existing[0].points
        } else if let boundary = existingBoundary, !boundary.points.isEmpty {
            let initialWound = AnnotatedWound(
                woundNumber: 1,
                label: "Wound #1",
                points: boundary.points,
                confidence: boundary.confidence,
                isManuallyAdjusted: true,
                colorHex: AnnotatedWound.colorPalette[0]
            )
            wounds = [initialWound]
            activeWoundIndex = 0
            points = boundary.points
        } else {
            // Initialize with default circular wound
            let defaultPoints = generateDefaultCirclePoints(center: CGPoint(x: image.size.width / 2, y: image.size.height / 2), radius: min(image.size.width, image.size.height) * 0.15)
            let initialWound = AnnotatedWound(
                woundNumber: 1,
                label: "Wound #1",
                points: defaultPoints,
                confidence: 1.0,
                isManuallyAdjusted: true,
                colorHex: AnnotatedWound.colorPalette[0]
            )
            wounds = [initialWound]
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
        saveActivePointsToWound()
        activeWoundIndex = newIndex
        points = wounds[newIndex].points
    }
    
    private func addNewWound() {
        saveActivePointsToWound()
        let nextNumber = (wounds.map { $0.woundNumber }.max() ?? 0) + 1
        let colorIdx = (nextNumber - 1) % AnnotatedWound.colorPalette.count
        
        // Offset center slightly
        let center = CGPoint(
            x: image.size.width * 0.5 + CGFloat((nextNumber % 3) - 1) * 60,
            y: image.size.height * 0.5 + CGFloat((nextNumber % 2) - 1) * 60
        )
        let newPoints = generateDefaultCirclePoints(center: center, radius: min(image.size.width, image.size.height) * 0.12)
        
        let newWound = AnnotatedWound(
            woundNumber: nextNumber,
            label: "Wound #\(nextNumber)",
            points: newPoints,
            confidence: 1.0,
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
    let imageSize: CGSize
    let points: [CGPoint]
    let activeColor: Color
    
    private let loupeSize: CGFloat = 110
    private let magnification: CGFloat = 2.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: loupeSize, height: loupeSize)
                .overlay(
                    GeometryReader { geo in
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            context.translateBy(x: center.x, y: center.y)
                            context.scaleBy(x: magnification, y: magnification)
                            context.translateBy(x: -touchLocation.x, y: -touchLocation.y)
                            
                            // Crosshair
                            var crosshair = Path()
                            crosshair.move(to: CGPoint(x: touchLocation.x - 15, y: touchLocation.y))
                            crosshair.addLine(to: CGPoint(x: touchLocation.x + 15, y: touchLocation.y))
                            crosshair.move(to: CGPoint(x: touchLocation.x, y: touchLocation.y - 15))
                            crosshair.addLine(to: CGPoint(x: touchLocation.x, y: touchLocation.y + 15))
                            context.stroke(crosshair, with: .color(activeColor), lineWidth: 1.5)
                        }
                    }
                    .clipShape(Circle())
                )
                .overlay(
                    Circle()
                        .stroke(activeColor, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                .position(x: max(loupeSize / 2 + 10, min(imageSize.width - loupeSize / 2 - 10, touchLocation.x)),
                          y: max(loupeSize / 2 + 10, touchLocation.y - loupeSize / 2 - 40))
        }
    }
}
