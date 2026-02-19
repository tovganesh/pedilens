//
//  PersistenceController.swift
//  PediLens
//
//  Created by PediLens Team
//

import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    // Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Add sample data for previews
        let user = User(context: viewContext)
        user.id = UUID()
        user.role = UserRole.patient.rawValue
        user.createdAt = Date()
        user.iCloudSyncEnabled = false
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        // Detect if running in test environment
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        
        container = NSPersistentCloudKitContainer(name: "PediLens")
        
        // Configure persistent store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }
        
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.type = NSInMemoryStoreType
        }
        
        // Disable CloudKit for tests, in-memory stores, and personal development team
        // TODO: Re-enable CloudKit when using paid Apple Developer account
        description.cloudKitContainerOptions = nil
        
        if !isRunningTests && !inMemory {
            // Enable persistent history tracking for local sync
            description.setOption(true as NSNumber,
                                forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber,
                                forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // CloudKit temporarily disabled for personal development team
            // Uncomment when using paid Apple Developer account:
            /*
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.pedilens.app"
            )
            description.cloudKitContainerOptions = cloudKitOptions
            */
        }
        
        // Load stores synchronously for tests to avoid race conditions
        if isRunningTests || inMemory {
            description.shouldAddStoreAsynchronously = false
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                // In production, handle this error appropriately
                fatalError("Core Data store failed to load: \(error.localizedDescription)")
            }
        }
        
        // Automatically merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Use property-level merge policy (newer property values win)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Save the view context if there are changes
    func saveContext() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
