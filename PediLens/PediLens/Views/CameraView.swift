//
//  CameraView.swift
//  PediLens
//
//  Camera capture view with live preview, LiDAR distance guidance, and media persistence
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
    
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var arManager = ARMeasurementManager()
    @State private var captureSessionManager: CaptureSessionManager?
    @State private var patientCaptureManager = PatientCaptureManager.shared
    
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
                    
                    // Show patient info if available
                    if let patient = woundRecord.patient {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(patient.name ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.white)
                            if let patientID = patient.patientID {
                                Text("ID: \(patientID)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.trailing)
                    }
                }
                
                // Calibration Guidance HUD
                CalibrationGuideView(
                    isLiDARAvailable: arManager.isLiDARAvailable,
                    distanceStatus: arManager.distanceStatus,
                    currentDistance: arManager.currentDistance,
                    detectedScale: nil
                )
                
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
            // Initialize capture session manager
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
    
    private func capturePhoto() {
        isCapturing = true
        
        Task {
            do {
                // Capture photo using CameraManager
                let capturedMedia = try await cameraManager.capturePhoto(livePhotoEnabled: false)
                
                // Create capture session first to get the session ID
                guard let sessionManager = captureSessionManager else {
                    throw NSError(domain: "CameraView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Capture session manager not initialized"])
                }
                
                // Create session with temporary path, we'll update it after saving files
                let session = try await sessionManager.createCaptureSession(
                    photoPath: "photo.heic",  // Temporary, will be the actual filename
                    livePhotoVideoPath: nil,
                    depthDataPath: nil,
                    location: capturedMedia.metadata.location,
                    woundRecord: woundRecord
                )
                
                // Now use the session's ID to save files
                guard let sessionID = session.id else {
                    throw NSError(domain: "CameraView", code: -2, userInfo: [NSLocalizedDescriptionKey: "Session ID not available"])
                }
                
                // Save photo to file storage
                let fileManager = FileStorageManager.shared
                let photoURL = try await fileManager.savePhoto(capturedMedia.photoData, for: sessionID)
                
                // Save depth data if available
                var depthDataPath: String?
                if let depthData = capturedMedia.depthData {
                    if let depthDataEncoded = try? encodeDepthData(depthData) {
                        let depthURL = try await fileManager.saveDepthData(depthDataEncoded, for: sessionID)
                        depthDataPath = depthURL.lastPathComponent
                    }
                }
                
                // Save live photo video if available
                var livePhotoVideoPath: String?
                if let livePhotoURL = capturedMedia.livePhotoVideoURL {
                    // Copy live photo video to permanent storage
                    let videoURL = try await fileManager.saveLivePhotoVideo(livePhotoURL, for: sessionID)
                    livePhotoVideoPath = videoURL.lastPathComponent
                }
                
                // Update session paths
                try await sessionManager.updatePaths(
                    for: session,
                    photoPath: photoURL.lastPathComponent,
                    livePhotoVideoPath: livePhotoVideoPath,
                    depthDataPath: depthDataPath
                )
                
                // Associate patient metadata if available
                if let patient = woundRecord.patient {
                    patientCaptureManager.associatePatientMetadata(
                        with: sessionID,
                        patient: patient,
                        context: viewContext
                    )
                }
                
                // Update wound record
                woundRecord.lastUpdated = Date()
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
