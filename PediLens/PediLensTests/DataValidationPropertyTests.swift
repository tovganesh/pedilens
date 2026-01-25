//
//  DataValidationPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for data validation
//  Feature: pedilens, Property 40: Data Validation Before Persistence
//  Validates: Requirements 14.1
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for data validation before persistence
/// These tests validate that all data is validated before being persisted to Core Data
final class DataValidationPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
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
    
    /// Saves context and handles errors
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Property 40: Data Validation Before Persistence
    // **Validates: Requirements 14.1**
    
    /// Property: For any User entity, required fields must be present before persistence
    /// This validates that User entities have all required fields
    func testProperty40_UserValidation_RequiredFieldsPresent() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create user with valid data
                let user = User.create(
                    in: context,
                    role: Bool.random() ? .doctor : .patient,
                    iCloudSyncEnabled: Bool.random()
                )
                
                // Validate required fields are present
                XCTAssertNotNil(user.id,
                              "Iteration \(iteration): User ID should not be nil")
                XCTAssertNotNil(user.role,
                              "Iteration \(iteration): User role should not be nil")
                XCTAssertFalse(user.role?.isEmpty ?? true,
                             "Iteration \(iteration): User role should not be empty")
                XCTAssertNotNil(user.createdAt,
                              "Iteration \(iteration): User createdAt should not be nil")
                
                // Validate role is valid
                let validRoles = ["doctor", "patient"]
                XCTAssertTrue(validRoles.contains(user.role ?? ""),
                            "Iteration \(iteration): User role should be valid")
                
                // Save should succeed with valid data
                try saveContext()
                
                // Clean up
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): User validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "User validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any Patient entity, required fields must be present and valid before persistence
    /// This validates that Patient entities have all required fields with valid data
    func testProperty40_PatientValidation_RequiredFieldsValid() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create user first
                let user = User.create(in: context, role: .doctor)
                try saveContext()
                
                // Create patient with valid data
                let name = generateRandomString(length: Int.random(in: 1...100))
                let patientID = generateRandomString(length: Int.random(in: 1...50))
                
                let patient = Patient.create(
                    in: context,
                    name: name,
                    patientID: patientID,
                    user: user
                )
                
                // Validate required fields are present
                XCTAssertNotNil(patient.id,
                              "Iteration \(iteration): Patient ID should not be nil")
                XCTAssertNotNil(patient.name,
                              "Iteration \(iteration): Patient name should not be nil")
                XCTAssertFalse(patient.name?.isEmpty ?? true,
                             "Iteration \(iteration): Patient name should not be empty")
                XCTAssertNotNil(patient.patientID,
                              "Iteration \(iteration): Patient patientID should not be nil")
                XCTAssertFalse(patient.patientID?.isEmpty ?? true,
                             "Iteration \(iteration): Patient patientID should not be empty")
                XCTAssertNotNil(patient.createdAt,
                              "Iteration \(iteration): Patient createdAt should not be nil")
                
                // Validate name length is reasonable
                XCTAssertLessThanOrEqual(patient.name?.count ?? 0, 200,
                                       "Iteration \(iteration): Patient name should not exceed reasonable length")
                
                // Validate patientID length is reasonable
                XCTAssertLessThanOrEqual(patient.patientID.count, 100,
                                       "Iteration \(iteration): Patient ID should not exceed reasonable length")
                
                // Save should succeed with valid data
                try saveContext()
                
                // Clean up
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Patient validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any WoundRecord entity, required fields must be present and valid before persistence
    /// This validates that WoundRecord entities have all required fields with valid data
    func testProperty40_WoundRecordValidation_RequiredFieldsValid() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create user and patient first
                let user = User.create(in: context, role: .doctor)
                let patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: 10),
                    patientID: generateRandomString(length: 10),
                    user: user
                )
                try saveContext()
                
                // Create wound record with valid data
                let location = generateRandomString(length: Int.random(in: 1...200))
                let validStatuses = ["active", "healing", "healed", "archived"]
                let status = validStatuses.randomElement()!
                
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: location,
                    initialAssessmentDate: Date(),
                    status: status,
                    patient: patient
                )
                
                // Validate required fields are present
                XCTAssertNotNil(woundRecord.id,
                              "Iteration \(iteration): WoundRecord ID should not be nil")
                XCTAssertNotNil(woundRecord.location,
                              "Iteration \(iteration): WoundRecord location should not be nil")
                XCTAssertFalse(woundRecord.location?.isEmpty ?? true,
                             "Iteration \(iteration): WoundRecord location should not be empty")
                XCTAssertNotNil(woundRecord.initialAssessmentDate,
                              "Iteration \(iteration): WoundRecord initialAssessmentDate should not be nil")
                XCTAssertNotNil(woundRecord.status,
                              "Iteration \(iteration): WoundRecord status should not be nil")
                XCTAssertFalse(woundRecord.status?.isEmpty ?? true,
                             "Iteration \(iteration): WoundRecord status should not be empty")
                XCTAssertNotNil(woundRecord.lastUpdated,
                              "Iteration \(iteration): WoundRecord lastUpdated should not be nil")
                
                // Validate status is valid
                XCTAssertTrue(validStatuses.contains(woundRecord.status),
                            "Iteration \(iteration): WoundRecord status should be valid")
                
                // Validate location length is reasonable
                XCTAssertLessThanOrEqual(woundRecord.location.count, 500,
                                       "Iteration \(iteration): WoundRecord location should not exceed reasonable length")
                
                // Validate dates are reasonable
                XCTAssertLessThanOrEqual(woundRecord.initialAssessmentDate, Date(),
                                       "Iteration \(iteration): Initial assessment date should not be in the future")
                XCTAssertLessThanOrEqual(woundRecord.lastUpdated, Date().addingTimeInterval(1),
                                       "Iteration \(iteration): Last updated should not be in the future")
                
                // Save should succeed with valid data
                try saveContext()
                
                // Clean up
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): WoundRecord validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "WoundRecord validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any CaptureSession entity, required fields must be present and valid before persistence
    /// This validates that CaptureSession entities have all required fields with valid data
    func testProperty40_CaptureSessionValidation_RequiredFieldsValid() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create full hierarchy first
                let user = User.create(in: context, role: .doctor)
                let patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: 10),
                    patientID: generateRandomString(length: 10),
                    user: user
                )
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: generateRandomString(length: 20),
                    patient: patient
                )
                try saveContext()
                
                // Create capture session with valid data
                let photoPath = "photos/\(UUID().uuidString).heic"
                
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: photoPath,
                    woundRecord: woundRecord
                )
                
                // Validate required fields are present
                XCTAssertNotNil(captureSession.id,
                              "Iteration \(iteration): CaptureSession ID should not be nil")
                XCTAssertNotNil(captureSession.timestamp,
                              "Iteration \(iteration): CaptureSession timestamp should not be nil")
                XCTAssertNotNil(captureSession.photoPath,
                              "Iteration \(iteration): CaptureSession photoPath should not be nil")
                XCTAssertFalse(captureSession.photoPath?.isEmpty ?? true,
                             "Iteration \(iteration): CaptureSession photoPath should not be empty")
                
                // Validate photoPath format
                XCTAssertTrue(captureSession.photoPath?.contains(".") ?? false,
                            "Iteration \(iteration): Photo path should have a file extension")
                
                // Validate timestamp is reasonable
                XCTAssertLessThanOrEqual(captureSession.timestamp!, Date().addingTimeInterval(1),
                                       "Iteration \(iteration): Timestamp should not be in the future")
                
                // Validate location data consistency
                if captureSession.locationAvailable {
                    XCTAssertTrue(captureSession.latitude >= -90 && captureSession.latitude <= 90,
                                "Iteration \(iteration): Latitude should be valid")
                    XCTAssertTrue(captureSession.longitude >= -180 && captureSession.longitude <= 180,
                                "Iteration \(iteration): Longitude should be valid")
                }
                
                // Save should succeed with valid data
                try saveContext()
                
                // Clean up
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): CaptureSession validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "CaptureSession validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any Measurement entity, required fields must be present and valid before persistence
    /// This validates that Measurement entities have all required fields with valid data
    func testProperty40_MeasurementValidation_RequiredFieldsValid() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create full hierarchy first
                let user = User.create(in: context, role: .doctor)
                let patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: 10),
                    patientID: generateRandomString(length: 10),
                    user: user
                )
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: generateRandomString(length: 20),
                    patient: patient
                )
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: "photos/\(UUID().uuidString).heic",
                    woundRecord: woundRecord
                )
                try saveContext()
                
                // Create measurement with valid data
                let lengthMM = Double.random(in: 0.1...200.0)
                let widthMM = Double.random(in: 0.1...200.0)
                let areaMM2 = Double.random(in: 0.01...40000.0)
                let perimeterMM = Double.random(in: 0.4...800.0)
                let depthMM = Bool.random() ? Double.random(in: 0.0...50.0) : 0.0
                let volumeMM3 = depthMM > 0 ? Double.random(in: 0.0...200000.0) : 0.0
                let confidence = Float.random(in: 0.0...1.0)
                
                // Create dummy boundary points and calibration data
                let boundaryPoints = try! JSONEncoder().encode([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
                let calibrationData = try! JSONEncoder().encode(["pixelsPerMM": 1.0])
                
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
                    captureSession: captureSession
                )
                
                // Validate required fields are present
                XCTAssertNotNil(measurement.id,
                              "Iteration \(iteration): Measurement ID should not be nil")
                XCTAssertNotNil(measurement.boundaryPoints,
                              "Iteration \(iteration): Measurement boundaryPoints should not be nil")
                XCTAssertNotNil(measurement.calibrationData,
                              "Iteration \(iteration): Measurement calibrationData should not be nil")
                
                // Validate measurement values are non-negative
                XCTAssertGreaterThanOrEqual(measurement.lengthMM, 0,
                                          "Iteration \(iteration): Length should be non-negative")
                XCTAssertGreaterThanOrEqual(measurement.widthMM, 0,
                                          "Iteration \(iteration): Width should be non-negative")
                XCTAssertGreaterThanOrEqual(measurement.areaMM2, 0,
                                          "Iteration \(iteration): Area should be non-negative")
                XCTAssertGreaterThanOrEqual(measurement.perimeterMM, 0,
                                          "Iteration \(iteration): Perimeter should be non-negative")
                XCTAssertGreaterThanOrEqual(measurement.depthMM, 0,
                                          "Iteration \(iteration): Depth should be non-negative")
                XCTAssertGreaterThanOrEqual(measurement.volumeMM3, 0,
                                          "Iteration \(iteration): Volume should be non-negative")
                
                // Validate confidence is in valid range
                XCTAssertGreaterThanOrEqual(measurement.detectionConfidence, 0.0,
                                          "Iteration \(iteration): Confidence should be >= 0")
                XCTAssertLessThanOrEqual(measurement.detectionConfidence, 1.0,
                                       "Iteration \(iteration): Confidence should be <= 1")
                
                // Validate measurement values are reasonable
                XCTAssertLessThan(measurement.lengthMM, 1000.0,
                                "Iteration \(iteration): Length should be reasonable (<1000mm)")
                XCTAssertLessThan(measurement.widthMM, 1000.0,
                                "Iteration \(iteration): Width should be reasonable (<1000mm)")
                XCTAssertLessThan(measurement.areaMM2, 1000000.0,
                                "Iteration \(iteration): Area should be reasonable (<1000000mm²)")
                
                // Validate depth/volume consistency
                if measurement.depthMM == 0 {
                    XCTAssertEqual(measurement.volumeMM3, 0,
                                 "Iteration \(iteration): Volume should be 0 when depth is 0")
                }
                
                // Save should succeed with valid data
                try saveContext()
                
                // Clean up
                measurement.delete(from: context)
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Measurement validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Measurement validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any Note entity, required fields must be present and valid before persistence
    /// This validates that Note entities have all required fields with valid data
    func testProperty40_NoteValidation_RequiredFieldsValid() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create full hierarchy first
                let user = User.create(in: context, role: .doctor)
                let patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: 10),
                    patientID: generateRandomString(length: 10),
                    user: user
                )
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: generateRandomString(length: 20),
                    patient: patient
                )
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: "photos/\(UUID().uuidString).heic",
                    woundRecord: woundRecord
                )
                try saveContext()
                
                // Create note with valid data
                let text = generateRandomString(length: Int.random(in: 1...1000))
                let validCategories = ["improved", "unchanged", "worsened", "general"]
                let category = validCategories.randomElement()!
                
                let note = Note.create(
                    in: context,
                    text: text,
                    category: category,
                    captureSession: captureSession
                )
                
                // Validate required fields are present
                XCTAssertNotNil(note.id,
                              "Iteration \(iteration): Note ID should not be nil")
                XCTAssertNotNil(note.text,
                              "Iteration \(iteration): Note text should not be nil")
                XCTAssertFalse(note.text?.isEmpty ?? true,
                             "Iteration \(iteration): Note text should not be empty")
                XCTAssertNotNil(note.category,
                              "Iteration \(iteration): Note category should not be nil")
                XCTAssertFalse(note.category?.isEmpty ?? true,
                             "Iteration \(iteration): Note category should not be empty")
                XCTAssertNotNil(note.createdAt,
                              "Iteration \(iteration): Note createdAt should not be nil")
                
                // Validate category is valid
                XCTAssertTrue(validCategories.contains(note.category ?? ""),
                            "Iteration \(iteration): Note category should be valid")
                
                // Validate text length is reasonable
                XCTAssertLessThanOrEqual(note.text.count, 10000,
                                       "Iteration \(iteration): Note text should not exceed reasonable length")
                
                // Validate createdAt is reasonable
                XCTAssertLessThanOrEqual(note.createdAt, Date().addingTimeInterval(1),
                                       "Iteration \(iteration): Created date should not be in the future")
                
                // Save should succeed with valid data
                try saveContext()
                
                // Clean up
                note.delete(from: context)
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Note validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Note validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any entity with relationships, relationship integrity must be maintained
    /// This validates that relationships are properly validated before persistence
    func testProperty40_RelationshipIntegrity_IsValidated() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create entities with relationships
                let user = User.create(in: context, role: .doctor)
                let patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: 10),
                    patientID: generateRandomString(length: 10),
                    user: user
                )
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: generateRandomString(length: 20),
                    patient: patient
                )
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: "photos/\(UUID().uuidString).heic",
                    woundRecord: woundRecord
                )
                
                try saveContext()
                
                // Validate relationships are properly set
                XCTAssertNotNil(patient.user,
                              "Iteration \(iteration): Patient should have user relationship")
                XCTAssertEqual(patient.user?.id, user.id,
                             "Iteration \(iteration): Patient user relationship should match")
                
                XCTAssertNotNil(woundRecord.patient,
                              "Iteration \(iteration): WoundRecord should have patient relationship")
                XCTAssertEqual(woundRecord.patient?.id, patient.id,
                             "Iteration \(iteration): WoundRecord patient relationship should match")
                
                XCTAssertNotNil(captureSession.woundRecord,
                              "Iteration \(iteration): CaptureSession should have woundRecord relationship")
                XCTAssertEqual(captureSession.woundRecord?.id, woundRecord.id,
                             "Iteration \(iteration): CaptureSession woundRecord relationship should match")
                
                // Validate inverse relationships
                XCTAssertTrue(user.patientsArray.contains(where: { $0.id == patient.id }),
                            "Iteration \(iteration): User should have patient in inverse relationship")
                XCTAssertTrue(patient.woundRecordsArray.contains(where: { $0.id == woundRecord.id }),
                            "Iteration \(iteration): Patient should have woundRecord in inverse relationship")
                XCTAssertTrue(woundRecord.captureSessionsArray.contains(where: { $0.id == captureSession.id }),
                            "Iteration \(iteration): WoundRecord should have captureSession in inverse relationship")
                
                // Clean up
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Relationship integrity validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Relationship integrity validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any entity with date fields, dates should be validated as reasonable
    /// This validates that date fields contain reasonable values
    func testProperty40_DateValidation_IsReasonable() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create entities with date fields
                let user = User.create(in: context, role: .doctor)
                let patient = Patient.create(
                    in: context,
                    name: generateRandomString(length: 10),
                    patientID: generateRandomString(length: 10),
                    dateOfBirth: Date(timeIntervalSinceNow: -Double.random(in: 18...100) * 365 * 24 * 3600),
                    user: user
                )
                let woundRecord = WoundRecord.create(
                    in: context,
                    location: generateRandomString(length: 20),
                    initialAssessmentDate: Date(timeIntervalSinceNow: -Double.random(in: 0...365) * 24 * 3600),
                    patient: patient
                )
                let captureSession = CaptureSession.create(
                    in: context,
                    photoPath: "photos/\(UUID().uuidString).heic",
                    woundRecord: woundRecord
                )
                let note = Note.create(
                    in: context,
                    text: generateRandomString(length: 50),
                    captureSession: captureSession
                )
                
                try saveContext()
                
                let now = Date()
                let oneSecondFromNow = now.addingTimeInterval(1)
                let oneHundredYearsAgo = now.addingTimeInterval(-100 * 365 * 24 * 3600)
                
                // Validate user dates
                XCTAssertLessThanOrEqual(user.createdAt, oneSecondFromNow,
                                       "Iteration \(iteration): User createdAt should not be in the future")
                XCTAssertGreaterThan(user.createdAt, oneHundredYearsAgo,
                                   "Iteration \(iteration): User createdAt should be reasonable")
                
                // Validate patient dates
                XCTAssertLessThanOrEqual(patient.createdAt, oneSecondFromNow,
                                       "Iteration \(iteration): Patient createdAt should not be in the future")
                if let dob = patient.dateOfBirth {
                    XCTAssertLessThanOrEqual(dob, now,
                                           "Iteration \(iteration): Patient dateOfBirth should not be in the future")
                    XCTAssertGreaterThan(dob, oneHundredYearsAgo,
                                       "Iteration \(iteration): Patient dateOfBirth should be reasonable")
                }
                
                // Validate wound record dates
                XCTAssertLessThanOrEqual(woundRecord.initialAssessmentDate, oneSecondFromNow,
                                       "Iteration \(iteration): Initial assessment date should not be in the future")
                XCTAssertLessThanOrEqual(woundRecord.lastUpdated, oneSecondFromNow,
                                       "Iteration \(iteration): Last updated should not be in the future")
                XCTAssertGreaterThanOrEqual(woundRecord.lastUpdated, woundRecord.initialAssessmentDate,
                                          "Iteration \(iteration): Last updated should be >= initial assessment")
                
                // Validate capture session dates
                guard let captureTimestamp = captureSession.timestamp,
                      let initialAssessmentDate = woundRecord.initialAssessmentDate,
                      let noteCreatedAt = note.createdAt else {
                    XCTFail("Iteration \(iteration): Required dates should not be nil")
                    failedCases.append(iteration)
                    continue
                }
                
                XCTAssertLessThanOrEqual(captureTimestamp, oneSecondFromNow,
                                       "Iteration \(iteration): Capture timestamp should not be in the future")
                XCTAssertGreaterThanOrEqual(captureTimestamp, initialAssessmentDate,
                                          "Iteration \(iteration): Capture timestamp should be >= wound initial assessment")
                
                // Validate note dates
                XCTAssertLessThanOrEqual(noteCreatedAt, oneSecondFromNow,
                                       "Iteration \(iteration): Note createdAt should not be in the future")
                XCTAssertGreaterThanOrEqual(noteCreatedAt, captureTimestamp,
                                          "Iteration \(iteration): Note createdAt should be >= capture timestamp")
                
                // Clean up
                note.delete(from: context)
                captureSession.delete(from: context)
                woundRecord.delete(from: context)
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Date validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Date validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any entity, UUID fields should be unique
    /// This validates that UUID fields are properly generated and unique
    func testProperty40_UUIDUniqueness_IsEnforced() throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create multiple entities of the same type
                let entityCount = Int.random(in: 10...50)
                var userIDs: Set<UUID> = []
                var patientIDs: Set<UUID> = []
                var woundRecordIDs: Set<UUID> = []
                
                let user = User.create(in: context, role: .doctor)
                if let userId = user.id {
                    userIDs.insert(userId)
                }
                
                for _ in 0..<entityCount {
                    let patient = Patient.create(
                        in: context,
                        name: generateRandomString(length: 10),
                        patientID: generateRandomString(length: 10),
                        user: user
                    )
                    if let patientId = patient.id {
                        patientIDs.insert(patientId)
                    }
                    
                    let woundRecord = WoundRecord.create(
                        in: context,
                        location: generateRandomString(length: 20),
                        patient: patient
                    )
                    if let woundRecordId = woundRecord.id {
                        woundRecordIDs.insert(woundRecordId)
                    }
                }
                
                try saveContext()
                
                // Validate all UUIDs are unique
                XCTAssertEqual(userIDs.count, 1,
                             "Iteration \(iteration): User ID should be unique")
                XCTAssertEqual(patientIDs.count, entityCount,
                             "Iteration \(iteration): All patient IDs should be unique")
                XCTAssertEqual(woundRecordIDs.count, entityCount,
                             "Iteration \(iteration): All wound record IDs should be unique")
                
                // Validate no overlap between different entity types
                let allIDs = userIDs.union(patientIDs).union(woundRecordIDs)
                XCTAssertEqual(allIDs.count, 1 + entityCount + entityCount,
                             "Iteration \(iteration): All IDs across entity types should be unique")
                
                // Clean up
                let allPatients = Patient.fetchAll(in: context)
                let allWoundRecords = WoundRecord.fetchAll(in: context)
                for woundRecord in allWoundRecords {
                    woundRecord.delete(from: context)
                }
                for patient in allPatients {
                    patient.delete(from: context)
                }
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): UUID uniqueness validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "UUID uniqueness validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any entity with string fields, string encoding should be preserved
    /// This validates that string data (including unicode) is properly validated and preserved
    func testProperty40_StringEncoding_IsPreserved() throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create entities with various string encodings
                let unicodeNames = [
                    "田中太郎",
                    "José García",
                    "Müller",
                    "Владимир",
                    "محمد",
                    "🏥 Hospital",
                    "Test\nNewline",
                    "Test\tTab",
                    "Test\"Quote",
                    "Test'Apostrophe"
                ]
                
                let user = User.create(in: context, role: .doctor)
                let name = unicodeNames.randomElement()!
                let patient = Patient.create(
                    in: context,
                    name: name,
                    patientID: generateRandomString(length: 10),
                    notes: unicodeNames.randomElement(),
                    user: user
                )
                
                try saveContext()
                
                // Validate string encoding is preserved
                XCTAssertEqual(patient.name, name,
                             "Iteration \(iteration): Patient name encoding should be preserved")
                
                // Fetch and verify again
                guard let patientId = patient.id else {
                    XCTFail("Iteration \(iteration): Patient ID should not be nil")
                    failedCases.append(iteration)
                    continue
                }
                let fetchedPatient = Patient.fetchPatient(byID: patientId, in: context)
                XCTAssertEqual(fetchedPatient?.name, name,
                             "Iteration \(iteration): Fetched patient name encoding should be preserved")
                
                // Clean up
                patient.delete(from: context)
                user.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): String encoding validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "String encoding validation property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
