//
//  CaptureSessionLocationPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for location recording with permission
//  Feature: pedilens, Property 15: Location Recording with Permission
//  Validates: Requirements 4.3
//

import XCTest
import CoreData
import CoreLocation
@testable import PediLens

/// Property-based tests for location recording with permission
/// These tests validate that capture sessions record location when permission is granted
final class CaptureSessionLocationPropertyTests: XCTestCase {
    
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
    
    private func generateRandomLocation() -> CLLocation {
        let latitude = Double.random(in: -90...90)
        let longitude = Double.random(in: -180...180)
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Property 15: Location Recording with Permission
    // **Validates: Requirements 4.3**
    
    /// Property: For any capture session created with location permission granted, location is recorded
    func testProperty15_LocationRecording_LocationRecordedWhenProvided() async throws {
        let iterations = 100
        var withLocation = 0
        var withoutLocation = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Randomly decide whether to provide location (simulating permission)
            let provideLocation = Bool.random()
            let location = provideLocation ? generateRandomLocation() : nil
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                location: location,
                woundRecord: woundRecord
            )
            
            // Verify location is recorded when provided
            if provideLocation {
                XCTAssertTrue(session.locationAvailable,
                            "Iteration \(iteration): Location should be available when provided")
                XCTAssertNotNil(session.location,
                              "Iteration \(iteration): Location should be set when provided")
                withLocation += 1
            } else {
                XCTAssertFalse(session.locationAvailable,
                             "Iteration \(iteration): Location should not be available when not provided")
                withoutLocation += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        // Both cases should occur
        XCTAssertGreaterThan(withLocation, 0,
                           "Some sessions should have location")
        XCTAssertGreaterThan(withoutLocation, 0,
                           "Some sessions should not have location")
    }
    
    /// Property: For any capture session with location, the coordinates are accurately stored
    func testProperty15_LocationRecording_CoordinatesAccuratelyStored() async throws {
        let iterations = 100
        var accurateCoordinates = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let originalLocation = generateRandomLocation()
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                location: originalLocation,
                woundRecord: woundRecord
            )
            
            // Verify coordinates match
            XCTAssertEqual(session.latitude, originalLocation.coordinate.latitude, accuracy: 0.000001,
                         "Iteration \(iteration): Latitude should match")
            XCTAssertEqual(session.longitude, originalLocation.coordinate.longitude, accuracy: 0.000001,
                         "Iteration \(iteration): Longitude should match")
            
            if abs(session.latitude - originalLocation.coordinate.latitude) < 0.000001 &&
               abs(session.longitude - originalLocation.coordinate.longitude) < 0.000001 {
                accurateCoordinates += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(accurateCoordinates, iterations,
                      "All coordinates should be accurately stored")
    }
    
    /// Property: For any capture session, location can be updated after creation
    func testProperty15_LocationRecording_LocationCanBeUpdated() async throws {
        let iterations = 100
        var successfulUpdates = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create session without location
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            XCTAssertFalse(session.locationAvailable,
                         "Iteration \(iteration): Location should not be available initially")
            
            // Update with location
            let newLocation = generateRandomLocation()
            try await captureSessionManager.updateLocation(for: session, location: newLocation)
            
            // Verify location is now set
            XCTAssertTrue(session.locationAvailable,
                        "Iteration \(iteration): Location should be available after update")
            XCTAssertEqual(session.latitude, newLocation.coordinate.latitude, accuracy: 0.000001,
                         "Iteration \(iteration): Updated latitude should match")
            XCTAssertEqual(session.longitude, newLocation.coordinate.longitude, accuracy: 0.000001,
                         "Iteration \(iteration): Updated longitude should match")
            
            successfulUpdates += 1
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulUpdates, iterations,
                      "All location updates should succeed")
    }
}
