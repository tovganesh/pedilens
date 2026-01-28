//
//  WoundManagerTests.swift
//  PediLensTests
//
//  Unit tests for WoundManager
//

import XCTest
import CoreData
@testable import PediLens

class WoundManagerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var woundManager: WoundManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Create in-memory persistence controller for testing
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
    
    // MARK: - Create Tests
    
    func testCreateWoundRecord() async throws {
        // Given
        let location = "Left foot, plantar surface"
        let date = Date()
        
        // When
        let record = try await woundManager.createWoundRecord(
            location: location,
            initialAssessmentDate: date,
            patient: nil
        )
        
        // Then
        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.location, location)
        XCTAssertEqual(record.initialAssessmentDate, date)
        XCTAssertEqual(record.status, "active")
        XCTAssertNil(record.patient)
    }
    
    func testCreateWoundRecordWithPatient() async throws {
        // Given
        let patient = Patient.create(
            in: context,
            name: "John Doe",
            patientID: "P001"
        )
        try context.save()
        
        let location = "Right foot, heel"
        
        // When
        let record = try await woundManager.createWoundRecord(
            location: location,
            patient: patient
        )
        
        // Then
        XCTAssertNotNil(record.patient)
        XCTAssertEqual(record.patient?.name, "John Doe")
        XCTAssertEqual(record.patient?.patientID, "P001")
    }
    
    func testCreateWoundRecordWithEmptyLocation() async {
        // Given
        let location = ""
        
        // When/Then
        do {
            _ = try await woundManager.createWoundRecord(location: location)
            XCTFail("Should throw invalidLocation error")
        } catch let error as WoundManagerError {
            XCTAssertEqual(error, .invalidLocation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCreateWoundRecordWithWhitespaceLocation() async {
        // Given
        let location = "   "
        
        // When/Then
        do {
            _ = try await woundManager.createWoundRecord(location: location)
            XCTFail("Should throw invalidLocation error")
        } catch let error as WoundManagerError {
            XCTAssertEqual(error, .invalidLocation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Read Tests
    
    func testFetchWoundRecords() async throws {
        // Given
        _ = try await woundManager.createWoundRecord(location: "Location 1")
        _ = try await woundManager.createWoundRecord(location: "Location 2")
        _ = try await woundManager.createWoundRecord(location: "Location 3")
        
        // When
        let records = try await woundManager.fetchWoundRecords()
        
        // Then
        XCTAssertEqual(records.count, 3)
    }
    
    func testFetchWoundRecordsForPatient() async throws {
        // Given
        let patient1 = Patient.create(in: context, name: "Patient 1", patientID: "P001")
        let patient2 = Patient.create(in: context, name: "Patient 2", patientID: "P002")
        try context.save()
        
        _ = try await woundManager.createWoundRecord(location: "Location 1", patient: patient1)
        _ = try await woundManager.createWoundRecord(location: "Location 2", patient: patient1)
        _ = try await woundManager.createWoundRecord(location: "Location 3", patient: patient2)
        
        // When
        let patient1Records = try await woundManager.fetchWoundRecords(for: patient1)
        let patient2Records = try await woundManager.fetchWoundRecords(for: patient2)
        
        // Then
        XCTAssertEqual(patient1Records.count, 2)
        XCTAssertEqual(patient2Records.count, 1)
    }
    
    func testFetchWoundRecordByID() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Test Location")
        let recordID = record.id!
        
        // When
        let fetchedRecord = try await woundManager.fetchWoundRecord(byID: recordID)
        
        // Then
        XCTAssertNotNil(fetchedRecord)
        XCTAssertEqual(fetchedRecord?.id, recordID)
        XCTAssertEqual(fetchedRecord?.location, "Test Location")
    }
    
    func testFetchWoundRecordByIDNotFound() async throws {
        // Given
        let nonExistentID = UUID()
        
        // When
        let fetchedRecord = try await woundManager.fetchWoundRecord(byID: nonExistentID)
        
        // Then
        XCTAssertNil(fetchedRecord)
    }
    
    func testFetchWoundRecordsByStatus() async throws {
        // Given
        let record1 = try await woundManager.createWoundRecord(location: "Location 1")
        let record2 = try await woundManager.createWoundRecord(location: "Location 2")
        let record3 = try await woundManager.createWoundRecord(location: "Location 3")
        
        // Archive one record
        try await woundManager.archiveWoundRecord(record2)
        
        // When
        let activeRecords = try await woundManager.fetchWoundRecords(withStatus: "active")
        let archivedRecords = try await woundManager.fetchWoundRecords(withStatus: "archived")
        
        // Then
        XCTAssertEqual(activeRecords.count, 2)
        XCTAssertEqual(archivedRecords.count, 1)
        XCTAssertTrue(activeRecords.contains { $0.id == record1.id })
        XCTAssertTrue(activeRecords.contains { $0.id == record3.id })
        XCTAssertTrue(archivedRecords.contains { $0.id == record2.id })
    }
    
    func testFetchWoundRecordsByDateRange() async throws {
        // Given
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        let oneHourFromNow = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        
        let record1 = try await woundManager.createWoundRecord(location: "Location 1")
        let record2 = try await woundManager.createWoundRecord(location: "Location 2")
        let record3 = try await woundManager.createWoundRecord(location: "Location 3")
        
        // When - fetch records within a range that includes the current time
        let records = try await woundManager.fetchWoundRecords(from: oneHourAgo, to: oneHourFromNow)
        
        // Then - all records should be returned since they were all just created
        XCTAssertEqual(records.count, 3)
        XCTAssertTrue(records.contains { $0.id == record1.id })
        XCTAssertTrue(records.contains { $0.id == record2.id })
        XCTAssertTrue(records.contains { $0.id == record3.id })
    }
    
    // MARK: - Update Tests
    
    func testUpdateWoundRecordLocation() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Original Location")
        let newLocation = "Updated Location"
        
        // When
        try await woundManager.updateWoundRecord(record, location: newLocation)
        
        // Then
        XCTAssertEqual(record.location, newLocation)
    }
    
    func testUpdateWoundRecordStatus() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Test Location")
        let newStatus = "healing"
        
        // When
        try await woundManager.updateWoundRecord(record, status: newStatus)
        
        // Then
        XCTAssertEqual(record.status, newStatus)
    }
    
    func testUpdateWoundRecordWithEmptyLocation() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Original Location")
        
        // When/Then
        do {
            try await woundManager.updateWoundRecord(record, location: "")
            XCTFail("Should throw invalidLocation error")
        } catch let error as WoundManagerError {
            XCTAssertEqual(error, .invalidLocation)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testArchiveWoundRecord() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Test Location")
        XCTAssertEqual(record.status, "active")
        
        // When
        try await woundManager.archiveWoundRecord(record)
        
        // Then
        XCTAssertEqual(record.status, "archived")
    }
    
    // MARK: - Delete Tests
    
    func testDeleteWoundRecord() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Test Location")
        let recordID = record.id!
        
        // When
        try await woundManager.deleteWoundRecord(record, createExport: false)
        
        // Then
        let fetchedRecord = try await woundManager.fetchWoundRecord(byID: recordID)
        XCTAssertNil(fetchedRecord)
    }
    
    func testDeleteWoundRecordWithCaptureSessions() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Test Location")
        let recordID = record.id!
        
        // Create a capture session
        let session = CaptureSession.create(
            in: context,
            photoPath: "test/path.heic",
            woundRecord: record
        )
        try context.save()
        
        XCTAssertEqual(record.captureSessionsArray.count, 1)
        
        // When
        try await woundManager.deleteWoundRecord(record, createExport: false)
        
        // Then
        let fetchedRecord = try await woundManager.fetchWoundRecord(byID: recordID)
        XCTAssertNil(fetchedRecord)
    }
    
    // MARK: - Validation Tests
    
    func testValidateWoundRecord() async throws {
        // Given
        let record = try await woundManager.createWoundRecord(location: "Test Location")
        
        // When
        let isValid = woundManager.validateWoundRecord(record)
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateWoundRecordWithEmptyLocation() {
        // Given
        let record = WoundRecord(context: context)
        record.id = UUID()
        record.location = ""
        record.initialAssessmentDate = Date()
        record.status = "active"
        
        // When
        let isValid = woundManager.validateWoundRecord(record)
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testValidateWoundRecordWithoutID() {
        // Given
        let record = WoundRecord(context: context)
        record.location = "Test Location"
        record.initialAssessmentDate = Date()
        record.status = "active"
        
        // When
        let isValid = woundManager.validateWoundRecord(record)
        
        // Then
        XCTAssertFalse(isValid)
    }
}

// MARK: - WoundManagerError Equatable

extension WoundManagerError: Equatable {
    public static func == (lhs: WoundManagerError, rhs: WoundManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidLocation, .invalidLocation):
            return true
        case (.recordNotFound, .recordNotFound):
            return true
        case (.saveFailed, .saveFailed):
            return true
        case (.deleteFailed, .deleteFailed):
            return true
        case (.exportFailed, .exportFailed):
            return true
        default:
            return false
        }
    }
}
