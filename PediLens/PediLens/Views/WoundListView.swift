//
//  WoundListView.swift
//  PediLens
//
//  Patient role wound list view with wound management, sync status, and storage settings
//  with adaptive layout for iPhone Duo Cover Screen & Internal Screen.
//

import SwiftUI
import CoreData

/// View for patient role - shows list of their wound records
struct WoundListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.duoGeometry) private var duoGeometry
    @StateObject private var syncManager = SyncManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WoundRecord.lastUpdated, ascending: false)],
        animation: .default)
    private var woundRecords: FetchedResults<WoundRecord>
    
    @State private var showingNewWoundSheet = false
    @State private var showingStorageSheet = false
    @State private var selectedWound: WoundRecord?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    private var activeSelectedWound: WoundRecord? {
        if let selected = selectedWound, woundRecords.contains(where: { $0.objectID == selected.objectID }) {
            return selected
        }
        return woundRecords.first
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            woundSidebarContent
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        } detail: {
            NavigationStack {
                if let wound = activeSelectedWound {
                    WoundDetailView(woundRecord: wound)
                } else {
                    splitPlaceholderView
                }
            }
        }
        .onAppear {
            if selectedWound == nil, let first = woundRecords.first {
                selectedWound = first
            }
        }
        .sheet(isPresented: $showingNewWoundSheet) {
            NewWoundView()
        }
        .sheet(isPresented: $showingStorageSheet) {
            StorageManagementView()
        }
    }
    
    @ViewBuilder
    private var woundSidebarContent: some View {
        VStack(spacing: 0) {
            // Sync status indicator bar
            HStack {
                SyncStatusView(syncStatus: syncManager.syncStatus)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, duoGeometry.isCoverScreen ? 4 : 6)
            
            List(selection: $selectedWound) {
                ForEach(woundRecords, id: \.self) { wound in
                    NavigationLink(value: wound) {
                        WoundRowView(woundRecord: wound)
                    }
                }
                .onDelete(perform: deleteWounds)
            }
            .navigationDestination(for: WoundRecord.self) { wound in
                WoundDetailView(woundRecord: wound)
            }
        }
        .navigationTitle("My Wounds")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showingStorageSheet = true }) {
                        Image(systemName: "internaldrive")
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Storage Management")
                    
                    Button(action: { showingNewWoundSheet = true }) {
                        Label("Add Wound", systemImage: "plus")
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Add new wound record")
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .overlay {
            if woundRecords.isEmpty {
                EmptyWoundListView(showingNewWoundSheet: $showingNewWoundSheet)
            }
        }
    }
    
    private var splitPlaceholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.7))
            
            Text("No Wound Selected")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select a wound record from the list on the left to review its history, capture photos, and inspect healing progress.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pediLensGlass(cornerRadius: 20)
        .padding()
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
                Text("\(sessions.count) photo sessions")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Empty state view when no wounds exist
struct EmptyWoundListView: View {
    @Binding var showingNewWoundSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cross.case")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Wounds Tracked")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start tracking your wound healing progress by adding your first wound.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingNewWoundSheet = true }) {
                Label("Add Your First Wound", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .pediLensGlassButton(prominent: true)
            .padding(.top, 10)
        }
        .padding()
    }
}
