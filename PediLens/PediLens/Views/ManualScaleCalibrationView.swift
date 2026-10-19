//
//  ManualScaleCalibrationView.swift
//  PediLens
//
//  Interactive caliper interface for manual reference scale definition and photo calibration
//

import SwiftUI

/// Preset reference objects for manual calibration
struct CalibrationPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let referenceType: ReferenceObjectType
    let lengthMM: Double
    let icon: String
    let description: String
    
    static let defaults: [CalibrationPreset] = [
        CalibrationPreset(
            id: "inrOneRupee",
            name: "₹1 Coin (New)",
            referenceType: .inrOneRupee,
            lengthMM: 20.00,
            icon: "indianrupeesign.circle.fill",
            description: "20.0 mm diameter"
        ),
        CalibrationPreset(
            id: "usQuarter",
            name: "US Quarter",
            referenceType: .usQuarter,
            lengthMM: 24.26,
            icon: "circle.circle.fill",
            description: "24.26 mm diameter"
        ),
        CalibrationPreset(
            id: "adultForefoot",
            name: "Adult Forefoot",
            referenceType: .adultForefoot,
            lengthMM: 98.00,
            icon: "shoeprints.fill",
            description: "98.0 mm metatarsal ball breadth"
        ),
        CalibrationPreset(
            id: "adultHallux",
            name: "Adult Great Toe",
            referenceType: .adultHallux,
            lengthMM: 26.00,
            icon: "oval.portrait.fill",
            description: "26.0 mm hallux breadth"
        ),
        CalibrationPreset(
            id: "adultLesserToe",
            name: "Lesser Toe",
            referenceType: .adultLesserToe,
            lengthMM: 14.00,
            icon: "oval.portrait",
            description: "14.0 mm lesser toe breadth"
        ),
        CalibrationPreset(
            id: "adultFinger",
            name: "Clinician Finger",
            referenceType: .adultFinger,
            lengthMM: 18.00,
            icon: "hand.point.up.fill",
            description: "18.0 mm finger breadth"
        ),
        CalibrationPreset(
            id: "creditCardWidth",
            name: "Credit Card (Width)",
            referenceType: .creditCard,
            lengthMM: 85.60,
            icon: "creditcard.fill",
            description: "85.6 mm long edge"
        ),
        CalibrationPreset(
            id: "creditCardHeight",
            name: "Credit Card (Height)",
            referenceType: .creditCard,
            lengthMM: 53.98,
            icon: "creditcard",
            description: "53.98 mm short edge"
        ),
        CalibrationPreset(
            id: "ruler1cm",
            name: "Ruler: 1 cm",
            referenceType: .ruler,
            lengthMM: 10.00,
            icon: "ruler",
            description: "10.0 mm span"
        ),
        CalibrationPreset(
            id: "ruler2cm",
            name: "Ruler: 2 cm",
            referenceType: .ruler,
            lengthMM: 20.00,
            icon: "ruler",
            description: "20.0 mm span"
        ),
        CalibrationPreset(
            id: "ruler5cm",
            name: "Ruler: 5 cm",
            referenceType: .ruler,
            lengthMM: 50.00,
            icon: "ruler.fill",
            description: "50.0 mm span"
        ),
        CalibrationPreset(
            id: "custom",
            name: "Custom Reference",
            referenceType: .custom,
            lengthMM: 10.00,
            icon: "slider.horizontal.3",
            description: "User defined distance"
        )
    ]
}

/// Interactive scale calibration view
struct ManualScaleCalibrationView: View {
    let image: UIImage
    let existingCalibration: MeasurementCalibration?
    let onSave: (MeasurementCalibration) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Preset selection
    @State private var selectedPreset: CalibrationPreset = CalibrationPreset.defaults[0]
    @State private var customLengthText: String = "10"
    @State private var customUnitIsCM: Bool = false
    
    // Caliper Pin positions in view coordinates
    @State private var pinA: CGPoint = .zero
    @State private var pinB: CGPoint = .zero
    @State private var isInitialized: Bool = false
    
    // Active dragging state
    @State private var draggingPin: PinID? = nil
    @State private var selectedPin: PinID = .pinA
    
