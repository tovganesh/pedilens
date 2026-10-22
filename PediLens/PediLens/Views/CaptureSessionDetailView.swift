//
//  CaptureSessionDetailView.swift
//  PediLens
//
//  Detail view for a capture session with photo, wound analysis, and export capabilities.
//  Adapted for iPhone Duo Dual-Pane Medical Workstation (Internal Screen) and
//  Compact Clinical Triage (Cover Screen).
//

import SwiftUI
import CoreData
import AVFoundation

/// Detail view for a capture session with photo and wound analysis
struct CaptureSessionDetailView: View {
    let session: CaptureSession
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duoGeometry) private var duoGeometry
    
    @State private var photoImage: UIImage?
    @State private var isLoadingPhoto = true
    @State private var isAnalyzing = false
    @State private var woundBoundary: WoundBoundary?
    @State private var measurements: WoundMeasurement?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var imageIdentifier: String = ""
    @State private var showingManualTrace = false
    @State private var showingScaleCalibration = false
    @State private var showingDeleteConfirmation = false
    @State private var showingReanalyzeConfirmation = false
    @State private var manualTracePoints: [CGPoint] = []
    @State private var customCalibration: MeasurementCalibration?
    
    // Export state
    @State private var showingExportSheet = false
    @State private var exportPackageToShare: ExportPackage?
    @State private var isExporting = false
    @State private var showingShareSheet = false
    
    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            Group {
                if availableWidth >= 620 {
                    // Internal Screen Full Workstation (only when available width >= 620 pt)
                    HStack(spacing: 0) {
                        // Left Pane: High-resolution wound photo & boundary overlay
                        VStack {
                            photoDisplayView(isExpanded: true)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                        
                        // Central hinge crease gutter / separator
                        ZStack {
                            Rectangle()
                                .fill(Color(uiColor: .separator).opacity(0.3))
                                .frame(width: 1)
                        }
                        .frame(width: 16)
                        
                        // Right Pane: Clinical metrics, tissue classification & actions
                        ScrollView {
                            VStack(spacing: 16) {
                                clinicalInspectorView
                            }
                            .padding(16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // Modal Sheet, Compact Cover Screen, or Single Column (< 620 pt)
                    ScrollView {
                        VStack(spacing: duoGeometry.isCoverScreen ? 14 : 20) {
                            photoDisplayView(isExpanded: false)
                            clinicalInspectorView
                        }
                        .padding(duoGeometry.isCoverScreen ? 12 : 16)
                    }
                    .duoCoverScreenPadding()
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
                .font(.body.weight(.semibold))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
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
        .task {
            await loadPhoto()
            await loadExistingMeasurement()
        }
        .onChange(of: photoImage) { newValue in
            if let newImage = newValue {
                let newIdentifier = "\(newImage.size.width)x\(newImage.size.height)"
                if newIdentifier != imageIdentifier {
                    imageIdentifier = newIdentifier
                    woundBoundary = nil
                    measurements = nil
                }
            }
        }
        .sheet(isPresented: $showingManualTrace) {
            if let image = photoImage {
                ManualBoundaryTraceView(
                    image: image,
                    existingBoundary: woundBoundary,
                    onComplete: { points in
                        processManualBoundary(points)
                    }
                )
            }
        }
        .sheet(isPresented: $showingScaleCalibration) {
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
        .sheet(isPresented: $showingShareSheet) {
            if let package = exportPackageToShare {
                ActivityViewController(activityItems: [package.fileURL])
            }
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
            Text("This will replace the current wound boundary and measurements. This action cannot be undone.")
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
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func photoDisplayView(isExpanded: Bool) -> some View {
        VStack(spacing: 12) {
            if isLoadingPhoto {
                ProgressView("Loading photo...")
                    .frame(height: isExpanded ? 400 : (duoGeometry.isCoverScreen ? 240 : 300))
            } else if let image = photoImage {
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
                    
                    // Overlay wound boundary if available
                    if let boundary = woundBoundary {
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
                
                // Wound boundary detection pill
                if let boundary = woundBoundary {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Wound Detection", systemImage: "viewfinder.circle.fill")
                                .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Detected (\(Int(boundary.confidence * 100))%)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .pediLensGlassPill(tint: .green)
                        }
                        
                        // Disclaimer for automatic detection
                        if case .automatic = boundary.detectionMethod {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI Boundary is Experimental")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Verify with Manual Trace for clinical accuracy.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.08))
                            .cornerRadius(8)
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
            // Session metadata
            VStack(alignment: .leading, spacing: 10) {
                Label("Session Information", systemImage: "calendar.badge.clock")
                    .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                    .foregroundColor(.primary)
                
                Divider()
                    .opacity(0.5)
                
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
            
            // Measurements section
            if let measurements = measurements {
                VStack(alignment: .leading, spacing: 12) {
                    // Section Header: Title & Recalibrate action
                    HStack(alignment: .center) {
                        Label("Clinical Measurements", systemImage: "ruler.fill")
                            .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer(minLength: 8)
                        
                        // Recalibrate / Adjust scale button
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
                    
                    // Calibration reference badge & scale readout row
                    HStack(spacing: 8) {
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
                        
                        if measurements.calibrationUsed.isUserCalibrated {
                            Text("Manual")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.1f px/mm", measurements.calibrationUsed.pixelsPerMillimeter))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Divider()
                        .opacity(0.4)
                    
                    // Warning if uncalibrated
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
                            .accessibilityLabel("Calibrate scale using interactive calipers")
                        }
                    }
                    
                    // Structured Clinical Metric Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        clinicalMetricCard(title: "Length", value: measurements.length.formatted(), icon: "arrow.left.and.right")
                        clinicalMetricCard(title: "Width", value: measurements.width.formatted(), icon: "arrow.up.and.down")
                        clinicalMetricCard(title: "Surface Area", value: measurements.area.formatted(), icon: "square.dashed")
                        clinicalMetricCard(title: "Perimeter", value: measurements.perimeter.formatted(), icon: "circle.dashed")
                        
                        if let depth = measurements.depth {
                            clinicalMetricCard(title: "Depth", value: depth.formatted(), icon: "arrow.down.to.line")
                        }
                        if let volume = measurements.volume {
                            clinicalMetricCard(title: "Volume", value: volume.formatted(), icon: "cube")
                        }
                    }
                }
                .padding(duoGeometry.isCoverScreen ? 10 : 14)
                .pediLensGlass(cornerRadius: 14)
                
                // Action buttons when measurements exist
                HStack(spacing: 12) {
                    Button(action: { showingManualTrace = true }) {
                        Label("Manual Trace", systemImage: "hand.draw")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton(prominent: true)
                    .accessibilityLabel("Manually trace wound boundary")
                    
                    Button(action: { showingReanalyzeConfirmation = true }) {
                        Label("Re-analyze", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Re-analyze wound boundary")
                }
            } else if isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing wound...")
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
                            Text("Automatic AI detection is experimental. For clinical accuracy, use Manual Trace to confirm wound boundaries.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(10)
                    
                    Button(action: { showingManualTrace = true }) {
                        Label("Manual Trace (Recommended)", systemImage: "hand.draw")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton(prominent: true)
                    .accessibilityLabel("Manually trace wound boundary for accurate measurements")
                    
                    Button(action: analyzeWound) {
                        Label("Auto-Detect Wound", systemImage: "waveform.path.ecg")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Automatically analyze wound and calculate measurements")
                    
                    Button(action: { showingScaleCalibration = true }) {
                        Label(customCalibration != nil ? "Scale Calibrated (Tap to Change)" : "Define Scale Reference", systemImage: "ruler")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Define scale reference using photo calipers")
                }
                .padding(duoGeometry.isCoverScreen ? 10 : 14)
                .pediLensGlass(cornerRadius: 14)
            }
            
            // Notes section
            notesSection
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        if !session.notesArray.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Clinical Notes", systemImage: "note.text")
                    .font(duoGeometry.isCoverScreen ? .subheadline : .headline)
                    .foregroundColor(.primary)
                
                Divider()
                    .opacity(0.5)
                
                ForEach(session.notesArray, id: \.objectID) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        if let text = note.text {
                            Text(text)
                                .font(.subheadline)
                        }
                        if let createdAt = note.createdAt {
                            Text(createdAt, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(duoGeometry.isCoverScreen ? 10 : 14)
            .pediLensGlass(cornerRadius: 14)
        }
    }
    
    // MARK: - Logic & Operations
    
    private func exportSession(format: ExportFormat) {
        guard let woundRecord = session.woundRecord else { return }
        isExporting = true
        
        Task {
            do {
                if UserManager.shared.currentUserRole == .doctor {
                    try await SecurityManager.shared.authenticateUser(
                        reason: "Authenticate with Face ID or Touch ID to export clinical records",
                        forcePrompt: false
                    )
                }
                let exportManager = ExportManager.shared
                let options = ExportOptions(
                    includePhotos: true,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false
                )
                let package = try await exportManager.createExport(
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
    
    private func loadPhoto() async {
        guard let photoPath = session.photoPath, let sessionID = session.id else {
            isLoadingPhoto = false
            return
        }
        
        do {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fullPhotoPath = documentsURL
                .appendingPathComponent("PediLens")
                .appendingPathComponent("Photos")
                .appendingPathComponent(sessionID.uuidString)
                .appendingPathComponent(photoPath)
                .path
            
            let fileManager = FileStorageManager.shared
            let photoData = try await fileManager.loadPhoto(at: fullPhotoPath)
            
            if let image = UIImage(data: photoData) {
                await MainActor.run {
                    self.photoImage = image
                    self.imageIdentifier = "\(image.size.width)x\(image.size.height)"
                    self.isLoadingPhoto = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingPhoto = false
                    self.errorMessage = "Failed to decode photo"
                    self.showingError = true
                }
            }
        } catch {
            await MainActor.run {
                self.isLoadingPhoto = false
                self.errorMessage = "Failed to load photo: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
    
    private func loadExistingMeasurement() async {
        guard let existingMeasurement = session.measurement else {
            return
        }
        
        if let boundaryData = existingMeasurement.boundaryPoints,
           let points = try? JSONDecoder().decode([CGPoint].self, from: boundaryData) {
            
            let minX = points.map { $0.x }.min() ?? 0
            let minY = points.map { $0.y }.min() ?? 0
            let maxX = points.map { $0.x }.max() ?? 0
            let maxY = points.map { $0.y }.max() ?? 0
            
            let boundingBox = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY
            )
            
            let boundary = WoundBoundary(
                points: points,
                confidence: existingMeasurement.detectionConfidence,
                boundingBox: boundingBox,
                detectionMethod: existingMeasurement.isManuallyAdjusted ? .refined(originalConfidence: existingMeasurement.detectionConfidence) : .automatic(modelVersion: "1.0")
            )
            
            let lengthValue = existingMeasurement.lengthMM
            let widthValue = existingMeasurement.widthMM
            let areaValue = existingMeasurement.areaMM2
            let perimeterValue = existingMeasurement.perimeterMM
            let depthValue = existingMeasurement.depthMM
            let volumeValue = existingMeasurement.volumeMM3
            
            let savedCalibration: MeasurementCalibration
            if let calData = existingMeasurement.calibrationData,
               let decodedCal = try? JSONDecoder().decode(MeasurementCalibration.self, from: calData) {
                savedCalibration = decodedCal
            } else {
                savedCalibration = MeasurementCalibration.estimated(pixelsPerMillimeter: 10.0)
            }
            
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
            
            await MainActor.run {
                self.woundBoundary = boundary
                self.measurements = measurement
                self.customCalibration = savedCalibration
            }
        }
    }
    
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
                let boundary = try await detectionService.detectWoundBoundary(in: image, calibration: calibration)
                
                let measurementManager = MeasurementManager()
                let measurements = measurementManager.calculateMeasurements(
                    boundary: boundary,
                    calibration: calibration,
                    depthData: depthData
                )
                
                let measurement = Measurement(context: viewContext)
                measurement.id = UUID()
                measurement.lengthMM = measurements.length.value
                measurement.widthMM = measurements.width.value
                measurement.areaMM2 = measurements.area.value
                measurement.perimeterMM = measurements.perimeter.value
                measurement.depthMM = measurements.depth?.value ?? 0.0
                measurement.volumeMM3 = measurements.volume?.value ?? 0.0
                measurement.detectionConfidence = boundary.confidence
                measurement.isManuallyAdjusted = false
                measurement.captureSession = session
                
                if let boundaryData = try? JSONEncoder().encode(boundary.points) {
                    measurement.boundaryPoints = boundaryData
                }
                
                if let calibrationData = try? JSONEncoder().encode(calibration) {
                    measurement.calibrationData = calibrationData
                }
                
                try viewContext.save()
                
                await MainActor.run {
                    self.woundBoundary = boundary
                    self.measurements = measurements
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
    
    private func processManualBoundary(_ points: [CGPoint]) {
        guard let image = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                let minX = points.map { $0.x }.min() ?? 0
                let minY = points.map { $0.y }.min() ?? 0
                let maxX = points.map { $0.x }.max() ?? 0
                let maxY = points.map { $0.y }.max() ?? 0
                
                let boundingBox = CGRect(
                    x: minX,
                    y: minY,
                    width: maxX - minX,
                    height: maxY - minY
                )
                
                let boundary = WoundBoundary(
                    points: points,
                    confidence: 1.0,
                    boundingBox: boundingBox,
                    detectionMethod: .manual
                )
                
                var depthData: DepthData? = nil
                if let depthPath = session.depthDataPath, let sessionID = session.id {
                    depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
                }
                
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
                
                let measurementManager = MeasurementManager()
                let measurements = measurementManager.calculateMeasurements(
                    boundary: boundary,
                    calibration: calibration,
                    depthData: depthData
                )
                
                if let existingMeasurement = session.measurement {
                    viewContext.delete(existingMeasurement)
                }
                
                let measurement = Measurement(context: viewContext)
                measurement.id = UUID()
                measurement.lengthMM = measurements.length.value
                measurement.widthMM = measurements.width.value
                measurement.areaMM2 = measurements.area.value
                measurement.perimeterMM = measurements.perimeter.value
                measurement.depthMM = measurements.depth?.value ?? 0.0
                measurement.volumeMM3 = measurements.volume?.value ?? 0.0
                measurement.detectionConfidence = boundary.confidence
                measurement.isManuallyAdjusted = true
                measurement.captureSession = session
                
                if let boundaryData = try? JSONEncoder().encode(boundary.points) {
                    measurement.boundaryPoints = boundaryData
                }
                
                if let calibrationData = try? JSONEncoder().encode(calibration) {
                    measurement.calibrationData = calibrationData
                }
                
                try viewContext.save()
                
                await MainActor.run {
                    self.woundBoundary = boundary
                    self.measurements = measurements
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.errorMessage = "Failed to process manual boundary: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func reanalyzeWound() {
        guard let _ = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                if let existingMeasurement = session.measurement {
                    viewContext.delete(existingMeasurement)
                }
                analyzeWound()
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    self.errorMessage = "Re-analysis failed: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
    }
    
    private func applyCustomCalibration(_ newCalibration: MeasurementCalibration) {
        self.customCalibration = newCalibration
        
        guard let boundary = woundBoundary else {
            if let measurement = session.measurement {
                if let calData = try? JSONEncoder().encode(newCalibration) {
                    measurement.calibrationData = calData
                    try? viewContext.save()
                }
            }
            return
        }
        
        Task {
            var depthData: DepthData? = nil
            if let depthPath = session.depthDataPath, let sessionID = session.id {
                depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
            }
            
            let measurementManager = MeasurementManager()
            let updatedMeasurements = measurementManager.calculateMeasurements(
                boundary: boundary,
                calibration: newCalibration,
                depthData: depthData
            )
            
            await MainActor.run {
                let measurement = session.measurement ?? Measurement(context: viewContext)
                measurement.id = measurement.id ?? UUID()
                measurement.lengthMM = updatedMeasurements.length.value
                measurement.widthMM = updatedMeasurements.width.value
                measurement.areaMM2 = updatedMeasurements.area.value
                measurement.perimeterMM = updatedMeasurements.perimeter.value
                measurement.depthMM = updatedMeasurements.depth?.value ?? 0.0
                measurement.volumeMM3 = updatedMeasurements.volume?.value ?? 0.0
                measurement.isManuallyAdjusted = true
                measurement.captureSession = session
                
                if let calData = try? JSONEncoder().encode(newCalibration) {
                    measurement.calibrationData = calData
                }
                
                try? viewContext.save()
                self.measurements = updatedMeasurements
            }
        }
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
    
    // MARK: - Clinical Metric Tile
    
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
