//
//  WoundDetailView.swift
//  PediLens
//
//  Detail view for a wound record showing metadata, capture sessions, and capture CTA
//

import SwiftUI
import CoreData

/// Detail view for a wound record
struct WoundDetailView: View {
    let woundRecord: WoundRecord
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showingCameraView = false
    @State private var refreshID = UUID()
    @State private var showingExportSheet = false
    @State private var exportPackageToShare: ExportPackage?
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
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
                
                // Show remarks if available
                if let notes = woundRecord.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remarks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { exportWound(format: .pdf) }) {
                        Label("Export PDF Report", systemImage: "doc.text.fill")
                    }
                    Button(action: { exportWound(format: .images) }) {
                        Label("Export Image Package", systemImage: "photo.stack")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export wound record")
                .disabled(captureSessions.isEmpty || isExporting)
            }
        }
        .sheet(isPresented: $showingCameraView) {
            CameraView(woundRecord: woundRecord, onDismiss: {
                // Refresh the view when camera is dismissed
                refreshID = UUID()
                // Force Core Data to refresh
                viewContext.refresh(woundRecord, mergeChanges: true)
            })
        }
        .sheet(isPresented: $showingShareSheet) {
            if let package = exportPackageToShare {
                ActivityViewController(activityItems: [package.fileURL])
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func exportWound(format: ExportFormat) {
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
}
