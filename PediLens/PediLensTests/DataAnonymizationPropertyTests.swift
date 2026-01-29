//
//  DataAnonymizationPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for data anonymization
//  Feature: pedilens, Property 27: Data Anonymization Option
//  Validates: Requirements 9.3
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for data anonymization
/// These tests validate that patient identifiable information can be anonymized in exports
final class DataAnonymizationPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var exportManager: ExportManager!
    var fileStorageManager: FileStorageManager!
    
    override func setUp() {
        super.setUp()
        // Use in-memory store for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        fileStorageManager = FileStorageManager.shared
        exportManager = ExportManager(
            fileStorageManager: fileStorageManager,
            persistenceController: persistenceController
        )
    }
    
    override func tearDown() {
        // Clean up context
        if let context = context {
            context.reset()
        }
        exportManager = nil
        fileStorageManager = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    /// Resets the context to prevent memory buildup
    private func resetContext() {
        context.reset()
        // Process pending changes
        context.processPendingChanges()
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
    
    /// Creates a test wound record with patient data
    private func createTestWoundRecord() throws -> (WoundRecord, String, String, String) {
        // Create user and patient
        let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
        let patientName = generateRandomPatientName()
        let patientID = generateRandomString(length: 10)
        let patient = Patient.create(
            in: context,
            name: patientName,
            patientID: patientID,
            user: user
        )
        
        // Create wound record
        let woundLocation = generateRandomWoundLocation()
        let woundRecord = WoundRecord.create(
            in: context,
            location: woundLocation,
            initialAssessmentDate: Date(timeIntervalSinceNow: -Double.random(in: 0...365) * 24 * 3600),
            status: ["active", "healing", "healed"].randomElement()!,
            patient: patient
        )
        
        // Create a capture session
        let photoPath = "photos/\(UUID().uuidString).heic"
        _ = CaptureSession.create(
            in: context,
            photoPath: photoPath,
            woundRecord: woundRecord
        )
        
        try saveContext()
        return (woundRecord, patientName, patientID, woundLocation)
    }
    
    /// Cleans up test export directory
    private func cleanupExport(_ package: ExportPackage) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: package.fileURL.path) {
            try? fileManager.removeItem(at: package.fileURL)
        }
    }
    
    // MARK: - Property 27: Data Anonymization Option
    // **Validates: Requirements 9.3**
    
    /// Property: For any export containing patient identifiable information,
    /// an anonymization option should be available
    func testProperty27_AnonymizationOptionAvailable() async throws {
        let iterations = 50  // Reduced from 100 to prevent Core Data overload
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Reset context every 10 iterations to prevent memory buildup
            if iteration > 0 && iteration % 10 == 0 {
                resetContext()
            }
            
            do {
                // Create test wound record with patient data
                let (woundRecord, patientName, patientID, woundLocation) = try createTestWoundRecord()
                
                // Test both anonymized and non-anonymized exports
                let anonymize = Bool.random()
                
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: anonymize,
                    dateRange: nil
                )
                
                // Create native format export (easiest to verify)
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Verify metadata reflects anonymization setting
                XCTAssertEqual(package.metadata.isAnonymized, anonymize,
                             "Iteration \(iteration): Metadata should reflect anonymization setting")
                
                // Read the export JSON
                let jsonURL = package.fileURL.appendingPathComponent("export.json")
                let jsonData = try Data(contentsOf: jsonURL)
                let exportDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
                
                // Verify anonymization flag in JSON
                let isAnonymized = exportDict["isAnonymized"] as? Bool ?? false
                XCTAssertEqual(isAnonymized, anonymize,
                             "Iteration \(iteration): JSON should reflect anonymization setting")
                
                // Verify patient data is removed when anonymized
                let records = exportDict["records"] as! [[String: Any]]
                for record in records {
                    if anonymize {
                        // Patient info should not be present
                        XCTAssertNil(record["patient"],
                                   "Iteration \(iteration): Patient info should be removed when anonymized")
                        
                        // Location should be anonymized
                        let location = record["location"] as? String ?? ""
                        XCTAssertEqual(location, "Anonymized",
                                     "Iteration \(iteration): Location should be anonymized")
                    } else {
                        // Patient info should be present
                        XCTAssertNotNil(record["patient"],
                                      "Iteration \(iteration): Patient info should be present when not anonymized")
                        
                        // Location should be original
                        let location = record["location"] as? String ?? ""
                        XCTAssertNotEqual(location, "Anonymized",
                                        "Iteration \(iteration): Location should not be anonymized")
                    }
                }
                
                // Clean up
                cleanupExport(package)
                
                // Delete entities and save immediately
                if let patient = woundRecord.patient {
                    context.delete(patient)
                }
                context.delete(woundRecord)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Anonymization test failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Anonymization option property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any anonymized export, patient names should be removed
    func testProperty27_PatientNamesRemovedWhenAnonymized() async throws {
        let iterations = 50  // Reduced from 100 to prevent Core Data overload
        var failedCases: [(name: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Reset context every 10 iterations to prevent memory buildup
            if iteration > 0 && iteration % 10 == 0 {
                resetContext()
            }
            
            do {
                // Create test wound record with patient data
                let (woundRecord, patientName, _, _) = try createTestWoundRecord()
                
                // Create anonymized export
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: true,
                    dateRange: nil
                )
                
                // Create native format export
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Read the export JSON
                let jsonURL = package.fileURL.appendingPathComponent("export.json")
                let jsonData = try Data(contentsOf: jsonURL)
                let exportDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
                
                // Convert to string to search for patient name
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                
                // Verify patient name is not in the export
                XCTAssertFalse(jsonString.contains(patientName),
                             "Iteration \(iteration): Patient name '\(patientName)' should not appear in anonymized export")
                
                // Clean up
                cleanupExport(package)
                
                // Delete entities and save immediately
                if let patient = woundRecord.patient {
                    context.delete(patient)
                }
                context.delete(woundRecord)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Patient name removal test failed with error: \(error)")
                failedCases.append((name: "", iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient name removal property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any anonymized export, patient IDs should be removed
    func testProperty27_PatientIDsRemovedWhenAnonymized() async throws {
        let iterations = 50  // Reduced from 100 to prevent Core Data overload
        var failedCases: [(id: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            // Reset context every 10 iterations to prevent memory buildup
            if iteration > 0 && iteration % 10 == 0 {
                resetContext()
            }
            
            do {
                // Create test wound record with patient data
                let (woundRecord, _, patientID, _) = try createTestWoundRecord()
                
                // Create anonymized export
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: true,
                    dateRange: nil
                )
                
                // Create native format export
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Read the export JSON
                let jsonURL = package.fileURL.appendingPathComponent("export.json")
                let jsonData = try Data(contentsOf: jsonURL)
                let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
                
                // Verify patient ID is not in the export
                XCTAssertFalse(jsonString.contains(patientID),
                             "Iteration \(iteration): Patient ID '\(patientID)' should not appear in anonymized export")
                
                // Clean up
                cleanupExport(package)
                
                // Delete entities and save immediately
                if let patient = woundRecord.patient {
                    context.delete(patient)
                }
                context.delete(woundRecord)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Patient ID removal test failed with error: \(error)")
                failedCases.append((id: "", iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient ID removal property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any non-anonymized export, patient data should be preserved
    func testProperty27_PatientDataPreservedWhenNotAnonymized() async throws {
        let iterations = 50  // Reduced from 100 to prevent Core Data overload
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Reset context every 10 iterations to prevent memory buildup
            if iteration > 0 && iteration % 10 == 0 {
                resetContext()
            }
            
            do {
                // Create test wound record with patient data
                let (woundRecord, patientName, patientID, _) = try createTestWoundRecord()
                
                // Create non-anonymized export
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false,
                    dateRange: nil
                )
                
                // Create native format export
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Read the export JSON
                let jsonURL = package.fileURL.appendingPathComponent("export.json")
                let jsonData = try Data(contentsOf: jsonURL)
                let exportDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
                
                // Verify patient data is present
                let records = exportDict["records"] as! [[String: Any]]
                for record in records {
                    let patientDict = record["patient"] as? [String: Any]
                    XCTAssertNotNil(patientDict,
                                  "Iteration \(iteration): Patient data should be present in non-anonymized export")
                    
                    if let patientDict = patientDict {
                        let name = patientDict["name"] as? String ?? ""
                        let id = patientDict["patientID"] as? String ?? ""
                        
                        XCTAssertEqual(name, patientName,
                                     "Iteration \(iteration): Patient name should match original")
                        XCTAssertEqual(id, patientID,
                                     "Iteration \(iteration): Patient ID should match original")
                    }
                }
                
                // Clean up
                cleanupExport(package)
                
                // Delete entities and save immediately
                if let patient = woundRecord.patient {
                    context.delete(patient)
                }
                context.delete(woundRecord)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Patient data preservation test failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient data preservation property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
