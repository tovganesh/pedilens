//
//  WoundRecordCreationPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for wound record creation prompts
//  Feature: pedilens, Property 30: Wound Record Creation Prompts
//  Validates: Requirements 10.2
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for wound record creation prompts
/// These tests validate that wound record creation requires proper prompts for location, date, and patient info
final class WoundRecordCreationPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 30: Wound Record Creation Prompts
    // **Validates: Requirements 10.2**
    
    /// Property: For any wound record creation, location prompt is required and must not be empty
    /// This validates that wound records cannot be created without a valid location
    func testProperty30_WoundRecordCreation_LocationRequired() async throws {
        let iterations = 100
        var successfulCreations = 0
        var failedValidations = 0
        
        for iteration in 0..<iterations {
            // Generate random location (some empty, some valid)
            let shouldBeValid = Bool.random()
            let location: String
            
            if shouldBeValid {
                // Generate valid location
                location = generateRandomString(length: Int.random(in: 5...50))
            } else {
                // Generate invalid location (empty or whitespace)
                location = Bool.random() ? "" : String(repeating: " ", count: Int.random(in: 0...5))
            }
            
            do {
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    initialAssessmentDate: generateRandomDate(),
                    patient: nil
                )
                
                // If creation succeeded, location must be valid
                XCTAssertFalse(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                             "Iteration \(iteration): Empty location should not allow creation")
                XCTAssertNotNil(record.location,
                              "Iteration \(iteration): Created record should have location")
                XCTAssertFalse(record.location?.isEmpty ?? true,
                             "Iteration \(iteration): Created record location should not be empty")
                
                successfulCreations += 1
                
                // Clean up
                try await woundManager.deleteWoundRecord(record, createExport: false)
                
            } catch {
                // If creation failed, location must be invalid
                XCTAssertTrue(location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            "Iteration \(iteration): Valid location should allow creation, but got error: \(error)")
                failedValidations += 1
            }
        }
        
        // Both successful and failed cases should occur
        XCTAssertGreaterThan(successfulCreations, 0,
                           "At least some wound records should be created successfully")
        XCTAssertGreaterThan(failedValidations, 0,
                           "At least some invalid locations should be rejected")
    }
    
    /// Property: For any wound record creation, initial assessment date is required
    /// This validates that wound records always have an initial assessment date
    func testProperty30_WoundRecordCreation_InitialAssessmentDateRequired() async throws {
        let iterations = 100
        var successfulCreations = 0
        
        for iteration in 0..<iterations {
            let location = generateRandomString(length: Int.random(in: 5...50))
            let date = generateRandomDate()
            
            do {
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    initialAssessmentDate: date,
                    patient: nil
                )
                
                // Verify initial assessment date is set
                XCTAssertNotNil(record.initialAssessmentDate,
                              "Iteration \(iteration): Record should have initial assessment date")
                XCTAssertEqual(record.initialAssessmentDate, date,
                             "Iteration \(iteration): Initial assessment date should match provided date")
                
                successfulCreations += 1
                
                // Clean up
                try await woundManager.deleteWoundRecord(record, createExport: false)
                
            } catch {
                XCTFail("Iteration \(iteration): Valid wound record creation failed: \(error)")
            }
        }
        
        XCTAssertEqual(successfulCreations, iterations,
                      "All wound records with valid data should be created successfully")
    }
    
    /// Property: For any wound record creation with patient, patient info is properly associated
    /// This validates that patient information is correctly linked when provided
    func testProperty30_WoundRecordCreation_PatientInfoOptional() async throws {
        let iterations = 100
        var withPatient = 0
        var withoutPatient = 0
        
        for iteration in 0..<iterations {
            let location = generateRandomString(length: Int.random(in: 5...50))
            let date = generateRandomDate()
            
            // Randomly decide whether to include patient
            let includePatient = Bool.random()
            var patient: Patient? = nil
            
            if includePatient {
                patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: Int.random(in: 5...30)),
                    patientID: "P\(Int.random(in: 1000...9999))"
                )
                try context.save()
            }
            
            do {
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    initialAssessmentDate: date,
                    patient: patient
                )
                
                // Verify patient association
                if includePatient {
                    XCTAssertNotNil(record.patient,
                                  "Iteration \(iteration): Record should have patient when provided")
                    XCTAssertEqual(record.patient?.id, patient?.id,
                                 "Iteration \(iteration): Patient should match provided patient")
                    withPatient += 1
                } else {
                    XCTAssertNil(record.patient,
                               "Iteration \(iteration): Record should not have patient when not provided")
                    withoutPatient += 1
                }
                
                // Clean up
                try await woundManager.deleteWoundRecord(record, createExport: false)
                if let patient = patient {
                    patient.delete(from: context)
                    try context.save()
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Valid wound record creation failed: \(error)")
            }
        }
        
        // Both cases should occur
        XCTAssertGreaterThan(withPatient, 0,
                           "Some wound records should be created with patient")
        XCTAssertGreaterThan(withoutPatient, 0,
                           "Some wound records should be created without patient")
    }
    
    /// Property: For any wound record creation, all required prompts are validated before persistence
    /// This validates the complete creation flow with all prompts
    func testProperty30_WoundRecordCreation_AllPromptsValidated() async throws {
        let iterations = 100
        var successfulCreations = 0
        
        for iteration in 0..<iterations {
            // Generate random valid data
            let location = generateRandomString(length: Int.random(in: 5...50))
            let date = generateRandomDate()
            let includePatient = Bool.random()
            
            var patient: Patient? = nil
            if includePatient {
                patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: Int.random(in: 5...30)),
                    patientID: "P\(Int.random(in: 1000...9999))"
                )
                try context.save()
            }
            
            do {
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    initialAssessmentDate: date,
                    patient: patient
                )
                
                // Verify all required fields are present
                XCTAssertNotNil(record.id,
                              "Iteration \(iteration): Record should have ID")
                XCTAssertNotNil(record.location,
                              "Iteration \(iteration): Record should have location")
                XCTAssertFalse(record.location?.isEmpty ?? true,
                             "Iteration \(iteration): Record location should not be empty")
                XCTAssertNotNil(record.initialAssessmentDate,
                              "Iteration \(iteration): Record should have initial assessment date")
                XCTAssertNotNil(record.status,
                              "Iteration \(iteration): Record should have status")
                XCTAssertEqual(record.status, "active",
                             "Iteration \(iteration): New record should have 'active' status")
                XCTAssertNotNil(record.lastUpdated,
                              "Iteration \(iteration): Record should have lastUpdated timestamp")
                
                // Verify patient association if provided
                if includePatient {
                    XCTAssertNotNil(record.patient,
                                  "Iteration \(iteration): Record should have patient when provided")
                }
                
                successfulCreations += 1
                
                // Clean up
                try await woundManager.deleteWoundRecord(record, createExport: false)
                if let patient = patient {
                    patient.delete(from: context)
                    try context.save()
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Valid wound record creation failed: \(error)")
            }
        }
        
        XCTAssertEqual(successfulCreations, iterations,
                      "All wound records with valid data should be created successfully")
    }
}
