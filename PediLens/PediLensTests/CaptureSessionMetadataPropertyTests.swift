//
//  CaptureSessionMetadataPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for metadata persistence
//  Feature: pedilens, Property 16: Metadata Persistence
//  Validates: Requirements 4.5, 5.1
//

import XCTest
import CoreData
import CoreLocation
@testable import PediLens

/// Property-based tests for metadata persistence
/// These tests validate that metadata (notes, tags, timestamps, location) is persisted with capture sessions
final class CaptureSessionMetadataPropertyTests: XCTestCase {
    
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
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    private func generateRandomLocation() -> CLLocation {
        let latitude = Double.random(in: -90...90)
        let longitude = Double.random(in: -180...180)
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Property 16: Metadata Persistence
    // **Validates: Requirements 4.5, 5.1**
    
    /// Property: For any metadata added to a capture session, it is persisted in local storage
    func testProperty16_MetadataPersistence_AllMetadataPersistedInLocalStorage() async throws {
        let iterations = 100
        var successfulPersistence = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create session with various metadata
            let location = Bool.random() ? generateRandomLocation() : nil
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                livePhotoVideoPath: Bool.random() ? "test/video_\(iteration).mov" : nil,
                depthDataPath: Bool.random() ? "test/depth_\(iteration).dat" : nil,
                location: location,
                woundRecord: woundRecord
            )
            
            let sessionID = session.id!
            
            // Add notes
            let noteCount = Int.random(in: 0...5)
            for i in 0..<noteCount {
                _ = try await captureSessionManager.addNote(
                    to: session,
                    text: generateRandomString(length: Int.random(in: 10...100)),
                    category: ["general", "improved", "unchanged", "worsened"].randomElement()!
                )
            }
            
            // Fetch the session again to verify persistence
            let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: sessionID)
            
            // Verify all metadata is persisted
            XCTAssertNotNil(fetchedSession,
                          "Iteration \(iteration): Session should be fetchable")
            XCTAssertNotNil(fetchedSession?.timestamp,
                          "Iteration \(iteration): Timestamp should be persisted")
            XCTAssertEqual(fetchedSession?.photoPath, session.photoPath,
                         "Iteration \(iteration): Photo path should be persisted")
            XCTAssertEqual(fetchedSession?.livePhotoVideoPath, session.livePhotoVideoPath,
                         "Iteration \(iteration): Live photo path should be persisted")
            XCTAssertEqual(fetchedSession?.depthDataPath, session.depthDataPath,
                         "Iteration \(iteration): Depth data path should be persisted")
            XCTAssertEqual(fetchedSession?.locationAvailable, session.locationAvailable,
                         "Iteration \(iteration): Location availability should be persisted")
            XCTAssertEqual(fetchedSession?.notesArray.count, noteCount,
                         "Iteration \(iteration): Notes should be persisted")
            
            successfulPersistence += 1
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulPersistence, iterations,
                      "All metadata should be persisted successfully")
    }
    
    /// Property: For any capture session, metadata persists across app restarts (simulated by context refresh)
    func testProperty16_MetadataPersistence_MetadataPersistsAcrossContextRefresh() async throws {
        let iterations = 50
        var persistentMetadata = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                location: generateRandomLocation(),
                woundRecord: woundRecord
            )
            
            let sessionID = session.id!
            let originalTimestamp = session.timestamp
            let originalLocation = session.location
            
            // Add a note
            _ = try await captureSessionManager.addNote(
                to: session,
                text: generateRandomString(length: 50),
                category: "general"
            )
            
            // Refresh the context (simulates app restart)
            context.refreshAllObjects()
            
            // Fetch the session again
            let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: sessionID)
            
            // Verify metadata persists
            XCTAssertNotNil(fetchedSession,
                          "Iteration \(iteration): Session should persist after context refresh")
            XCTAssertEqual(fetchedSession?.timestamp, originalTimestamp,
                         "Iteration \(iteration): Timestamp should persist")
            if let session = fetchedSession {
                XCTAssertEqual(session.latitude, originalLocation?.coordinate.latitude ?? 0, accuracy: 0.000001,
                             "Iteration \(iteration): Location should persist")
            }
            XCTAssertEqual(fetchedSession?.notesArray.count, 1,
                         "Iteration \(iteration): Notes should persist")
            
            persistentMetadata += 1
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(persistentMetadata, iterations,
                      "All metadata should persist across context refresh")
    }
    
    /// Property: For any capture session with notes, all notes are persisted with their metadata
    func testProperty16_MetadataPersistence_NotesPersistedWithMetadata() async throws {
        let iterations = 100
        var successfulNotePersistence = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            let session = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration).heic",
                woundRecord: woundRecord
            )
            
            // Add multiple notes with different categories
            let categories = ["general", "improved", "unchanged", "worsened"]
            var noteTexts: [String] = []
            var noteCategories: [String] = []
            
            let noteCount = Int.random(in: 1...5)
            for _ in 0..<noteCount {
                let text = generateRandomString(length: Int.random(in: 10...100))
                let category = categories.randomElement()!
                noteTexts.append(text)
                noteCategories.append(category)
                
                _ = try await captureSessionManager.addNote(
                    to: session,
                    text: text,
                    category: category
                )
            }
            
            // Fetch the session and verify notes
            let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: session.id!)
            let fetchedNotes = fetchedSession?.notesArray ?? []
            
            XCTAssertEqual(fetchedNotes.count, noteCount,
                         "Iteration \(iteration): All notes should be persisted")
            
            // Verify each note has its metadata
            for note in fetchedNotes {
                XCTAssertNotNil(note.id,
                              "Iteration \(iteration): Note should have ID")
                XCTAssertNotNil(note.text,
                              "Iteration \(iteration): Note should have text")
                XCTAssertNotNil(note.category,
                              "Iteration \(iteration): Note should have category")
                XCTAssertNotNil(note.createdAt,
                              "Iteration \(iteration): Note should have creation timestamp")
                XCTAssertTrue(categories.contains(note.category ?? ""),
                            "Iteration \(iteration): Note category should be valid")
            }
            
            successfulNotePersistence += 1
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulNotePersistence, iterations,
                      "All notes should be persisted with their metadata")
    }
}
