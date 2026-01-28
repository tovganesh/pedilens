//
//  SyncStatusView.swift
//  PediLens
//
//  UI component for displaying sync status
//

import SwiftUI

/// View for displaying sync status indicator
struct SyncStatusView: View {
    let syncStatus: SyncStatus
    
    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            statusText
        }
        .font(.caption)
        .foregroundColor(statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusBackgroundColor)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch syncStatus {
        case .synced:
            Image(systemName: "checkmark.icloud")
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
        case .pending:
            Image(systemName: "clock.arrow.circlepath")
        case .offline:
            Image(systemName: "wifi.slash")
        case .error:
            Image(systemName: "exclamationmark.icloud")
        }
    }
    
    private var statusText: Text {
        switch syncStatus {
        case .synced:
            return Text("Synced")
        case .syncing(let progress):
            return Text("Syncing \(Int(progress * 100))%")
        case .pending(let itemCount):
            return Text("\(itemCount) pending")
        case .offline:
            return Text("Offline")
        case .error:
            return Text("Sync Error")
        }
    }
    
    private var statusColor: Color {
        switch syncStatus {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .pending:
            return .orange
        case .offline:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var statusBackgroundColor: Color {
        switch syncStatus {
        case .synced:
            return .green.opacity(0.1)
        case .syncing:
            return .blue.opacity(0.1)
        case .pending:
            return .orange.opacity(0.1)
        case .offline:
            return .gray.opacity(0.1)
        case .error:
            return .red.opacity(0.1)
        }
    }
}

/// View model for sync status
class SyncStatusViewModel: ObservableObject {
    @Published var syncStatus: SyncStatus = .synced
    
    private let syncManager: SyncManager
    
    init(syncManager: SyncManager = .shared) {
        self.syncManager = syncManager
        updateStatus()
    }
    
    func updateStatus() {
        syncStatus = syncManager.getSyncStatus()
    }
    
    func forceSyncNow() async {
        do {
            try await syncManager.forceSyncNow()
            updateStatus()
        } catch {
            syncStatus = .error("Sync failed: \(error.localizedDescription)")
        }
    }
}

/// Compact sync status indicator for toolbar
struct SyncStatusIndicator: View {
    @StateObject private var viewModel = SyncStatusViewModel()
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            statusIcon
        }
        .sheet(isPresented: $showingDetail) {
            SyncStatusDetailView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.updateStatus()
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch viewModel.syncStatus {
        case .synced:
            Image(systemName: "checkmark.icloud.fill")
                .foregroundColor(.green)
        case .syncing:
            ProgressView()
                .scaleEffect(0.8)
        case .pending:
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.orange)
        case .offline:
            Image(systemName: "wifi.slash")
                .foregroundColor(.gray)
        case .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundColor(.red)
        }
    }
}

/// Detailed sync status view
struct SyncStatusDetailView: View {
    @ObservedObject var viewModel: SyncStatusViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSyncing = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        SyncStatusView(syncStatus: viewModel.syncStatus)
                    }
                    
                    if case .syncing(let progress) = viewModel.syncStatus {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }
                    
                    if case .error(let message) = viewModel.syncStatus {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button {
                        Task {
                            isSyncing = true
                            await viewModel.forceSyncNow()
                            isSyncing = false
                        }
                    } label: {
                        HStack {
                            Text("Sync Now")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isSyncing)
                }
                
                Section {
                    Text("iCloud sync keeps your wound documentation up to date across all your devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Synced") {
    SyncStatusView(syncStatus: .synced)
}

#Preview("Syncing") {
    SyncStatusView(syncStatus: .syncing(progress: 0.65))
}

#Preview("Pending") {
    SyncStatusView(syncStatus: .pending(itemCount: 3))
}

#Preview("Offline") {
    SyncStatusView(syncStatus: .offline)
}

#Preview("Error") {
    SyncStatusView(syncStatus: .error("Network unavailable"))
}

#Preview("Indicator") {
    SyncStatusIndicator()
}
