//
//  PersistenceControllerTests.swift
//  PediLensTests
//
//  Tests for PersistenceController singleton
//  Validates: Requirements 5.1, 6.1
//

import XCTest
import CoreData
@testable import PediLens

class PersistenceControllerTests: XCTestCase {
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceExists() {
        // When: Accessing the shared instance
        let instance = PersistenceController.shared
        
        // Then: It should not be nil
        XCTAssertNotNil(instance)
        XCTAssertNotNil(instance.container)
    }
    
    func testSharedInstanceIsSingleton() {
        // When: Accessing the shared instance multiple times
        let instance1 = PersistenceController.shared
        let instance2 = PersistenceController.shared
        
        // Then: Both references should point to the same instance
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Container Configuration Tests
    
    func testContainerIsNSPersistentCloudKitContainer() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // Then: The container should be NSPersistentCloudKitContainer
        XCTAssertTrue(controller.container is NSPersistentCloudKitContainer)
    }
    
    func testContainerName() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // Then: The container name should be "PediLens"
        XCTAssertEqual(controller.container.name, "PediLens")
    }
    
    func testPersistentHistoryTrackingEnabled() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // When: Checking the persistent store description
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }
        
        // Then: Persistent history tracking should be enabled
        let historyTracking = description.options[NSPersistentHistoryTrackingKey] as? NSNumber
        XCTAssertEqual(historyTracking?.boolValue, true)
    }
    
    func testRemoteChangeNotificationEnabled() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // When: Checking the persistent store description
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }
        
        // Then: Remote change notification should be enabled
        let remoteNotification = description.options[NSPersistentStoreRemoteChangeNotificationPostOptionKey] as? NSNumber
        XCTAssertEqual(remoteNotification?.boolValue, true)
    }
    
    func testCloudKitContainerIdentifier() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // When: Checking the persistent store description
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }
        
        // Then: CloudKit container identifier should be set correctly
        XCTAssertNotNil(description.cloudKitContainerOptions)
        XCTAssertEqual(description.cloudKitContainerOptions?.containerIdentifier, "iCloud.com.pedilens.app")
    }
    
    // MARK: - View Context Configuration Tests
    
    func testAutomaticallyMergesChangesFromParent() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // Then: View context should automatically merge changes from parent
        XCTAssertTrue(controller.container.viewContext.automaticallyMergesChangesFromParent)
    }
    
    func testMergePolicyConfiguration() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        
        // Then: Merge policy should be NSMergeByPropertyObjectTrumpMergePolicy
        let mergePolicy = controller.container.viewContext.mergePolicy as? NSMergePolicy
        XCTAssertEqual(mergePolicy, NSMergeByPropertyObjectTrumpMergePolicy)
    }
    
    // MARK: - In-Memory Store Tests
    
    func testInMemoryStoreCreation() {
        // When: Creating an in-memory persistence controller
        let controller = PersistenceController(inMemory: true)
        
        // Then: It should be configured with /dev/null URL
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }
        
        XCTAssertEqual(description.url?.path, "/dev/null")
    }
    
    func testInMemoryStoreDoesNotPersist() {
        // Given: An in-memory persistence controller
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // When: Creating and saving a user
        let user = User(context: context)
        user.id = UUID()
        user.role = "patient"
        user.createdAt = Date()
        user.iCloudSyncEnabled = false
        
        do {
            try context.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
        
        // Then: Data should exist in this instance
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try? context.fetch(fetchRequest)
        XCTAssertEqual(users?.count, 1)
        
        // But: Creating a new in-memory instance should have no data
        let newController = PersistenceController(inMemory: true)
        let newContext = newController.container.viewContext
        let newUsers = try? newContext.fetch(fetchRequest)
        XCTAssertEqual(newUsers?.count, 0)
    }
    
    // MARK: - Preview Instance Tests
    
    func testPreviewInstanceExists() {
        // When: Accessing the preview instance
        let preview = PersistenceController.preview
        
        // Then: It should not be nil and should be in-memory
        XCTAssertNotNil(preview)
        XCTAssertNotNil(preview.container)
    }
    
    func testPreviewInstanceHasSampleData() {
        // Given: The preview instance
        let preview = PersistenceController.preview
        let context = preview.container.viewContext
        
        // When: Fetching users
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try? context.fetch(fetchRequest)
        
        // Then: There should be at least one sample user
        XCTAssertNotNil(users)
        XCTAssertGreaterThanOrEqual(users?.count ?? 0, 1)
        
        // And: The sample user should have valid data
        if let user = users?.first {
            XCTAssertNotNil(user.id)
            XCTAssertNotNil(user.role)
            XCTAssertNotNil(user.createdAt)
        }
    }
    
    // MARK: - Save Context Tests
    
    func testSaveContextWithChanges() {
        // Given: An in-memory persistence controller
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // When: Creating a user and calling saveContext
        let user = User(context: context)
        user.id = UUID()
        user.role = "doctor"
        user.createdAt = Date()
        user.iCloudSyncEnabled = true
        
        XCTAssertTrue(context.hasChanges)
        controller.saveContext()
        
        // Then: Changes should be saved
        XCTAssertFalse(context.hasChanges)
        
        // And: Data should be retrievable
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try? context.fetch(fetchRequest)
        XCTAssertEqual(users?.count, 1)
        XCTAssertEqual(users?.first?.role, "doctor")
    }
    
    func testSaveContextWithoutChanges() {
        // Given: An in-memory persistence controller with no changes
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // When: Calling saveContext without making changes
        XCTAssertFalse(context.hasChanges)
        
        // Then: It should not throw an error
        controller.saveContext()
        XCTAssertFalse(context.hasChanges)
    }
    
    func testSaveContextWithMultipleEntities() {
        // Given: An in-memory persistence controller
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // When: Creating multiple related entities
        let user = User(context: context)
        user.id = UUID()
        user.role = "doctor"
        user.createdAt = Date()
        user.iCloudSyncEnabled = false
        
        let patient = Patient(context: context)
        patient.id = UUID()
        patient.name = "John Doe"
        patient.patientID = "P001"
        patient.createdAt = Date()
        patient.user = user
        
        let woundRecord = WoundRecord(context: context)
        woundRecord.id = UUID()
        woundRecord.location = "Left foot"
        woundRecord.initialAssessmentDate = Date()
        woundRecord.lastUpdated = Date()
        woundRecord.status = "active"
        woundRecord.patient = patient
        
        controller.saveContext()
        
        // Then: All entities should be saved and relationships maintained
        let userFetch: NSFetchRequest<User> = User.fetchRequest()
        let users = try? context.fetch(userFetch)
        XCTAssertEqual(users?.count, 1)
        
        let patientFetch: NSFetchRequest<Patient> = Patient.fetchRequest()
        let patients = try? context.fetch(patientFetch)
        XCTAssertEqual(patients?.count, 1)
        
        let woundFetch: NSFetchRequest<WoundRecord> = WoundRecord.fetchRequest()
        let wounds = try? context.fetch(woundFetch)
        XCTAssertEqual(wounds?.count, 1)
        
        // And: Relationships should be intact
        XCTAssertEqual(users?.first?.patients?.count, 1)
        XCTAssertEqual(patients?.first?.woundRecords?.count, 1)
        XCTAssertEqual(wounds?.first?.patient?.id, patient.id)
    }
    
    // MARK: - Core Data Model Tests
    
    func testAllEntitiesExist() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // Then: All required entities should exist
        let expectedEntities = ["User", "Patient", "WoundRecord", "CaptureSession", "Photo", "Measurement", "Note"]
        let entityNames = model.entities.map { $0.name ?? "" }
        
        for entityName in expectedEntities {
            XCTAssertTrue(entityNames.contains(entityName), "Entity \(entityName) not found in model")
        }
    }
    
    func testUserEntityAttributes() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // When: Getting the User entity
        guard let userEntity = model.entitiesByName["User"] else {
            XCTFail("User entity not found")
            return
        }
        
        // Then: It should have all required attributes
        let attributeNames = userEntity.attributesByName.keys.map { String($0) }
        XCTAssertTrue(attributeNames.contains("id"))
        XCTAssertTrue(attributeNames.contains("role"))
        XCTAssertTrue(attributeNames.contains("createdAt"))
        XCTAssertTrue(attributeNames.contains("iCloudSyncEnabled"))
    }
    
    func testPatientEntityAttributes() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // When: Getting the Patient entity
        guard let patientEntity = model.entitiesByName["Patient"] else {
            XCTFail("Patient entity not found")
            return
        }
        
        // Then: It should have all required attributes
        let attributeNames = patientEntity.attributesByName.keys.map { String($0) }
        XCTAssertTrue(attributeNames.contains("id"))
        XCTAssertTrue(attributeNames.contains("name"))
        XCTAssertTrue(attributeNames.contains("patientID"))
        XCTAssertTrue(attributeNames.contains("dateOfBirth"))
        XCTAssertTrue(attributeNames.contains("notes"))
        XCTAssertTrue(attributeNames.contains("createdAt"))
    }
    
    func testWoundRecordEntityAttributes() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // When: Getting the WoundRecord entity
        guard let woundEntity = model.entitiesByName["WoundRecord"] else {
            XCTFail("WoundRecord entity not found")
            return
        }
        
        // Then: It should have all required attributes
        let attributeNames = woundEntity.attributesByName.keys.map { String($0) }
        XCTAssertTrue(attributeNames.contains("id"))
        XCTAssertTrue(attributeNames.contains("location"))
        XCTAssertTrue(attributeNames.contains("initialAssessmentDate"))
        XCTAssertTrue(attributeNames.contains("status"))
        XCTAssertTrue(attributeNames.contains("lastUpdated"))
    }
    
    func testCaptureSessionEntityAttributes() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // When: Getting the CaptureSession entity
        guard let sessionEntity = model.entitiesByName["CaptureSession"] else {
            XCTFail("CaptureSession entity not found")
            return
        }
        
        // Then: It should have all required attributes
        let attributeNames = sessionEntity.attributesByName.keys.map { String($0) }
        XCTAssertTrue(attributeNames.contains("id"))
        XCTAssertTrue(attributeNames.contains("timestamp"))
        XCTAssertTrue(attributeNames.contains("photoPath"))
        XCTAssertTrue(attributeNames.contains("livePhotoVideoPath"))
        XCTAssertTrue(attributeNames.contains("depthDataPath"))
        XCTAssertTrue(attributeNames.contains("latitude"))
        XCTAssertTrue(attributeNames.contains("longitude"))
        XCTAssertTrue(attributeNames.contains("locationAvailable"))
    }
    
    func testMeasurementEntityAttributes() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // When: Getting the Measurement entity
        guard let measurementEntity = model.entitiesByName["Measurement"] else {
            XCTFail("Measurement entity not found")
            return
        }
        
        // Then: It should have all required attributes
        let attributeNames = measurementEntity.attributesByName.keys.map { String($0) }
        XCTAssertTrue(attributeNames.contains("id"))
        XCTAssertTrue(attributeNames.contains("lengthMM"))
        XCTAssertTrue(attributeNames.contains("widthMM"))
        XCTAssertTrue(attributeNames.contains("areaMM2"))
        XCTAssertTrue(attributeNames.contains("depthMM"))
        XCTAssertTrue(attributeNames.contains("volumeMM3"))
        XCTAssertTrue(attributeNames.contains("perimeterMM"))
        XCTAssertTrue(attributeNames.contains("boundaryPoints"))
        XCTAssertTrue(attributeNames.contains("calibrationData"))
        XCTAssertTrue(attributeNames.contains("isManuallyAdjusted"))
        XCTAssertTrue(attributeNames.contains("detectionConfidence"))
    }
    
    func testNoteEntityAttributes() {
        // Given: The shared persistence controller
        let controller = PersistenceController.shared
        let model = controller.container.managedObjectModel
        
        // When: Getting the Note entity
        guard let noteEntity = model.entitiesByName["Note"] else {
            XCTFail("Note entity not found")
            return
        }
        
        // Then: It should have all required attributes
        let attributeNames = noteEntity.attributesByName.keys.map { String($0) }
        XCTAssertTrue(attributeNames.contains("id"))
        XCTAssertTrue(attributeNames.contains("text"))
        XCTAssertTrue(attributeNames.contains("category"))
        XCTAssertTrue(attributeNames.contains("createdAt"))
    }
}
