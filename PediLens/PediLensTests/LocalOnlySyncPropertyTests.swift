//
//  LocalOnlySyncPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for local-only operation when sync is disabled
//  Feature: pedilens, Property 22: Local-Only Operation When Sync Disabled
//  Validates: Requirements 6.4
//

import XCTest
import CoreData
import CloudKit
@testable import PediLens

/// Property-based tests for local-only functionality when sync is disabled
/// These tests validate that the system functions entirely with local storage when sync is disabled
final class LocalOnlySyncPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 22: Local-Only Operation When Sync Disabled
    // **Validates: Requirements 6.4**
    
    /// Property: For any operation when iCloud sync is disabled,
    /// the system should function entirely using local storage without attempting cloud operations
    func testProperty22_LocalOnlyOperationWhenSyncDisabled() throws {
        let iterations = 100
        var failedCases: [(operation: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user with sync DISABLED
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
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
                // CREATE: Create wound record with sync disabled
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: location,
                    initialAssessmentDate: initialDate,
                    status: status,
                    patient: patient
                )
                
                guard let woundRecordUUID = woundRecord.id else {
                    failedCases.append((operation: "create", iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Verify sync is DISABLED for user
                XCTAssertFalse(user.iCloudSyncEnabled,
                             "Iteration \(iteration): Sync should be disabled")
                
                // Verify the wound record was persisted locally
                let fetchedRecord = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                XCTAssertNotNil(fetchedRecord,
                              "Iteration \(iteration): WoundRecord should be persisted locally")
                
                // Verify sync status does not indicate syncing
                let syncStatus = syncManager.getSyncStatus()
                
                // When sync is disabled, status should be synced (no pending operations)
                // or offline (not attempting to sync)
                switch syncStatus {
                case .synced, .offline:
                    // These are acceptable states when sync is disabled
                    break
                case .syncing, .pending:
                    XCTFail("Iteration \(iteration): Should not be syncing when sync is disabled")
                    failedCases.append((operation: "sync_status", iteration: iteration))
                case .error(let message):
                    // Errors are acceptable if they indicate sync is disabled
                    if !message.contains("disabled") {
                        XCTFail("Iteration \(iteration): Unexpected error: \(message)")
                        failedCases.append((operation: "error", iteration: iteration))
                    }
                }
                
                // UPDATE: Update wound record with sync disabled
                let newStatus = ["active", "healing", "healed"].randomElement()!
                fetchedRecord?.update(status: newStatus)
                try saveContext()
                
                // Verify update persisted locally
                let updatedRecord = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                XCTAssertEqual(updatedRecord?.status, newStatus,
                             "Iteration \(iteration): Updated status should persist locally")
                
                // DELETE: Delete wound record with sync disabled
                fetchedRecord?.delete(from: context)
                try saveContext()
                
                // Verify deletion persisted locally
                let deletedRecord = WoundRecord.fetchWoundRecord(byID: woundRecordUUID, in: context)
                XCTAssertNil(deletedRecord,
                           "Iteration \(iteration): WoundRecord should be deleted locally")
                
                // Clean up
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Local-only operation failed with error: \(error)")
                failedCases.append((operation: "exception", iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Local-only operation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any capture session when sync is disabled,
    /// all operations should complete using local storage only
    func testProperty22_CaptureSessionLocalOnlyWhenSyncDisabled() throws {
        let iterations = 100
        var failedCases: [(photoPath: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user with sync DISABLED
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Create patient and wound record
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
            let hasLivePhoto = Bool.random()
            let livePhotoPath = hasLivePhoto ? "photos/\(UUID().uuidString).mov" : nil
            
            do {
                // CREATE: Create capture session with sync disabled
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: photoPath,
                    livePhotoVideoPath: livePhotoPath,
                    woundRecord: woundRecord
                )
                
                guard let sessionUUID = captureSession.id else {
                    failedCases.append((photoPath: photoPath, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Verify sync is DISABLED
                XCTAssertFalse(user.iCloudSyncEnabled,
                             "Iteration \(iteration): Sync should be disabled")
                
                // Verify the capture session was persisted locally
                let fetchedSession = CaptureSession.fetchCaptureSession(byID: sessionUUID, in: context)
                XCTAssertNotNil(fetchedSession,
                              "Iteration \(iteration): CaptureSession should be persisted locally")
                
                // Verify no sync operations are pending
                let syncStatus = syncManager.getSyncStatus()
                switch syncStatus {
                case .syncing, .pending:
                    XCTFail("Iteration \(iteration): Should not have pending sync operations when sync is disabled")
                    failedCases.append((photoPath: photoPath, iteration: iteration))
                default:
                    break
                }
                
                // Clean up
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Capture session local-only operation failed with error: \(error)")
                failedCases.append((photoPath: photoPath, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Capture session local-only property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any measurement when sync is disabled,
    /// all operations should complete using local storage only
    func testProperty22_MeasurementLocalOnlyWhenSyncDisabled() throws {
        let iterations = 100
        var failedCases: [(area: Double, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create full hierarchy with sync DISABLED
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
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
            
            // Generate random measurement data
            let lengthMM = Double.random(in: 5.0...100.0)
            let widthMM = Double.random(in: 5.0...100.0)
            let areaMM2 = Double.random(in: 25.0...10000.0)
            let perimeterMM = Double.random(in: 20.0...400.0)
            
            // Create dummy boundary points and calibration data
            let boundaryPoints = try! JSONEncoder().encode([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
            let calibrationData = try! JSONEncoder().encode(["pixelsPerMM": 1.0])
            
            do {
                // CREATE: Create measurement with sync disabled
                let measurement = Measurement.create(
                    in: context,
                    lengthMM: lengthMM,
                    widthMM: widthMM,
                    areaMM2: areaMM2,
                    perimeterMM: perimeterMM,
                    boundaryPoints: boundaryPoints,
                    calibrationData: calibrationData,
                    detectionConfidence: 0.8,
                    captureSession: captureSession
                )
                
                guard let measurementUUID = measurement.id else {
                    failedCases.append((area: areaMM2, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Verify sync is DISABLED
                XCTAssertFalse(user.iCloudSyncEnabled,
                             "Iteration \(iteration): Sync should be disabled")
                
                // Verify the measurement was persisted locally
                let fetchedMeasurement = Measurement.fetchMeasurement(byID: measurementUUID, in: context)
                XCTAssertNotNil(fetchedMeasurement,
                              "Iteration \(iteration): Measurement should be persisted locally")
                
                // Verify no sync operations are pending
                let syncStatus = syncManager.getSyncStatus()
                switch syncStatus {
                case .syncing, .pending:
                    XCTFail("Iteration \(iteration): Should not have pending sync operations when sync is disabled")
                    failedCases.append((area: areaMM2, iteration: iteration))
                default:
                    break
                }
                
                // Clean up
                measurement.delete(from: context)
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Measurement local-only operation failed with error: \(error)")
                failedCases.append((area: areaMM2, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Measurement local-only property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any patient data when sync is disabled,
    /// all operations should complete using local storage only
    func testProperty22_PatientDataLocalOnlyWhenSyncDisabled() throws {
        let iterations = 100
        var failedCases: [(name: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Create user with sync DISABLED
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Generate random patient data
            let name = generateRandomPatientName()
            let patientID = generateRandomString(length: Int.random(in: 5...15))
            let dateOfBirth = Bool.random() ? Date(timeIntervalSinceNow: -Double.random(in: 18...90) * 365 * 24 * 3600) : nil
            
            do {
                // CREATE: Create patient with sync disabled
                let patient = Patient.create(
                    in: context,
                    name: name,
                    patientID: patientID,
                    dateOfBirth: dateOfBirth,
                    user: user
                )
                
                guard let patientUUID = patient.id else {
                    failedCases.append((name: name, iteration: iteration))
                    continue
                }
                
                // Save to persistent store
                try saveContext()
                
                // Verify sync is DISABLED
                XCTAssertFalse(user.iCloudSyncEnabled,
                             "Iteration \(iteration): Sync should be disabled")
                
                // Verify the patient was persisted locally
                let fetchedPatient = Patient.fetchPatient(byID: patientUUID, in: context)
                XCTAssertNotNil(fetchedPatient,
                              "Iteration \(iteration): Patient should be persisted locally")
                
                // Verify no sync operations are pending
                let syncStatus = syncManager.getSyncStatus()
                switch syncStatus {
                case .syncing, .pending:
                    XCTFail("Iteration \(iteration): Should not have pending sync operations when sync is disabled")
                    failedCases.append((name: name, iteration: iteration))
                default:
                    break
                }
                
                // Clean up
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Patient local-only operation failed with error: \(error)")
                failedCases.append((name: name, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient local-only property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
