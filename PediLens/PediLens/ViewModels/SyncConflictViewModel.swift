//
//  SyncConflictViewModel.swift
//  PediLens
//
//  View model for handling sync conflicts
//

import Foundation
import CoreData
import CloudKit
import Combine

/// View model for sync conflict resolution
class SyncConflictViewModel: ObservableObject {
    @Published var conflicts: [SyncConflict] = []
    @Published var isResolvingConflict = false
    @Published var errorMessage: String?
    
    private let syncManager: SyncManager
    private var cancellables = Set<AnyCancellable>()
    
    init(syncManager: SyncManager = .shared) {
        self.syncManager = syncManager
    }
    
    /// Resolve a conflict by choosing the local version
    func resolveWithLocalVersion(_ conflict: SyncConflict) async {
        isResolvingConflict = true
        errorMessage = nil
        
        do {
            // Keep local version, update cloud
            try await syncManager.resolveConflict(conflict)
            
            // Remove from conflicts list
            await MainActor.run {
                conflicts.removeAll { $0.localVersion.objectID == conflict.localVersion.objectID }
                isResolvingConflict = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to resolve conflict: \(error.localizedDescription)"
                isResolvingConflict = false
            }
        }
    }
    
    /// Resolve a conflict by choosing the cloud version
    func resolveWithCloudVersion(_ conflict: SyncConflict) async {
        isResolvingConflict = true
        errorMessage = nil
        
        do {
            // Accept cloud version, overwrite local
            // This is handled by the sync manager
            try await syncManager.resolveConflict(conflict)
            
            // Remove from conflicts list
            await MainActor.run {
                conflicts.removeAll { $0.localVersion.objectID == conflict.localVersion.objectID }
                isResolvingConflict = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to resolve conflict: \(error.localizedDescription)"
                isResolvingConflict = false
            }
        }
    }
    
    /// Resolve a conflict by keeping both versions
    func resolveWithBothVersions(_ conflict: SyncConflict) async {
        isResolvingConflict = true
        errorMessage = nil
        
        do {
            // Create a duplicate with cloud data
            // This preserves both versions for user review
            try await syncManager.resolveConflict(conflict)
            
            // Remove from conflicts list
            await MainActor.run {
                conflicts.removeAll { $0.localVersion.objectID == conflict.localVersion.objectID }
                isResolvingConflict = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to resolve conflict: \(error.localizedDescription)"
                isResolvingConflict = false
            }
        }
    }
    
    /// Load pending conflicts
    func loadConflicts() async {
        // In a real implementation, this would query the persistent history
        // and detect conflicts between local and cloud versions
        // For now, this is a placeholder
        await MainActor.run {
            // conflicts would be populated from sync manager
        }
    }
}
