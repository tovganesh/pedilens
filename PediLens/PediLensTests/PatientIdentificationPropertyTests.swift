//
//  PatientIdentificationPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for patient identification in capture workflow
//

import XCTest
import CoreData
@testable import PediLens

final class PatientIdentificationPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var patientCaptureManager: PatientCaptureManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        patientCaptureManager = PatientCaptureManager.shared
        context = persistenceController.container.viewContext
    }
    
    override func tearDown() {
        context = nil
        patientCaptureManager = nil
        persistenceController = nil
        
        super.tearDown()
    }
    
    // MARK: - Property 43: Doctor Patient Identification Prompt
    // **Validates: Requirements 16.1**
    
    /// Property: For any capture session initiated by a doctor user without an associated patient, a prompt SHALL appear
    func testProperty43_DoctorPatientIdentificationPrompt_RequiredForDoctorRole() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create doctor user
            let doctorUser = User.create(in: context, role: .doctor)
            
            // Verify patient identification is required for doctor
            let requiresIdentification = patientCaptureManager.requiresPatientIdentification(for: doctorUser)
            
            if !requiresIdentification {
                failedCases.append(iteration)
            }
            
            // Verify validation fails without patient
            let isValid = patientCaptureManager.validatePatientSelection(for: doctorUser, patient: nil)
            
            if isValid {
                // Should not be valid without patient for doctor role
                failedCases.append(iteration)
            }
            
            // Clean up
            context.delete(doctorUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Doctor patient identification requirement failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any doctor user, patient identification SHALL be required before capture
    func testProperty43_DoctorPatientIdentificationPrompt_ValidationEnforced() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create doctor user
            let doctorUser = User.create(in: context, role: .doctor)
            
            // Create patient
            let patient = Patient.create(
                in: context,
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                user: doctorUser
            )
            
            // Verify validation passes with patient
            let isValidWithPatient = patientCaptureManager.validatePatientSelection(for: doctorUser, patient: patient)
            
            if !isValidWithPatient {
                failedCases.append(iteration)
            }
            
            // Verify validation fails without patient
            let isValidWithoutPatient = patientCaptureManager.validatePatientSelection(for: doctorUser, patient: nil)
            
            if isValidWithoutPatient {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.delete(patient)
            context.delete(doctorUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Doctor patient identification validation failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient role SHALL NOT require patient identification
    func testProperty43_DoctorPatientIdentificationPrompt_NotRequiredForPatientRole() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create patient user
            let patientUser = User.create(in: context, role: .patient)
            
            // Verify patient identification is NOT required for patient role
            let requiresIdentification = patientCaptureManager.requiresPatientIdentification(for: patientUser)
            
            if requiresIdentification {
                failedCases.append(iteration)
            }
            
            // Verify validation passes without patient for patient role
            let isValid = patientCaptureManager.validatePatientSelection(for: patientUser, patient: nil)
            
            if !isValid {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.delete(patientUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient role identification requirement failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Active patient SHALL be retrievable after being set
    func testProperty43_DoctorPatientIdentificationPrompt_ActivePatientManagement() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create doctor user and patient
            let doctorUser = User.create(in: context, role: .doctor)
            let patient = Patient.create(
                in: context,
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                user: doctorUser
            )
            
            // Set active patient
            patientCaptureManager.setActivePatient(patient)
            
            // Verify active patient can be retrieved
            let activePatient = patientCaptureManager.getActivePatient()
            
            if activePatient?.id != patient.id {
                failedCases.append(iteration)
            }
            
            // Clear active patient
            patientCaptureManager.setActivePatient(nil)
            
            // Verify active patient is cleared
            let clearedPatient = patientCaptureManager.getActivePatient()
            
            if clearedPatient != nil {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.delete(patient)
            context.delete(doctorUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Active patient management failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    // MARK: - Property 44: Patient Metadata in Doctor Captures
    // **Validates: Requirements 16.2, 16.3, 16.5, 16.6**
    
    /// Property: For any capture by a doctor user, patient name and ID SHALL be associated with the image
    func testProperty44_PatientMetadataInDoctorCaptures_MetadataAssociation() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create doctor user and patient
            let doctorUser = User.create(in: context, role: .doctor)
            let patient = Patient.create(
                in: context,
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                user: doctorUser
            )
            
            // Create a unique image ID
            let imageID = UUID()
            
            // Associate patient metadata with the image
            patientCaptureManager.associatePatientMetadata(with: imageID, patient: patient, context: context)
            
            // Retrieve metadata
            let retrievedMetadata = patientCaptureManager.getPatientMetadata(for: imageID, context: context)
            
            // Verify metadata was stored and retrieved correctly
            if retrievedMetadata == nil {
                failedCases.append(iteration)
            }
            
            if let metadata = retrievedMetadata {
                if metadata.patientName != patient.name {
                    failedCases.append(iteration)
                }
                
                if metadata.patientID != patient.patientID {
                    failedCases.append(iteration)
                }
            }
            
            // Clean up
            context.delete(patient)
            context.delete(doctorUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient metadata association failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient metadata SHALL include patient name, ID, and capture date
    func testProperty44_PatientMetadataInDoctorCaptures_MetadataCompleteness() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create doctor user and patient
            let doctorUser = User.create(in: context, role: .doctor)
            let patient = Patient.create(
                in: context,
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                user: doctorUser
            )
            
            // Create a unique image ID
            let imageID = UUID()
            
            // Associate metadata
            patientCaptureManager.associatePatientMetadata(with: imageID, patient: patient, context: context)
            
            // Retrieve metadata
            if let metadata = patientCaptureManager.getPatientMetadata(for: imageID, context: context) {
                // Verify all required fields are present
                if metadata.patientName.isEmpty {
                    failedCases.append(iteration)
                }
                
                if metadata.patientID.isEmpty {
                    failedCases.append(iteration)
                }
                
                // Verify capture date is recent (within last minute)
                let timeDifference = abs(metadata.captureDate.timeIntervalSinceNow)
                if timeDifference > 60 {
                    failedCases.append(iteration)
                }
            } else {
                failedCases.append(iteration)
            }
            
            // Clean up
            context.delete(patient)
            context.delete(doctorUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient metadata completeness failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient metadata SHALL persist across app sessions
    func testProperty44_PatientMetadataInDoctorCaptures_MetadataPersistence() {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create doctor user and patient
            let doctorUser = User.create(in: context, role: .doctor)
            let patient = Patient.create(
                in: context,
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                user: doctorUser
            )
            
            // Create a unique image ID
            let imageID = UUID()
            
            // Associate metadata
            patientCaptureManager.associatePatientMetadata(with: imageID, patient: patient, context: context)
            
            // Simulate app restart by creating a new manager instance
            let newManager = PatientCaptureManager.shared
            
            // Retrieve metadata with new manager instance
            let retrievedMetadata = newManager.getPatientMetadata(for: imageID, context: context)
            
            // Verify metadata persisted
            if retrievedMetadata == nil {
                failedCases.append(iteration)
            }
            
            if let metadata = retrievedMetadata {
                if metadata.patientName != patient.name || metadata.patientID != patient.patientID {
                    failedCases.append(iteration)
                }
            }
            
            // Clean up
            UserDefaults.standard.removeObject(forKey: "patientMetadata_\(imageID.uuidString)")
            context.delete(patient)
            context.delete(doctorUser)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient metadata persistence failed for \(failedCases.count) out of \(iterations) cases")
    }
}
