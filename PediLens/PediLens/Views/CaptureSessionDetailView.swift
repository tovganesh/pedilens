//
//  CaptureSessionDetailView.swift
//  PediLens
//
//  Detail view for a capture session with photo, wound analysis, and export capabilities
//

import SwiftUI
import CoreData
import AVFoundation

/// Detail view for a capture session with photo and wound analysis
struct CaptureSessionDetailView: View {
    let session: CaptureSession
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var photoImage: UIImage?
    @State private var isLoadingPhoto = true
    @State private var isAnalyzing = false
    @State private var woundBoundary: WoundBoundary?
    @State private var measurements: WoundMeasurement?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var imageIdentifier: String = ""
    @State private var showingManualTrace = false
    @State private var showingReanalyzeConfirmation = false
    @State private var manualTracePoints: [CGPoint] = []
    
    // Export state
    @State private var showingExportSheet = false
    @State private var exportPackageToShare: ExportPackage?
    @State private var isExporting = false
    @State private var showingShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Photo display
                if isLoadingPhoto {
                    ProgressView("Loading photo...")
                        .frame(height: 300)
                } else if let image = photoImage {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
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
                            .frame(maxHeight: 400)
                            .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                        }
                    }
                    
                    // Wound boundary overlay if available
                    if let boundary = woundBoundary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wound Detection")
                                .font(.headline)
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Boundary detected")
                                    .font(.subheadline)
                                Spacer()
                                Text("Confidence: \(Int(boundary.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Disclaimer for automatic detection
                            if case .automatic = boundary.detectionMethod {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Experimental Feature")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text("Automatic detection is experimental. For accurate measurements, please use Manual Trace to verify or adjust the boundary.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Photo not available")
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 300)
                }
                
                // Session metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Information")
                        .font(.headline)
                    
                    LabeledContent("Captured", value: session.timestamp ?? Date(), format: .dateTime)
                    
                    if session.locationAvailable, let location = session.location {
                        LabeledContent("Location", value: "Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lon: \(String(format: "%.4f", location.coordinate.longitude))")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Measurements section
                if let measurements = measurements {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Measurements")
                                .font(.headline)
                            Spacer()
                            // Calibration status indicator
                            HStack(spacing: 4) {
                                Image(systemName: measurements.calibrationUsed.calibrationType.icon)
                                    .font(.caption)
                                Text(measurements.calibrationUsed.calibrationType.displayName)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(measurements.calibrationUsed.accuracy == .high ? .green : (measurements.calibrationUsed.accuracy == .medium ? .blue : .orange))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (measurements.calibrationUsed.accuracy == .high ? Color.green : (measurements.calibrationUsed.accuracy == .medium ? Color.blue : Color.orange)).opacity(0.12)
                            )
                            .clipShape(Capsule())
                        }
                        
                        // Warning if uncalibrated
                        if measurements.needsCalibrationWarning {
                            UncalibratedMeasurementWarning()
                        }
                        
                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            GridRow {
                                Text("Length:")
                                    .foregroundColor(.secondary)
                                Text(measurements.length.formatted())
                            }
                            
                            GridRow {
                                Text("Width:")
                                    .foregroundColor(.secondary)
                                Text(measurements.width.formatted())
                            }
                            
                            GridRow {
                                Text("Area:")
                                    .foregroundColor(.secondary)
                                Text(measurements.area.formatted())
                            }
                            
                            GridRow {
                                Text("Perimeter:")
                                    .foregroundColor(.secondary)
                                Text(measurements.perimeter.formatted())
                            }
                            
                            if let depth = measurements.depth {
                                GridRow {
                                    Text("Depth:")
                                        .foregroundColor(.secondary)
                                    Text(depth.formatted())
                                }
                            }
                            
                            if let volume = measurements.volume {
                                GridRow {
                                    Text("Volume:")
                                        .foregroundColor(.secondary)
                                    Text(volume.formatted())
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Action buttons when measurements exist
                    HStack(spacing: 12) {
                        Button(action: { showingManualTrace = true }) {
                            Label("Manual Trace", systemImage: "hand.draw")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Manually trace wound boundary")
                        
                        Button(action: { showingReanalyzeConfirmation = true }) {
                            Label("Re-analyze", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
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
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                } else if photoImage != nil {
                    VStack(spacing: 12) {
                        // Disclaimer before analysis
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Analysis Options")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Automatic detection is experimental. For best accuracy, use Manual Trace to draw the wound boundary yourself.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        Button(action: analyzeWound) {
                            Label("Auto-Detect Wound", systemImage: "waveform.path.ecg")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Automatically analyze wound and calculate measurements")
                        
                        Button(action: { showingManualTrace = true }) {
                            Label("Manual Trace (Recommended)", systemImage: "hand.draw")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Manually trace wound boundary for accurate measurements")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
                .accessibilityLabel("Export session")
                .disabled(session.woundRecord == nil || isExporting)
            }
        }
        .task {
            await loadPhoto()
            await loadExistingMeasurement()
        }
        .onChange(of: photoImage) { newValue in
            // When photo changes, check if we need to reload measurements
            if let newImage = newValue {
                let newIdentifier = "\(newImage.size.width)x\(newImage.size.height)"
                if newIdentifier != imageIdentifier {
                    imageIdentifier = newIdentifier
                    // Clear existing measurements to force re-analysis
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
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func exportSession(format: ExportFormat) {
        guard let woundRecord = session.woundRecord else { return }
        isExporting = true
        
        Task {
            do {
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
            // Reconstruct full path: Documents/PediLens/Photos/{sessionID}/photo.heic
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
        // Check if measurement already exists for this session
        guard let existingMeasurement = session.measurement else {
            return
        }
        
        // Decode boundary points
        if let boundaryData = existingMeasurement.boundaryPoints,
           let points = try? JSONDecoder().decode([CGPoint].self, from: boundaryData) {
            
            // Reconstruct WoundBoundary
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
            
            // Reconstruct WoundMeasurement using Foundation.Measurement
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
            }
        }
    }
    
    private func analyzeWound() {
        guard let image = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                // STEP 1: Detect reference scale for calibration
                print("🔍 Step 1: Detecting reference scale...")
                let scaleService = ScaleDetectionService()
                let calibration: MeasurementCalibration
                
                if let scaleInfo = try? await scaleService.detectReferenceScale(in: image) {
                    // Scale detected! Use it for calibration
                    if let detectedCalibration = MeasurementCalibration.fromReferenceScale(scaleInfo) {
                        calibration = detectedCalibration
                        print("✅ Scale detected: \(calibration.calibrationType.displayName)")
                        print("   Accuracy: \(calibration.accuracy.description)")
                        print("   Pixels per cm: \(String(format: "%.2f", calibration.pixelsPerCentimeter))")
                    } else {
                        // Scale detected but calibration failed
                        calibration = MeasurementCalibration.estimated()
                        print("⚠️ Scale detected but calibration failed, using estimated")
                    }
                } else {
                    // No scale detected, use estimated calibration
                    calibration = MeasurementCalibration.estimated()
                    print("ℹ️ No reference scale detected, using estimated calibration")
                    print("   Accuracy: \(calibration.accuracy.description)")
                }
                
                // STEP 2: Load depth data if available
                print("🔍 Step 2: Loading depth data...")
                var depthData: DepthData? = nil
                if let depthPath = session.depthDataPath, let sessionID = session.id {
                    depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
                    if depthData != nil {
                        print("✅ Depth data loaded")
                    }
                }
                
                // STEP 3: Run wound detection using CoreML model
                print("🔍 Step 3: Detecting wound boundary...")
                let detectionService = CoreMLWoundDetectionService()
                let boundary = try await detectionService.detectWoundBoundary(in: image, calibration: calibration)
                print("✅ Wound boundary detected with \(boundary.points.count) points")
                
                // STEP 4: Calculate measurements with detected calibration
                print("🔍 Step 4: Calculating measurements...")
                let measurementManager = MeasurementManager()
                let measurements = measurementManager.calculateMeasurements(
                    boundary: boundary,
                    calibration: calibration,
                    depthData: depthData
                )
                print("✅ Measurements calculated:")
                print("   Length: \(String(format: "%.2f", measurements.length.value))mm")
                print("   Width: \(String(format: "%.2f", measurements.width.value))mm")
                print("   Area: \(String(format: "%.2f", measurements.area.value))mm²")
                print("   Calibration: \(calibration.calibrationType.displayName)")
                
                // STEP 5: Save measurement to Core Data
                print("🔍 Step 5: Saving to database...")
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
                
                // Encode boundary points
                if let boundaryData = try? JSONEncoder().encode(boundary.points) {
                    measurement.boundaryPoints = boundaryData
                }
                
                // Encode calibration data (with new calibration type)
                if let calibrationData = try? JSONEncoder().encode(calibration) {
                    measurement.calibrationData = calibrationData
                }
                
                try viewContext.save()
                print("✅ Saved to database")
                
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
    
    /// Load depth data from file storage
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
        
        // Decode depth data
        guard let depthDict = try JSONSerialization.jsonObject(with: depthDataEncoded) as? [String: Any],
              let width = depthDict["width"] as? Int,
              let height = depthDict["height"] as? Int,
              let depthBytesBase64 = depthDict["depthBytes"] as? String,
              let bytesPerRow = depthDict["bytesPerRow"] as? Int,
              let depthBytes = Data(base64Encoded: depthBytesBase64) else {
            throw NSError(domain: "DepthDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode depth data"])
        }
        
        // Create pixel buffer from depth bytes
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
        
        // Copy depth bytes to pixel buffer
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
    
    /// Process manually traced boundary
    private func processManualBoundary(_ points: [CGPoint]) {
        guard let image = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                // Calculate bounding box
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
                
                // Create boundary from manual points
                let boundary = WoundBoundary(
                    points: points,
                    confidence: 1.0, // Manual tracing has 100% confidence
                    boundingBox: boundingBox,
                    detectionMethod: .manual
                )
                
                // Load depth data if available
                var depthData: DepthData? = nil
                if let depthPath = session.depthDataPath, let sessionID = session.id {
                    depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
                }
                
                // Determine calibration to use (reuse existing calibration, detect scale, or fallback to estimated)
                let calibration: MeasurementCalibration
                if let existingCalData = session.measurement?.calibrationData,
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
                
                // Delete existing measurement if any
                if let existingMeasurement = session.measurement {
                    viewContext.delete(existingMeasurement)
                }
                
                // Save new measurement
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
                
                // Encode boundary points
                if let boundaryData = try? JSONEncoder().encode(boundary.points) {
                    measurement.boundaryPoints = boundaryData
                }
                
                // Encode calibration data
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
    
    /// Re-analyze wound with confirmation
    private func reanalyzeWound() {
        guard let _ = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                // Delete existing measurement
                if let existingMeasurement = session.measurement {
                    viewContext.delete(existingMeasurement)
                }
                
                // Run new analysis
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
