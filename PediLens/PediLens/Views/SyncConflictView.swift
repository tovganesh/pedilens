//
//  SyncConflictView.swift
//  PediLens
//
//  UI for resolving sync conflicts
//

import SwiftUI

/// View for resolving sync conflicts
struct SyncConflictView: View {
    @StateObject private var viewModel = SyncConflictViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.conflicts.isEmpty {
                    ContentUnavailableView(
                        "No Conflicts",
                        systemImage: "checkmark.circle",
                        description: Text("All data is synchronized")
                    )
                } else {
                    ForEach(viewModel.conflicts, id: \.localVersion.objectID) { conflict in
                        ConflictRow(conflict: conflict, viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Sync Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await viewModel.loadConflicts()
            }
        }
    }
}

/// Row view for a single conflict
struct ConflictRow: View {
    let conflict: SyncConflict
    @ObservedObject var viewModel: SyncConflictViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(conflictTitle)
                .font(.headline)
            
            Text(conflictDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("Keep Local") {
                    Task {
                        await viewModel.resolveWithLocalVersion(conflict)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Keep Cloud") {
                    Task {
                        await viewModel.resolveWithCloudVersion(conflict)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Keep Both") {
                    Task {
                        await viewModel.resolveWithBothVersions(conflict)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .disabled(viewModel.isResolvingConflict)
        }
        .padding(.vertical, 8)
    }
    
    private var conflictTitle: String {
        switch conflict.conflictType {
        case .modifiedBoth:
            return "Modified on Both Devices"
        case .deletedLocally:
            return "Deleted Locally"
        case .deletedRemotely:
            return "Deleted on iCloud"
        }
    }
    
    private var conflictDescription: String {
        let entityName = conflict.localVersion.entity.name ?? "Record"
        
        switch conflict.conflictType {
        case .modifiedBoth:
            return "\(entityName) was modified on this device and on iCloud. Choose which version to keep."
        case .deletedLocally:
            return "\(entityName) was deleted on this device but still exists on iCloud."
        case .deletedRemotely:
            return "\(entityName) was deleted on iCloud but still exists on this device."
        }
    }
}

#Preview {
    SyncConflictView()
}
