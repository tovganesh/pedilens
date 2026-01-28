//
//  TimelineEntryCompletenessPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for timeline entry completeness
//  Feature: pedilens, Property 11: Timeline Entry Completeness
//  Validates: Requirements 3.2, 10.3
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for timeline entry completeness
/// These tests validate that timeline entries include thumbnail, timestamp, and key measurements
final class TimelineEntryCompletenessPropertyTests: XCTestCase {
    
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
    
    private func createRandomBoundary(pointCount: Int) -> WoundBoundary {
        var points: [CGPoint] = []
        for _ in 0..<pointCount {
            let x = CGFloat.random(in: 0...100)
            let y = CGFloat.random(in: 0...100)
            points.append(CGPoint(x: x, y: y))
        }
        
        return WoundBoundary(
            points: points,
            confidence: Float.random(in: 0.5...1.0),
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            detectionMethod: .automatic(modelVersion: "1.0")
        )
    }
    
    private func createRandomCalibration() -> MeasurementCalibration {
        return MeasurementCalibration(
            pixelsPerMillimeter: Double.random(in: 1.0...10.0),
            referenceObject: .ruler(lengthMM: 100),
            calibrationDate: Date(),
            depthCalibration: nil
        )
    }
    
    // MARK: - Property 11: Timeline Entry Completeness
    // **Validates: Requirements 3.2, 10.3**
    
