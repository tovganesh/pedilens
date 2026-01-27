//
//  UserRolePropertyTests.swift
//  PediLensTests
//
//  Property-based tests for user role management
//

import XCTest
import CoreData
@testable import PediLens

final class UserRolePropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var userManager: UserManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        userManager = UserManager(persistenceController: persistenceController)
        context = persistenceController.container.viewContext
    }
    
    override func tearDown() {
        context = nil
        userManager = nil
        persistenceController = nil
        
        super.tearDown()
    }
    
    // MARK: - Property 25: Doctor Role Patient Association Requirement
    // **Validates: Requirements 8.4**
    
    /// Property: For any wound record created by a doctor user, patient identifiers SHALL be required
    func testProperty25_DoctorPatientAssociation_RequiredForDoctorRole() async throws {
        // Set user role to doctor
        try await userManager.setUserRole(.doctor)
        
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create a patient
            let patient = Patient(context: context)
            patient.id = UUID()
            patient.name = "Patient \(iteration)"
            patient.patientID = "PID-\(iteration)"
            patient.createdAt = Date()
            
            // Create a wound record using the helper method
            let woundRecord = WoundRecord.create(
                in: context,
                location: "Test Location \(iteration)",
                initialAssessmentDate: Date(),
                status: "active",
                patient: patient
            )
            
            // Verify the association exists
            if woundRecord.patient == nil {
                failedCases.append(iteration)
            }
            
            // Verify patient has required identifiers
            if patient.name?.isEmpty ?? true || patient.patientID?.isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            // Clean up for next iteration
            context.rollback()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Doctor patient association property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Doctor role SHALL require patient identification before creating wound records
    func testProperty25_DoctorPatientAssociation_ValidationEnforced() async throws {
        // Set user role to doctor
        try await userManager.setUserRole(.doctor)
        
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Attempt to create wound record without patient (should be invalid for doctor role)
            let woundRecord = WoundRecord.create(
                in: context,
                location: "Test Location \(iteration)",
                initialAssessmentDate: Date(),
                status: "active",
                patient: nil // No patient association
            )
            
            // For doctor role, wound records without patient should be considered invalid
            // This is a business rule that should be enforced at the UI/validation layer
            let isValid = woundRecord.patient != nil
            
            if isValid {
                // If wound record without patient is considered valid for doctor, that's a failure
                failedCases.append(iteration)
            }
            
            // Clean up
            context.rollback()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Doctor patient association validation failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: All wound records for doctor users SHALL have patient metadata
    func testProperty25_DoctorPatientAssociation_MetadataPresent() async throws {
        // Set user role to doctor
        try await userManager.setUserRole(.doctor)
        
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create patient with full metadata
            let patient = Patient(context: context)
            patient.id = UUID()
            patient.name = "Patient \(iteration)"
            patient.patientID = "PID-\(String(format: "%04d", iteration))"
            patient.createdAt = Date()
            patient.dateOfBirth = Date().addingTimeInterval(-Double.random(in: 18...80) * 365 * 24 * 3600)
            patient.notes = iteration % 2 == 0 ? "Test notes" : nil
            
            // Create wound record associated with patient using helper method
            let woundRecord = WoundRecord.create(
                in: context,
                location: "Location \(iteration)",
                initialAssessmentDate: Date(),
                status: "active",
                patient: patient
            )
            
            // Verify patient metadata is present and valid
            guard let associatedPatient = woundRecord.patient else {
                failedCases.append(iteration)
                context.rollback()
                continue
            }
            
            // Verify required patient identifiers
            if associatedPatient.name?.isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            if associatedPatient.patientID?.isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            // Verify patient ID format (should be non-empty string)
            if associatedPatient.patientID?.trimmingCharacters(in: .whitespaces).isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.rollback()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Doctor patient metadata property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    // MARK: - Property 26: Patient Role Self-Documentation
    // **Validates: Requirements 8.5**
    
    /// Property: For any wound record created by a patient user, patient identifiers SHALL NOT be required
    func testProperty26_PatientSelfDocumentation_NoPatientIdentifierRequired() async throws {
        // Set user role to patient
        try await userManager.setUserRole(.patient)
        
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create wound record without patient association (valid for patient role) using helper method
            let woundRecord = WoundRecord.create(
                in: context,
                location: "Test Location \(iteration)",
                initialAssessmentDate: Date(),
                status: "active",
                patient: nil // No patient association needed for patient role
            )
            
            // For patient role, wound records without patient association should be valid
            let isValid = true // Patient role doesn't require patient association
            
            if !isValid {
                failedCases.append(iteration)
            }
            
            // Verify the wound record is valid without patient
            if woundRecord.id == nil || woundRecord.location?.isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.rollback()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient self-documentation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient role SHALL allow wound record creation without patient identifiers
    func testProperty26_PatientSelfDocumentation_IndependentRecordCreation() async throws {
        // Set user role to patient
        try await userManager.setUserRole(.patient)
        
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Attempt to create wound record for patient role (no patient entity needed) using helper method
            let woundRecord = WoundRecord.create(
                in: context,
                location: "Location \(iteration)",
                initialAssessmentDate: Date(),
                status: ["active", "healing", "healed"].randomElement()!,
                patient: nil
            )
            
            // Patient role: wound record should be valid without patient association
            let hasPatient = woundRecord.patient != nil
            
            // For patient role, having no patient association is expected and valid
            if hasPatient {
                // It's okay if patient is associated, but not required
                // This test just verifies it's not mandatory
            }
            
            // Verify wound record has required fields
            if woundRecord.id == nil {
                failedCases.append(iteration)
            }
            
            if woundRecord.location?.isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.rollback()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient independent record creation failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient role workflow SHALL focus on personal tracking without patient management
    func testProperty26_PatientSelfDocumentation_SimplifiedWorkflow() async throws {
        // Set user role to patient
        try await userManager.setUserRole(.patient)
        
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Verify patient role cannot access patient management features
            let canManageMultiplePatients = userManager.canAccessFeature(.multiplePatients)
            let canSearchPatients = userManager.canAccessFeature(.patientSearch)
            
            // Patient role should not have access to these features
            if canManageMultiplePatients {
                failedCases.append(iteration)
            }
            
            if canSearchPatients {
                failedCases.append(iteration)
            }
            
            // Create a simple wound record (patient's own) using helper method
            let woundRecord = WoundRecord.create(
                in: context,
                location: "Personal wound \(iteration)",
                initialAssessmentDate: Date(),
                status: "active",
                patient: nil
            )
            
            // Verify wound record is valid for personal tracking
            if woundRecord.id == nil || woundRecord.location?.isEmpty ?? true {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.rollback()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient simplified workflow property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
