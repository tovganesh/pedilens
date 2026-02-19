//
//  ContentView.swift
//  PediLens
//
//  Created by PediLens Team
//

import SwiftUI
import CoreData
import AVFoundation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var userManager = UserManager.shared
    
    @FetchRequest(
        sortDescriptors: [],
        animation: .default)
    private var users: FetchedResults<User>
    
    var currentUser: User? {
        users.first
    }
    
    var body: some View {
        Group {
            if let user = currentUser, let role = userManager.currentUserRole {
                switch role {
                case .doctor:
                    PatientListView(user: user)
                case .patient:
                    WoundListView()
                }
            } else {
                // Fallback if role not set (shouldn't happen after onboarding)
                LoadingView()
            }
        }
        .onAppear {
            userManager.loadCurrentUser()
        }
    }
}

/// View for patient role - shows list of their wound records
struct WoundListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WoundRecord.lastUpdated, ascending: false)],
        animation: .default)
    private var woundRecords: FetchedResults<WoundRecord>
    
    @State private var showingNewWoundSheet = false
    @State private var selectedWound: WoundRecord?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(woundRecords) { wound in
                    NavigationLink(destination: WoundDetailView(woundRecord: wound)) {
                        WoundRowView(woundRecord: wound)
                    }
                }
                .onDelete(perform: deleteWounds)
            }
            .navigationTitle("My Wounds")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewWoundSheet = true }) {
                        Label("Add Wound", systemImage: "plus")
                    }
                    .accessibilityLabel("Add new wound record")
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingNewWoundSheet) {
                NewWoundView()
            }
            .overlay {
                if woundRecords.isEmpty {
                    EmptyWoundListView(showingNewWoundSheet: $showingNewWoundSheet)
                }
            }
        }
    }
    
    private func deleteWounds(offsets: IndexSet) {
        withAnimation {
            offsets.map { woundRecords[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting wound: \(error)")
            }
        }
    }
}

/// Row view for wound list
struct WoundRowView: View {
    let woundRecord: WoundRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(woundRecord.location ?? "Unknown Location")
                .font(.headline)
            
            Text("Last updated: \(woundRecord.lastUpdated ?? Date(), style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let sessions = woundRecord.captureSessions as? Set<CaptureSession> {
                Text("\(sessions.count) capture sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Empty state view
struct EmptyWoundListView: View {
    @Binding var showingNewWoundSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cross.case")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Wound Records")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to create your first wound record and start documenting.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingNewWoundSheet = true }) {
                Label("Add Wound Record", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Add your first wound record")
        }
    }
}

/// View for creating a new wound record
struct NewWoundView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var location = ""
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isLocationValid: Bool {
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wound Information")) {
                    TextField("Location (e.g., Left foot, plantar surface)", text: $location)
                        .accessibilityLabel("Wound location")
                    
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .accessibilityLabel("Additional notes")
                }
                
                Section {
                    Text("Initial assessment date: \(Date(), style: .date)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Wound Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createWound()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createWound() {
        let wound = WoundRecord(context: viewContext)
        wound.id = UUID()
        wound.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        wound.initialAssessmentDate = Date()
        wound.lastUpdated = Date()
        wound.status = "active"
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create wound record: \(error.localizedDescription)"
            showingError = true
        }
    }
}

/// Detail view for a wound record
struct WoundDetailView: View {
    let woundRecord: WoundRecord
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingCameraView = false
    @State private var refreshID = UUID()
    
    var captureSessions: [CaptureSession] {
        let sessions = woundRecord.captureSessions as? Set<CaptureSession> ?? []
        return sessions.sorted { $0.timestamp ?? Date() > $1.timestamp ?? Date() }
    }
    