    /// Property: For any timeline entry displayed, it includes thumbnail image, timestamp, and key measurements (area at minimum)
    func testProperty11_TimelineEntryCompleteness_AllEntriesHaveRequiredData() async throws {
        let iterations = 100
        var completeEntries = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create a capture session
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            // Add measurement with area
            let boundary = createRandomBoundary(pointCount: Int.random(in: 4...10))
            let calibration = createRandomCalibration()
            
            // Encode boundary points and calibration
            let boundaryData = try! JSONEncoder().encode(boundary.points.map { ["x": $0.x, "y": $0.y] })
            let calibrationData = try! JSONEncoder().encode(["pixelsPerMM": calibration.pixelsPerMillimeter])
            
            _ = Measurement.create(
                in: context,
                lengthMM: Double.random(in: 10...100),
                widthMM: Double.random(in: 10...100),
                areaMM2: Double.random(in: 100...1000),
                perimeterMM: Double.random(in: 40...400),
                boundaryPoints: boundaryData,
                calibrationData: calibrationData,
                detectionConfidence: boundary.confidence,
                captureSession: session
            )
            
            // Verify timeline entry has required data
            let timelineSessions = woundRecord.captureSessionsArray
            
            XCTAssertEqual(timelineSessions.count, 1,
                         "Iteration \(iteration): Timeline should have one entry")
            
            if let entry = timelineSessions.first {
                // Check thumbnail (photoPath)
                XCTAssertNotNil(entry.photoPath,
                              "Iteration \(iteration): Entry should have photo path (thumbnail)")
                XCTAssertFalse(entry.photoPath?.isEmpty ?? true,
                             "Iteration \(iteration): Photo path should not be empty")
                
                // Check timestamp
                XCTAssertNotNil(entry.timestamp,
                              "Iteration \(iteration): Entry should have timestamp")
                
                // Check key measurements (area at minimum)
                XCTAssertNotNil(entry.measurement,
                              "Iteration \(iteration): Entry should have measurement")
                
                if let measurement = entry.measurement {
                    XCTAssertGreaterThan(measurement.areaMM2, 0,
                                       "Iteration \(iteration): Entry should have area measurement")
                }
                
                // If all required data is present
                if entry.photoPath != nil && !entry.photoPath!.isEmpty &&
                   entry.timestamp != nil &&
                   entry.measurement != nil &&
                   entry.measurement!.areaMM2 > 0 {
                    completeEntries += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(completeEntries, iterations,
                      "All timeline entries should have complete data (thumbnail, timestamp, area)")
    }
    
    /// Property: For any timeline entry, the thumbnail path is accessible
    func testProperty11_TimelineEntryCompleteness_ThumbnailPathAccessible() async throws {
        let iterations = 100
        var accessibleThumbnails = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let photoPath = "test/photo_\(iteration)_\(UUID().uuidString).heic"
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: photoPath,
                woundRecord: woundRecord
            )
            
            // Verify photo path is set and accessible
            XCTAssertNotNil(session.photoPath,
                          "Iteration \(iteration): Session should have photo path")
            XCTAssertEqual(session.photoPath, photoPath,
                         "Iteration \(iteration): Photo path should match")
            
            if session.photoPath == photoPath {
                accessibleThumbnails += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(accessibleThumbnails, iterations,
                      "All timeline entries should have accessible thumbnail paths")
    }
    
    /// Property: For any timeline entry with measurements, all key measurements are present
    func testProperty11_TimelineEntryCompleteness_KeyMeasurementsPresent() async throws {
        let iterations = 100
        var completeMeasurements = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            // Create measurement
            let boundary = createRandomBoundary(pointCount: Int.random(in: 4...10))
            let calibration = createRandomCalibration()
            
            // Encode boundary points and calibration
            let boundaryData = try! JSONEncoder().encode(boundary.points.map { ["x": $0.x, "y": $0.y] })
            let calibrationData = try! JSONEncoder().encode(["pixelsPerMM": calibration.pixelsPerMillimeter])
            
            let measurement = Measurement.create(
                in: context,
                lengthMM: Double.random(in: 10...100),
                widthMM: Double.random(in: 10...100),
                areaMM2: Double.random(in: 100...1000),
                perimeterMM: Double.random(in: 40...400),
                boundaryPoints: boundaryData,
                calibrationData: calibrationData,
                detectionConfidence: boundary.confidence,
                captureSession: session
            )
            
            // Verify key measurements are present
            XCTAssertGreaterThan(measurement.areaMM2, 0,
                               "Iteration \(iteration): Area should be present and positive")
            XCTAssertGreaterThan(measurement.lengthMM, 0,
                               "Iteration \(iteration): Length should be present and positive")
            XCTAssertGreaterThan(measurement.widthMM, 0,
                               "Iteration \(iteration): Width should be present and positive")
            XCTAssertGreaterThan(measurement.perimeterMM, 0,
                               "Iteration \(iteration): Perimeter should be present and positive")
            
            if measurement.areaMM2 > 0 && measurement.lengthMM > 0 &&
               measurement.widthMM > 0 && measurement.perimeterMM > 0 {
                completeMeasurements += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(completeMeasurements, iterations,
                      "All timeline entries with measurements should have complete key measurements")
    }
    
    /// Property: For any timeline entry, the timestamp is within a reasonable range
    func testProperty11_TimelineEntryCompleteness_TimestampReasonable() async throws {
        let iterations = 100
        var reasonableTimestamps = 0
        
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let oneDayFromNow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            // Verify timestamp is reasonable (not in distant past or future)
            if let timestamp = session.timestamp {
                XCTAssertGreaterThanOrEqual(timestamp, oneYearAgo,
                                          "Iteration \(iteration): Timestamp should not be too far in the past")
                XCTAssertLessThanOrEqual(timestamp, oneDayFromNow,
                                       "Iteration \(iteration): Timestamp should not be in the future")
                
                if timestamp >= oneYearAgo && timestamp <= oneDayFromNow {
                    reasonableTimestamps += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(reasonableTimestamps, iterations,
                      "All timeline entries should have reasonable timestamps")
    }
    
    /// Property: For any timeline with multiple entries, each entry has unique data
    func testProperty11_TimelineEntryCompleteness_UniqueEntries() async throws {
        let iterations = 50
        var uniqueEntries = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create multiple sessions
            let sessionCount = Int.random(in: 3...8)
            var sessionIDs: Set<UUID> = []
            
            for sessionIndex in 0..<sessionCount {
                let session = try await captureSessionManager.createCaptureSession(
                    photoPath: "test/photo_\(iteration)_\(sessionIndex).heic",
                    woundRecord: woundRecord
                )
                
                if let id = session.id {
                    sessionIDs.insert(id)
                }
                
                // Small delay
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Verify all entries are unique
            let timelineSessions = woundRecord.captureSessionsArray
            
            XCTAssertEqual(timelineSessions.count, sessionCount,
                         "Iteration \(iteration): Timeline should have all sessions")
            XCTAssertEqual(sessionIDs.count, sessionCount,
                         "Iteration \(iteration): All session IDs should be unique")
            
            if timelineSessions.count == sessionCount && sessionIDs.count == sessionCount {
                uniqueEntries += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(uniqueEntries, iterations,
                      "All timeline entries should be unique")
    }
    
    /// Property: For any timeline entry without measurements, it still has thumbnail and timestamp
    func testProperty11_TimelineEntryCompleteness_MinimalDataWithoutMeasurements() async throws {
        let iterations = 100
        var completeMinimalEntries = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create session without measurement
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            // Verify minimal data is present (thumbnail and timestamp)
            XCTAssertNotNil(session.photoPath,
                          "Iteration \(iteration): Entry should have photo path even without measurements")
            XCTAssertNotNil(session.timestamp,
                          "Iteration \(iteration): Entry should have timestamp even without measurements")
            
            if session.photoPath != nil && session.timestamp != nil {
                completeMinimalEntries += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(completeMinimalEntries, iterations,
                      "All timeline entries should have at least thumbnail and timestamp")
    }
}

