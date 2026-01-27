//
//  PatientManagerTests.swift
//  PediLensTests
//
//  Unit tests for PatientManager
//

import XCTest
import CoreData
@testable import PediLens

class PatientManagerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var patientManager: PatientManager!
    var testUser: User!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        patientManager = PatientManager(persistenceController: persistenceController)
        
        // Create a test user
        let context = persistenceController.container.viewContext
        testUser = User.create(in: context, role: .doctor)
        try context.save()
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        patientManager = nil
        testUser = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Create Patient Tests
    
    func testCreatePatient() async throws {
        // Given
        let name = "John Doe"
        let patientID = "P12345"
        let dateOfBirth = Date(timeIntervalSince1970: 0)
        let notes = "Test patient"
        
        // When
        let patient = try await patientManager.createPatient(
            name: name,
            patientID: patientID,
            dateOfBirth: dateOfBirth,
            notes: notes,
            for: testUser
        )
        
        // Then
        XCTAssertEqual(patient.name, name)
        XCTAssertEqual(patient.patientID, patientID)
        XCTAssertEqual(patient.dateOfBirth, dateOfBirth)
        XCTAssertEqual(patient.notes, notes)
        XCTAssertEqual(patient.user, testUser)
        XCTAssertNotNil(patient.id)
        XCTAssertNotNil(patient.createdAt)
    }
    
    func testCreatePatientWithEmptyName() async throws {
        // Given
        let name = "   "
        let patientID = "P12345"
        
        // When/Then
        do {
            _ = try await patientManager.createPatient(
                name: name,
                patientID: patientID,
                for: testUser
            )
            XCTFail("Should throw invalidInput error")
        } catch PatientManagerError.invalidInput(let message) {
            XCTAssertTrue(message.contains("name"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testCreatePatientWithEmptyID() async throws {
        // Given
        let name = "John Doe"
        let patientID = "   "
        
        // When/Then
        do {
            _ = try await patientManager.createPatient(
                name: name,
                patientID: patientID,
                for: testUser
            )
            XCTFail("Should throw invalidInput error")
        } catch PatientManagerError.invalidInput(let message) {
            XCTAssertTrue(message.contains("ID"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Update Patient Tests
    
    func testUpdatePatient() async throws {
        // Given
        let patient = try await patientManager.createPatient(
            name: "John Doe",
            patientID: "P12345",
            for: testUser
        )
        
        let newName = "Jane Doe"
        let newPatientID = "P67890"
        let newNotes = "Updated notes"
        
        // When
        try await patientManager.updatePatient(
            patient,
            name: newName,
            patientID: newPatientID,
            notes: newNotes
        )
        
        // Then
        XCTAssertEqual(patient.name, newName)
        XCTAssertEqual(patient.patientID, newPatientID)
        XCTAssertEqual(patient.notes, newNotes)
    }
    
    func testUpdatePatientWithEmptyName() async throws {
        // Given
        let patient = try await patientManager.createPatient(
            name: "John Doe",
            patientID: "P12345",
            for: testUser
        )
        
        // When/Then
        do {
            try await patientManager.updatePatient(patient, name: "   ")
            XCTFail("Should throw invalidInput error")
        } catch PatientManagerError.invalidInput(let message) {
            XCTAssertTrue(message.contains("name"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Delete Patient Tests
    
    func testDeletePatient() async throws {
        // Given
        let patient = try await patientManager.createPatient(
            name: "John Doe",
            patientID: "P12345",
            for: testUser
        )
        let patientID = patient.id
        
        // When
        try await patientManager.deletePatient(patient)
        
        // Then
        let fetchedPatient = try await patientManager.fetchPatient(byID: patientID!)
        XCTAssertNil(fetchedPatient)
    }
    
    // MARK: - Fetch Patient Tests
    
    func testFetchPatients() async throws {
        // Given
        _ = try await patientManager.createPatient(name: "John Doe", patientID: "P1", for: testUser)
        _ = try await patientManager.createPatient(name: "Jane Smith", patientID: "P2", for: testUser)
        _ = try await patientManager.createPatient(name: "Bob Johnson", patientID: "P3", for: testUser)
        
        // When
        let patients = try await patientManager.fetchPatients(for: testUser)
        
        // Then
        XCTAssertEqual(patients.count, 3)
        // Should be sorted by name
        XCTAssertEqual(patients[0].name, "Bob Johnson")
        XCTAssertEqual(patients[1].name, "Jane Smith")
        XCTAssertEqual(patients[2].name, "John Doe")
    }
    
    func testFetchPatientByID() async throws {
        // Given
        let patient = try await patientManager.createPatient(
            name: "John Doe",
            patientID: "P12345",
            for: testUser
        )
        
        // When
        let fetchedPatient = try await patientManager.fetchPatient(byID: patient.id!)
        
        // Then
        XCTAssertNotNil(fetchedPatient)
        XCTAssertEqual(fetchedPatient?.name, "John Doe")
        XCTAssertEqual(fetchedPatient?.patientID, "P12345")
    }
    
    // MARK: - Search Patient Tests
    
    func testSearchPatientsByName() async throws {
        // Given
        _ = try await patientManager.createPatient(name: "John Doe", patientID: "P1", for: testUser)
        _ = try await patientManager.createPatient(name: "Jane Doe", patientID: "P2", for: testUser)
        _ = try await patientManager.createPatient(name: "Bob Smith", patientID: "P3", for: testUser)
        
        // When
        let results = try await patientManager.searchPatients("Doe", for: testUser)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.name == "John Doe" })
        XCTAssertTrue(results.contains { $0.name == "Jane Doe" })
    }
    
    func testSearchPatientsByID() async throws {
        // Given
        _ = try await patientManager.createPatient(name: "John Doe", patientID: "P12345", for: testUser)
        _ = try await patientManager.createPatient(name: "Jane Doe", patientID: "P67890", for: testUser)
        _ = try await patientManager.createPatient(name: "Bob Smith", patientID: "P11111", for: testUser)
        
        // When
        let results = try await patientManager.searchPatients("123", for: testUser)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "John Doe")
    }
    
    func testSearchPatientsCaseInsensitive() async throws {
        // Given
        _ = try await patientManager.createPatient(name: "John Doe", patientID: "P1", for: testUser)
        
        // When
        let results = try await patientManager.searchPatients("john", for: testUser)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "John Doe")
    }
    
    func testSearchPatientsPartialMatch() async throws {
        // Given
        _ = try await patientManager.createPatient(name: "John Doe", patientID: "P1", for: testUser)
        
        // When
        let results = try await patientManager.searchPatients("oh", for: testUser)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "John Doe")
    }
    
    // MARK: - Statistics Tests
    
    func testCalculateStatistics() async throws {
        // Given
        let patient = try await patientManager.createPatient(
            name: "John Doe",
            patientID: "P12345",
            for: testUser
        )
        
        let context = persistenceController.container.viewContext
        
        // Create wound records with different statuses
        _ = WoundRecord.create(in: context, location: "Left foot", status: "active", patient: patient)
        _ = WoundRecord.create(in: context, location: "Right foot", status: "active", patient: patient)
        _ = WoundRecord.create(in: context, location: "Left hand", status: "healed", patient: patient)
        try context.save()
        
        // When
        let stats = patientManager.calculateStatistics(for: patient)
        
        // Then
        XCTAssertEqual(stats.totalWounds, 3)
        XCTAssertEqual(stats.activeWounds, 2)
        XCTAssertEqual(stats.healedWounds, 1)
        XCTAssertEqual(stats.healingRate, 1.0 / 3.0, accuracy: 0.001)
    }
    
    func testCalculateStatisticsNoWounds() async throws {
        // Given
        let patient = try await patientManager.createPatient(
            name: "John Doe",
            patientID: "P12345",
            for: testUser
        )
        
        // When
        let stats = patientManager.calculateStatistics(for: patient)
        
        // Then
        XCTAssertEqual(stats.totalWounds, 0)
        XCTAssertEqual(stats.activeWounds, 0)
        XCTAssertEqual(stats.healedWounds, 0)
        XCTAssertEqual(stats.healingRate, 0.0)
    }
}
