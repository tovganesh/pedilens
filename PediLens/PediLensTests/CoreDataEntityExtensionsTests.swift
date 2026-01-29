//
//  CoreDataEntityExtensionsTests.swift
//  PediLensTests
//
//  Unit tests for Core Data entity extensions
//

import XCTest
import CoreData
import CoreLocation
@testable import PediLens

final class CoreDataEntityExtensionsTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use in-memory store for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
        try super.tearDownWithError()
    }
    
    // MARK: - User Extension Tests
    
    func testUserCreate() throws {
        // Test creating a user
        let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: true)
        
        XCTAssertNotNil(user.id)
        XCTAssertEqual(user.role, UserRole.doctor.rawValue)
        XCTAssertTrue(user.iCloudSyncEnabled)
        XCTAssertNotNil(user.createdAt)
    }
    
    func testUserFetchCurrentUser() throws {
        // Create a user
        let user = User.create(in: context, role: .patient)
        try context.save()
        
        // Fetch current user
        let fetchedUser = User.fetchCurrentUser(in: context)
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, user.id)
    }

    func testUserUpdateRole() throws {
        let user = User.create(in: context, role: .patient)
        user.updateRole(.doctor)
        
        XCTAssertEqual(user.role, UserRole.doctor.rawValue)
        XCTAssertEqual(user.userRole, .doctor)
    }
    
    func testUserUpdateICloudSync() throws {
        let user = User.create(in: context, role: .patient, iCloudSyncEnabled: false)
        user.updateICloudSync(enabled: true)
        
        XCTAssertTrue(user.iCloudSyncEnabled)
    }
    
    func testUserPatientsArray() throws {
        let user = User.create(in: context, role: .doctor)
        let patient1 = Patient.create(in: context, name: "Alice", patientID: "P001", user: user)
        let patient2 = Patient.create(in: context, name: "Bob", patientID: "P002", user: user)
        
        let patients = user.patientsArray
        XCTAssertEqual(patients.count, 2)
        XCTAssertEqual(patients[0].name, "Alice") // Sorted by name
        XCTAssertEqual(patients[1].name, "Bob")
    }
    
    // MARK: - Patient Extension Tests
    
    func testPatientCreate() throws {
        let user = User.create(in: context, role: .doctor)
        let dateOfBirth = Date(timeIntervalSince1970: 0)
        let patient = Patient.create(
            in: context,
            name: "John Doe",
            patientID: "P123",
            dateOfBirth: dateOfBirth,
            notes: "Test notes",
            user: user
        )
        
        XCTAssertNotNil(patient.id)
        XCTAssertEqual(patient.name, "John Doe")
        XCTAssertEqual(patient.patientID, "P123")
        XCTAssertEqual(patient.dateOfBirth, dateOfBirth)
        XCTAssertEqual(patient.notes, "Test notes")
        XCTAssertEqual(patient.user, user)
        XCTAssertNotNil(patient.createdAt)
    }

    func testPatientFetchPatientsForUser() throws {
        let user = User.create(in: context, role: .doctor)
        let patient1 = Patient.create(in: context, name: "Alice", patientID: "P001", user: user)
        let patient2 = Patient.create(in: context, name: "Bob", patientID: "P002", user: user)
        try context.save()
        
        let patients = Patient.fetchPatients(for: user, in: context)
        XCTAssertEqual(patients.count, 2)
        XCTAssertEqual(patients[0].name, "Alice")
        XCTAssertEqual(patients[1].name, "Bob")
    }
    
    func testPatientFetchByID() throws {
        let patient = Patient.create(in: context, name: "Jane", patientID: "P456")
        try context.save()
        
        let fetchedPatient = Patient.fetchPatient(byID: patient.id!, in: context)
        XCTAssertNotNil(fetchedPatient)
        XCTAssertEqual(fetchedPatient?.id, patient.id)
        XCTAssertEqual(fetchedPatient?.name, "Jane")
    }
    
    func testPatientSearch() throws {
        let user = User.create(in: context, role: .doctor)
        let patient1 = Patient.create(in: context, name: "Alice Smith", patientID: "P001", user: user)
        let patient2 = Patient.create(in: context, name: "Bob Jones", patientID: "P002", user: user)
        let patient3 = Patient.create(in: context, name: "Charlie Brown", patientID: "A123", user: user)
        try context.save()
        
        // Search by name
        let nameResults = Patient.search("Alice", for: user, in: context)
        XCTAssertEqual(nameResults.count, 1)
        XCTAssertEqual(nameResults[0].name, "Alice Smith")
        
        // Search by patient ID
        let idResults = Patient.search("A123", for: user, in: context)
        XCTAssertEqual(idResults.count, 1)
        XCTAssertEqual(idResults[0].name, "Charlie Brown")
        
        // Partial match
        let partialResults = Patient.search("P00", for: user, in: context)
        XCTAssertEqual(partialResults.count, 2)
    }
    
    func testPatientUpdate() throws {
        let patient = Patient.create(in: context, name: "Old Name", patientID: "P001")
        patient.update(name: "New Name", patientID: "P002", notes: "Updated notes")
        
        XCTAssertEqual(patient.name, "New Name")
        XCTAssertEqual(patient.patientID, "P002")
        XCTAssertEqual(patient.notes, "Updated notes")
    }

    func testPatientWoundRecordsArray() throws {
        let patient = Patient.create(in: context, name: "Test", patientID: "P001")
        let record1 = WoundRecord.create(in: context, location: "Left foot", patient: patient)
        let record2 = WoundRecord.create(in: context, location: "Right foot", patient: patient)
        
        // Update timestamps to ensure sorting
        record1.lastUpdated = Date(timeIntervalSinceNow: -100)
        record2.lastUpdated = Date()
        
        let records = patient.woundRecordsArray
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].location, "Right foot") // Most recent first
    }
    
    func testPatientActiveWoundCount() throws {
        let patient = Patient.create(in: context, name: "Test", patientID: "P001")
        let record1 = WoundRecord.create(in: context, location: "Left foot", status: "active", patient: patient)
        let record2 = WoundRecord.create(in: context, location: "Right foot", status: "healed", patient: patient)
        
        XCTAssertEqual(patient.activeWoundCount, 1)
        XCTAssertEqual(patient.totalWoundCount, 2)
    }
    
    // MARK: - WoundRecord Extension Tests
    
    func testWoundRecordCreate() throws {
        let patient = Patient.create(in: context, name: "Test", patientID: "P001")
        let initialDate = Date(timeIntervalSince1970: 0)
        let record = WoundRecord.create(
            in: context,
            location: "Left foot, plantar surface",
            initialAssessmentDate: initialDate,
            status: "active",
            patient: patient
        )
        
        XCTAssertNotNil(record.id)
        XCTAssertEqual(record.location, "Left foot, plantar surface")
        XCTAssertEqual(record.initialAssessmentDate, initialDate)
        XCTAssertEqual(record.status, "active")
        XCTAssertEqual(record.patient, patient)
        XCTAssertNotNil(record.lastUpdated)
    }
    
    func testWoundRecordFetchForPatient() throws {
        let patient = Patient.create(in: context, name: "Test", patientID: "P001")
        let record1 = WoundRecord.create(in: context, location: "Left foot", patient: patient)
        let record2 = WoundRecord.create(in: context, location: "Right foot", patient: patient)
        try context.save()
        
        let records = WoundRecord.fetchWoundRecords(for: patient, in: context)
        XCTAssertEqual(records.count, 2)
    }

    func testWoundRecordFetchByStatus() throws {
        let patient = Patient.create(in: context, name: "Test", patientID: "P001")
        let record1 = WoundRecord.create(in: context, location: "Left foot", status: "active", patient: patient)
        let record2 = WoundRecord.create(in: context, location: "Right foot", status: "healed", patient: patient)
        try context.save()
        
        let activeRecords = WoundRecord.fetchWoundRecords(withStatus: "active", for: patient, in: context)
        XCTAssertEqual(activeRecords.count, 1)
        XCTAssertEqual(activeRecords[0].location, "Left foot")
    }
    
    func testWoundRecordFetchByDateRange() throws {
        let patient = Patient.create(in: context, name: "Test", patientID: "P001")
        let record1 = WoundRecord.create(in: context, location: "Left foot", patient: patient)
        record1.lastUpdated = Date(timeIntervalSince1970: 1000)
        
        let record2 = WoundRecord.create(in: context, location: "Right foot", patient: patient)
        record2.lastUpdated = Date(timeIntervalSince1970: 2000)
        try context.save()
        
        let startDate = Date(timeIntervalSince1970: 500)
        let endDate = Date(timeIntervalSince1970: 1500)
        let records = WoundRecord.fetchWoundRecords(from: startDate, to: endDate, for: patient, in: context)
        
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].location, "Left foot")
    }
    
    func testWoundRecordUpdate() throws {
        let record = WoundRecord.create(in: context, location: "Old location", status: "active")
        let oldTimestamp = record.lastUpdated
        
        // Wait a tiny bit to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)
        
        record.update(location: "New location", status: "healed")
        
        XCTAssertEqual(record.location, "New location")
        XCTAssertEqual(record.status, "healed")
        XCTAssertNotEqual(record.lastUpdated, oldTimestamp)
    }
    
    func testWoundRecordArchive() throws {
        let record = WoundRecord.create(in: context, location: "Test", status: "active")
        record.archive()
        
        XCTAssertEqual(record.status, "archived")
        XCTAssertFalse(record.isActive)
    }
    
    func testWoundRecordCaptureSessionsArray() throws {
        let record = WoundRecord.create(in: context, location: "Test")
        let session1 = CaptureSession.create(in: context, photoPath: "path1", woundRecord: record)
        session1.timestamp = Date(timeIntervalSinceNow: -100)
        
        let session2 = CaptureSession.create(in: context, photoPath: "path2", woundRecord: record)
        session2.timestamp = Date()
        
        let sessions = record.captureSessionsArray
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions[0].photoPath, "path2") // Most recent first
        XCTAssertEqual(record.mostRecentSession?.photoPath, "path2")
    }

    // MARK: - CaptureSession Extension Tests
    
    func testCaptureSessionCreate() throws {
        let record = WoundRecord.create(in: context, location: "Test")
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let session = CaptureSession.create(
            in: context,
            photoPath: "/path/to/photo.heic",
            livePhotoVideoPath: "/path/to/video.mov",
            depthDataPath: "/path/to/depth.dat",
            location: location,
            woundRecord: record
        )
        
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.photoPath, "/path/to/photo.heic")
        XCTAssertEqual(session.livePhotoVideoPath, "/path/to/video.mov")
        XCTAssertEqual(session.depthDataPath, "/path/to/depth.dat")
        XCTAssertTrue(session.locationAvailable)
        XCTAssertEqual(session.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(session.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertNotNil(session.timestamp)
        XCTAssertEqual(session.woundRecord, record)
    }
    
    func testCaptureSessionCreateWithoutLocation() throws {
        let session = CaptureSession.create(in: context, photoPath: "/path/to/photo.heic")
        
        XCTAssertFalse(session.locationAvailable)
        XCTAssertEqual(session.latitude, 0.0)
        XCTAssertEqual(session.longitude, 0.0)
        XCTAssertNil(session.location)
    }
    
    func testCaptureSessionFetchForWoundRecord() throws {
        let record = WoundRecord.create(in: context, location: "Test")
        let session1 = CaptureSession.create(in: context, photoPath: "path1", woundRecord: record)
        let session2 = CaptureSession.create(in: context, photoPath: "path2", woundRecord: record)
        try context.save()
        
        let sessions = CaptureSession.fetchCaptureSessions(for: record, in: context)
        XCTAssertEqual(sessions.count, 2)
    }
    
    func testCaptureSessionFetchByDateRange() throws {
        let record = WoundRecord.create(in: context, location: "Test")
        let session1 = CaptureSession.create(in: context, photoPath: "path1", woundRecord: record)
        session1.timestamp = Date(timeIntervalSince1970: 1000)
        
        let session2 = CaptureSession.create(in: context, photoPath: "path2", woundRecord: record)
        session2.timestamp = Date(timeIntervalSince1970: 2000)
        try context.save()
        
        let startDate = Date(timeIntervalSince1970: 500)
        let endDate = Date(timeIntervalSince1970: 1500)
        let sessions = CaptureSession.fetchCaptureSessions(from: startDate, to: endDate, for: record, in: context)
        
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].photoPath, "path1")
    }
    
    func testCaptureSessionFetchWithDepthData() throws {
        let session1 = CaptureSession.create(in: context, photoPath: "path1", depthDataPath: "/depth.dat")
        let session2 = CaptureSession.create(in: context, photoPath: "path2")
        try context.save()
        
        let sessionsWithDepth = CaptureSession.fetchCaptureSessionsWithDepthData(in: context)
        XCTAssertEqual(sessionsWithDepth.count, 1)
        XCTAssertEqual(sessionsWithDepth[0].photoPath, "path1")
    }

    func testCaptureSessionUpdatePaths() throws {
        let session = CaptureSession.create(in: context, photoPath: "old_path")
        session.updatePaths(photoPath: "new_path", livePhotoVideoPath: "video_path")
        
        XCTAssertEqual(session.photoPath, "new_path")
        XCTAssertEqual(session.livePhotoVideoPath, "video_path")
    }
    
    func testCaptureSessionUpdateLocation() throws {
        let session = CaptureSession.create(in: context, photoPath: "path")
        let newLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        session.updateLocation(newLocation)
        
        XCTAssertTrue(session.locationAvailable)
        XCTAssertEqual(session.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(session.longitude, -74.0060, accuracy: 0.0001)
        XCTAssertNotNil(session.location)
    }
    
    func testCaptureSessionComputedProperties() throws {
        let session = CaptureSession.create(
            in: context,
            photoPath: "path",
            livePhotoVideoPath: "video",
            depthDataPath: "depth"
        )
        
        XCTAssertTrue(session.hasLivePhoto)
        XCTAssertTrue(session.hasDepthData)
        XCTAssertFalse(session.hasMeasurement)
    }
    
    // MARK: - Measurement Extension Tests
    
    func testMeasurementCreate() throws {
        let session = CaptureSession.create(in: context, photoPath: "path")
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        
        let measurement = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            depthMM: 5.0,
            volumeMM3: 6000.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95,
            isManuallyAdjusted: false,
            captureSession: session
        )
        
        XCTAssertNotNil(measurement.id)
        XCTAssertEqual(measurement.lengthMM, 50.0)
        XCTAssertEqual(measurement.widthMM, 30.0)
        XCTAssertEqual(measurement.areaMM2, 1200.0)
        XCTAssertEqual(measurement.perimeterMM, 160.0)
        XCTAssertEqual(measurement.depthMM, 5.0)
        XCTAssertEqual(measurement.volumeMM3, 6000.0)
        XCTAssertEqual(measurement.detectionConfidence, 0.95)
        XCTAssertFalse(measurement.isManuallyAdjusted)
        XCTAssertEqual(measurement.captureSession, session)
    }

    func testMeasurementFetchForCaptureSession() throws {
        let session = CaptureSession.create(in: context, photoPath: "path")
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        let measurement = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95,
            captureSession: session
        )
        try context.save()
        
        let fetchedMeasurement = Measurement.fetchMeasurement(for: session, in: context)
        XCTAssertNotNil(fetchedMeasurement)
        XCTAssertEqual(fetchedMeasurement?.id, measurement.id)
    }
    
    func testMeasurementFetchWithDepth() throws {
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        
        let measurement1 = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            depthMM: 5.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95
        )
        
        let measurement2 = Measurement.create(
            in: context,
            lengthMM: 40.0,
            widthMM: 20.0,
            areaMM2: 800.0,
            perimeterMM: 120.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.90
        )
        try context.save()
        
        let measurementsWithDepth = Measurement.fetchMeasurementsWithDepth(in: context)
        XCTAssertEqual(measurementsWithDepth.count, 1)
        XCTAssertEqual(measurementsWithDepth[0].depthMM, 5.0)
    }
    
    func testMeasurementUpdate() throws {
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        let measurement = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95
        )
        
        measurement.update(lengthMM: 60.0, widthMM: 35.0, areaMM2: 1500.0)
        
        XCTAssertEqual(measurement.lengthMM, 60.0)
        XCTAssertEqual(measurement.widthMM, 35.0)
        XCTAssertEqual(measurement.areaMM2, 1500.0)
    }

    func testMeasurementMarkAsManuallyAdjusted() throws {
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        let measurement = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95,
            isManuallyAdjusted: false
        )
        
        measurement.markAsManuallyAdjusted()
        XCTAssertTrue(measurement.isManuallyAdjusted)
    }
    
    func testMeasurementUnitConversions() throws {
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        let measurement = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            depthMM: 5.0,
            volumeMM3: 6000.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95
        )
        
        // Test metric conversions
        XCTAssertEqual(measurement.lengthCM, 5.0, accuracy: 0.01)
        XCTAssertEqual(measurement.widthCM, 3.0, accuracy: 0.01)
        XCTAssertEqual(measurement.areaCM2, 12.0, accuracy: 0.01)
        XCTAssertEqual(measurement.depthCM, 0.5, accuracy: 0.01)
        XCTAssertEqual(measurement.volumeCM3, 6.0, accuracy: 0.01)
        
        // Test imperial conversions
        XCTAssertEqual(measurement.lengthInches, 1.9685, accuracy: 0.01)
        XCTAssertEqual(measurement.widthInches, 1.1811, accuracy: 0.01)
        XCTAssertEqual(measurement.areaInches2, 1.8601, accuracy: 0.01)
        XCTAssertEqual(measurement.depthInches, 0.1969, accuracy: 0.01)
        XCTAssertEqual(measurement.volumeInches3, 0.3661, accuracy: 0.01)
    }
    
    func testMeasurementComputedProperties() throws {
        let boundaryData = Data([1, 2, 3, 4])
        let calibrationData = Data([5, 6, 7, 8])
        let measurement = Measurement.create(
            in: context,
            lengthMM: 50.0,
            widthMM: 30.0,
            areaMM2: 1200.0,
            perimeterMM: 160.0,
            depthMM: 5.0,
            volumeMM3: 6000.0,
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: 0.95
        )
        
        XCTAssertTrue(measurement.hasDepthData)
        XCTAssertTrue(measurement.hasVolumeData)
    }

    // MARK: - Note Extension Tests
    
    func testNoteCreate() throws {
        let session = CaptureSession.create(in: context, photoPath: "path")
        let note = Note.create(
            in: context,
            text: "Wound showing signs of improvement",
            category: "improved",
            captureSession: session
        )
        
        XCTAssertNotNil(note.id)
        XCTAssertEqual(note.text, "Wound showing signs of improvement")
        XCTAssertEqual(note.category, "improved")
        XCTAssertNotNil(note.createdAt)
        XCTAssertEqual(note.captureSession, session)
    }
    
    func testNoteFetchForCaptureSession() throws {
        let session = CaptureSession.create(in: context, photoPath: "path")
        let note1 = Note.create(in: context, text: "Note 1", captureSession: session)
        let note2 = Note.create(in: context, text: "Note 2", captureSession: session)
        try context.save()
        
        let notes = Note.fetchNotes(for: session, in: context)
        XCTAssertEqual(notes.count, 2)
    }
    
    func testNoteFetchByCategory() throws {
        let session = CaptureSession.create(in: context, photoPath: "path")
        let note1 = Note.create(in: context, text: "Improved", category: "improved", captureSession: session)
        let note2 = Note.create(in: context, text: "Worsened", category: "worsened", captureSession: session)
        try context.save()
        
        let improvedNotes = Note.fetchNotes(withCategory: "improved", for: session, in: context)
        XCTAssertEqual(improvedNotes.count, 1)
        XCTAssertEqual(improvedNotes[0].text, "Improved")
    }
    
    func testNoteUpdate() throws {
        let note = Note.create(in: context, text: "Old text", category: "general")
        note.update(text: "New text", category: "improved")
        
        XCTAssertEqual(note.text, "New text")
        XCTAssertEqual(note.category, "improved")
    }
    
    func testNoteCategoryProperties() throws {
        let improvedNote = Note.create(in: context, text: "Test", category: "improved")
        let unchangedNote = Note.create(in: context, text: "Test", category: "unchanged")
        let worsenedNote = Note.create(in: context, text: "Test", category: "worsened")
        let generalNote = Note.create(in: context, text: "Test", category: "general")
        
        XCTAssertTrue(improvedNote.isImproved)
        XCTAssertFalse(improvedNote.isUnchanged)
        
        XCTAssertTrue(unchangedNote.isUnchanged)
        XCTAssertFalse(unchangedNote.isWorsened)
        
        XCTAssertTrue(worsenedNote.isWorsened)
        XCTAssertFalse(worsenedNote.isGeneral)
        
        XCTAssertTrue(generalNote.isGeneral)
        XCTAssertFalse(generalNote.isImproved)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteOperations() throws {
        let user = User.create(in: context, role: .doctor)
        let patient = Patient.create(in: context, name: "Test", patientID: "P001", user: user)
        let record = WoundRecord.create(in: context, location: "Test", patient: patient)
        let session = CaptureSession.create(in: context, photoPath: "path", woundRecord: record)
        try context.save()
        
        // Safely unwrap IDs before using them
        guard let sessionID = session.id else {
            XCTFail("Session ID should not be nil after creation")
            return
        }
        
        guard let recordID = record.id else {
            XCTFail("Record ID should not be nil after creation")
            return
        }
        
        // Test deleting session
        session.delete(from: context)
        try context.save()
        
        let fetchedSession = CaptureSession.fetchCaptureSession(byID: sessionID, in: context)
        XCTAssertNil(fetchedSession)
        
        // Test cascade delete - deleting patient should delete wound records
        patient.delete(from: context)
        try context.save()
        
        let fetchedRecord = WoundRecord.fetchWoundRecord(byID: recordID, in: context)
        XCTAssertNil(fetchedRecord)
    }
}
