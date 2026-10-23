//
//  CaptureSessionDetailView.swift
//  PediLens
//
//  Created by PediLens Team
//  Detailed view for a single capture session showing photo, wound boundary,
//  and comprehensive clinical measurements.
//  Enhanced to support multi-wound auto-detection, multi-wound tracing,
//  individual clinical annotations, and visit-to-visit comparison.
//

import SwiftUI
import CoreData
import CoreGraphics

/// Detailed view for a single capture session with multi-wound capabilities
struct CaptureSessionDetailView: View {
    @ObservedObject var session: CaptureSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.duoGeometry) private var duoGeometry
    
    @State private var photoImage: UIImage?
    @State private var imageIdentifier: String?
    @State private var woundBoundary: WoundBoundary?
    @State private var annotatedWounds: [AnnotatedWound] = []
    @State private var selectedWoundID: UUID?
    @State private var measurements: WoundMeasurement?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingManualTrace = false
    @State private var showingScaleCalibration = false
    @State private var showingDeleteConfirmation = false
    @State private var showingReanalyzeConfirmation = false
    @State private var showingComparisonView = false
    @State private var woundToAnnotate: AnnotatedWound?
    @State private var manualTracePoints: [CGPoint] = []
    @State private var customCalibration: MeasurementCalibration?
    
    // Export state
    @State private var showingExportSheet = false
    @State private var exportPackageToShare: ExportPackage?
    @State private var isExporting = false
    @State private var showingShareSheet = false
    
    private var hasHistoricalSessions: Bool {
        guard let record = session.woundRecord else { return false }
        return record.captureSessionsArray.contains { $0.id != session.id }
    }
    
    var body: some View {
        mainContent
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .task {
                await loadPhoto()
                await loadExistingMeasurement()
            }
            .onChange(of: photoImage) { newValue in
                handlePhotoChange(newValue)
            }
            .sheet(isPresented: $showingManualTrace) {
                manualTraceSheet
            }
            .sheet(item: $woundToAnnotate) { wound in
                WoundAnnotationEditorView(wound: wound) { updated in
                    saveWoundAnnotation(updated)
                }
            }
            .sheet(isPresented: $showingComparisonView) {
                comparisonSheet
            }
            .sheet(isPresented: $showingScaleCalibration) {
                scaleCalibrationSheet
            }
            .sheet(isPresented: $showingShareSheet) {
                shareSheet
            }
            .confirmationDialog(
                "Re-analyze Wound",
                isPresented: $showingReanalyzeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Re-analyze", role: .destructive) {
                    reanalyzeWound()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will replace current wound boundaries and measurements. This action cannot be undone.")
            }
            .alert("Delete Photo Session", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCurrentSession()
                }
            } message: {
                Text("Are you sure you want to permanently delete this photo and all associated wound measurements and notes? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
    }
    
    // MARK: - Subviews & Sheets
    
    private var mainContent: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            Group {
                if availableWidth >= 780 {
                    dualPaneContent
                } else {
                    singleColumnContent
                }
            }
        }
    }
    
    private var dualPaneContent: some View {
        HStack(spacing: 0) {
            VStack {
                photoDisplayView(isExpanded: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            
            ZStack {
                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.3))
                    .frame(width: 1)
            }
            .frame(width: 16)
            
            ScrollView {
                VStack(spacing: 16) {
                    clinicalInspectorView
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var singleColumnContent: some View {
        ScrollView {
            VStack(spacing: duoGeometry.isCoverScreen ? 14 : 20) {
                photoDisplayView(isExpanded: false)
                clinicalInspectorView
            }
            .padding(duoGeometry.isCoverScreen ? 12 : 16)
        }
        .duoCoverScreenPadding()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Done") {
                dismiss()
            }
            .font(.body.weight(.semibold))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                if hasHistoricalSessions {
                    Button(action: { showingComparisonView = true }) {
                        Image(systemName: "rectangle.split.2x1")
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Compare with previous visits")
                }
                
                Menu {
                    Button(action: { exportSession(format: .pdf) }) {
                        Label("Export PDF Report", systemImage: "doc.text.fill")
                    }
                    Button(action: { exportSession(format: .images) }) {
                        Label("Export Image Package", systemImage: "photo.stack")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .pediLensGlassButton()
                .accessibilityLabel("Export session")
                .disabled(session.woundRecord == nil || isExporting)
                
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .pediLensGlassButton()
                .accessibilityLabel("Delete photo session")
            }
        }
    }
    
    @ViewBuilder
    private var manualTraceSheet: some View {
        if let image = photoImage {
            ManualBoundaryTraceView(
                image: image,
                existingWounds: annotatedWounds.isEmpty ? nil : annotatedWounds,
                existingBoundary: woundBoundary,
                onCompleteMultiple: { updatedWounds in
                    processManualWounds(updatedWounds)
                },
                onComplete: { points in
                    processManualBoundary(points)
                }
            )
        }
    }
    
    @ViewBuilder
    private var comparisonSheet: some View {
        if let image = photoImage {
            VisitComparisonView(
                currentSession: session,
                currentImage: image,
                currentWounds: annotatedWounds
            )
        }
    }
    
    @ViewBuilder
    private var scaleCalibrationSheet: some View {
        if let image = photoImage {
            ManualScaleCalibrationView(
                image: image,
                existingCalibration: customCalibration ?? measurements?.calibrationUsed,
                onSave: { newCal in
                    applyCustomCalibration(newCal)
                }
            )
        }
    }
    
    @ViewBuilder
    private var shareSheet: some View {
        if let package = exportPackageToShare {
            ActivityViewController(activityItems: [package.fileURL])
        }
    }
    
    private func handlePhotoChange(_ newValue: UIImage?) {
        if let newImage = newValue {
            let newIdentifier = "\(newImage.size.width)x\(newImage.size.height)"
            if newIdentifier != imageIdentifier {
                imageIdentifier = newIdentifier
                woundBoundary = nil
                annotatedWounds = []
                measurements = nil
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func photoDisplayView(isExpanded: Bool) -> some View {
        VStack(spacing: 12) {
            if let image = photoImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: isExpanded ? 460 : (duoGeometry.isCoverScreen ? 270 : 340))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Multi-wound overlay or single boundary overlay
                    if !annotatedWounds.isEmpty {
                        GeometryReader { geometry in
                            WoundBoundaryOverlay(
                                wounds: annotatedWounds,
                                selectedWoundID: selectedWoundID,
                                imageSize: image.size,
                                displaySize: geometry.size,
                                onSelectWound: { id in
                                    selectedWoundID = id
                                }
                            )
                        }
                        .frame(maxHeight: isExpanded ? 460 : (duoGeometry.isCoverScreen ? 270 : 340))
                        .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                    } else if let boundary = woundBoundary {
                        GeometryReader { geometry in
                            WoundBoundaryOverlay(
                                boundary: boundary,
                                imageSize: image.size,
                                displaySize: geometry.size
                            )
                        }
                        .frame(maxHeight: isExpanded ? 460 : (duoGeometry.isCoverScreen ? 270 : 340))
                        .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                    }
                }
                
                // Wound Detection Pill
                if !annotatedWounds.isEmpty || woundBoundary != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Wound Detection", systemImage: "viewfinder.circle.fill")
                                .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            let count = !annotatedWounds.isEmpty ? annotatedWounds.count : 1
                            let avgConf: Float = !annotatedWounds.isEmpty ?
                                (annotatedWounds.reduce(0.0) { $0 + $1.confidence } / Float(annotatedWounds.count)) :
                                (woundBoundary?.confidence ?? 0.8)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(count) Wound\(count > 1 ? "s" : "") (\(Int(avgConf * 100))%)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .pediLensGlassPill(tint: .green)
                        }
                        
                        // Multi-wound selection pills
                        if annotatedWounds.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(annotatedWounds) { wound in
                                        Button(action: {
                                            selectedWoundID = wound.id
                                        }) {
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(wound.displayColor)
                                                    .frame(width: 8, height: 8)
                                                Text(wound.label)
                                                    .font(.caption.weight(selectedWoundID == wound.id ? .bold : .medium))
                                                if wound.areaMM2 > 0 {
                                                    Text(String(format: "%.1f cm²", wound.areaCM2))
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(selectedWoundID == wound.id ? wound.displayColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(selectedWoundID == wound.id ? wound.displayColor : Color.clear, lineWidth: 1.5)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(duoGeometry.isCoverScreen ? 10 : 14)
                    .pediLensGlass(cornerRadius: 14)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("Photo not available")
                        .foregroundColor(.secondary)
                }
                .frame(height: isExpanded ? 400 : 250)
            }
        }
    }
    
    @ViewBuilder
    private var clinicalInspectorView: some View {
        Group {
            // Visit Comparison Callout if previous visits exist
            if hasHistoricalSessions {
                Button(action: { showingComparisonView = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.split.2x1.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Compare With Previous Visit")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Interactive overlay, split curtain & delta analysis")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .pediLensGlass(cornerRadius: 14)
                }
                .buttonStyle(.plain)
            }
            
            // Session metadata
            VStack(alignment: .leading, spacing: 10) {
                Label("Session Information", systemImage: "calendar.badge.clock")
                    .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                    .foregroundColor(.primary)
                
                Divider().opacity(0.5)
                
                HStack {
                    Text("Captured")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(session.timestamp ?? Date(), format: .dateTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                if session.locationAvailable, let location = session.location {
                    HStack {
                        Text("Coordinates")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(duoGeometry.isCoverScreen ? 10 : 14)
            .pediLensGlass(cornerRadius: 14)
            
            // Overall Measurements section
            if let measurements = measurements {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        Label("Cumulative Wound Burden", systemImage: "ruler.fill")
                            .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                            .foregroundColor(.primary)
                        
                        Spacer(minLength: 8)
                        adjustScaleButton(measurements: measurements)
                    }
                    
                    HStack(spacing: 8) {
                        calibrationBadge(measurements: measurements)
                        if measurements.calibrationUsed.isUserCalibrated {
                            manualTag
                        }
                        Spacer()
                        Text(String(format: "%.1f px/mm", measurements.calibrationUsed.pixelsPerMillimeter))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider().opacity(0.4)
                    
                    if measurements.needsCalibrationWarning {
                        VStack(alignment: .leading, spacing: 8) {
                            UncalibratedMeasurementWarning()
                            Button(action: { showingScaleCalibration = true }) {
                                Label("Calibrate Scale (Define Reference)", systemImage: "ruler.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .pediLensGlassButton(prominent: true)
                        }
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        clinicalMetricCard(title: "Total Surface Area", value: measurements.area.formatted(), icon: "square.dashed")
                        clinicalMetricCard(title: "Max Length", value: measurements.length.formatted(), icon: "arrow.left.and.right")
                        clinicalMetricCard(title: "Max Width", value: measurements.width.formatted(), icon: "arrow.up.and.down")
                        clinicalMetricCard(title: "Total Perimeter", value: measurements.perimeter.formatted(), icon: "circle.dashed")
                        
                        if let depth = measurements.depth {
                            clinicalMetricCard(title: "Max Depth", value: depth.formatted(), icon: "arrow.down.to.line")
                        }
                        if let volume = measurements.volume {
                            clinicalMetricCard(title: "Total Volume", value: volume.formatted(), icon: "cube")
                        }
                    }
                }
                .padding(duoGeometry.isCoverScreen ? 10 : 14)
                .pediLensGlass(cornerRadius: 14)
                
                // Individual Wounds & Annotations Section
                if !annotatedWounds.isEmpty {
                    individualWoundsSection
                }
                
                // Action buttons
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        manualTraceButton
                        reanalyzeButton
                    }
                    VStack(spacing: 10) {
                        manualTraceButton
                        reanalyzeButton
                    }
                }
            } else if isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing wound(s)...")
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .pediLensGlass(cornerRadius: 14)
            } else if photoImage != nil {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analysis Options")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Automatic AI detects multiple wounds in frame. You can also manually trace and annotate each lesion individually.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(10)
                    
                    Button(action: analyzeWound) {
                        Label("Auto-Detect All Wounds", systemImage: "waveform.path.ecg")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton(prominent: true)
                    
                    Button(action: { showingManualTrace = true }) {
                        Label("Manually Trace Wounds", systemImage: "hand.draw")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton()
                    
                    Button(action: { showingScaleCalibration = true }) {
                        Label(customCalibration != nil ? "Scale Calibrated" : "Define Scale Reference", systemImage: "ruler")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton()
                }
            }
        }
    }
    
    // MARK: - Individual Wounds & Clinical Annotations Section
    
    private var individualWoundsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Individual Lesions (\(annotatedWounds.count))", systemImage: "circles.hexagonpath.fill")
                    .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Tap card to annotate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider().opacity(0.4)
            
            ForEach(annotatedWounds) { wound in
                let isSelected = selectedWoundID == wound.id
                
                Button(action: {
                    selectedWoundID = wound.id
                    woundToAnnotate = wound
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(wound.displayColor)
                                .frame(width: 12, height: 12)
                            
                            Text(wound.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Edit")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        // Anatomical & Staging Tags
                        HStack(spacing: 6) {
                            Text(wound.anatomicalLocation)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                            
                            Text(wound.stageWagner)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        
                        // Physical Metrics
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Area")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f cm²", wound.areaCM2))
                                    .font(.caption.weight(.bold))
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Dimensions")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.0f × %.0f mm", wound.lengthMM, wound.widthMM))
                                    .font(.caption.weight(.semibold))
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Tissue")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(wound.tissueType)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                        }
                        
                        if !wound.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(wound.notes)
                                .font(.caption2)
                                .italic()
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .background(isSelected ? wound.displayColor.opacity(0.12) : Color.secondary.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? wound.displayColor : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(duoGeometry.isCoverScreen ? 10 : 14)
        .pediLensGlass(cornerRadius: 14)
    }
    
    // MARK: - Photo & Measurement Loading
    
    private func loadPhoto() async {
        guard let photoPath = session.photoPath,
              let sessionID = session.id else {
            return
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullPath = documentsURL
            .appendingPathComponent("PediLens")
            .appendingPathComponent("Photos")
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathComponent(photoPath)
            .path
        
        let fileManager = FileStorageManager.shared
        do {
            let data = try await fileManager.loadPhoto(at: fullPath)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.photoImage = image
                    self.imageIdentifier = "\(image.size.width)x\(image.size.height)"
                }
            }
        } catch {
            print("Failed to load photo: \(error.localizedDescription)")
        }
    }
    
    private func loadExistingMeasurement() async {
        guard let existingMeasurement = session.measurement else {
            return
        }
        
        if let boundaryData = existingMeasurement.boundaryPoints {
            // First decode multi-wound payload or fallback
            let decodedWounds = MultiWoundPayload.decode(from: boundaryData) ?? []
            
            let savedCalibration: MeasurementCalibration
            if let calData = existingMeasurement.calibrationData,
               let decodedCal = try? JSONDecoder().decode(MeasurementCalibration.self, from: calData) {
                savedCalibration = decodedCal
            } else {
                savedCalibration = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
            }
            
            let lengthValue = existingMeasurement.lengthMM
            let widthValue = existingMeasurement.widthMM
            let areaValue = existingMeasurement.areaMM2
            let perimeterValue = existingMeasurement.perimeterMM
            let depthValue = existingMeasurement.depthMM
            let volumeValue = existingMeasurement.volumeMM3
            
            let measurement = WoundMeasurement(
                length: Foundation.Measurement(value: lengthValue, unit: UnitLength.millimeters),
                width: Foundation.Measurement(value: widthValue, unit: UnitLength.millimeters),
                area: Foundation.Measurement(value: areaValue, unit: UnitArea.squareMillimeters),
                depth: depthValue > 0 ? Foundation.Measurement(value: depthValue, unit: UnitLength.millimeters) : nil,
                volume: volumeValue > 0 ? Foundation.Measurement(value: volumeValue, unit: UnitVolume.cubicMillimeters) : nil,
                perimeter: Foundation.Measurement(value: perimeterValue, unit: UnitLength.millimeters),
                timestamp: session.timestamp ?? Date(),
                calibrationUsed: savedCalibration
            )
            
            let primaryPoints = decodedWounds.first?.points ?? []
            let primaryBoundary = WoundBoundary(
                id: decodedWounds.first?.id ?? UUID(),
                woundNumber: decodedWounds.first?.woundNumber ?? 1,
                points: primaryPoints,
                confidence: existingMeasurement.detectionConfidence,
                boundingBox: decodedWounds.first?.boundingBox ?? .zero,
                detectionMethod: existingMeasurement.isManuallyAdjusted ? .refined(originalConfidence: existingMeasurement.detectionConfidence) : .automatic(modelVersion: "1.0"),
                label: decodedWounds.first?.label,
                colorHex: decodedWounds.first?.colorHex
            )
            
            await MainActor.run {
                self.annotatedWounds = decodedWounds
                self.selectedWoundID = decodedWounds.first?.id
                self.woundBoundary = primaryBoundary
                self.measurements = measurement
                self.customCalibration = savedCalibration
            }
        }
    }
    
    // MARK: - Multi-Wound Analysis & Persistence
    
    private func analyzeWound() {
        guard let image = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                let calibration: MeasurementCalibration
                if let custom = self.customCalibration {
                    calibration = custom
                } else {
                    let scaleService = ScaleDetectionService()
                    if let scaleInfo = try? await scaleService.detectReferenceScale(in: image),
                       let detectedCalibration = MeasurementCalibration.fromReferenceScale(scaleInfo) {
                        calibration = detectedCalibration
                    } else {
                        calibration = MeasurementCalibration.estimated()
                    }
                }
                
                var depthData: DepthData? = nil
                if let depthPath = session.depthDataPath, let sessionID = session.id {
                    depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
                }
                
                let detectionService = CoreMLWoundDetectionService()
                let boundaries = try await detectionService.detectMultipleWoundBoundaries(in: image, calibration: calibration)
                
                let measurementManager = MeasurementManager()
                
                // Build AnnotatedWounds for all detected boundaries
                var newAnnotatedWounds: [AnnotatedWound] = []
                for b in boundaries {
                    let annotated = measurementManager.calculateAnnotatedWound(
                        boundary: b,
                        calibration: calibration,
                        depthData: depthData
                    )
                    newAnnotatedWounds.append(annotated)
                }
                
                // Compute cumulative summary metrics
                let totalAreaMM2 = newAnnotatedWounds.reduce(0.0) { $0 + $1.areaMM2 }
                let maxLengthMM = newAnnotatedWounds.map { $0.lengthMM }.max() ?? 0.0
                let maxWidthMM = newAnnotatedWounds.map { $0.widthMM }.max() ?? 0.0
                let totalPerimeterMM = newAnnotatedWounds.reduce(0.0) { $0 + $1.perimeterMM }
                let maxDepthMM = newAnnotatedWounds.map { $0.depthMM }.max() ?? 0.0
                let totalVolumeMM3 = newAnnotatedWounds.reduce(0.0) { $0 + $1.volumeMM3 }
                let avgConfidence = boundaries.reduce(0.0) { $0 + $1.confidence } / Float(max(1, boundaries.count))
                
                let summaryMeasurements = WoundMeasurement(
                    length: Foundation.Measurement(value: maxLengthMM, unit: UnitLength.millimeters),
                    width: Foundation.Measurement(value: maxWidthMM, unit: UnitLength.millimeters),
                    area: Foundation.Measurement(value: totalAreaMM2, unit: UnitArea.squareMillimeters),
                    depth: maxDepthMM > 0 ? Foundation.Measurement(value: maxDepthMM, unit: UnitLength.millimeters) : nil,
                    volume: totalVolumeMM3 > 0 ? Foundation.Measurement(value: totalVolumeMM3, unit: UnitVolume.cubicMillimeters) : nil,
                    perimeter: Foundation.Measurement(value: totalPerimeterMM, unit: UnitLength.millimeters),
                    timestamp: Date(),
                    calibrationUsed: calibration
                )
                
                // Save or update CoreData Measurement
                let measurement = session.measurement ?? Measurement(context: viewContext)
                measurement.id = measurement.id ?? UUID()
                measurement.lengthMM = maxLengthMM
                measurement.widthMM = maxWidthMM
                measurement.areaMM2 = totalAreaMM2
                measurement.perimeterMM = totalPerimeterMM
                measurement.depthMM = maxDepthMM
                measurement.volumeMM3 = totalVolumeMM3
                measurement.detectionConfidence = avgConfidence
                measurement.isManuallyAdjusted = false
                measurement.captureSession = session
                
                // Encode multi-wound payload
                measurement.boundaryPoints = MultiWoundPayload.encode(newAnnotatedWounds)
                
                if let calibrationData = try? JSONEncoder().encode(calibration) {
                    measurement.calibrationData = calibrationData
                }
                
                try viewContext.save()
                
                await MainActor.run {
                    self.annotatedWounds = newAnnotatedWounds
                    self.selectedWoundID = newAnnotatedWounds.first?.id
                    self.woundBoundary = boundaries.first
                    self.measurements = summaryMeasurements
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.errorMessage = "Analysis failed: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func processManualWounds(_ wounds: [AnnotatedWound]) {
        guard let image = photoImage else { return }
        isAnalyzing = true
        
        Task {
            do {
                let calibration: MeasurementCalibration
                if let custom = self.customCalibration {
                    calibration = custom
                } else if let existingCalData = session.measurement?.calibrationData,
                          let decodedCal = try? JSONDecoder().decode(MeasurementCalibration.self, from: existingCalData) {
                    calibration = decodedCal
                } else if let scaleInfo = try? await ScaleDetectionService().detectReferenceScale(in: image),
                          let detectedCal = MeasurementCalibration.fromReferenceScale(scaleInfo) {
                    calibration = detectedCal
                } else {
                    calibration = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
                }
                
                var depthData: DepthData? = nil
                if let depthPath = session.depthDataPath, let sessionID = session.id {
                    depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
                }
                
                let measurementManager = MeasurementManager()
                var updatedWounds: [AnnotatedWound] = []
                
                for w in wounds {
                    let boundary = WoundBoundary(
                        id: w.id,
                        woundNumber: w.woundNumber,
                        points: w.points,
                        confidence: 1.0,
                        boundingBox: w.boundingBox,
                        detectionMethod: .manual,
                        label: w.label,
                        colorHex: w.colorHex
                    )
                    let annotated = measurementManager.calculateAnnotatedWound(
                        boundary: boundary,
                        calibration: calibration,
                        depthData: depthData,
                        existing: w
                    )
                    updatedWounds.append(annotated)
                }
                
                let totalAreaMM2 = updatedWounds.reduce(0.0) { $0 + $1.areaMM2 }
                let maxLengthMM = updatedWounds.map { $0.lengthMM }.max() ?? 0.0
                let maxWidthMM = updatedWounds.map { $0.widthMM }.max() ?? 0.0
                let totalPerimeterMM = updatedWounds.reduce(0.0) { $0 + $1.perimeterMM }
                let maxDepthMM = updatedWounds.map { $0.depthMM }.max() ?? 0.0
                let totalVolumeMM3 = updatedWounds.reduce(0.0) { $0 + $1.volumeMM3 }
                
                let summaryMeasurements = WoundMeasurement(
                    length: Foundation.Measurement(value: maxLengthMM, unit: UnitLength.millimeters),
                    width: Foundation.Measurement(value: maxWidthMM, unit: UnitLength.millimeters),
                    area: Foundation.Measurement(value: totalAreaMM2, unit: UnitArea.squareMillimeters),
                    depth: maxDepthMM > 0 ? Foundation.Measurement(value: maxDepthMM, unit: UnitLength.millimeters) : nil,
                    volume: totalVolumeMM3 > 0 ? Foundation.Measurement(value: totalVolumeMM3, unit: UnitVolume.cubicMillimeters) : nil,
                    perimeter: Foundation.Measurement(value: totalPerimeterMM, unit: UnitLength.millimeters),
                    timestamp: Date(),
                    calibrationUsed: calibration
                )
                
                let measurement = session.measurement ?? Measurement(context: viewContext)
                measurement.id = measurement.id ?? UUID()
                measurement.lengthMM = maxLengthMM
                measurement.widthMM = maxWidthMM
                measurement.areaMM2 = totalAreaMM2
                measurement.perimeterMM = totalPerimeterMM
                measurement.depthMM = maxDepthMM
                measurement.volumeMM3 = totalVolumeMM3
                measurement.detectionConfidence = 1.0
                measurement.isManuallyAdjusted = true
                measurement.captureSession = session
                
                measurement.boundaryPoints = MultiWoundPayload.encode(updatedWounds)
                if let calibrationData = try? JSONEncoder().encode(calibration) {
                    measurement.calibrationData = calibrationData
                }
                
                try viewContext.save()
                
                let primaryPoints = updatedWounds.first?.points ?? []
                let primaryBoundary = WoundBoundary(
                    id: updatedWounds.first?.id ?? UUID(),
                    woundNumber: updatedWounds.first?.woundNumber ?? 1,
                    points: primaryPoints,
                    confidence: 1.0,
                    boundingBox: updatedWounds.first?.boundingBox ?? .zero,
                    detectionMethod: .manual,
                    label: updatedWounds.first?.label,
                    colorHex: updatedWounds.first?.colorHex
                )
                
                await MainActor.run {
                    self.annotatedWounds = updatedWounds
                    self.selectedWoundID = updatedWounds.first?.id
                    self.woundBoundary = primaryBoundary
                    self.measurements = summaryMeasurements
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.errorMessage = "Failed to process manual boundaries: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func saveWoundAnnotation(_ updatedWound: AnnotatedWound) {
        if let index = annotatedWounds.firstIndex(where: { $0.id == updatedWound.id }) {
            annotatedWounds[index] = updatedWound
        } else {
            annotatedWounds.append(updatedWound)
        }
        
        if let measurement = session.measurement {
            measurement.boundaryPoints = MultiWoundPayload.encode(annotatedWounds)
            try? viewContext.save()
        }
    }
    
    private func processManualBoundary(_ points: [CGPoint]) {
        let singleWound = AnnotatedWound(
            woundNumber: 1,
            label: "Wound #1",
            points: points,
            isManuallyAdjusted: true
        )
        processManualWounds([singleWound])
    }
    
    private func reanalyzeWound() {
        guard let _ = photoImage else { return }
        isAnalyzing = true
        Task {
            analyzeWound()
        }
    }
    
    private func loadDepthData(sessionID: UUID, depthPath: String) async throws -> DepthData {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullDepthPath = documentsURL
            .appendingPathComponent("PediLens")
            .appendingPathComponent("Photos")
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathComponent(depthPath)
            .path
        
        let fileManager = FileStorageManager.shared
        let depthDataEncoded = try await fileManager.loadPhoto(at: fullDepthPath)
        
        guard let depthDict = try JSONSerialization.jsonObject(with: depthDataEncoded) as? [String: Any],
              let width = depthDict["width"] as? Int,
              let height = depthDict["height"] as? Int,
              let depthBytesBase64 = depthDict["depthBytes"] as? String,
              let bytesPerRow = depthDict["bytesPerRow"] as? Int,
              let depthBytes = Data(base64Encoded: depthBytesBase64) else {
            throw NSError(domain: "DepthDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode depth data"])
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_DepthFloat32,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let depthMap = pixelBuffer else {
            throw NSError(domain: "DepthDataError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create depth pixel buffer"])
        }
        
        CVPixelBufferLockBaseAddress(depthMap, [])
        defer { CVPixelBufferUnlockBaseAddress(depthMap, []) }
        
        if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
            depthBytes.withUnsafeBytes { bytes in
                memcpy(baseAddress, bytes.baseAddress!, min(depthBytes.count, bytesPerRow * height))
            }
        }
        
        let accuracy: DepthAccuracy = (depthDict["accuracy"] as? String) == "absolute" ? .absolute : .relative
        
        return DepthData(
            depthMap: depthMap,
            calibrationData: nil,
            accuracy: accuracy
        )
    }
    
    private func applyCustomCalibration(_ newCalibration: MeasurementCalibration) {
        self.customCalibration = newCalibration
        
        guard !annotatedWounds.isEmpty else {
            if let measurement = session.measurement {
                if let calData = try? JSONEncoder().encode(newCalibration) {
                    measurement.calibrationData = calData
                    try? viewContext.save()
                }
            }
            return
        }
        
        processManualWounds(annotatedWounds)
    }
    
    private func deleteCurrentSession() {
        Task {
            if UserManager.shared.currentUserRole == .doctor {
                do {
                    _ = try await SecurityManager.shared.authenticateUser(
                        reason: "Authenticate with Face ID or Touch ID to delete clinical photo record",
                        forcePrompt: true
                    )
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Biometric authentication required to delete record."
                        self.showingError = true
                    }
                    return
                }
            }
            
            if let sessionID = session.id {
                try? await FileStorageManager.shared.deleteFiles(for: sessionID)
            }
            
            await MainActor.run {
                session.delete(from: viewContext)
                do {
                    try viewContext.save()
                    dismiss()
                } catch {
                    self.errorMessage = "Failed to delete photo session: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    // MARK: - Action Buttons & Badges
    
    private var manualTraceButton: some View {
        Button(action: { showingManualTrace = true }) {
            Label("Manual Trace", systemImage: "hand.draw")
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .pediLensGlassButton(prominent: true)
        .accessibilityLabel("Manually trace wound boundaries")
    }
    
    private var reanalyzeButton: some View {
        Button(action: { showingReanalyzeConfirmation = true }) {
            Label("Re-analyze", systemImage: "arrow.clockwise")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .pediLensGlassButton()
        .accessibilityLabel("Re-analyze wound boundaries")
    }
    
    private func adjustScaleButton(measurements: WoundMeasurement) -> some View {
        Button(action: { showingScaleCalibration = true }) {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.below.rectangle")
                    .font(.caption2)
                Text(measurements.calibrationUsed.isUserCalibrated ? "Recalibrate" : "Adjust Scale")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .pediLensGlassPill(tint: .accentColor)
        .accessibilityLabel("Recalibrate scale")
    }
    
    private func calibrationBadge(measurements: WoundMeasurement) -> some View {
        HStack(spacing: 5) {
            Image(systemName: measurements.calibrationUsed.calibrationType.icon)
                .font(.caption2)
            Text(measurements.calibrationUsed.calibrationType.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .foregroundColor(measurements.calibrationUsed.accuracy == .high ? .green : (measurements.calibrationUsed.accuracy == .medium ? .blue : .orange))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .pediLensGlassPill(tint: measurements.calibrationUsed.accuracy == .high ? .green : (measurements.calibrationUsed.accuracy == .medium ? .blue : .orange))
    }
    
    private var manualTag: some View {
        Text("Manual")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(4)
    }

    private func clinicalMetricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(duoGeometry.isCoverScreen ? 8 : 10)
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.7))
        .cornerRadius(10)
    }
    
    private func exportSession(format: ExportFormat) {
        guard let woundRecord = session.woundRecord else {
            errorMessage = "Incomplete record: Missing wound record."
            showingError = true
            return
        }
        
        isExporting = true
        
        Task {
            do {
                if UserManager.shared.currentUserRole == .doctor {
                    try await SecurityManager.shared.authenticateUser(
                        reason: "Authenticate with Face ID or Touch ID to export clinical wound records",
                        forcePrompt: false
                    )
                }
                
                let options = ExportOptions(
                    includePhotos: true,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false
                )
                let package = try await ExportManager.shared.createExport(
                    for: [woundRecord],
                    format: format,
                    options: options
                )
                
                await MainActor.run {
                    self.isExporting = false
                    self.exportPackageToShare = package
                    self.showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = "Export failed: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
}

/// Helper wrapper for UIActivityViewController in SwiftUI
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
