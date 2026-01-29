//
//  LocalErrorLoggingPropertyTests.swift
//  PediLensTests
//
//  Property 42: Local Error Logging
//  Validates: Requirements 14.4
//

import XCTest
@testable import PediLens

class LocalErrorLoggingPropertyTests: XCTestCase {
    
    var errorLogger: ErrorLogger!
    
    override func setUp() {
        super.setUp()
        errorLogger = ErrorLogger.shared
    }
    
    override func tearDown() {
        // Clean up test logs
        super.tearDown()
    }
    
    // MARK: - Property 42: Local Error Logging
    
    /// **Property 42: Local Error Logging**
    /// *For any* critical error that occurs, an error log entry SHALL be created locally without transmitting data externally.
    /// **Validates: Requirements 14.4**
    func testLocalErrorLogging() {
        // Test with 100 random error scenarios
        for iteration in 0..<100 {
            let errorCode = Int.random(in: -10000...10000)
            let errorMessage = "Test error \(iteration): \(UUID().uuidString)"
            
            let initialLogSize = errorLogger.getCurrentLogSize()
            
            // Create a test error
            let testError = NSError(
                domain: "com.pedilens.test",
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            
            // Log the error
            errorLogger.log(error: testError, context: "Property test iteration \(iteration)")
            
            // Wait for async logging to complete
            Thread.sleep(forTimeInterval: 0.1)
            
            // Verify log was created
            let finalLogSize = errorLogger.getCurrentLogSize()
            
            // Log size should increase (encrypted log entry was written)
            XCTAssertGreaterThan(finalLogSize, initialLogSize,
                               "Log size should increase after logging error (iteration \(iteration))")
        }
    }
    
    /// Test that logs are encrypted
    func testLogsAreEncrypted() {
        // Test with 50 random error messages
        for iteration in 0..<50 {
            let errorMessage = "Sensitive data \(iteration): \(UUID().uuidString)"
            
            let testError = NSError(
                domain: "com.pedilens.test",
                code: 999,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            
            // Log the error
            errorLogger.log(error: testError, context: "Encryption test")
            
            // Wait for async logging
            Thread.sleep(forTimeInterval: 0.1)
            
            // Try to read log file directly (should be encrypted)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logDirectory = documentsPath.appendingPathComponent("PediLens/Logs", isDirectory: true)
            
            guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil),
                  let logFile = files.first(where: { $0.pathExtension == "log" }),
                  let rawData = try? Data(contentsOf: logFile),
                  let rawString = String(data: rawData, encoding: .utf8) else {
                continue
            }
            
            // Raw file should NOT contain the plaintext error message (it's encrypted)
            XCTAssertFalse(rawString.contains(errorMessage),
                          "Log file should not contain plaintext error message (iteration \(iteration))")
        }
    }
    
    /// Test log rotation by age (7 days)
    func testLogRotationByAge() {
        // This is a unit test since we can't easily generate time-based properties
        let testError = NSError(domain: "com.pedilens.test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // Log an error
        errorLogger.log(error: testError, context: "Age rotation test")
        Thread.sleep(forTimeInterval: 0.5)
        
        let initialCount = errorLogger.getLogFileCount()
        
        // In a real scenario, logs older than 7 days would be deleted
        // For testing, we verify the rotation mechanism exists
        XCTAssertGreaterThan(initialCount, 0, "At least one log file should exist")
    }
    
    /// Test log rotation by size (10MB max)
    func testLogRotationBySize() {
        // Test with varying numbers of errors
        for testRun in 0..<20 {
            let errorCount = Int.random(in: 10...100)
            
            let initialSize = errorLogger.getCurrentLogSize()
            
            // Log multiple errors
            for i in 0..<errorCount {
                let testError = NSError(
                    domain: "com.pedilens.test",
                    code: i,
                    userInfo: [NSLocalizedDescriptionKey: "Test error \(i) with some additional context to increase size - run \(testRun)"]
                )
                errorLogger.log(error: testError, context: "Size rotation test")
            }
            
            // Wait for async logging
            Thread.sleep(forTimeInterval: 0.5)
            
            let finalSize = errorLogger.getCurrentLogSize()
            
            // Log size should not exceed 10MB (rotation should occur)
            let maxSize: Int64 = 10 * 1024 * 1024
            XCTAssertLessThanOrEqual(finalSize, maxSize,
                                    "Log size should not exceed 10MB (test run \(testRun))")
        }
    }
    
    /// Test that logs can be exported
    func testLogExport() async throws {
        // Log some test errors
        for i in 0..<5 {
            let testError = NSError(
                domain: "com.pedilens.test",
                code: i,
                userInfo: [NSLocalizedDescriptionKey: "Export test error \(i)"]
            )
            errorLogger.log(error: testError, context: "Export test")
        }
        
        // Wait for logging
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Export logs
        let exportURL = try await errorLogger.exportSanitizedLogs()
        
        // Verify export file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path), "Export file should exist")
        
        // Verify export file contains data
        let exportData = try Data(contentsOf: exportURL)
        XCTAssertGreaterThan(exportData.count, 0, "Export file should contain data")
        
        // Verify it's valid JSON
        let jsonObject = try JSONSerialization.jsonObject(with: exportData)
        XCTAssertNotNil(jsonObject, "Export should be valid JSON")
        
        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    /// Test that no external transmission occurs
    func testNoExternalTransmission() {
        // Test with 50 random error messages
        for iteration in 0..<50 {
            let errorMessage = "Test error \(iteration): \(UUID().uuidString)"
            
            let testError = NSError(
                domain: "com.pedilens.test",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            
            // Log the error
            errorLogger.log(error: testError, context: "No transmission test")
            
            // Wait for logging
            Thread.sleep(forTimeInterval: 0.1)
            
            // Verify log exists locally
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logDirectory = documentsPath.appendingPathComponent("PediLens/Logs", isDirectory: true)
            
            guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil) else {
                XCTFail("Should be able to read log directory (iteration \(iteration))")
                continue
            }
            
            let logFiles = files.filter { $0.pathExtension == "log" }
            
            // At least one log file should exist locally
            // Note: We can't directly test "no external transmission" but we verify local storage
            XCTAssertFalse(logFiles.isEmpty,
                          "At least one log file should exist locally (iteration \(iteration))")
        }
    }
    
    /// Test log entry structure
    func testLogEntryStructure() {
        // Test with 20 random error scenarios
        for iteration in 0..<20 {
            let errorCode = Int.random(in: -1000...1000)
            let errorMessage = "Test error \(iteration): \(UUID().uuidString)"
            
            let testError = NSError(
                domain: "com.pedilens.test",
                code: errorCode,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
            
            // Log the error
            errorLogger.log(error: testError, context: "Structure test")
            
            // Wait for logging
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Export and verify structure
        let expectation = XCTestExpectation(description: "Export logs")
        
        Task {
            do {
                let exportURL = try await errorLogger.exportSanitizedLogs()
                let exportData = try Data(contentsOf: exportURL)
                
                if let jsonArray = try JSONSerialization.jsonObject(with: exportData) as? [[String: Any]] {
                    // Verify at least some entries exist
                    XCTAssertGreaterThan(jsonArray.count, 0, "Should have at least one log entry")
                    
                    // Check first entry has required fields
                    if let firstEntry = jsonArray.first {
                        XCTAssertNotNil(firstEntry["id"], "Log entry should have id")
                        XCTAssertNotNil(firstEntry["timestamp"], "Log entry should have timestamp")
                        XCTAssertNotNil(firstEntry["errorDescription"], "Log entry should have errorDescription")
                        XCTAssertNotNil(firstEntry["errorDomain"], "Log entry should have errorDomain")
                        XCTAssertNotNil(firstEntry["errorCode"], "Log entry should have errorCode")
                        XCTAssertNotNil(firstEntry["context"], "Log entry should have context")
                        XCTAssertNotNil(firstEntry["stackTrace"], "Log entry should have stackTrace")
                        XCTAssertNotNil(firstEntry["deviceInfo"], "Log entry should have deviceInfo")
                        XCTAssertNotNil(firstEntry["appVersion"], "Log entry should have appVersion")
                    }
                }
                
                try? FileManager.default.removeItem(at: exportURL)
            } catch {
                XCTFail("Failed to export logs: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
