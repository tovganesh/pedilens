//
//  CoreDataOfflinePropertyTests.swift
//  PediLensTests
//
//  Property-based tests for offline functionality
//  Feature: pedilens, Property 17: Offline Functionality Completeness
//  Validates: Requirements 5.2, 13.1, 13.5
//

import XCTest
import CoreData
import CoreLocation
@testable import PediLens

/// Property-based tests for offline Core Data operations
/// These tests validate that all CRUD operations work without network connectivity
final class CoreDataOfflinePropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing (simulates offline-only operation)
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDown() {
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
        let firstNames = ["John", "Jane", "Michael", "Sarah", "David", "Emily", "田中", "佐藤", "María", "José"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "太郎", "花子", "García", "Rodríguez"]
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
    
    /// Generates random wound location
    private func generateRandomWoundLocation() -> String {
        let locations = [
            "Left foot, plantar surface",
            "Right foot, heel",
            "Left foot, toe",
            "Right foot, dorsal surface",
            "Left ankle",
            "Right ankle"
        ]
        return locations.randomElement()!
    }
    
    /// Generates random wound status
    private func generateRandomWoundStatus() -> String {
        let statuses = ["active", "healing", "healed", "archived"]
        return statuses.randomElement()!
    }
    
    /// Generates random note category
    private func generateRandomNoteCategory() -> String {
        let categories = ["improved", "unchanged", "worsened", "general"]
        return categories.randomElement()!
    }
    
    /// Saves context and handles errors
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Property 17: Offline Functionality Completeness
    // **Validates: Requirements 5.2, 13.1, 13.5**
    
    /// Property: For any User entity created offline, it should be persisted and retrievable
    /// This validates offline CREATE and READ operations for User
    func testProperty17_UserCRUD_WorksOffline() throws {
        let iterations = 100
        var failedCases: [(role: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Generate random user data
            let role = Bool.random() ? UserRole.doctor : UserRole.patient
            let iCloudSyncEnabled = Bool.random()
            
            do {
                // CREATE: Create user offline
                let user = User.create(
                    in: context,
                    role: role,
                    iCloudSyncEnabled: iCloudSyncEnabled
                )
                
                guard let userId = user.id else {
                    failedCases.append((role: role, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // READ: Fetch the user back
                let fetchedUser = User.fetchCurrentUser(in: context)
                
                // Verify the user was persisted correctly
                guard let fetchedUser = fetchedUser else {
                    failedCases.append((role: role.rawValue, iteration: iteration))
                    continue
                }
                
                XCTAssertEqual(fetchedUser.id, userId,
                             "Iteration \(iteration): User ID should match")
                XCTAssertEqual(fetchedUser.role, role.rawValue,
                             "Iteration \(iteration): User role should match")
                XCTAssertEqual(fetchedUser.iCloudSyncEnabled, iCloudSyncEnabled,
                             "Iteration \(iteration): iCloud sync setting should match")
                
                // UPDATE: Update user properties
                let newSyncSetting = !iCloudSyncEnabled
                fetchedUser.updateICloudSync(enabled: newSyncSetting)
                try saveContext()
                
                // Verify update
                let updatedUser = User.fetchCurrentUser(in: context)
                XCTAssertEqual(updatedUser?.iCloudSyncEnabled, newSyncSetting,
                             "Iteration \(iteration): Updated sync setting should persist")
                
                // DELETE: Delete user
                fetchedUser.delete(from: context)
                try saveContext()
                
                // Verify deletion
                let deletedUser = User.fetchCurrentUser(in: context)
                XCTAssertNil(deletedUser,
                           "Iteration \(iteration): User should be deleted")
                
            } catch {
                XCTFail("Iteration \(iteration): Offline User CRUD failed with error: \(error)")
                failedCases.append((role: role.rawValue, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "User CRUD offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any Patient entity created offline, it should be persisted and retrievable
    /// This validates offline CREATE and READ operations for Patient
    func testProperty17_PatientCRUD_WorksOffline() throws {
        let iterations = 100
        var failedCases: [(name: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create a user first
            let user = User.create(in: context, role: .doctor)
            try saveContext()
            
            // Generate random patient data
            let name = generateRandomPatientName()
            let patientID = generateRandomString(length: Int.random(in: 5...15))
            let dateOfBirth = Bool.random() ? Date(timeIntervalSinceNow: -Double.random(in: 18...90) * 365 * 24 * 3600) : nil
            let notes = Bool.random() ? generateRandomString(length: Int.random(in: 10...100)) : nil
            
            do {
                // CREATE: Create patient offline
                let patient = Patient.create(
                    in: context,
                    name: name,
                    patientID: patientID,
                    dateOfBirth: dateOfBirth,
                    notes: notes,
                    user: user
                )
                
                guard let patientUUID = patient.id else {
                    XCTFail("Iteration \(iteration): Patient ID should not be nil")
                    failedCases.append((name: name, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // READ: Fetch the patient back
                let fetchedPatient = Patient.fetchPatient(byID: patientUUID, in: context)
                
                // Verify the patient was persisted correctly
                guard let fetchedPatient = fetchedPatient else {
                    failedCases.append((name: name, iteration: iteration))
                    continue
                }
                
                XCTAssertEqual(fetchedPatient.id, patientUUID,
                             "Iteration \(iteration): Patient ID should match")
                XCTAssertEqual(fetchedPatient.name, name,
                             "Iteration \(iteration): Patient name should match")
                XCTAssertEqual(fetchedPatient.patientID, patientID,
                             "Iteration \(iteration): Patient ID should match")
                
                // UPDATE: Update patient properties
                let newName = generateRandomPatientName()
                fetchedPatient.update(name: newName)
                try saveContext()
                
                // Verify update
                let updatedPatient = Patient.fetchPatient(byID: patientUUID, in: context)
                XCTAssertEqual(updatedPatient?.name, newName,
                             "Iteration \(iteration): Updated name should persist")
                
                // DELETE: Delete patient
                fetchedPatient.delete(from: context)
                try saveContext()
                
                // Verify deletion
                let deletedPatient = Patient.fetchPatient(byID: patientUUID, in: context)
                XCTAssertNil(deletedPatient,
                           "Iteration \(iteration): Patient should be deleted")
                
                // Clean up user
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Offline Patient CRUD failed with error: \(error)")
                failedCases.append((name: name, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient CRUD offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any WoundRecord entity created offline, it should be persisted and retrievable
    /// This validates offline CREATE and READ operations for WoundRecord
    func testProperty17_WoundRecordCRUD_WorksOffline() throws {
        let iterations = 100
        var failedCases: [(location: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user and patient first
            let user = User.create(in: context, role: .doctor)
            let patient = Patient.create(
                in: context,
                name: generateRandomPatientName(),
                patientID: generateRandomString(length: 10),
                user: user
            )
            try saveContext()
            
            // Generate random wound record data
            let location = generateRandomWoundLocation()
            let initialDate = Date(timeIntervalSinceNow: -Double.random(in: 0...365) * 24 * 3600)
            let status = generateRandomWoundStatus()
            
            do {
                // CREATE: Create wound record offline
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
                
                // READ: Fetch the wound record back
                let fetchedRecord = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                
                // Verify the wound record was persisted correctly
                guard let fetchedRecord = fetchedRecord else {
                    failedCases.append((location: location, iteration: iteration))
                    continue
                }
                
                XCTAssertEqual(fetchedRecord.id, woundRecordUUID,
                             "Iteration \(iteration): WoundRecord ID should match")
                XCTAssertEqual(fetchedRecord.location, location,
                             "Iteration \(iteration): Location should match")
                XCTAssertEqual(fetchedRecord.status, status,
                             "Iteration \(iteration): Status should match")
                
                // UPDATE: Update wound record properties
                let newStatus = generateRandomWoundStatus()
                fetchedRecord.update(status: newStatus)
                try saveContext()
                
                // Verify update
                let updatedRecord = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                XCTAssertEqual(updatedRecord?.status, newStatus,
                             "Iteration \(iteration): Updated status should persist")
                
                // DELETE: Delete wound record
                fetchedRecord.delete(from: context)
                try saveContext()
                
                // Verify deletion
                let deletedRecord = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                XCTAssertNil(deletedRecord,
                           "Iteration \(iteration): WoundRecord should be deleted")
                
                // Clean up
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Offline WoundRecord CRUD failed with error: \(error)")
                failedCases.append((location: location, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "WoundRecord CRUD offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any CaptureSession entity created offline, it should be persisted and retrievable
    /// This validates offline CREATE and READ operations for CaptureSession
    func testProperty17_CaptureSessionCRUD_WorksOffline() throws {
        let iterations = 100
        var failedCases: [(photoPath: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user, patient, and wound record first
            let user = User.create(in: context, role: .doctor)
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
            try saveContext()
            
            // Generate random capture session data
            let photoPath = "photos/\(UUID().uuidString).heic"
            let hasLivePhoto = Bool.random()
            let livePhotoPath = hasLivePhoto ? "photos/\(UUID().uuidString).mov" : nil
            let hasDepthData = Bool.random()
            let depthDataPath = hasDepthData ? "photos/\(UUID().uuidString).dat" : nil
            let hasLocation = Bool.random()
            let location = hasLocation ? CLLocation(latitude: Double.random(in: -90...90),
                                                   longitude: Double.random(in: -180...180)) : nil
            
            do {
                // CREATE: Create capture session offline
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: photoPath,
                    livePhotoVideoPath: livePhotoPath,
                    depthDataPath: depthDataPath,
                    location: location,
                    woundRecord: woundRecord
                )
                
                guard let sessionUUID = captureSession.id else {
                    failedCases.append((photoPath: photoPath, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // READ: Fetch the capture session back
                let fetchedSession = CaptureSession.fetchCaptureSession(byID: sessionUUID, in: context)
                
                // Verify the capture session was persisted correctly
                guard let fetchedSession = fetchedSession else {
                    failedCases.append((photoPath: photoPath, iteration: iteration))
                    continue
                }
                
                XCTAssertEqual(fetchedSession.id, sessionUUID,
                             "Iteration \(iteration): CaptureSession ID should match")
                XCTAssertEqual(fetchedSession.photoPath, photoPath,
                             "Iteration \(iteration): Photo path should match")
                XCTAssertEqual(fetchedSession.livePhotoVideoPath, livePhotoPath,
                             "Iteration \(iteration): Live photo path should match")
                XCTAssertEqual(fetchedSession.depthDataPath, depthDataPath,
                             "Iteration \(iteration): Depth data path should match")
                XCTAssertEqual(fetchedSession.locationAvailable, hasLocation,
                             "Iteration \(iteration): Location availability should match")
                
                // UPDATE: Update capture session paths
                let newPhotoPath = "photos/\(UUID().uuidString).heic"
                fetchedSession.updatePaths(photoPath: newPhotoPath)
                try saveContext()
                
                // Verify update
                let updatedSession = CaptureSession.fetchCaptureSession(byID: sessionUUID, in: context)
                XCTAssertEqual(updatedSession?.photoPath, newPhotoPath,
                             "Iteration \(iteration): Updated photo path should persist")
                
                // DELETE: Delete capture session
                fetchedSession.delete(from: context)
                try saveContext()
                
                // Verify deletion
                let deletedSession = CaptureSession.fetchCaptureSession(byID: sessionUUID, in: context)
                XCTAssertNil(deletedSession,
                           "Iteration \(iteration): CaptureSession should be deleted")
                
                // Clean up
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Offline CaptureSession CRUD failed with error: \(error)")
                failedCases.append((photoPath: photoPath, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "CaptureSession CRUD offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any Measurement entity created offline, it should be persisted and retrievable
    /// This validates offline CREATE and READ operations for Measurement
    func testProperty17_MeasurementCRUD_WorksOffline() throws {
        let iterations = 100
        var failedCases: [(area: Double, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create full hierarchy first
            let user = User.create(in: context, role: .doctor)
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
            let captureSession = CaptureSession.create(
                in: context,
                photoPath: "photos/\(UUID().uuidString).heic",
                woundRecord: woundRecord
            )
            try saveContext()
            
            // Generate random measurement data
            let lengthMM = Double.random(in: 5.0...100.0)
            let widthMM = Double.random(in: 5.0...100.0)
            let areaMM2 = Double.random(in: 25.0...10000.0)
            let perimeterMM = Double.random(in: 20.0...400.0)
            let hasDepth = Bool.random()
            let depthMM = hasDepth ? Double.random(in: 0.5...20.0) : 0.0
            let volumeMM3 = hasDepth ? Double.random(in: 10.0...2000.0) : 0.0
            let confidence = Float.random(in: 0.3...1.0)
            let isManuallyAdjusted = Bool.random()
            
            // Create dummy boundary points and calibration data
            let boundaryPoints = try! JSONEncoder().encode([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
            let calibrationData = try! JSONEncoder().encode(["pixelsPerMM": 1.0])
            
            do {
                // CREATE: Create measurement offline
                let measurement = Measurement.create(
                    in: context,
                    lengthMM: lengthMM,
                    widthMM: widthMM,
                    areaMM2: areaMM2,
                    perimeterMM: perimeterMM,
                    depthMM: depthMM,
                    volumeMM3: volumeMM3,
                    boundaryPoints: boundaryPoints,
                    calibrationData: calibrationData,
                    detectionConfidence: confidence,
                    isManuallyAdjusted: isManuallyAdjusted,
                    captureSession: captureSession
                )
                
                guard let measurementUUID = measurement.id else {
                    failedCases.append((area: areaMM2, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // READ: Fetch the measurement back
                let fetchedMeasurement = Measurement.fetchMeasurement(byID: measurementUUID, in: context)
                
                // Verify the measurement was persisted correctly
                guard let fetchedMeasurement = fetchedMeasurement else {
                    failedCases.append((area: areaMM2, iteration: iteration))
                    continue
                }
                
                XCTAssertEqual(fetchedMeasurement.id, measurementUUID,
                             "Iteration \(iteration): Measurement ID should match")
                XCTAssertEqual(fetchedMeasurement.lengthMM, lengthMM, accuracy: 0.001,
                             "Iteration \(iteration): Length should match")
                XCTAssertEqual(fetchedMeasurement.widthMM, widthMM, accuracy: 0.001,
                             "Iteration \(iteration): Width should match")
                XCTAssertEqual(fetchedMeasurement.areaMM2, areaMM2, accuracy: 0.001,
                             "Iteration \(iteration): Area should match")
                XCTAssertEqual(fetchedMeasurement.depthMM, depthMM ?? 0.0, accuracy: 0.001,
                             "Iteration \(iteration): Depth should match")
                
                // UPDATE: Update measurement values
                let newArea = Double.random(in: 25.0...10000.0)
                fetchedMeasurement.update(areaMM2: newArea)
                try saveContext()
                
                // Verify update
                let updatedMeasurement = Measurement.fetchMeasurement(byID: measurementUUID, in: context)
                XCTAssertEqual(updatedMeasurement?.areaMM2, newArea, accuracy: 0.001,
                             "Iteration \(iteration): Updated area should persist")
                
                // DELETE: Delete measurement
                fetchedMeasurement.delete(from: context)
                try saveContext()
                
                // Verify deletion
                let deletedMeasurement = Measurement.fetchMeasurement(byID: measurementUUID, in: context)
                XCTAssertNil(deletedMeasurement,
                           "Iteration \(iteration): Measurement should be deleted")
                
                // Clean up
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Offline Measurement CRUD failed with error: \(error)")
                failedCases.append((area: areaMM2, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Measurement CRUD offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any Note entity created offline, it should be persisted and retrievable
    /// This validates offline CREATE and READ operations for Note
    func testProperty17_NoteCRUD_WorksOffline() throws {
        let iterations = 100
        var failedCases: [(text: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create full hierarchy first
            let user = User.create(in: context, role: .doctor)
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
            let captureSession = CaptureSession.create(
                in: context,
                photoPath: "photos/\(UUID().uuidString).heic",
                woundRecord: woundRecord
            )
            try saveContext()
            
            // Generate random note data
            let text = generateRandomString(length: Int.random(in: 10...200))
            let category = generateRandomNoteCategory()
            
            do {
                // CREATE: Create note offline
                let note = Note.create(
                    in: context,
                    text: text,
                    category: category,
                    captureSession: captureSession
                )
                
                guard let noteUUID = note.id else {
                    failedCases.append((text: text, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // READ: Fetch the note back
                let fetchedNote = Note.fetchNote(byID: noteUUID, in: context)
                
                // Verify the note was persisted correctly
                guard let fetchedNote = fetchedNote else {
                    failedCases.append((text: text, iteration: iteration))
                    continue
                }
                
                XCTAssertEqual(fetchedNote.id, noteUUID,
                             "Iteration \(iteration): Note ID should match")
                XCTAssertEqual(fetchedNote.text, text,
                             "Iteration \(iteration): Text should match")
                XCTAssertEqual(fetchedNote.category, category,
                             "Iteration \(iteration): Category should match")
                
                // UPDATE: Update note content
                let newText = generateRandomString(length: Int.random(in: 10...200))
                fetchedNote.update(text: newText)
                try saveContext()
                
                // Verify update
                let updatedNote = Note.fetchNote(byID: noteUUID, in: context)
                XCTAssertEqual(updatedNote?.text, newText,
                             "Iteration \(iteration): Updated text should persist")
                
                // DELETE: Delete note
                fetchedNote.delete(from: context)
                try saveContext()
                
                // Verify deletion
                let deletedNote = Note.fetchNote(byID: noteUUID, in: context)
                XCTAssertNil(deletedNote,
                           "Iteration \(iteration): Note should be deleted")
                
                // Clean up
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Offline Note CRUD failed with error: \(error)")
                failedCases.append((text: text, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Note CRUD offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any complex entity graph created offline, all relationships should be preserved
    /// This validates offline relationship integrity
    func testProperty17_ComplexEntityGraph_PreservesRelationships() throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create a complex entity graph
                let user = User.create(in: context, role: .doctor)
                
                // Create multiple patients
                let patientCount = Int.random(in: 1...5)
                var patients: [Patient] = []
                for _ in 0..<patientCount {
                    let patient = Patient.create(
                        in: context,
                        name: generateRandomPatientName(),
                        patientID: generateRandomString(length: 10),
                        user: user
                    )
                    patients.append(patient)
                }
                
                // Create wound records for each patient
                var woundRecords: [WoundRecord] = []
                for patient in patients {
                    let woundCount = Int.random(in: 1...3)
                    for _ in 0..<woundCount {
                        let woundRecord = WoundRecord.create(
                            in: context,
                            location: generateRandomWoundLocation(),
                            patient: patient
                        )
                        woundRecords.append(woundRecord)
                    }
                }
                
                // Create capture sessions for each wound record
                var captureSessions: [CaptureSession] = []
                for woundRecord in woundRecords {
                    let sessionCount = Int.random(in: 1...3)
                    for _ in 0..<sessionCount {
                        let captureSession = CaptureSession.create(
                            in: context,
                            photoPath: "photos/\(UUID().uuidString).heic",
                            woundRecord: woundRecord
                        )
                        captureSessions.append(captureSession)
                    }
                }
                
                // Save the entire graph
                try saveContext()
                
                // Verify relationships are preserved
                let fetchedUser = User.fetchCurrentUser(in: context)
                guard let fetchedUser = fetchedUser else {
                    failedCases.append(iteration)
                    continue
                }
                
                // Verify user -> patients relationship
                XCTAssertEqual(fetchedUser.patientsArray.count, patientCount,
                             "Iteration \(iteration): User should have correct number of patients")
                
                // Verify patient -> wound records relationship
                for patient in fetchedUser.patientsArray {
                    XCTAssertGreaterThan(patient.woundRecordsArray.count, 0,
                                       "Iteration \(iteration): Patient should have wound records")
                    
                    // Verify wound record -> capture sessions relationship
                    for woundRecord in patient.woundRecordsArray {
                        XCTAssertGreaterThan(woundRecord.captureSessionsArray.count, 0,
                                           "Iteration \(iteration): Wound record should have capture sessions")
                    }
                }
                
                // Clean up
                for captureSession in captureSessions {
                    captureSession.delete(from: context)
                }
                for woundRecord in woundRecords {
                    woundRecord.delete(from: context)
                }
                for patient in patients {
                    patient.delete(from: context)
                }
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Complex graph offline test failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Complex entity graph offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any fetch request with predicates, results should be correct offline
    /// This validates offline query functionality
    func testProperty17_FetchWithPredicates_WorksOffline() throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create test data
                let user = User.create(in: context, role: .doctor)
                
                // Create patients with known data
                let patient1 = Patient.create(
                    in: context,
                    name: "John Smith",
                    patientID: "P001",
                    user: user
                )
                let patient2 = Patient.create(
                    in: context,
                    name: "Jane Doe",
                    patientID: "P002",
                    user: user
                )
                
                // Create wound records with different statuses
                let activeWound = WoundRecord.create(
                    in: context,
                    location: "Left foot",
                    status: "active",
                    patient: patient1
                )
                let healedWound = WoundRecord.create(
                    in: context,
                    location: "Right foot",
                    status: "healed",
                    patient: patient2
                )
                
                try saveContext()
                
                // Test search by name
                let searchResults = Patient.search("John", for: user, in: context)
                XCTAssertEqual(searchResults.count, 1,
                             "Iteration \(iteration): Search should find one patient")
                XCTAssertEqual(searchResults.first?.name, "John Smith",
                             "Iteration \(iteration): Search should find correct patient")
                
                // Test fetch by status
                let activeWounds = WoundRecord.fetchWoundRecords(withStatus: "active", in: context)
                XCTAssertEqual(activeWounds.count, 1,
                             "Iteration \(iteration): Should find one active wound")
                XCTAssertEqual(activeWounds.first?.location, "Left foot",
                             "Iteration \(iteration): Should find correct wound")
                
                // Test fetch by patient
                let patient1Wounds = WoundRecord.fetchWoundRecords(for: patient1, in: context)
                XCTAssertEqual(patient1Wounds.count, 1,
                             "Iteration \(iteration): Patient 1 should have one wound")
                
                // Clean up
                activeWound.delete(from: context)
                healedWound.delete(from: context)
                patient1.delete(from: context)
                patient2.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Fetch with predicates offline test failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Fetch with predicates offline property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any concurrent offline operations, data integrity should be maintained
    /// This validates thread-safe offline operations
    func testProperty17_ConcurrentOfflineOperations_MaintainIntegrity() throws {
        let iterations = 30
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let expectation = self.expectation(description: "Concurrent operations \(iteration)")
            let operationCount = Int.random(in: 10...30)
            expectation.expectedFulfillmentCount = operationCount
            
            var createdPatientIDs: [UUID] = []
            let idsLock = NSLock()
            
            // Create user first
            let user = User.create(in: context, role: .doctor)
            try saveContext()
            
            // Perform concurrent create operations
            for _ in 0..<operationCount {
                DispatchQueue.global(qos: .userInitiated).async {
                    // Create a background context for this operation
                    let backgroundContext = self.persistenceController.container.newBackgroundContext()
                    
                    do {
                        // Fetch user in background context
                        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
                        let users = try backgroundContext.fetch(fetchRequest)
                        guard let bgUser = users.first else {
                            expectation.fulfill()
                            return
                        }
                        
                        // Create patient
                        let patient = Patient.create(
                            in: backgroundContext,
                            name: self.generateRandomPatientName(),
                            patientID: self.generateRandomString(length: 10),
                            user: bgUser
                        )
                        
                        let patientID = patient.id
                        
                        // Save
                        try backgroundContext.save()
                        
                        // Track created ID
                        idsLock.lock()
                        createdPatientIDs.append(patientID)
                        idsLock.unlock()
                        
                        expectation.fulfill()
                        
                    } catch {
                        XCTFail("Concurrent operation failed: \(error)")
                        expectation.fulfill()
                    }
                }
            }
            
            // Wait for all operations
            wait(for: [expectation], timeout: 10.0)
            
            // Verify all patients were created
            let allPatients = Patient.fetchAll(in: context)
            
            if allPatients.count != operationCount {
                failedCases.append(iteration)
            }
            
            // Clean up
            for patient in allPatients {
                patient.delete(from: context)
            }
            user.delete(from: context)
            try saveContext()
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Concurrent offline operations property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
