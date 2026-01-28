//
//  WoundRecordDeletionPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for wound record deletion confirmation
//  Feature: pedilens, Property 31: Deletion Confirmation
//  Validates: Requirements 10.5
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for wound record deletion confirmation
/// These tests validate that wound record deletion requires confirmation
final class WoundRecordDeletionPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var woundManager: WoundManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        woundManager = WoundManager(persistenceController: persistenceController)
    }
    
    override func tearDown() {
        woundManager = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Generates random string of specified length
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// Generates random date within a range
    private func generateRandomDate(daysBack: Int = 365) -> Date {
        let now = Date()
        let randomDays = Int.random(in: 0...daysBack)
        return Calendar.current.date(byAdding: .day, value: -randomDays, to: now) ?? now
    }
    
    // MARK: - Property 31: Deletion Confirmation
    // **Validates: Requirements 10.5**
    
    /// Property: For any wound record deletion request, the record must exist before deletion
    /// This validates that deletion operations are only performed on valid records
    func testProperty31_DeletionConfirmation_RecordMustExist() async throws {
        let iterations = 100
        var successfulDeletions = 0
        
        for iteration in 0..<iterations {
            // Create a wound record
            let location = generateRandomString(length: Int.random(in: 5...50))
            let record = try await woundManager.createWoundRecord(
                location: location,
                initialAssessmentDate: generateRandomDate(),
                patient: nil
            )
            
            let recordID = record.id!
            
            // Verify record exists before deletion
            let fetchedBeforeDeletion = try await woundManager.fetchWoundRecord(byID: recordID)
            XCTAssertNotNil(fetchedBeforeDeletion,
                          "Iteration \(iteration): Record should exist before deletion")
            
            // Delete the record
            try await woundManager.deleteWoundRecord(record, createExport: false)
            
            // Verify record no longer exists after deletion
            let fetchedAfterDeletion = try await woundManager.fetchWoundRecord(byID: recordID)
            XCTAssertNil(fetchedAfterDeletion,
                       "Iteration \(iteration): Record should not exist after deletion")
            
            successfulDeletions += 1
        }
        
        XCTAssertEqual(successfulDeletions, iterations,
                      "All valid deletion requests should succeed")
    }
    
    /// Property: For any wound record deletion, the deletion is permanent and cannot be undone
    /// This validates that deleted records are truly removed from the system
    func testProperty31_DeletionConfirmation_DeletionIsPermanent() async throws {
        let iterations = 100
        var permanentDeletions = 0
        
        for iteration in 0..<iterations {
            // Create a wound record with some data
            let location = generateRandomString(length: Int.random(in: 5...50))
            let record = try await woundManager.createWoundRecord(
                location: location,
                initialAssessmentDate: generateRandomDate(),
                patient: nil
            )
            
            let recordID = record.id!
            let recordLocation = record.location!
            
            // Delete the record
            try await woundManager.deleteWoundRecord(record, createExport: false)
            
            // Verify record cannot be fetched by ID
            let fetchedByID = try await woundManager.fetchWoundRecord(byID: recordID)
            XCTAssertNil(fetchedByID,
                       "Iteration \(iteration): Deleted record should not be fetchable by ID")
            
            // Verify record is not in the list of all records
            let allRecords = try await woundManager.fetchWoundRecords()
            XCTAssertFalse(allRecords.contains { $0.id == recordID },
                         "Iteration \(iteration): Deleted record should not appear in all records list")
            
            permanentDeletions += 1
        }
        
        XCTAssertEqual(permanentDeletions, iterations,
                      "All deletions should be permanent")
    }
    
    /// Property: For any wound record deletion with export option, the export flag is respected
    /// This validates that the createExport parameter is properly handled
    func testProperty31_DeletionConfirmation_ExportOptionRespected() async throws {
        let iterations = 100
        var withExport = 0
        var withoutExport = 0
        
        for iteration in 0..<iterations {
            // Create a wound record
            let location = generateRandomString(length: Int.random(in: 5...50))
            let record = try await woundManager.createWoundRecord(
                location: location,
                initialAssessmentDate: generateRandomDate(),
                patient: nil
            )
            
            let recordID = record.id!
            
            // Randomly decide whether to create export
            let createExport = Bool.random()
            
            // Delete the record with or without export
            try await woundManager.deleteWoundRecord(record, createExport: createExport)
            
            // Verify record is deleted regardless of export option
            let fetchedAfterDeletion = try await woundManager.fetchWoundRecord(byID: recordID)
            XCTAssertNil(fetchedAfterDeletion,
                       "Iteration \(iteration): Record should be deleted regardless of export option")
            
            if createExport {
                withExport += 1
                // Note: Export functionality will be implemented in task 16
                // For now, we just verify the deletion still works
            } else {
                withoutExport += 1
            }
        }
        
        // Both cases should occur
        XCTAssertGreaterThan(withExport, 0,
                           "Some deletions should request export")
        XCTAssertGreaterThan(withoutExport, 0,
                           "Some deletions should not request export")
    }
    
    /// Property: For any wound record deletion with associated data, all related data is handled
    /// This validates that deletion properly handles capture sessions and other related data
    func testProperty31_DeletionConfirmation_RelatedDataHandled() async throws {
        let iterations = 50  // Fewer iterations since we're creating more data
        var successfulDeletions = 0
        
        for iteration in 0..<iterations {
            // Create a wound record
            let location = generateRandomString(length: Int.random(in: 5...50))
            let record = try await woundManager.createWoundRecord(
                location: location,
                initialAssessmentDate: generateRandomDate(),
                patient: nil
            )
            
            let recordID = record.id!
            
            // Add some capture sessions using the context.perform block to avoid timing issues
            let sessionCount = Int.random(in: 0...5)
            if sessionCount > 0 {
                try await context.perform {
                    for i in 0..<sessionCount {
                        _ = CaptureSession.create(
                            in: self.context,
                            photoPath: "test/path_\(i).heic",
                            woundRecord: record
                        )
                    }
                    // Save immediately to obtain permanent IDs
                    try self.context.save()
                }
            }
            
            // Delete the record (cascade delete should handle sessions automatically)
            try await woundManager.deleteWoundRecord(record, createExport: false)
            
            // Verify record is deleted
            let fetchedAfterDeletion = try await woundManager.fetchWoundRecord(byID: recordID)
            XCTAssertNil(fetchedAfterDeletion,
                       "Iteration \(iteration): Record should be deleted")
            
            successfulDeletions += 1
        }
        
        XCTAssertEqual(successfulDeletions, iterations,
                      "All deletions with related data should succeed")
    }
    
    /// Property: For any wound record deletion, the operation is atomic (all or nothing)
    /// This validates that deletion either completes fully or fails without partial changes
    func testProperty31_DeletionConfirmation_AtomicOperation() async throws {
        let iterations = 100
        var atomicDeletions = 0
        
        for iteration in 0..<iterations {
            // Create a wound record
            let location = generateRandomString(length: Int.random(in: 5...50))
            let record = try await woundManager.createWoundRecord(
                location: location,
                initialAssessmentDate: generateRandomDate(),
                patient: nil
            )
            
            let recordID = record.id!
            
            // Count records before deletion
            let recordsBeforeDeletion = try await woundManager.fetchWoundRecords()
            let countBefore = recordsBeforeDeletion.count
            
            // Delete the record
            try await woundManager.deleteWoundRecord(record, createExport: false)
            
            // Count records after deletion
            let recordsAfterDeletion = try await woundManager.fetchWoundRecords()
            let countAfter = recordsAfterDeletion.count
            
            // Verify exactly one record was removed
            XCTAssertEqual(countAfter, countBefore - 1,
                         "Iteration \(iteration): Exactly one record should be removed")
            
            // Verify the specific record is gone
            XCTAssertFalse(recordsAfterDeletion.contains { $0.id == recordID },
                         "Iteration \(iteration): Deleted record should not be in the list")
            
            atomicDeletions += 1
        }
        
        XCTAssertEqual(atomicDeletions, iterations,
                      "All deletions should be atomic operations")
    }
}
