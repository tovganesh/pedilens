//
//  DataIntegrityPropertyTests.swift
//  PediLensTests
//
//  Property 41: Data Integrity Checksums
//  Validates: Requirements 14.3
//

import XCTest
@testable import PediLens

class DataIntegrityPropertyTests: XCTestCase {
    
    var integrityManager: DataIntegrityManager!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        integrityManager = DataIntegrityManager.shared
        
        // Create test directory
        let tempDir = FileManager.default.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent("DataIntegrityTests_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }
    
    // MARK: - Property 41: Data Integrity Checksums
    
    /// **Property 41: Data Integrity Checksums**
    /// *For any* photo or metadata file stored, a checksum SHALL be maintained for integrity verification.
    /// **Validates: Requirements 14.3**
    func testDataIntegrityChecksums() {
        // Test with 100 random file scenarios
        for iteration in 0..<100 {
            // Generate random file data
            let fileSize = Int.random(in: 100...10000)
            var fileData = Data(count: fileSize)
            _ = fileData.withUnsafeMutableBytes { bytes in
                SecRandomCopyBytes(kSecRandomDefault, fileSize, bytes.baseAddress!)
            }
            
            // Create test file
            let fileName = "test_file_\(iteration).dat"
            let fileURL = testDirectory.appendingPathComponent(fileName)
            
            do {
                try fileData.write(to: fileURL)
                
                // Generate checksum
                let checksum = try integrityManager.generateChecksum(for: fileURL)
                
                // Wait for async save to complete
                Thread.sleep(forTimeInterval: 0.1)
                
                // Verify checksum exists and is not empty
                XCTAssertFalse(checksum.isEmpty, "Checksum should not be empty (iteration \(iteration))")
                XCTAssertEqual(checksum.count, 64, "SHA-256 checksum should be 64 characters (iteration \(iteration))")
                
                // Verify integrity immediately
                let isValid = try integrityManager.verifyIntegrity(for: fileURL)
                XCTAssertTrue(isValid, "File should pass integrity check immediately after checksum generation (iteration \(iteration))")
                
                // Verify checksum entry was stored
                let entry = integrityManager.getChecksumEntry(for: fileURL)
                XCTAssertNotNil(entry, "Checksum entry should be stored (iteration \(iteration))")
                XCTAssertEqual(entry?.checksum, checksum, "Stored checksum should match generated checksum (iteration \(iteration))")
                XCTAssertEqual(entry?.algorithm, "SHA-256", "Algorithm should be SHA-256 (iteration \(iteration))")
                XCTAssertEqual(entry?.fileSize, Int64(fileSize), "File size should match (iteration \(iteration))")
                
                // Clean up
                integrityManager.removeChecksum(for: fileURL)
                try? FileManager.default.removeItem(at: fileURL)
                
            } catch {
                XCTFail("Failed to test checksum for iteration \(iteration): \(error)")
            }
        }
    }
    
    /// Test checksum detects file corruption
    func testChecksumDetectsCorruption() {
        // Test with 50 random corruption scenarios
        for iteration in 0..<50 {
            // Generate random file data
            let fileSize = Int.random(in: 1000...5000)
            var fileData = Data(count: fileSize)
            _ = fileData.withUnsafeMutableBytes { bytes in
                SecRandomCopyBytes(kSecRandomDefault, fileSize, bytes.baseAddress!)
            }
            
            // Create test file
            let fileName = "corruption_test_\(iteration).dat"
            let fileURL = testDirectory.appendingPathComponent(fileName)
            
            do {
                try fileData.write(to: fileURL)
                
                // Generate checksum
                _ = try integrityManager.generateChecksum(for: fileURL)
                
                // Corrupt the file by modifying a random byte
                var corruptedData = fileData
                let corruptionIndex = Int.random(in: 0..<fileSize)
                corruptedData[corruptionIndex] = corruptedData[corruptionIndex] ^ 0xFF
                try corruptedData.write(to: fileURL)
                
                // Verify integrity should fail
                let isValid = try integrityManager.verifyIntegrity(for: fileURL)
                XCTAssertFalse(isValid, "Corrupted file should fail integrity check (iteration \(iteration))")
                
                // Clean up
                integrityManager.removeChecksum(for: fileURL)
                try? FileManager.default.removeItem(at: fileURL)
                
            } catch DataIntegrityError.checksumMismatch {
                // Expected error - this is actually a success case
                integrityManager.removeChecksum(for: fileURL)
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                XCTFail("Unexpected error for iteration \(iteration): \(error)")
            }
        }
    }
    
    /// Test checksum persistence across app restarts
    func testChecksumPersistence() {
        // Create multiple test files
        var fileURLs: [URL] = []
        var expectedChecksums: [String: String] = [:]
        
        for i in 0..<20 {
            let fileSize = Int.random(in: 500...2000)
            var fileData = Data(count: fileSize)
            _ = fileData.withUnsafeMutableBytes { bytes in
                SecRandomCopyBytes(kSecRandomDefault, fileSize, bytes.baseAddress!)
            }
            
            let fileName = "persistence_test_\(i).dat"
            let fileURL = testDirectory.appendingPathComponent(fileName)
            
            do {
                try fileData.write(to: fileURL)
                let checksum = try integrityManager.generateChecksum(for: fileURL)
                
                fileURLs.append(fileURL)
                expectedChecksums[fileURL.path] = checksum
            } catch {
                XCTFail("Failed to create test file \(i): \(error)")
            }
        }
        
        // Wait for async save
        Thread.sleep(forTimeInterval: 1.0)
        
        // Verify all checksums are retrievable
        for fileURL in fileURLs {
            let entry = integrityManager.getChecksumEntry(for: fileURL)
            XCTAssertNotNil(entry, "Checksum entry should be persisted for \(fileURL.lastPathComponent)")
            XCTAssertEqual(entry?.checksum, expectedChecksums[fileURL.path],
                          "Persisted checksum should match for \(fileURL.lastPathComponent)")
        }
        
        // Clean up
        for fileURL in fileURLs {
            integrityManager.removeChecksum(for: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    /// Test checksum verification updates last verified date
    func testChecksumVerificationUpdatesDate() {
        // Create test file
        let fileData = Data(repeating: 0x42, count: 1000)
        let fileURL = testDirectory.appendingPathComponent("date_test.dat")
        
        do {
            try fileData.write(to: fileURL)
            
            // Generate checksum
            _ = try integrityManager.generateChecksum(for: fileURL)
            
            // Wait a moment
            Thread.sleep(forTimeInterval: 0.5)
            
            // Get initial entry
            guard let initialEntry = integrityManager.getChecksumEntry(for: fileURL) else {
                XCTFail("Checksum entry should exist")
                return
            }
            
            let initialVerifiedDate = initialEntry.lastVerified
            
            // Wait another moment
            Thread.sleep(forTimeInterval: 0.5)
            
            // Verify integrity
            _ = try integrityManager.verifyIntegrity(for: fileURL)
            
            // Wait for async update
            Thread.sleep(forTimeInterval: 0.5)
            
            // Get updated entry
            guard let updatedEntry = integrityManager.getChecksumEntry(for: fileURL) else {
                XCTFail("Checksum entry should still exist")
                return
            }
            
            // Last verified date should be updated
            XCTAssertGreaterThan(updatedEntry.lastVerified, initialVerifiedDate,
                               "Last verified date should be updated after verification")
            
            // Clean up
            integrityManager.removeChecksum(for: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
            
        } catch {
            XCTFail("Failed to test date update: \(error)")
        }
    }
    
    /// Test periodic integrity check
    func testPeriodicIntegrityCheck() async {
        // Create multiple test files
        var fileURLs: [URL] = []
        
        for i in 0..<10 {
            let fileSize = Int.random(in: 500...1500)
            var fileData = Data(count: fileSize)
            _ = fileData.withUnsafeMutableBytes { bytes in
                SecRandomCopyBytes(kSecRandomDefault, fileSize, bytes.baseAddress!)
            }
            
            let fileName = "periodic_test_\(i).dat"
            let fileURL = testDirectory.appendingPathComponent(fileName)
            
            do {
                try fileData.write(to: fileURL)
                _ = try integrityManager.generateChecksum(for: fileURL)
                fileURLs.append(fileURL)
            } catch {
                XCTFail("Failed to create test file \(i): \(error)")
            }
        }
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Perform periodic check
        await integrityManager.performPeriodicCheck()
        
        // All files should still be valid
        for fileURL in fileURLs {
            do {
                let isValid = try integrityManager.verifyIntegrity(for: fileURL)
                XCTAssertTrue(isValid, "File \(fileURL.lastPathComponent) should be valid after periodic check")
            } catch {
                XCTFail("Failed to verify \(fileURL.lastPathComponent): \(error)")
            }
        }
        
        // Clean up
        for fileURL in fileURLs {
            integrityManager.removeChecksum(for: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    /// Test checksum removal
    func testChecksumRemoval() {
        // Test with 30 random files
        for iteration in 0..<30 {
            let fileData = Data(repeating: UInt8(iteration), count: 1000)
            let fileURL = testDirectory.appendingPathComponent("removal_test_\(iteration).dat")
            
            do {
                try fileData.write(to: fileURL)
                
                // Generate checksum
                _ = try integrityManager.generateChecksum(for: fileURL)
                
                // Wait for async save
                Thread.sleep(forTimeInterval: 0.1)
                
                // Verify entry exists
                XCTAssertNotNil(integrityManager.getChecksumEntry(for: fileURL),
                              "Checksum entry should exist before removal (iteration \(iteration))")
                
                // Remove checksum
                integrityManager.removeChecksum(for: fileURL)
                
                // Wait for async removal
                Thread.sleep(forTimeInterval: 0.1)
                
                // Verify entry is removed
                XCTAssertNil(integrityManager.getChecksumEntry(for: fileURL),
                           "Checksum entry should be removed (iteration \(iteration))")
                
                // Clean up file
                try? FileManager.default.removeItem(at: fileURL)
                
            } catch {
                XCTFail("Failed to test checksum removal for iteration \(iteration): \(error)")
            }
        }
    }
}
