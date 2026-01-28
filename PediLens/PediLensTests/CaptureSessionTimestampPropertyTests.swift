//
//  CaptureSessionTimestampPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for automatic timestamp recording
//  Feature: pedilens, Property 14: Automatic Timestamp Recording
//  Validates: Requirements 4.2
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for automatic timestamp recording
/// These tests validate that capture sessions automatically record timestamps
final class CaptureSessionTimestampPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var captureSessionManager: CaptureSessionManager!
    var woundManager: WoundManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        captureSessionManager = CaptureSessionManager(persistenceController: persistenceController)
        woundManager = WoundManager(persistenceController: persistenceController)
    }
    
    override func tearDown() {
        captureSessionManager = nil
        woundManager = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    // MARK: - Property 14: Automatic Timestamp Recording
    // **Validates: Requirements 4.2**
    
    /// Property: For any capture session created, a timestamp is automatically recorded at creation
    func testProperty14_AutomaticTimestampRecording_TimestampSetAtCreation() async throws {
        let iterations = 100
        var successfulCreations = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let beforeCreation = Date()
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            let afterCreation = Date()
            
            // Verify timestamp is set
            XCTAssertNotNil(session.timestamp,
                          "Iteration \(iteration): Timestamp should be set")
            
            // Verify timestamp is within reasonable range (created between before and after)
            if let timestamp = session.timestamp {
                XCTAssertGreaterThanOrEqual(timestamp, beforeCreation.addingTimeInterval(-1),
                                          "Iteration \(iteration): Timestamp should be after creation start")
                XCTAssertLessThanOrEqual(timestamp, afterCreation.addingTimeInterval(1),
                                       "Iteration \(iteration): Timestamp should be before creation end")
            }
            
            successfulCreations += 1
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulCreations, iterations,
                      "All capture sessions should have automatic timestamps")
    }
    
    /// Property: For any capture session, the timestamp reflects the moment of creation
    func testProperty14_AutomaticTimestampRecording_TimestampReflectsCreationTime() async throws {
        let iterations = 50
        var timestamps: [Date] = []
        
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        
        for iteration in 0..<iterations {
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            if let timestamp = session.timestamp {
                timestamps.append(timestamp)
            }
            
            // Small delay to ensure timestamps are different
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Verify all timestamps are present
        XCTAssertEqual(timestamps.count, iterations,
                      "All sessions should have timestamps")
        
        // Verify timestamps are in chronological order (or very close)
        for i in 1..<timestamps.count {
            XCTAssertGreaterThanOrEqual(timestamps[i], timestamps[i-1],
                                      "Timestamps should be in chronological order")
        }
        
        // Clean up
        try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
    }
    
    /// Property: For any capture session, the timestamp is immutable after creation
    func testProperty14_AutomaticTimestampRecording_TimestampIsImmutable() async throws {
        let iterations = 100
        var immutableTimestamps = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            let originalTimestamp = session.timestamp
            
            // Wait a bit
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            // Fetch the session again
            let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: session.id!)
            
            // Verify timestamp hasn't changed
            XCTAssertEqual(fetchedSession?.timestamp, originalTimestamp,
                         "Iteration \(iteration): Timestamp should remain unchanged")
            
            if fetchedSession?.timestamp == originalTimestamp {
                immutableTimestamps += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(immutableTimestamps, iterations,
                      "All timestamps should remain immutable")
    }
}