    var body: some View {
        List {
            Section(header: Text("Wound Information")) {
                LabeledContent("Location", value: woundRecord.location ?? "Unknown")
                LabeledContent("Initial Assessment", value: woundRecord.initialAssessmentDate ?? Date(), format: .dateTime)
                LabeledContent("Status", value: woundRecord.status ?? "active")
            }
            
            Section(header: Text("Capture Sessions")) {
                if captureSessions.isEmpty {
                    Text("No photos captured yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(captureSessions) { session in
                        NavigationLink(destination: CaptureSessionDetailView(session: session)) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading) {
                                    Text(session.timestamp ?? Date(), style: .date)
                                        .font(.headline)
                                    Text(session.timestamp ?? Date(), style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: { showingCameraView = true }) {
                    Label("Capture Wound Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Capture new wound photo")
            }
        }
        .id(refreshID)
        .navigationTitle(woundRecord.location ?? "Wound")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCameraView) {
            CameraView(woundRecord: woundRecord, onDismiss: {
                // Refresh the view when camera is dismissed
                refreshID = UUID()
                // Force Core Data to refresh
                viewContext.refresh(woundRecord, mergeChanges: true)
            })
        }
    }
}

/// Camera view with live preview and capture
struct CameraView: View {
    let woundRecord: WoundRecord
    var onDismiss: (() -> Void)? = nil
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var cameraManager = CameraManager()
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top bar
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Capture button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .disabled(isCapturing)
                    .accessibilityLabel("Capture photo")
                    
                    Text("Tap to capture wound photo")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Task {
                do {
                    try await cameraManager.startSession()
                } catch {
                    errorMessage = "Failed to start camera: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                if errorMessage.contains("camera") {
                    dismiss()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func capturePhoto() {
        isCapturing = true
        
        Task {
            do {
                let capturedMedia = try await cameraManager.capturePhoto(livePhotoEnabled: false)
                
                // Create capture session
                let session = CaptureSession(context: viewContext)
                session.id = UUID()
                session.timestamp = Date()
                session.photoPath = "" // Will be set after saving photo
                session.woundRecord = woundRecord
                
                // Save photo to file storage
                let fileManager = FileStorageManager.shared
                let photoURL = try await fileManager.savePhoto(capturedMedia.photoData, for: session.id!)
                session.photoPath = photoURL.lastPathComponent
                
                // Save depth data if available
                if let depthData = capturedMedia.depthData {
                    // Convert depth map to Data
                    if let depthDataEncoded = try? encodeDepthData(depthData) {
                        let depthURL = try await fileManager.saveDepthData(depthDataEncoded, for: session.id!)
                        session.depthDataPath = depthURL.lastPathComponent
                    }
                }
                
                // Update wound record
                woundRecord.lastUpdated = Date()
                
                // Save to Core Data
                try viewContext.save()
                
                // Call onDismiss callback before dismissing
                await MainActor.run {
                    onDismiss?()
                }
                
                // Dismiss camera
                dismiss()
            } catch {
                errorMessage = "Failed to capture photo: \(error.localizedDescription)"
                showingError = true
                isCapturing = false
            }
        }
    }
    
    /// Encode depth data to Data for storage
    private func encodeDepthData(_ depthData: DepthData) throws -> Data {
        // Create a dictionary to store depth information
        var depthDict: [String: Any] = [:]
        
        // Store depth map dimensions
        let width = CVPixelBufferGetWidth(depthData.depthMap)
        let height = CVPixelBufferGetHeight(depthData.depthMap)
        depthDict["width"] = width
        depthDict["height"] = height
        depthDict["accuracy"] = depthData.accuracy == .absolute ? "absolute" : "relative"
        
        // Lock the pixel buffer to access data
        CVPixelBufferLockBaseAddress(depthData.depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthData.depthMap, .readOnly) }
        
        // Get the base address and bytes per row
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthData.depthMap) else {
            throw NSError(domain: "DepthDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get depth map base address"])
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthData.depthMap)
        let dataSize = bytesPerRow * height
        
        // Copy depth data
        let depthBytes = Data(bytes: baseAddress, count: dataSize)
        
        // Encode as JSON with depth bytes as base64
        depthDict["depthBytes"] = depthBytes.base64EncodedString()
        depthDict["bytesPerRow"] = bytesPerRow
        
        return try JSONSerialization.data(withJSONObject: depthDict)
    }
}

/// UIViewRepresentable wrapper for camera preview
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        // Add preview layer
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame when view size changes
        if let previewLayer = cameraManager.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

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
                        Text("Measurements")
                            .font(.headline)
                        
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
                        Button(action: analyzeWound) {
                            Label("Analyze Wound", systemImage: "waveform.path.ecg")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Analyze wound and calculate measurements")
                        
                        Button(action: { showingManualTrace = true }) {
                            Label("Manual Trace", systemImage: "hand.draw")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("Manually trace wound boundary")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
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
            
            let measurement = WoundMeasurement(
                length: Foundation.Measurement(value: lengthValue, unit: UnitLength.millimeters),
                width: Foundation.Measurement(value: widthValue, unit: UnitLength.millimeters),
                area: Foundation.Measurement(value: areaValue, unit: UnitArea.squareMillimeters),
                depth: depthValue > 0 ? Foundation.Measurement(value: depthValue, unit: UnitLength.millimeters) : nil,
                volume: volumeValue > 0 ? Foundation.Measurement(value: volumeValue, unit: UnitVolume.cubicMillimeters) : nil,
                perimeter: Foundation.Measurement(value: perimeterValue, unit: UnitLength.millimeters),
                timestamp: session.timestamp ?? Date(),
                calibrationUsed: MeasurementCalibration(
                    pixelsPerMillimeter: 10.0,
                    referenceObject: .ruler(lengthMM: 100),
                    calibrationDate: Date(),
                    depthCalibration: nil
                )
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
                // Load depth data if available
                var depthData: DepthData? = nil
                if let depthPath = session.depthDataPath, let sessionID = session.id {
                    depthData = try? await loadDepthData(sessionID: sessionID, depthPath: depthPath)
                }
                
                // Run wound detection
                let detectionService = WoundDetectionService()
                let boundary = try await detectionService.detectWoundBoundary(in: image, calibration: nil)
                
                // Calculate measurements
                // For now, use a default calibration (in production, this would come from user calibration)
                let defaultCalibration = MeasurementCalibration(
                    pixelsPerMillimeter: 10.0, // Placeholder value
                    referenceObject: .ruler(lengthMM: 100),
                    calibrationDate: Date(),
                    depthCalibration: nil
                )
                
                let measurementManager = MeasurementManager()
                let measurements = measurementManager.calculateMeasurements(
                    boundary: boundary,
                    calibration: defaultCalibration,
                    depthData: depthData
                )
                
                // Save measurement to Core Data
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
                
                // Encode calibration data
                if let calibrationData = try? JSONEncoder().encode(defaultCalibration) {
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
        
        // Note: We can't reconstruct AVCameraCalibrationData from saved data
        // For now, we'll create a simplified DepthData without calibration
        // In production, you'd need to save and restore calibration parameters
        
        let accuracy: DepthAccuracy = (depthDict["accuracy"] as? String) == "absolute" ? .absolute : .relative
        
        // Create a mock calibration data - in production this would be properly saved/restored
        // For now, we'll use the depth map without full calibration
        throw NSError(domain: "DepthDataError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Depth data loading not fully implemented - calibration data cannot be reconstructed"])
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
                
                // Calculate measurements
                let defaultCalibration = MeasurementCalibration(
                    pixelsPerMillimeter: 10.0,
                    referenceObject: .ruler(lengthMM: 100),
                    calibrationDate: Date(),
                    depthCalibration: nil
                )
                
                let measurementManager = MeasurementManager()
                let measurements = measurementManager.calculateMeasurements(
                    boundary: boundary,
                    calibration: defaultCalibration,
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
                if let calibrationData = try? JSONEncoder().encode(defaultCalibration) {
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
        guard let image = photoImage else { return }
        
        isAnalyzing = true
        
        Task {
            do {
                // Delete existing measurement
                if let existingMeasurement = session.measurement {
                    viewContext.delete(existingMeasurement)
                }
                
                // Run new analysis
                await analyzeWound()
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

/// Loading view
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}

/// Wound boundary overlay view
struct WoundBoundaryOverlay: View {
    let boundary: WoundBoundary
    let imageSize: CGSize
    let displaySize: CGSize
    
    var body: some View {
        Canvas { context, size in
            // Calculate scale factors
            let scaleX = size.width / imageSize.width
            let scaleY = size.height / imageSize.height
            
            // Create path from boundary points
            var path = Path()
            
            if let firstPoint = boundary.points.first {
                let scaledFirst = CGPoint(
                    x: firstPoint.x * scaleX,
                    y: firstPoint.y * scaleY
                )
                path.move(to: scaledFirst)
                
                for point in boundary.points.dropFirst() {
                    let scaledPoint = CGPoint(
                        x: point.x * scaleX,
                        y: point.y * scaleY
                    )
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
                        
                        // Calculate scale from image to display
                        let scaleX = size.width / image.size.width
                        let scaleY = size.height / image.size.height
                        
                        var path = Path()
                        let firstScaled = CGPoint(
                            x: tracePoints[0].x * scaleX,
                            y: tracePoints[0].y * scaleY
                        )
                        path.move(to: firstScaled)
                        
                        for point in tracePoints.dropFirst() {
                            let scaledPoint = CGPoint(
                                x: point.x * scaleX,
                                y: point.y * scaleY
                            )
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
                            let scaledPoint = CGPoint(
                                x: point.x * scaleX,
                                y: point.y * scaleY
                            )
                            
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
        // Check if tapping near an existing point to select it
        let scaleX = image.size.width / viewSize.width
        let scaleY = image.size.height / viewSize.height
        
        let imagePoint = CGPoint(
            x: location.x * scaleX,
            y: location.y * scaleY
        )
        
        // Check if tapping near an existing point (within 20 pixels)
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
        // Convert from view coordinates to image coordinates
        let scaleX = image.size.width / viewSize.width
        let scaleY = image.size.height / viewSize.height
        
        let imagePoint = CGPoint(
            x: location.x * scaleX,
            y: location.y * scaleY
        )
        
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
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        
        let displayPoint = CGPoint(
            x: point.x * scaleX,
            y: point.y * scaleY
        )
        
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
                        // value.location is in the coordinate space of the parent
                        let newImagePoint = CGPoint(
                            x: value.location.x / scaleX,
                            y: value.location.y / scaleY
                        )
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