    // Container size tracking
    @State private var containerSize: CGSize = .zero
    
    enum PinID {
        case pinA
        case pinB
    }
    
    // Effective reference length in mm
    private var effectiveLengthMM: Double {
        if selectedPreset.id == "custom" {
            let val = Double(customLengthText.replacingOccurrences(of: ",", with: ".")) ?? 10.0
            return customUnitIsCM ? val * 10.0 : val
        }
        return selectedPreset.lengthMM
    }
    
    // Aspect fit geometry calculation
    private var aspectFitGeometry: AspectFitGeometry {
        AspectFitGeometry(imageSize: image.size, containerSize: containerSize)
    }
    
    // Caliper distance in image pixels
    private var pixelDistance: Double {
        guard containerSize.width > 0, containerSize.height > 0 else { return 0 }
        let imgA = aspectFitGeometry.viewToImage(pinA)
        let imgB = aspectFitGeometry.viewToImage(pinB)
        let dx = Double(imgB.x - imgA.x)
        let dy = Double(imgB.y - imgA.y)
        return sqrt(dx * dx + dy * dy)
    }
    
    // Computed pixels per millimeter
    private var pixelsPerMillimeter: Double {
        guard effectiveLengthMM > 0, pixelDistance > 0 else { return 10.0 }
        return pixelDistance / effectiveLengthMM
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header instruction banner
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Drag the calipers to span the reference object (e.g. coin, card, or ruler markings).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                
                // Interactive Photo Canvas
                GeometryReader { geometry in
                    ZStack {
                        // Background image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        
                        if isInitialized {
                            // Caliper line and endcaps
                            CaliperOverlay(
                                pinA: pinA,
                                pinB: pinB,
                                pixelDistance: pixelDistance
                            )
                            
                            // Pin A Handle
                            PinHandleView(
                                pinID: .pinA,
                                position: pinA,
                                isSelected: selectedPin == .pinA,
                                isDragging: draggingPin == .pinA,
                                onDrag: { newPos in
                                    pinA = clampPoint(newPos, in: geometry.size)
                                    selectedPin = .pinA
                                },
                                onDragStateChanged: { isDragging in
                                    draggingPin = isDragging ? .pinA : nil
                                    if isDragging { selectedPin = .pinA }
                                }
                            )
                            
                            // Pin B Handle
                            PinHandleView(
                                pinID: .pinB,
                                position: pinB,
                                isSelected: selectedPin == .pinB,
                                isDragging: draggingPin == .pinB,
                                onDrag: { newPos in
                                    pinB = clampPoint(newPos, in: geometry.size)
                                    selectedPin = .pinB
                                },
                                onDragStateChanged: { isDragging in
                                    draggingPin = isDragging ? .pinB : nil
                                    if isDragging { selectedPin = .pinB }
                                }
                            )
                            
                            // Magnifier Loupe during drag
                            if let activePin = draggingPin {
                                let targetPos = activePin == .pinA ? pinA : pinB
                                MagnifierLoupeView(
                                    image: image,
                                    aspectFit: aspectFitGeometry,
                                    focusPoint: targetPos
                                )
                                .position(
                                    x: min(max(targetPos.x, 50), geometry.size.width - 50),
                                    y: max(targetPos.y - 70, 50)
                                )
                            }
                        }
                    }
                    .onAppear {
                        containerSize = geometry.size
                        initializePins(in: geometry.size)
                    }
                    .onChange(of: geometry.size) { newSize in
                        containerSize = newSize
                        if !isInitialized {
                            initializePins(in: newSize)
                        }
                    }
                }
                .clipped()
                
                // Bottom Calibration Controls & Presets
                VStack(spacing: 12) {
                    // Reference preset horizontal scroll
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SELECT REFERENCE")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            // Nudge buttons for active pin
                            HStack(spacing: 8) {
                                Text("Nudge \(selectedPin == .pinA ? "Pin A" : "Pin B"):")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Button(action: { nudgeActivePin(dx: -1, dy: 0) }) {
                                    Image(systemName: "arrow.left")
                                        .font(.caption2)
                                }
                                Button(action: { nudgeActivePin(dx: 1, dy: 0) }) {
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                }
                                Button(action: { nudgeActivePin(dx: 0, dy: -1) }) {
                                    Image(systemName: "arrow.up")
                                        .font(.caption2)
                                }
                                Button(action: { nudgeActivePin(dx: 0, dy: 1) }) {
                                    Image(systemName: "arrow.down")
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(CalibrationPreset.defaults) { preset in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPreset = preset
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: preset.icon)
                                                .font(.caption)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(preset.name)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .lineLimit(1)
                                                Text(preset.description)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .pediLensGlassPill(tint: selectedPreset.id == preset.id ? .accentColor : nil)
                                    .foregroundColor(selectedPreset.id == preset.id ? .accentColor : .primary)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Custom size input row if custom is selected
                    if selectedPreset.id == "custom" {
                        HStack(spacing: 12) {
                            Text("Known Length:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Length", text: $customLengthText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            
                            Picker("Unit", selection: $customUnitIsCM) {
                                Text("mm").tag(false)
                                Text("cm").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Live Calibration Metric Summary Card
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KNOWN REFERENCE")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(String(format: "%.2f mm", effectiveLengthMM))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider().frame(height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PIXEL DISTANCE")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(String(format: "%.1f px", pixelDistance))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider().frame(height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CALIBRATED SCALE")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(String(format: "%.2f px/mm", pixelsPerMillimeter))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .pediLensGlass(cornerRadius: 12)
                    .padding(.horizontal, 16)
                    
                    // Action Buttons
                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                        }
                        .pediLensGlassButton()
                        
                        Button(action: applyCalibration) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply Calibration")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .pediLensGlassButton(prominent: true)
                        .disabled(pixelDistance < 15)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("Calibrate Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") { applyCalibration() }
                        .fontWeight(.semibold)
                        .disabled(pixelDistance < 15)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func initializePins(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        
        let cx = size.width * 0.5
        let cy = size.height * 0.45
        
        // If existing calibration exists, attempt to scale initial distance to reference
        var initialSpan: CGFloat = size.width * 0.3
        if let existing = existingCalibration, existing.pixelsPerMillimeter > 0 {
            let viewScale = aspectFitGeometry.scale
            let estimatedPoints = CGFloat(existing.pixelsPerMillimeter * effectiveLengthMM) * viewScale
            if estimatedPoints > 20 && estimatedPoints < size.width * 0.8 {
                initialSpan = estimatedPoints
            }
        }
        
        pinA = CGPoint(x: cx - initialSpan / 2, y: cy)
        pinB = CGPoint(x: cx + initialSpan / 2, y: cy)
        isInitialized = true
    }
    
    private func nudgeActivePin(dx: CGFloat, dy: CGFloat) {
        if selectedPin == .pinA {
            pinA = clampPoint(CGPoint(x: pinA.x + dx, y: pinA.y + dy), in: containerSize)
        } else {
            pinB = clampPoint(CGPoint(x: pinB.x + dx, y: pinB.y + dy), in: containerSize)
        }
    }
    
    private func clampPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(p.x, 10), size.width - 10),
            y: min(max(p.y, 10), size.height - 10)
        )
    }
    
    private func applyCalibration() {
        guard pixelDistance >= 15 else { return }
        
        let calibration: MeasurementCalibration
        if selectedPreset.referenceType.isAnatomical {
            calibration = MeasurementCalibration.fuzzyAnatomical(
                pixelsPerMillimeter: pixelsPerMillimeter,
                landmark: selectedPreset.referenceType,
                referenceLengthMM: effectiveLengthMM,
                pixelDistance: pixelDistance,
                confidence: 0.75,
                notes: selectedPreset.name
            )
        } else {
            calibration = MeasurementCalibration.manual(
                pixelsPerMillimeter: pixelsPerMillimeter,
                referenceType: selectedPreset.referenceType,
                referenceLengthMM: effectiveLengthMM,
                pixelDistance: pixelDistance,
                notes: selectedPreset.name
            )
        }
        
        onSave(calibration)
        dismiss()
    }
}

// MARK: - Subviews

/// Caliper line and perpendicular tick ends
struct CaliperOverlay: View {
    let pinA: CGPoint
    let pinB: CGPoint
    let pixelDistance: Double
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: pinA)
            path.addLine(to: pinB)
            
            // Perpendicular tick marks at ends
            let dx = pinB.x - pinA.x
            let dy = pinB.y - pinA.y
            let len = hypot(dx, dy)
            if len > 0 {
                let ux = (dx / len) * 10
                let uy = (dy / len) * 10
                let px = -uy
                let py = ux
                
                // Tick A
                path.move(to: CGPoint(x: pinA.x + px, y: pinA.y + py))
                path.addLine(to: CGPoint(x: pinA.x - px, y: pinA.y - py))
                
                // Tick B
                path.move(to: CGPoint(x: pinB.x + px, y: pinB.y + py))
                path.addLine(to: CGPoint(x: pinB.x - px, y: pinB.y - py))
            }
            
            // Stroke line with glowing backdrop
            context.stroke(path, with: .color(Color.black.opacity(0.4)), lineWidth: 4)
            context.stroke(path, with: .color(Color.accentColor), lineWidth: 2)
        }
        .allowsHitTesting(false)
        .overlay(
            // Midpoint distance tag
            HStack(spacing: 3) {
                Image(systemName: "ruler")
                    .font(.system(size: 9))
                Text(String(format: "%.0f px", pixelDistance))
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.65))
            .cornerRadius(4)
            .position(x: (pinA.x + pinB.x) / 2, y: (pinA.y + pinB.y) / 2 - 14)
            .allowsHitTesting(false)
        )
    }
}

