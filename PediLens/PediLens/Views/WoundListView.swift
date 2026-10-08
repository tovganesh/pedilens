//
//  WoundListView.swift
//  PediLens
//
//  Patient role wound list view with wound management, sync status, and storage settings
//

import SwiftUI
import CoreData

/// View for patient role - shows list of their wound records
struct WoundListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var syncManager = SyncManager.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WoundRecord.lastUpdated, ascending: false)],
        animation: .default)
    private var woundRecords: FetchedResults<WoundRecord>
    
    @State private var showingNewWoundSheet = false
    @State private var showingStorageSheet = false
    @State private var selectedWound: WoundRecord?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sync status indicator bar
                HStack {
                    SyncStatusView(syncStatus: syncManager.syncStatus)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                
                List {
                    ForEach(woundRecords) { wound in
                        NavigationLink(destination: WoundDetailView(woundRecord: wound)) {
                            WoundRowView(woundRecord: wound)
                        }
                    }
                    .onDelete(perform: deleteWounds)
                }
            }
            .navigationTitle("My Wounds")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingStorageSheet = true }) {
                            Image(systemName: "internaldrive")
                        }
                        .accessibilityLabel("Storage Management")
                        
                        Button(action: { showingNewWoundSheet = true }) {
                            Label("Add Wound", systemImage: "plus")
                        }
                        .accessibilityLabel("Add new wound record")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingNewWoundSheet) {
                NewWoundView()
            }
            .sheet(isPresented: $showingStorageSheet) {
                StorageManagementView()
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
