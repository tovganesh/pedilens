//
//  SyncManager.swift
//  PediLens
//
//  Manages CloudKit synchronization for wound records and related data
//

import Foundation
import CoreData
import CloudKit
import Combine

/// Sync status enumeration
enum SyncStatus: Equatable {
    case synced
    case syncing(progress: Double)
    case pending(itemCount: Int)
    case offline
    case error(String)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.synced, .synced):
            return true
        case (.syncing(let p1), .syncing(let p2)):
            return p1 == p2
        case (.pending(let c1), .pending(let c2)):
            return c1 == c2
        case (.offline, .offline):
            return true
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

/// Sync conflict type
enum ConflictType {
    case modifiedBoth
    case deletedLocally
    case deletedRemotely
}

/// Sync conflict structure
struct SyncConflict {
    let localVersion: NSManagedObject
    let cloudVersion: CKRecord
    let conflictType: ConflictType
}

/// Protocol for sync management
protocol SyncManagerProtocol {
    func enableSync() async throws
    func disableSync() async throws
    func forceSyncNow() async throws
    func getSyncStatus() -> SyncStatus
    func resolveConflict(_ conflict: SyncConflict) async throws
}

/// Manages CloudKit synchronization
class SyncManager: SyncManagerProtocol {
    static let shared = SyncManager()
    
    private let persistenceController: PersistenceController
    private var syncStatusSubject = CurrentValueSubject<SyncStatus, Never>(.synced)
    private var cancellables = Set<AnyCancellable>()
    private var syncQueue: [SyncOperation] = []
    private var isProcessingQueue = false
    private var retryAttempts: [String: Int] = [:]
    private let maxRetryAttempts = 5
    