/// Interactive draggable handle for caliper pins
struct PinHandleView: View {
    let pinID: ManualScaleCalibrationView.PinID
    let position: CGPoint
    let isSelected: Bool
    let isDragging: Bool
    let onDrag: (CGPoint) -> Void
    let onDragStateChanged: (Bool) -> Void
    
    var body: some View {
        ZStack {
            // Invisible larger touch target
            Circle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
            
            // Outer shadow / glow ring
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.white, lineWidth: isDragging ? 3 : 2)
                .background(Circle().fill(isSelected ? Color.accentColor.opacity(0.25) : Color.black.opacity(0.2)))
                .frame(width: 26, height: 26)
            
            // Inner precision dot
            Circle()
                .fill(isSelected ? Color.accentColor : Color.white)
                .frame(width: 8, height: 8)
            
            // Pin label (A or B)
            Text(pinID == .pinA ? "A" : "B")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.white)
                .offset(y: 20)
                .shadow(color: .black, radius: 2)
        }
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onDragStateChanged(true)
                    onDrag(value.location)
                }
                .onEnded { _ in
                    onDragStateChanged(false)
                }
        )
    }
}

/// Circular Magnifier Loupe showing 2.2x zoom under current pin
struct MagnifierLoupeView: View {
    let image: UIImage
    let aspectFit: AspectFitGeometry
    let focusPoint: CGPoint
    
    private let loupeSize: CGFloat = 80
    private let magnification: CGFloat = 2.2
    
    var body: some View {
        ZStack {
            // Loupe background
            Circle()
                .fill(Color.black)
                .frame(width: loupeSize, height: loupeSize)
            
            // Magnified image
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: aspectFit.containerSize.width * magnification,
                    height: aspectFit.containerSize.height * magnification
                )
                .offset(
                    x: (aspectFit.containerSize.width / 2 - focusPoint.x) * magnification,
                    y: (aspectFit.containerSize.height / 2 - focusPoint.y) * magnification
                )
                .frame(width: loupeSize, height: loupeSize)
                .clipShape(Circle())
            
            // Loupe border & crosshair
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: loupeSize, height: loupeSize)
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            // Center crosshair
            Path { path in
                let half = loupeSize / 2
                path.move(to: CGPoint(x: half - 8, y: half))
                path.addLine(to: CGPoint(x: half + 8, y: half))
                path.move(to: CGPoint(x: half, y: half - 8))
                path.addLine(to: CGPoint(x: half, y: half + 8))
            }
            .stroke(Color.accentColor, lineWidth: 1.5)
            .frame(width: loupeSize, height: loupeSize)
        }
        .allowsHitTesting(false)
    }
}
