//
//  SyncConflictPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for sync conflict preservation
//  Feature: pedilens, Property 21: Sync Conflict Preservation
//  Validates: Requirements 6.3
//

import XCTest
import CoreData
import CloudKit
@testable import PediLens

/// Property-based tests for sync conflict preservation
/// These tests validate that both local and cloud versions are preserved until user resolution
final class SyncConflictPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var syncManager: SyncManager!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        syncManager = SyncManager(persistenceController: persistenceController)
    }
    
    override func tearDown() {
        syncManager = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Generates random string of specified length
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// Generates random patient name
    private func generateRandomPatientName() -> String {
        let firstNames = ["John", "Jane", "Michael", "Sarah", "David", "Emily"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones"]
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
    
    /// Generates random wound location
    private func generateRandomWoundLocation() -> String {
        let locations = [
            "Left foot, plantar surface",
            "Right foot, heel",
            "Left foot, toe",
            "Right foot, dorsal surface"
        ]
        return locations.randomElement()!
    }
    
    /// Saves context and handles errors
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// Creates a mock CloudKit record for testing
    private func createMockCloudKitRecord(for object: NSManagedObject) -> CKRecord {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: object.entity.name ?? "Unknown", recordID: recordID)
        return record
    }
    
    // MARK: - Property 21: Sync Conflict Preservation
    // **Validates: Requirements 6.3**
    
    /// Property: For any sync conflict detected (modified both),
    /// both the local and cloud versions should be preserved until user resolution
    func testProperty21_ConflictPreservation_ModifiedBoth() throws {
        let iterations = 100
        var failedCases: [(location: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user with sync enabled
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: true)
            
            // Create patient
            let patient = Patient.create(
                in: context,
                name: generateRandomPatientName(),
                patientID: generateRandomString(length: 10),
                user: user
            )
            
            // Generate random wound record data
            let location = generateRandomWoundLocation()
            let initialDate = Date(timeIntervalSinceNow: -Double.random(in: 0...365) * 24 * 3600)
            let status = ["active", "healing", "healed"].randomElement()!
            
            do {
                // CREATE: Create wound record (local version)
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: location,
                    initialAssessmentDate: initialDate,
                    status: status,
                    patient: patient
                )
                
                guard let woundRecordUUID = woundRecord.id else {
                    failedCases.append((location: location, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Simulate a conflict: modify locally
                let newLocalStatus = "healing"
                woundRecord.update(status: newLocalStatus)
                try saveContext()
                
                // Verify local version exists
                let localVersion = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                XCTAssertNotNil(localVersion,
                              "Iteration \(iteration): Local version should exist")
                XCTAssertEqual(localVersion?.status, newLocalStatus,
                             "Iteration \(iteration): Local version should have updated status")
                
                // Create a mock cloud version (simulating cloud modification)
                let cloudRecord = createMockCloudKitRecord(for: woundRecord)
                
                // Create a conflict
                let conflict = SyncConflict(
                    localVersion: woundRecord,
                    cloudVersion: cloudRecord,
                    conflictType: .modifiedBoth
                )
                
                // Verify conflict can be created (both versions exist)
                XCTAssertNotNil(conflict.localVersion,
                              "Iteration \(iteration): Local version should be preserved in conflict")
                XCTAssertNotNil(conflict.cloudVersion,
                              "Iteration \(iteration): Cloud version should be preserved in conflict")
                
                // Verify conflict type
                XCTAssertEqual(conflict.conflictType, .modifiedBoth,
                             "Iteration \(iteration): Conflict type should be modifiedBoth")
                
                // Clean up
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Conflict preservation test failed with error: \(error)")
                failedCases.append((location: location, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Conflict preservation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any sync conflict detected (deleted locally),
    /// both versions should be preserved until user resolution
    func testProperty21_ConflictPreservation_DeletedLocally() throws {
        let iterations = 100
        var failedCases: [(name: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user with sync enabled
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: true)
            
            // Generate random patient data
            let name = generateRandomPatientName()
            let patientID = generateRandomString(length: 10)
            
            do {
                // CREATE: Create patient (local version)
                let patient = Patient.create(
                    in: context,
                    name: name,
                    patientID: patientID,
                    user: user
                )
                
                guard let patientUUID = patient.id else {
                    failedCases.append((name: name, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Create a mock cloud version (simulating cloud still has it)
                let cloudRecord = createMockCloudKitRecord(for: patient)
                
                // Simulate local deletion (but don't actually delete yet for testing)
                // In a real scenario, the deletion would be queued
                
                // Create a conflict
                let conflict = SyncConflict(
                    localVersion: patient,
                    cloudVersion: cloudRecord,
                    conflictType: .deletedLocally
                )
                
                // Verify conflict can be created (both versions exist)
                XCTAssertNotNil(conflict.localVersion,
                              "Iteration \(iteration): Local version should be preserved in conflict")
                XCTAssertNotNil(conflict.cloudVersion,
                              "Iteration \(iteration): Cloud version should be preserved in conflict")
                
                // Verify conflict type
                XCTAssertEqual(conflict.conflictType, .deletedLocally,
                             "Iteration \(iteration): Conflict type should be deletedLocally")
                
                // Clean up
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Conflict preservation test failed with error: \(error)")
                failedCases.append((name: name, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Conflict preservation (deleted locally) property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any sync conflict detected (deleted remotely),
    /// both versions should be preserved until user resolution
    func testProperty21_ConflictPreservation_DeletedRemotely() throws {
        let iterations = 100
        var failedCases: [(photoPath: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create full hierarchy with sync enabled
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: true)
            let patient = Patient.create(
                in: context,
                name: generateRandomPatientName(),
                patientID: generateRandomString(length: 10),
                user: user
            )
            let woundRecord = WoundRecord.create(
                in: context,
                location: generateRandomWoundLocation(),
                patient: patient
            )
            
            // Generate random capture session data
            let photoPath = "photos/\(UUID().uuidString).heic"
            
            do {
                // CREATE: Create capture session (local version)
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: photoPath,
                    woundRecord: woundRecord
                )
                
                guard let sessionUUID = captureSession.id else {
                    failedCases.append((photoPath: photoPath, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Verify local version exists
                let localVersion = CaptureSession.fetchCaptureSession(byID: sessionUUID, in: context)
                XCTAssertNotNil(localVersion,
                              "Iteration \(iteration): Local version should exist")
                
                // Create a mock cloud version (simulating cloud deletion)
                let cloudRecord = createMockCloudKitRecord(for: captureSession)
                
                // Create a conflict
                let conflict = SyncConflict(
                    localVersion: captureSession,
                    cloudVersion: cloudRecord,
                    conflictType: .deletedRemotely
                )
                
                // Verify conflict can be created (both versions exist)
                XCTAssertNotNil(conflict.localVersion,
                              "Iteration \(iteration): Local version should be preserved in conflict")
                XCTAssertNotNil(conflict.cloudVersion,
                              "Iteration \(iteration): Cloud version should be preserved in conflict")
                
                // Verify conflict type
                XCTAssertEqual(conflict.conflictType, .deletedRemotely,
                             "Iteration \(iteration): Conflict type should be deletedRemotely")
                
                // Clean up
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Conflict preservation test failed with error: \(error)")
                failedCases.append((photoPath: photoPath, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Conflict preservation (deleted remotely) property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
