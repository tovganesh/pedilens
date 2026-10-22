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
    
    private var activeSelectedWound: WoundRecord? {
        if let selected = selectedWound, woundRecords.contains(where: { $0.objectID == selected.objectID }) {
            return selected
        }
        return woundRecords.first
    }
    
    var body: some View {
        Group {
            if duoGeometry.isInternalExpanded {
                // Internal Screen: Adaptive Dual-Pane Split Layout
                HStack(spacing: 0) {
                    // Master sidebar: Wound list
                    NavigationView {
                        woundListContent(isSplitMaster: true)
                    }
                    .navigationViewStyle(.stack)
                    .frame(width: duoGeometry.masterPaneWidth)
                    
                    // Central hinge crease gutter / separator
                    ZStack {
                        Rectangle()
                            .fill(Color(uiColor: .separator).opacity(0.3))
                            .frame(width: 1)
                    }
                    .frame(width: 16)
                    
                    // Detail pane: Selected wound record
                    NavigationView {
                        if let wound = activeSelectedWound {
                            WoundDetailView(woundRecord: wound)
                        } else {
                            splitPlaceholderView
                        }
                    }
                    .navigationViewStyle(.stack)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // Cover Screen & Standard: Single-column stack navigation
                NavigationView {
                    woundListContent(isSplitMaster: false)
                }
                .navigationViewStyle(.stack)
                .duoCoverScreenPadding()
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
    private func woundListContent(isSplitMaster: Bool) -> some View {
        VStack(spacing: 0) {
            // Sync status indicator bar
            HStack {
                SyncStatusView(syncStatus: syncManager.syncStatus)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, duoGeometry.isCoverScreen ? 4 : 6)
            
            List {
                ForEach(woundRecords) { wound in
                    if isSplitMaster {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedWound = wound
                            }
                        }) {
                            WoundRowView(woundRecord: wound)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(activeSelectedWound?.objectID == wound.objectID ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        NavigationLink(destination: WoundDetailView(woundRecord: wound)) {
                            WoundRowView(woundRecord: wound)
                        }
                    }
                }
                .onDelete(perform: deleteWounds)
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
            }
            .pediLensGlassButton(prominent: true)
            .accessibilityLabel("Add your first wound record")
        }
    }
}