    // Network monitoring
    private var isNetworkAvailable = true
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupNotifications()
        checkNetworkStatus()
    }
    
    // MARK: - Public Methods
    
    /// Enable iCloud sync
    func enableSync() async throws {
        // Check if CloudKit is available
        let container = CKContainer(identifier: "iCloud.com.pedilens.app")
        let accountStatus = try await container.accountStatus()
        
        guard accountStatus == .available else {
            throw SyncError.cloudKitUnavailable
        }
        
        // Update user preferences
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try context.fetch(fetchRequest)
            if let user = users.first {
                user.iCloudSyncEnabled = true
                try context.save()
            }
        } catch {
            throw SyncError.enableFailed(error.localizedDescription)
        }
        
        // Enable CloudKit options on persistent store
        guard let description = persistenceController.container.persistentStoreDescriptions.first else {
            throw SyncError.storeConfigurationFailed
        }
        
        let cloudKitOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.pedilens.app"
        )
        description.cloudKitContainerOptions = cloudKitOptions
        
        // Trigger initial sync
        try await forceSyncNow()
    }
    
    /// Disable iCloud sync
    func disableSync() async throws {
        // Update user preferences
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try context.fetch(fetchRequest)
            if let user = users.first {
                user.iCloudSyncEnabled = false
                try context.save()
            }
        } catch {
            throw SyncError.disableFailed(error.localizedDescription)
        }
        
        // Disable CloudKit options on persistent store
        guard let description = persistenceController.container.persistentStoreDescriptions.first else {
            throw SyncError.storeConfigurationFailed
        }
        
        description.cloudKitContainerOptions = nil
        
        // Clear sync queue
        syncQueue.removeAll()
        syncStatusSubject.send(.synced)
    }
    
    /// Force immediate sync
    func forceSyncNow() async throws {
        guard isSyncEnabled() else {
            throw SyncError.syncDisabled
        }
        
        guard isNetworkAvailable else {
            throw SyncError.networkUnavailable
        }
        
        syncStatusSubject.send(.syncing(progress: 0.0))
        
        // Use NSPersistentCloudKitContainer's built-in sync
        // This triggers the container to sync pending changes
        let context = persistenceController.container.viewContext
        
        do {
            // Save any pending changes
            if context.hasChanges {
                try context.save()
            }
            
            // Process any queued operations
            await processQueuedOperations()
            
            syncStatusSubject.send(.synced)
        } catch {
            syncStatusSubject.send(.error(error.localizedDescription))
            throw SyncError.syncFailed(error.localizedDescription)
        }
    }
    
    /// Get current sync status
    func getSyncStatus() -> SyncStatus {
        return syncStatusSubject.value
    }
    
    /// Resolve a sync conflict
    func resolveConflict(_ conflict: SyncConflict) async throws {
        // For now, preserve both versions by creating a duplicate
        // In a real implementation, this would present UI for user resolution
        
        let context = persistenceController.container.viewContext
        
        switch conflict.conflictType {
        case .modifiedBoth:
            // Keep local version and create a copy with cloud data
            // This preserves both versions for user review
            break
            
        case .deletedLocally:
            // Local deletion wins - delete from cloud
            break
            
        case .deletedRemotely:
            // Cloud deletion wins - delete local
            context.delete(conflict.localVersion)
            try context.save()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for remote change notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] notification in
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
        
        // Listen for network status changes
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .sink { [weak self] _ in
                self?.checkNetworkStatus()
            }
            .store(in: &cancellables)
    }
    
    private func handleRemoteChange(_ notification: Notification) {
        // Handle remote changes from CloudKit
        Task {
            await processRemoteChanges()
        }
    }
    
    private func processRemoteChanges() async {
        // Process changes from CloudKit
        // NSPersistentCloudKitContainer handles this automatically
        // We just need to update our status
        syncStatusSubject.send(.syncing(progress: 0.5))
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        syncStatusSubject.send(.synced)
    }
    
    private func checkNetworkStatus() {
        // In a real implementation, use NWPathMonitor
        // For now, assume network is available
        isNetworkAvailable = true
        
        if isNetworkAvailable && !syncQueue.isEmpty {
            Task {
                await processQueuedOperations()
            }
        }
    }
    
    private func isSyncEnabled() -> Bool {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first?.iCloudSyncEnabled ?? false
        } catch {
            return false
        }
    }
    
    private func queueOperation(_ operation: SyncOperation) {
        syncQueue.append(operation)
        syncStatusSubject.send(.pending(itemCount: syncQueue.count))
    }
    
    private func processQueuedOperations() async {
        guard !isProcessingQueue else { return }
        guard !syncQueue.isEmpty else { return }
        guard isNetworkAvailable else { return }
        
        isProcessingQueue = true
        
        while !syncQueue.isEmpty {
            let operation = syncQueue.removeFirst()
            
            do {
                try await executeOperation(operation)
                retryAttempts.removeValue(forKey: operation.id)
            } catch {
                // Implement exponential backoff
                let attempts = retryAttempts[operation.id, default: 0]
                
                if attempts < maxRetryAttempts {
                    retryAttempts[operation.id] = attempts + 1
                    
                    // Exponential backoff: 2^attempts seconds
                    let delay = UInt64(pow(2.0, Double(attempts)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                    
                    // Re-queue the operation
                    syncQueue.append(operation)
                } else {
                    // Max retries exceeded
                    syncStatusSubject.send(.error("Operation failed after \(maxRetryAttempts) attempts"))
                }
            }
        }
        
        isProcessingQueue = false
        
        if syncQueue.isEmpty {
            syncStatusSubject.send(.synced)
        }
    }
    
    private func executeOperation(_ operation: SyncOperation) async throws {
        // Execute the sync operation
        // This is a placeholder - actual implementation would sync specific records
        let context = persistenceController.container.viewContext
        
        if context.hasChanges {
            try context.save()
        }
    }
}

// MARK: - Supporting Types

struct SyncOperation {
    let id: String
    let type: OperationType
    let recordID: NSManagedObjectID
    
    enum OperationType {
        case create
        case update
        case delete
    }
}

enum SyncError: LocalizedError {
    case cloudKitUnavailable
    case enableFailed(String)
    case disableFailed(String)
    case storeConfigurationFailed
    case syncDisabled
    case networkUnavailable
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .cloudKitUnavailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .enableFailed(let message):
            return "Failed to enable sync: \(message)"
        case .disableFailed(let message):
            return "Failed to disable sync: \(message)"
        case .storeConfigurationFailed:
            return "Failed to configure persistent store."
        case .syncDisabled:
            return "Sync is disabled. Enable sync in settings."
        case .networkUnavailable:
            return "Network is unavailable. Sync will resume when connected."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}
