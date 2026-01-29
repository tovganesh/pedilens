//
//  ExportPackageCreationPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for export package creation
//  Feature: pedilens, Property 23: Export Package Creation
//  Validates: Requirements 7.1, 7.5
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for export package creation
/// These tests validate that export packages contain all selected data
final class ExportPackageCreationPropertyTests: XCTestCase {
    
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
        exportManager = nil
        fileStorageManager = nil
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
            "Right foot, dorsal surface",
            "Left ankle",
            "Right ankle"
        ]
        return locations.randomElement()!
    }
    
    /// Saves context and handles errors
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    /// Creates a test wound record with capture sessions
    private func createTestWoundRecord(
        sessionCount: Int,
        includeMeasurements: Bool,
        includeNotes: Bool
    ) throws -> WoundRecord {
        // Create user and patient
        let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
        let patient = Patient.create(
            in: context,
            name: generateRandomPatientName(),
            patientID: generateRandomString(length: 10),
            user: user
        )
        
        // Create wound record
        let woundRecord = WoundRecord.create(
            in: context,
            location: generateRandomWoundLocation(),
            initialAssessmentDate: Date(timeIntervalSinceNow: -Double.random(in: 0...365) * 24 * 3600),
            status: ["active", "healing", "healed"].randomElement()!,
            patient: patient
        )
        
        // Create capture sessions
        for _ in 0..<sessionCount {
            let photoPath = "photos/\(UUID().uuidString).heic"
            let captureSession = CaptureSession.create(
                in: context,
                photoPath: photoPath,
                woundRecord: woundRecord
            )
            
            // Add measurement if requested
            if includeMeasurements {
                let boundaryPoints = try JSONEncoder().encode([
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: 10, y: 10),
                    CGPoint(x: 10, y: 0)
                ])
                let calibrationData = try JSONEncoder().encode(["pixelsPerMM": 1.0])
                
                _ = Measurement.create(
                    in: context,
                    lengthMM: Double.random(in: 5.0...100.0),
                    widthMM: Double.random(in: 5.0...100.0),
                    areaMM2: Double.random(in: 25.0...10000.0),
                    perimeterMM: Double.random(in: 20.0...400.0),
                    boundaryPoints: boundaryPoints,
                    calibrationData: calibrationData,
                    detectionConfidence: Float.random(in: 0.5...1.0),
                    captureSession: captureSession
                )
            }
            
            // Add notes if requested
            if includeNotes {
                let noteCount = Int.random(in: 0...3)
                for _ in 0..<noteCount {
                    _ = Note.create(
                        in: context,
                        text: generateRandomString(length: Int.random(in: 10...50)),
                        category: ["improved", "unchanged", "worsened", "general"].randomElement()!,
                        captureSession: captureSession
                    )
                }
            }
        }
        
        try saveContext()
        return woundRecord
    }
    
    /// Cleans up test export directory
    private func cleanupExport(_ package: ExportPackage) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: package.fileURL.path) {
            try? fileManager.removeItem(at: package.fileURL)
        }
    }
    
    // MARK: - Property 23: Export Package Creation
    // **Validates: Requirements 7.1, 7.5**
    
    /// Property: For any export request, an export package should be created containing
    /// all selected photos, measurements, metadata, and a summary report with wound progression statistics
    func testProperty23_ExportPackageContainsAllSelectedData() async throws {
        let iterations = 100
        var failedCases: [(format: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            do {
                // Generate random export parameters
                let sessionCount = Int.random(in: 1...5)
                let includeMeasurements = Bool.random()
                let includeNotes = Bool.random()
                let includePhotos = Bool.random()
                let anonymize = Bool.random()
                
                // Create test wound record
                let woundRecord = try createTestWoundRecord(
                    sessionCount: sessionCount,
                    includeMeasurements: includeMeasurements,
                    includeNotes: includeNotes
                )
                
                // Test each export format
                let formats: [ExportFormat] = [.pdf, .images, .native]
                let format = formats.randomElement()!
                
                let options = ExportOptions(
                    includePhotos: includePhotos,
                    includeMeasurements: includeMeasurements,
                    includeNotes: includeNotes,
                    anonymize: anonymize,
                    dateRange: nil
                )
                
                // Create export package
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: format,
                    options: options
                )
                
                // Verify export package was created
                XCTAssertNotNil(package.id,
                              "Iteration \(iteration): Export package should have an ID")
                
                XCTAssertEqual(package.format, format,
                             "Iteration \(iteration): Export format should match requested format")
                
                // Verify file exists
                let fileManager = FileManager.default
                XCTAssertTrue(fileManager.fileExists(atPath: package.fileURL.path),
                            "Iteration \(iteration): Export file should exist at \(package.fileURL.path)")
                
                // Verify metadata
                XCTAssertEqual(package.metadata.recordCount, 1,
                             "Iteration \(iteration): Metadata should show 1 record")
                
                XCTAssertEqual(package.metadata.sessionCount, sessionCount,
                             "Iteration \(iteration): Metadata should show \(sessionCount) sessions")
                
                XCTAssertEqual(package.metadata.isAnonymized, anonymize,
                             "Iteration \(iteration): Metadata anonymization flag should match option")
                
                // Verify summary report exists (for PDF and native formats)
                if format == .pdf {
                    // For PDF, the report.pdf file should exist
                    let pdfURL = package.fileURL
                    let summaryExists = fileManager.fileExists(atPath: pdfURL.path)
                    
                    XCTAssertTrue(summaryExists,
                                "Iteration \(iteration): PDF report should exist for format \(format)")
                } else if format == .native {
                    // For native, the export.json file should exist
                    let jsonURL = package.fileURL.appendingPathComponent("export.json")
                    let summaryExists = fileManager.fileExists(atPath: jsonURL.path)
                    
                    XCTAssertTrue(summaryExists,
                                "Iteration \(iteration): Summary report should exist for format \(format)")
                }
                
                // Verify wound progression statistics are included in metadata
                XCTAssertNotNil(package.metadata.dateRange,
                              "Iteration \(iteration): Date range should be calculated")
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Export package creation failed with error: \(error)")
                failedCases.append((format: "unknown", iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Export package creation property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any export with photos included, the export package should contain all photo files
    func testProperty23_ExportPackageContainsPhotosWhenRequested() async throws {
        let iterations = 50
        var failedCases: [(sessionCount: Int, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            do {
                let sessionCount = Int.random(in: 1...5)
                
                // Create test wound record
                let woundRecord = try createTestWoundRecord(
                    sessionCount: sessionCount,
                    includeMeasurements: true,
                    includeNotes: true
                )
                
                // Create export with photos included
                let options = ExportOptions(
                    includePhotos: true,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false,
                    dateRange: nil
                )
                
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Verify photos directory exists
                let photosDir = package.fileURL.appendingPathComponent("photos")
                let fileManager = FileManager.default
                
                XCTAssertTrue(fileManager.fileExists(atPath: photosDir.path),
                            "Iteration \(iteration): Photos directory should exist")
                
                // Count photo files
                let photoFiles = try fileManager.contentsOfDirectory(at: photosDir, includingPropertiesForKeys: nil)
                
                XCTAssertEqual(photoFiles.count, sessionCount,
                             "Iteration \(iteration): Should have \(sessionCount) photo files, found \(photoFiles.count)")
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Photo export test failed with error: \(error)")
                failedCases.append((sessionCount: 0, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Photo export property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any export with measurements included, the export package should contain measurement data
    func testProperty23_ExportPackageContainsMeasurementsWhenRequested() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create test wound record with measurements
                let woundRecord = try createTestWoundRecord(
                    sessionCount: Int.random(in: 1...3),
                    includeMeasurements: true,
                    includeNotes: false
                )
                
                // Create export with measurements included
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: false,
                    anonymize: false,
                    dateRange: nil
                )
                
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Read the export JSON
                let jsonURL = package.fileURL.appendingPathComponent("export.json")
                let jsonData = try Data(contentsOf: jsonURL)
                let exportDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
                
                // Verify measurements are included
                let records = exportDict["records"] as! [[String: Any]]
                XCTAssertFalse(records.isEmpty,
                             "Iteration \(iteration): Export should contain records")
                
                for record in records {
                    let sessions = record["sessions"] as! [[String: Any]]
                    for session in sessions {
                        XCTAssertNotNil(session["measurement"],
                                      "Iteration \(iteration): Session should contain measurement data")
                    }
                }
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Measurement export test failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Measurement export property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any export with date range filter, only sessions within the range should be included
    func testProperty23_ExportPackageRespectsDateRangeFilter() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create wound record with sessions at different times
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
                
                // Create sessions at different dates
                let now = Date()
                let dates = [
                    now.addingTimeInterval(-10 * 24 * 3600), // 10 days ago
                    now.addingTimeInterval(-5 * 24 * 3600),  // 5 days ago
                    now.addingTimeInterval(-2 * 24 * 3600),  // 2 days ago
                    now                                       // today
                ]
                
                for date in dates {
                    let session = CaptureSession.create(
                        in: context,
                        photoPath: "photos/\(UUID().uuidString).heic",
                        woundRecord: woundRecord
                    )
                    session.timestamp = date
                }
                
                try saveContext()
                
                // Create export with date range filter (last 7 days)
                let startDate = now.addingTimeInterval(-7 * 24 * 3600)
                let dateRange = DateInterval(start: startDate, end: now)
                
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: false,
                    includeNotes: false,
                    anonymize: false,
                    dateRange: dateRange
                )
                
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Verify only sessions within date range are included
                // Should include: 5 days ago, 2 days ago, today (3 sessions)
                // Should exclude: 10 days ago (1 session)
                XCTAssertEqual(package.metadata.sessionCount, 3,
                             "Iteration \(iteration): Should include 3 sessions within date range")
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Date range filter test failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Date range filter property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
