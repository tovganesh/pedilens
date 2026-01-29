//
//  StorageManagementView.swift
//  PediLens
//
//  Storage management UI for displaying usage and providing cleanup tools
//  Requirements: 5.5
//

import SwiftUI

struct StorageManagementView: View {
    @StateObject private var viewModel = StorageManagementViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Storage usage section
                    storageUsageSection
                    
                    // Warning if near capacity
                    if viewModel.isNearCapacity {
                        storageWarningBanner
                    }
                    
                    // Cleanup tools section
                    cleanupToolsSection
                    
                    // Storage breakdown section
                    storageBreakdownSection
                }
                .padding()
            }
            .navigationTitle("Storage Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadStorageInfo()
            }
            .refreshable {
                await viewModel.loadStorageInfo()
            }
            .alert("Cleanup Complete", isPresented: $viewModel.showCleanupAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.cleanupMessage)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private var storageUsageSection: some View {
        VStack(spacing: 16) {
            // Storage gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: viewModel.usagePercentage)
                    .stroke(
                        viewModel.isNearCapacity ? Color.red : Color.blue,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: viewModel.usagePercentage)
                
                VStack(spacing: 4) {
                    Text("\(Int(viewModel.usagePercentage * 100))%")
                        .font(.system(size: 48, weight: .bold))
                    
                    Text("Used")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Storage usage")
            .accessibilityValue("\(Int(viewModel.usagePercentage * 100)) percent used")
            
            // Storage details
            VStack(spacing: 8) {
                HStack {
                    Text("Used")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.formattedUsedSpace)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Available")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.formattedAvailableSpace)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Total Photos")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.photoCount)")
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var storageWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Storage Warning")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Text("You're using \(Int(viewModel.usagePercentage * 100))% of your storage. Consider cleaning up old files.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Storage warning")
        .accessibilityValue("Using \(Int(viewModel.usagePercentage * 100)) percent of storage")
    }
    
    private var cleanupToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup Tools")
                .font(.headline)
            
            // Cleanup orphaned files button
            Button(action: {
                Task {
                    await viewModel.cleanupOrphanedFiles()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clean Up Orphaned Files")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Remove files that are no longer associated with any records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.isCleaningUp {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .disabled(viewModel.isCleaningUp)
            .accessibilityLabel("Clean up orphaned files")
            .accessibilityHint("Removes files that are no longer associated with any records")
            
            // Clear detection cache button
            Button(action: {
                viewModel.clearDetectionCache()
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clear Detection Cache")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Clear cached wound detection results to free up memory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "memorychip")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .accessibilityLabel("Clear detection cache")
            .accessibilityHint("Clears cached wound detection results to free up memory")
        }
    }
    
    private var storageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Breakdown")
                .font(.headline)
            
            VStack(spacing: 12) {
                StorageBreakdownRow(
                    label: "Photos",
                    icon: "photo",
                    color: .blue,
                    size: viewModel.formattedUsedSpace
                )
                
                StorageBreakdownRow(
                    label: "Thumbnails",
                    icon: "photo.on.rectangle",
                    color: .green,
                    size: "Included"
                )
                
                StorageBreakdownRow(
                    label: "Depth Data",
                    icon: "cube",
                    color: .purple,
                    size: "Included"
                )
                
                StorageBreakdownRow(
                    label: "Live Photos",
                    icon: "livephoto",
                    color: .orange,
                    size: "Included"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct StorageBreakdownRow: View {
    let label: String
    let icon: String
    let color: Color
    let size: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(size)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - ViewModel

@MainActor
class StorageManagementViewModel: ObservableObject {
    @Published var storageInfo: StorageInfo?
    @Published var isLoading = false
    @Published var isCleaningUp = false
    @Published var showCleanupAlert = false
    @Published var cleanupMessage = ""
    @Published var showError = false
    @Published var errorMessage: String?
    
    var usagePercentage: Double {
        guard let info = storageInfo else { return 0 }
        let total = Double(info.totalUsedBytes + info.availableBytes)
        guard total > 0 else { return 0 }
        return Double(info.totalUsedBytes) / total
    }
    
    var isNearCapacity: Bool {
        return usagePercentage >= 0.80
    }
    
    var formattedUsedSpace: String {
        guard let info = storageInfo else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: info.totalUsedBytes, countStyle: .file)
    }
    
    var formattedAvailableSpace: String {
        guard let info = storageInfo else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: info.availableBytes, countStyle: .file)
    }
    
    var photoCount: Int {
        return storageInfo?.photoCount ?? 0
    }
    
    func loadStorageInfo() async {
        isLoading = true
        defer { isLoading = false }
        
        storageInfo = await FileStorageManager.shared.getStorageUsage()
    }
    
    func cleanupOrphanedFiles() async {
        isCleaningUp = true
        defer { isCleaningUp = false }
        
        do {
            let cleanedCount = try await FileStorageManager.shared.cleanupOrphanedFiles()
            
            // Reload storage info
            await loadStorageInfo()
            
            // Show success message
            cleanupMessage = "Successfully cleaned up \(cleanedCount) orphaned file\(cleanedCount == 1 ? "" : "s")."
            showCleanupAlert = true
        } catch {
            errorMessage = "Failed to clean up orphaned files: \(error.localizedDescription)"
            showError = true
        }
    }
    
    func clearDetectionCache() {
        PerformanceOptimizer.shared.clearDetectionCache()
        cleanupMessage = "Detection cache cleared successfully."
        showCleanupAlert = true
    }
}

// MARK: - Previews

struct StorageManagementView_Previews: PreviewProvider {
    static var previews: some View {
        StorageManagementView()
    }
}
