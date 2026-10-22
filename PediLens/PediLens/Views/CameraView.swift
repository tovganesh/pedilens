//
//  CameraView.swift
//  PediLens
//
//  Camera capture view with live preview, LiDAR distance guidance, and media persistence.
//  Adapted for iPhone Duo: Compact one-hand capture on Cover Screen (466x678 pt)
//  and Ergonomic thumb-rail capture on Internal Screen (669x951 pt).
//

import SwiftUI
import CoreData
import AVFoundation

/// Camera view with live preview and capture
struct CameraView: View {
    let woundRecord: WoundRecord
    var onDismiss: (() -> Void)? = nil
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.duoGeometry) private var duoGeometry
    
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var arManager = ARMeasurementManager()
    @State private var captureSessionManager: CaptureSessionManager?
    @State private var patientCaptureManager = PatientCaptureManager.shared
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCapturing = false
    
    var body: some View {
        ZStack {
            // Camera preview fills screen
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Adaptive Controls Overlay
            if duoGeometry.isInternalExpanded {
                // Internal Screen: Two-Hand Ergonomic Layout with Right-Hand Thumb Rail
                internalExpandedOverlay
            } else {
                // Cover Screen & Standard: Compact Vertical Overlay
                coverScreenOverlay
            }
        }
        .onAppear {
            captureSessionManager = CaptureSessionManager(persistenceController: .shared)
            
            if arManager.isLiDARAvailable {
                arManager.startSession()
            }
            
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
            if arManager.isLiDARAvailable {
                arManager.pauseSession()
            }
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
    
    // MARK: - Internal Screen Ergonomic Layout
    
    private var internalExpandedOverlay: some View {
        VStack {
            // Top Bar spanning outside edges
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .pediLensGlassPill(interactive: true)
                .padding(.leading, 20)
                
                Spacer()
                
                if let patient = woundRecord.patient {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(patient.name ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        if let patientID = patient.patientID {
                            Text("ID: \(patientID)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .pediLensGlass(cornerRadius: 12)
                    .padding(.trailing, 20)
                }
            }
            .padding(.top, 10)
            
            Spacer()
            
            // Lower cluster: Guidance on left/center, Shutter button anchored in right thumb zone
            HStack(alignment: .bottom) {
                // Calibration Guidance HUD on left pane
                CalibrationGuideView(
                    isLiDARAvailable: arManager.isLiDARAvailable,
                    distanceStatus: arManager.distanceStatus,
                    currentDistance: arManager.currentDistance,
                    detectedScale: nil
                )
                .padding(.leading, 24)
                .padding(.bottom, 24)
                
                Spacer()
                
                // Right thumb capture cluster
                VStack(spacing: 12) {
                    captureShutterButton(diameter: 74, outerDiameter: 86)
                    
                    Text("Capture")
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .pediLensGlassPill()
                }
                .padding(.trailing, 32)
                .padding(.bottom, 28)
            }
        }
    }
    
    // MARK: - Cover Screen Compact Layout
    
    private var coverScreenOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .pediLensGlassPill(interactive: true)
                .padding(.leading, 12)
                
                Spacer()
                
                if let patient = woundRecord.patient {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(patient.name ?? "Unknown")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        if let patientID = patient.patientID {
                            Text("ID: \(patientID)")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .pediLensGlass(cornerRadius: 10)
                    .padding(.trailing, 12)
                }
            }
            .padding(.top, duoGeometry.isCoverScreen ? 4 : 8)
            
            // Calibration Guidance HUD
            CalibrationGuideView(
                isLiDARAvailable: arManager.isLiDARAvailable,
                distanceStatus: arManager.distanceStatus,
                currentDistance: arManager.currentDistance,
                detectedScale: nil
            )
            .scaleEffect(duoGeometry.isCoverScreen ? 0.9 : 1.0)
            
            Spacer()
            
            // Bottom controls
            VStack(spacing: 10) {
                captureShutterButton(
                    diameter: duoGeometry.isCoverScreen ? 62 : 70,
                    outerDiameter: duoGeometry.isCoverScreen ? 74 : 82
                )
                
                Text("Tap to capture wound photo")
                    .foregroundColor(.white)
                    .font(.caption2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .pediLensGlassPill()
            }
            .padding(.bottom, duoGeometry.isCoverScreen ? 16 : 36)
        }
    }
    
    @ViewBuilder
    private func captureShutterButton(diameter: CGFloat, outerDiameter: CGFloat) -> some View {
        Button(action: capturePhoto) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: diameter, height: diameter)
                
                Circle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 3)
                    .frame(width: outerDiameter, height: outerDiameter)
            }
        }
        .disabled(isCapturing)
        .accessibilityLabel("Capture photo")
    }
    
    private func capturePhoto() {
        isCapturing = true
        
        Task {
            do {
                let capturedMedia = try await cameraManager.capturePhoto(livePhotoEnabled: false)
                
                guard let sessionManager = captureSessionManager else {
                    throw NSError(domain: "CameraView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Capture session manager not initialized"])
                }
                
                let session = try await sessionManager.createCaptureSession(
                    photoPath: "photo.heic",
                    livePhotoVideoPath: nil,
                    depthDataPath: nil,
                    location: capturedMedia.metadata.location,
                    woundRecord: woundRecord
                )
                
                guard let sessionID = session.id else {
                    throw NSError(domain: "CameraView", code: -2, userInfo: [NSLocalizedDescriptionKey: "Session ID not available"])
                }
                
                let fileManager = FileStorageManager.shared
                let photoURL = try await fileManager.savePhoto(capturedMedia.photoData, for: sessionID)
                
                var depthDataPath: String?
                if let depthData = capturedMedia.depthData {
                    if let depthDataEncoded = try? encodeDepthData(depthData) {
                        let depthURL = try await fileManager.saveDepthData(depthDataEncoded, for: sessionID)
                        depthDataPath = depthURL.lastPathComponent
                    }
                }
                
                var livePhotoVideoPath: String?
                if let livePhotoURL = capturedMedia.livePhotoVideoURL {
                    let videoURL = try await fileManager.saveLivePhotoVideo(livePhotoURL, for: sessionID)
                    livePhotoVideoPath = videoURL.lastPathComponent
                }
                
                try await sessionManager.updatePaths(
                    for: session,
                    photoPath: photoURL.lastPathComponent,
                    livePhotoVideoPath: livePhotoVideoPath,
                    depthDataPath: depthDataPath
                )
                
                if let patient = woundRecord.patient {
                    patientCaptureManager.associatePatientMetadata(
                        with: sessionID,
                        patient: patient,
                        context: viewContext
                    )
                }
                
                woundRecord.lastUpdated = Date()
                try viewContext.save()
                
                await MainActor.run {
                    onDismiss?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCapturing = false
                    errorMessage = "Failed to capture photo: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func encodeDepthData(_ depthData: DepthData) throws -> Data {
        let depthMap = depthData.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            throw NSError(domain: "DepthDataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get base address"])
        }
        
        let totalBytes = bytesPerRow * height
        let depthBytes = Data(bytes: baseAddress, count: totalBytes)
        
        let depthDict: [String: Any] = [
            "width": width,
            "height": height,
            "bytesPerRow": bytesPerRow,
            "depthBytes": depthBytes.base64EncodedString(),
            "accuracy": depthData.accuracy == .absolute ? "absolute" : "relative"
        ]
        
        return try JSONSerialization.data(withJSONObject: depthDict)
    }
}

/// UIViewRepresentable wrapper for camera preview
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}
