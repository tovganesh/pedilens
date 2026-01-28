//
//  CaptureSessionManagerTests.swift
//  PediLensTests
//
//  Unit tests for CaptureSessionManager
//

import XCTest
import CoreData
import CoreLocation
@testable import PediLens

class CaptureSessionManagerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var captureSessionManager: CaptureSessionManager!
    var woundManager: WoundManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // Create in-memory persistence controller for testing
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
    
    // MARK: - Create Tests
    
    func testCreateCaptureSession() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let photoPath = "test/photo.heic"
        
        // When
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: photoPath,
            woundRecord: woundRecord
        )
        
        // Then
        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.photoPath, photoPath)
        XCTAssertNotNil(session.timestamp)
        XCTAssertEqual(session.woundRecord?.id, woundRecord.id)
    }
    
    func testCreateCaptureSessionWithAllData() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let photoPath = "test/photo.heic"
        let livePhotoVideoPath = "test/video.mov"
        let depthDataPath = "test/depth.dat"
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // When
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: photoPath,
            livePhotoVideoPath: livePhotoVideoPath,
            depthDataPath: depthDataPath,
            location: location,
            woundRecord: woundRecord
        )
        
        // Then
        XCTAssertEqual(session.photoPath, photoPath)
        XCTAssertEqual(session.livePhotoVideoPath, livePhotoVideoPath)
        XCTAssertEqual(session.depthDataPath, depthDataPath)
        XCTAssertTrue(session.locationAvailable)
        XCTAssertEqual(session.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(session.longitude, -122.4194, accuracy: 0.0001)
    }
    
    func testCreateCaptureSessionWithEmptyPhotoPath() async {
        // Given
        let woundRecord = try! await woundManager.createWoundRecord(location: "Test Location")
        let photoPath = ""
        
        // When/Then
        do {
            _ = try await captureSessionManager.createCaptureSession(
                photoPath: photoPath,
                woundRecord: woundRecord
            )
            XCTFail("Should throw invalidPhotoPath error")
        } catch let error as CaptureSessionManagerError {
            XCTAssertEqual(error, .invalidPhotoPath)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAddNoteToSession() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        let noteText = "Wound showing improvement"
        
        // When
        let note = try await captureSessionManager.addNote(
            to: session,
            text: noteText,
            category: "improved"
        )
        
        // Then
        XCTAssertNotNil(note.id)
        XCTAssertEqual(note.text, noteText)
        XCTAssertEqual(note.category, "improved")
        XCTAssertEqual(note.captureSession?.id, session.id)
    }
    
    func testAddEmptyNote() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        
        // When/Then
        do {
            _ = try await captureSessionManager.addNote(to: session, text: "")
            XCTFail("Should throw invalidNoteText error")
        } catch let error as CaptureSessionManagerError {
            XCTAssertEqual(error, .invalidNoteText)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAddTag() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        
        // When
        try await captureSessionManager.addTag(to: session, tag: "baseline")
        
        // Then
        let notes = session.notesArray
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.text, "baseline")
        XCTAssertEqual(notes.first?.category, "tag")
    }
    
    // MARK: - Read Tests
    
    func testFetchCaptureSessions() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        _ = try await captureSessionManager.createCaptureSession(photoPath: "test/photo1.heic", woundRecord: woundRecord)
        _ = try await captureSessionManager.createCaptureSession(photoPath: "test/photo2.heic", woundRecord: woundRecord)
        _ = try await captureSessionManager.createCaptureSession(photoPath: "test/photo3.heic", woundRecord: woundRecord)
        
        // When
        let sessions = try await captureSessionManager.fetchCaptureSessions(for: woundRecord)
        
        // Then
        XCTAssertEqual(sessions.count, 3)
    }
    
    func testFetchCaptureSessionByID() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        let sessionID = session.id!
        
        // When
        let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: sessionID)
        
        // Then
        XCTAssertNotNil(fetchedSession)
        XCTAssertEqual(fetchedSession?.id, sessionID)
    }
    
    func testFetchCaptureSessionByIDNotFound() async throws {
        // Given
        let nonExistentID = UUID()
        
        // When
        let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: nonExistentID)
        
        // Then
        XCTAssertNil(fetchedSession)
    }
    
    func testFetchCaptureSessionsWithDepthData() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        _ = try await captureSessionManager.createCaptureSession(photoPath: "test/photo1.heic", woundRecord: woundRecord)
        _ = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo2.heic",
            depthDataPath: "test/depth2.dat",
            woundRecord: woundRecord
        )
        _ = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo3.heic",
            depthDataPath: "test/depth3.dat",
            woundRecord: woundRecord
        )
        
        // When
        let sessionsWithDepth = try await captureSessionManager.fetchCaptureSessionsWithDepthData(for: woundRecord)
        
        // Then
        XCTAssertEqual(sessionsWithDepth.count, 2)
        XCTAssertTrue(sessionsWithDepth.allSatisfy { $0.hasDepthData })
    }
    
    // MARK: - Update Tests
    
    func testUpdatePaths() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        let newPhotoPath = "test/new_photo.heic"
        
        // When
        try await captureSessionManager.updatePaths(for: session, photoPath: newPhotoPath)
        
        // Then
        XCTAssertEqual(session.photoPath, newPhotoPath)
    }
    
    func testUpdateLocation() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        let newLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        
        // When
        try await captureSessionManager.updateLocation(for: session, location: newLocation)
        
        // Then
        XCTAssertTrue(session.locationAvailable)
        XCTAssertEqual(session.latitude, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(session.longitude, -74.0060, accuracy: 0.0001)
    }
    
    // MARK: - Delete Tests
    
    func testDeleteCaptureSession() async throws {
        // Given
        let woundRecord = try await woundManager.createWoundRecord(location: "Test Location")
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo.heic",
            woundRecord: woundRecord
        )
        let sessionID = session.id!
        
        // When
        try await captureSessionManager.deleteCaptureSession(session)
        
        // Then
        let fetchedSession = try await captureSessionManager.fetchCaptureSession(byID: sessionID)
        XCTAssertNil(fetchedSession)
    }
}

// MARK: - CaptureSessionManagerError Equatable

extension CaptureSessionManagerError: Equatable {
    public static func == (lhs: CaptureSessionManagerError, rhs: CaptureSessionManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidPhotoPath, .invalidPhotoPath):
            return true
        case (.sessionNotFound, .sessionNotFound):
            return true
        case (.saveFailed, .saveFailed):
            return true
        case (.invalidNoteText, .invalidNoteText):
            return true
        default:
            return false
        }
    }
}
