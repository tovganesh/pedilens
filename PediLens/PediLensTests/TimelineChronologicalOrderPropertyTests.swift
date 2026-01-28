//
//  TimelineChronologicalOrderPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for timeline chronological ordering
//  Feature: pedilens, Property 10: Timeline Chronological Ordering
//  Validates: Requirements 3.1
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for timeline chronological ordering
/// These tests validate that capture sessions are displayed in reverse chronological order
final class TimelineChronologicalOrderPropertyTests: XCTestCase {
    
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
    
    // MARK: - Property 10: Timeline Chronological Ordering
    // **Validates: Requirements 3.1**
    
    /// Property: For any wound record timeline, all capture sessions are displayed in reverse chronological order (newest first)
    func testProperty10_TimelineChronologicalOrdering_SessionsInReverseChronologicalOrder() async throws {
        let iterations = 100
        var successfulOrderings = 0
        
        for iteration in 0..<iterations {
            // Create a wound record
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create random number of capture sessions (3-10)
            let sessionCount = Int.random(in: 3...10)
            var createdSessions: [CaptureSession] = []
            
            for sessionIndex in 0..<sessionCount {
                let session = try await captureSessionManager.createCaptureSession(
                    photoPath: "test/photo_\(iteration)_\(sessionIndex).heic",
                    woundRecord: woundRecord
                )
                createdSessions.append(session)
                
                // Small delay to ensure different timestamps
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Fetch the wound record's capture sessions array
            let timelineSessions = woundRecord.captureSessionsArray
            
            // Verify sessions are in reverse chronological order (newest first)
            var isOrdered = true
            for i in 1..<timelineSessions.count {
                let previousTimestamp = timelineSessions[i-1].timestamp ?? Date.distantPast
                let currentTimestamp = timelineSessions[i].timestamp ?? Date.distantPast
                
                if previousTimestamp < currentTimestamp {
                    isOrdered = false
                    break
                }
            }
            
            XCTAssertTrue(isOrdered,
                         "Iteration \(iteration): Timeline sessions should be in reverse chronological order (newest first)")
            
            if isOrdered {
                successfulOrderings += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulOrderings, iterations,
                      "All timelines should display sessions in reverse chronological order")
    }
    
    /// Property: For any wound record with multiple sessions created at different times, the timeline maintains chronological order
    func testProperty10_TimelineChronologicalOrdering_MaintainsOrderWithVariedTimestamps() async throws {
        let iterations = 50
        var successfulOrderings = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create sessions with varying delays
            let sessionCount = Int.random(in: 5...15)
            
            for sessionIndex in 0..<sessionCount {
                _ = try await captureSessionManager.createCaptureSession(
                    photoPath: "test/photo_\(iteration)_\(sessionIndex).heic",
                    woundRecord: woundRecord
                )
                
                // Random delay between 5ms and 50ms
                let delay = UInt64.random(in: 5_000_000...50_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
            
            // Get timeline sessions
            let timelineSessions = woundRecord.captureSessionsArray
            
            // Verify count matches
            XCTAssertEqual(timelineSessions.count, sessionCount,
                         "Iteration \(iteration): Timeline should contain all sessions")
            
            // Verify reverse chronological order
            var isOrdered = true
            for i in 1..<timelineSessions.count {
                guard let prevTimestamp = timelineSessions[i-1].timestamp,
                      let currTimestamp = timelineSessions[i].timestamp else {
                    isOrdered = false
                    break
                }
                
                if prevTimestamp < currTimestamp {
                    isOrdered = false
                    break
                }
            }
            
            XCTAssertTrue(isOrdered,
                         "Iteration \(iteration): Sessions should be ordered newest to oldest")
            
            if isOrdered {
                successfulOrderings += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulOrderings, iterations,
                      "All timelines should maintain reverse chronological order")
    }
    
    /// Property: For any wound record, the most recent session appears first in the timeline
    func testProperty10_TimelineChronologicalOrdering_MostRecentSessionFirst() async throws {
        let iterations = 100
        var successfulOrderings = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create multiple sessions
            let sessionCount = Int.random(in: 3...8)
            var lastCreatedSession: CaptureSession?
            
            for sessionIndex in 0..<sessionCount {
                let session = try await captureSessionManager.createCaptureSession(
                    photoPath: "test/photo_\(iteration)_\(sessionIndex).heic",
                    woundRecord: woundRecord
                )
                lastCreatedSession = session
                
                // Small delay
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Get timeline sessions
            let timelineSessions = woundRecord.captureSessionsArray
            
            // Verify the first session in timeline is the last created
            if let firstInTimeline = timelineSessions.first,
               let lastCreated = lastCreatedSession {
                XCTAssertEqual(firstInTimeline.id, lastCreated.id,
                             "Iteration \(iteration): Most recent session should be first in timeline")
                
                if firstInTimeline.id == lastCreated.id {
                    successfulOrderings += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulOrderings, iterations,
                      "Most recent session should always appear first in timeline")
    }
    
    /// Property: For any wound record with a single session, the timeline contains that session
    func testProperty10_TimelineChronologicalOrdering_SingleSessionTimeline() async throws {
        let iterations = 100
        var successfulOrderings = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create a single session
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            // Get timeline sessions
            let timelineSessions = woundRecord.captureSessionsArray
            
            // Verify timeline contains exactly one session
            XCTAssertEqual(timelineSessions.count, 1,
                         "Iteration \(iteration): Timeline should contain exactly one session")
            
            // Verify it's the correct session
            if let firstSession = timelineSessions.first {
                XCTAssertEqual(firstSession.id, session.id,
                             "Iteration \(iteration): Timeline should contain the created session")
                
                if firstSession.id == session.id {
                    successfulOrderings += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulOrderings, iterations,
                      "Single session timelines should display correctly")
    }
    
    /// Property: For any wound record with no sessions, the timeline is empty
    func testProperty10_TimelineChronologicalOrdering_EmptyTimeline() async throws {
        let iterations = 100
        var successfulOrderings = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Don't create any sessions
            
            // Get timeline sessions
            let timelineSessions = woundRecord.captureSessionsArray
            
            // Verify timeline is empty
            XCTAssertEqual(timelineSessions.count, 0,
                         "Iteration \(iteration): Timeline should be empty when no sessions exist")
            
            if timelineSessions.count == 0 {
                successfulOrderings += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulOrderings, iterations,
                      "Empty timelines should be handled correctly")
    }
}

