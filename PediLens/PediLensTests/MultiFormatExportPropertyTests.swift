//
//  MultiFormatExportPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for multi-format export support
//  Feature: pedilens, Property 24: Multi-Format Export Support
//  Validates: Requirements 7.2
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for multi-format export support
/// These tests validate that the system supports generating exports in all requested formats
final class MultiFormatExportPropertyTests: XCTestCase {
    
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
    
    /// Creates a test wound record with capture sessions
    private func createTestWoundRecord() throws -> WoundRecord {
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
        
        // Create a capture session
        let photoPath = "photos/\(UUID().uuidString).heic"
        _ = CaptureSession.create(
            in: context,
            photoPath: photoPath,
            woundRecord: woundRecord
        )
        
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
    
    // MARK: - Property 24: Multi-Format Export Support
    // **Validates: Requirements 7.2**
    
    /// Property: For any export package creation, the system should support generating
    /// the requested format (PDF, images, or native format)
    func testProperty24_AllExportFormatsSupported() async throws {
        let iterations = 100
        var failedCases: [(format: String, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            do {
                // Create test wound record
                let woundRecord = try createTestWoundRecord()
                
                // Test each export format
                let formats: [ExportFormat] = [.pdf, .images, .native]
                let format = formats.randomElement()!
                
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false,
                    dateRange: nil
                )
                
                // Create export package
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: format,
                    options: options
                )
                
                // Verify export package was created with correct format
                XCTAssertEqual(package.format, format,
                             "Iteration \(iteration): Export format should match requested format")
                
                // Verify file exists
                let fileManager = FileManager.default
                XCTAssertTrue(fileManager.fileExists(atPath: package.fileURL.path),
                            "Iteration \(iteration): Export file should exist for format \(format)")
                
                // Verify format-specific characteristics
                switch format {
                case .pdf:
                    // PDF should be a single file
                    XCTAssertTrue(package.fileURL.pathExtension == "pdf" || package.fileURL.lastPathComponent.contains("pdf"),
                                "Iteration \(iteration): PDF export should contain PDF file")
                    
                case .images:
                    // Images export should be a directory
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: package.fileURL.path, isDirectory: &isDirectory)
                    XCTAssertTrue(isDirectory.boolValue,
                                "Iteration \(iteration): Images export should be a directory")
                    
                    // Should contain a manifest file
                    let manifestURL = package.fileURL.appendingPathComponent("manifest.txt")
                    XCTAssertTrue(fileManager.fileExists(atPath: manifestURL.path),
                                "Iteration \(iteration): Images export should contain manifest")
                    
                case .native:
                    // Native export should be a directory with export.json
                    var isDirectory: ObjCBool = false
                    fileManager.fileExists(atPath: package.fileURL.path, isDirectory: &isDirectory)
                    XCTAssertTrue(isDirectory.boolValue,
                                "Iteration \(iteration): Native export should be a directory")
                    
                    let jsonURL = package.fileURL.appendingPathComponent("export.json")
                    XCTAssertTrue(fileManager.fileExists(atPath: jsonURL.path),
                                "Iteration \(iteration): Native export should contain export.json")
                }
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                let formatName: String
                switch iteration % 3 {
                case 0: formatName = "pdf"
                case 1: formatName = "images"
                default: formatName = "native"
                }
                XCTFail("Iteration \(iteration): Export failed for format \(formatName) with error: \(error)")
                failedCases.append((format: formatName, iteration: iteration))
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Multi-format export property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any PDF export request, a PDF file should be generated
    func testProperty24_PDFFormatGeneratesPDF() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create test wound record
                let woundRecord = try createTestWoundRecord()
                
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false,
                    dateRange: nil
                )
                
                // Create PDF export
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .pdf,
                    options: options
                )
                
                // Verify it's a PDF format
                XCTAssertEqual(package.format, .pdf,
                             "Iteration \(iteration): Package format should be PDF")
                
                // Verify PDF file exists
                let fileManager = FileManager.default
                XCTAssertTrue(fileManager.fileExists(atPath: package.fileURL.path),
                            "Iteration \(iteration): PDF file should exist")
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): PDF export failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "PDF export property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any images export request, a directory with image files should be generated
    func testProperty24_ImagesFormatGeneratesImageDirectory() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create test wound record
                let woundRecord = try createTestWoundRecord()
                
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false,
                    dateRange: nil
                )
                
                // Create images export
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .images,
                    options: options
                )
                
                // Verify it's an images format
                XCTAssertEqual(package.format, .images,
                             "Iteration \(iteration): Package format should be images")
                
                // Verify directory exists
                let fileManager = FileManager.default
                var isDirectory: ObjCBool = false
                XCTAssertTrue(fileManager.fileExists(atPath: package.fileURL.path, isDirectory: &isDirectory),
                            "Iteration \(iteration): Export directory should exist")
                XCTAssertTrue(isDirectory.boolValue,
                            "Iteration \(iteration): Export should be a directory")
                
                // Verify manifest exists
                let manifestURL = package.fileURL.appendingPathComponent("manifest.txt")
                XCTAssertTrue(fileManager.fileExists(atPath: manifestURL.path),
                            "Iteration \(iteration): Manifest file should exist")
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Images export failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Images export property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any native format export request, a JSON file with structured data should be generated
    func testProperty24_NativeFormatGeneratesJSON() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create test wound record
                let woundRecord = try createTestWoundRecord()
                
                let options = ExportOptions(
                    includePhotos: false,
                    includeMeasurements: true,
                    includeNotes: true,
                    anonymize: false,
                    dateRange: nil
                )
                
                // Create native export
                let package = try await exportManager.createExport(
                    for: [woundRecord],
                    format: .native,
                    options: options
                )
                
                // Verify it's a native format
                XCTAssertEqual(package.format, .native,
                             "Iteration \(iteration): Package format should be native")
                
                // Verify JSON file exists
                let fileManager = FileManager.default
                let jsonURL = package.fileURL.appendingPathComponent("export.json")
                XCTAssertTrue(fileManager.fileExists(atPath: jsonURL.path),
                            "Iteration \(iteration): export.json file should exist")
                
                // Verify JSON is valid
                let jsonData = try Data(contentsOf: jsonURL)
                let exportDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                XCTAssertNotNil(exportDict,
                              "Iteration \(iteration): export.json should contain valid JSON")
                
                // Verify JSON structure
                XCTAssertNotNil(exportDict?["version"],
                              "Iteration \(iteration): JSON should have version field")
                XCTAssertNotNil(exportDict?["records"],
                              "Iteration \(iteration): JSON should have records field")
                
                // Clean up
                cleanupExport(package)
                woundRecord.delete(from: context)
                try saveContext()
                
            } catch {
                XCTFail("Iteration \(iteration): Native export failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Native export property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
