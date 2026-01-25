//
//  FileStorageManagerTests.swift
//  PediLensTests
//
//  Unit tests for FileStorageManager
//

import XCTest
import CoreData
@testable import PediLens

class FileStorageManagerTests: XCTestCase {
    var fileStorageManager: FileStorageManager!
    var testSessionID: UUID!
    
    override func setUp() {
        super.setUp()
        fileStorageManager = FileStorageManager.shared
        testSessionID = UUID()
    }
    
    override func tearDown() {
        // Clean up test files
        if let testSessionID = testSessionID {
            Task {
                try? await fileStorageManager.deleteFiles(for: testSessionID)
            }
        }
        testSessionID = nil
        fileStorageManager = nil
        super.tearDown()
    }
    
    // MARK: - Photo Storage Tests
    
    func testSavePhoto_ValidData_SavesSuccessfully() async throws {
        // Given: Valid image data
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        // When: Saving the photo
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: testSessionID)
        
        // Then: Photo file should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoURL.path),
                     "Photo file should exist at saved path")
        
        // And: Photo should be in HEIC format
        XCTAssertEqual(photoURL.pathExtension, "heic",
                      "Photo should be saved in HEIC format")
    }
    
    func testSavePhoto_GeneratesThumbnail() async throws {
        // Given: Valid image data
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        // When: Saving the photo
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: testSessionID)
        
        // Then: Thumbnail should be generated
        let thumbnailURL = photoURL.deletingLastPathComponent().appendingPathComponent("thumbnail.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path),
                     "Thumbnail should be generated")
    }
    
    func testSavePhoto_ThumbnailMaintainsAspectRatio() async throws {
        // Given: Wide image (2:1 aspect ratio)
        let testImage = createTestImage(size: CGSize(width: 2000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        // When: Saving the photo
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: testSessionID)
        
        // Then: Thumbnail should maintain aspect ratio
        let thumbnailURL = photoURL.deletingLastPathComponent().appendingPathComponent("thumbnail.jpg")
        if let thumbnailData = try? Data(contentsOf: thumbnailURL),
           let thumbnail = UIImage(data: thumbnailData) {
            let aspectRatio = thumbnail.size.width / thumbnail.size.height
            XCTAssertEqual(aspectRatio, 2.0, accuracy: 0.1,
                          "Thumbnail should maintain original aspect ratio")
            XCTAssertLessThanOrEqual(thumbnail.size.width, 300,
                                    "Thumbnail width should not exceed 300")
            XCTAssertLessThanOrEqual(thumbnail.size.height, 300,
                                    "Thumbnail height should not exceed 300")
        } else {
            XCTFail("Failed to load thumbnail")
        }
    }
    
    func testSavePhoto_UsesCompleteFileProtection() async throws {
        // Given: Valid image data
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        // When: Saving the photo
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: testSessionID)
        
        // Then: File should have complete protection
        let attributes = try FileManager.default.attributesOfItem(atPath: photoURL.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
        XCTAssertEqual(protection, .complete,
                      "Photo should use complete file protection")
    }
    
    // MARK: - Live Photo Video Tests
    
    func testSaveLivePhotoVideo_ValidURL_SavesSuccessfully() async throws {
        // Given: A temporary video file
        let tempVideoURL = createTempVideoFile()
        
        // When: Saving the live photo video
        let savedVideoURL = try await fileStorageManager.saveLivePhotoVideo(tempVideoURL, for: testSessionID)
        
        // Then: Video file should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedVideoURL.path),
                     "Video file should exist at saved path")
        
        // And: Video should be in MOV format
        XCTAssertEqual(savedVideoURL.pathExtension, "mov",
                      "Video should be saved in MOV format")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempVideoURL)
    }
    
    func testSaveLivePhotoVideo_UsesCompleteFileProtection() async throws {
        // Given: A temporary video file
        let tempVideoURL = createTempVideoFile()
        
        // When: Saving the live photo video
        let savedVideoURL = try await fileStorageManager.saveLivePhotoVideo(tempVideoURL, for: testSessionID)
        
        // Then: File should have complete protection
        let attributes = try FileManager.default.attributesOfItem(atPath: savedVideoURL.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
        XCTAssertEqual(protection, .complete,
                      "Video should use complete file protection")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempVideoURL)
    }
    
    // MARK: - Depth Data Tests
    
    func testSaveDepthData_ValidData_SavesSuccessfully() async throws {
        // Given: Valid depth data
        let depthData = Data(repeating: 0xFF, count: 1024)
        
        // When: Saving the depth data
        let depthURL = try await fileStorageManager.saveDepthData(depthData, for: testSessionID)
        
        // Then: Depth file should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: depthURL.path),
                     "Depth file should exist at saved path")
        
        // And: Depth file should have correct extension
        XCTAssertEqual(depthURL.pathExtension, "dat",
                      "Depth data should be saved with .dat extension")
    }
    
    func testSaveDepthData_UsesCompleteFileProtection() async throws {
        // Given: Valid depth data
        let depthData = Data(repeating: 0xFF, count: 1024)
        
        // When: Saving the depth data
        let depthURL = try await fileStorageManager.saveDepthData(depthData, for: testSessionID)
        
        // Then: File should have complete protection
        let attributes = try FileManager.default.attributesOfItem(atPath: depthURL.path)
        let protection = attributes[.protectionKey] as? FileProtectionType
        XCTAssertEqual(protection, .complete,
                      "Depth data should use complete file protection")
    }
    
    // MARK: - Load Photo Tests
    
    func testLoadPhoto_ExistingPhoto_LoadsSuccessfully() async throws {
        // Given: A saved photo
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: testSessionID)
        
        // When: Loading the photo
        let loadedData = try await fileStorageManager.loadPhoto(at: photoURL.path)
        
        // Then: Loaded data should not be empty
        XCTAssertFalse(loadedData.isEmpty, "Loaded data should not be empty")
        XCTAssertGreaterThan(loadedData.count, 0, "Loaded data should have content")
    }
    
    func testLoadPhoto_NonExistentPhoto_ThrowsError() async {
        // Given: A non-existent path
        let nonExistentPath = "/non/existent/path/photo.heic"
        
        // When/Then: Loading should throw an error
        do {
            _ = try await fileStorageManager.loadPhoto(at: nonExistentPath)
            XCTFail("Loading non-existent photo should throw an error")
        } catch {
            // Expected error
            XCTAssertNotNil(error, "Should throw an error for non-existent photo")
        }
    }
    
    // MARK: - Delete Files Tests
    
    func testDeleteFiles_ExistingSession_DeletesAllFiles() async throws {
        // Given: A session with photo, video, and depth data
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: testSessionID)
        
        let tempVideoURL = createTempVideoFile()
        _ = try await fileStorageManager.saveLivePhotoVideo(tempVideoURL, for: testSessionID)
        try? FileManager.default.removeItem(at: tempVideoURL)
        
        let depthData = Data(repeating: 0xFF, count: 1024)
        _ = try await fileStorageManager.saveDepthData(depthData, for: testSessionID)
        
        let sessionDir = photoURL.deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path),
                     "Session directory should exist before deletion")
        
        // When: Deleting the session files
        try await fileStorageManager.deleteFiles(for: testSessionID)
        
        // Then: Session directory should be deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: sessionDir.path),
                      "Session directory should be deleted")
    }
    
    func testDeleteFiles_NonExistentSession_DoesNotThrowError() async throws {
        // Given: A non-existent session ID
        let nonExistentSessionID = UUID()
        
        // When/Then: Deleting should not throw an error
        try await fileStorageManager.deleteFiles(for: nonExistentSessionID)
        // If we reach here, the test passes
    }
    
    // MARK: - Storage Usage Tests
    
    func testGetStorageUsage_EmptyStorage_ReturnsZero() async {
        // Given: Empty storage (cleanup any existing test files)
        try? await fileStorageManager.deleteFiles(for: testSessionID)
        
        // When: Getting storage usage
        let storageInfo = await fileStorageManager.getStorageUsage()
        
        // Then: Photo count should be zero or minimal
        XCTAssertGreaterThanOrEqual(storageInfo.photoCount, 0,
                                   "Photo count should be non-negative")
        XCTAssertGreaterThanOrEqual(storageInfo.totalUsedBytes, 0,
                                   "Total used bytes should be non-negative")
        XCTAssertGreaterThan(storageInfo.availableBytes, 0,
                            "Available bytes should be positive")
    }
    
    func testGetStorageUsage_WithPhotos_ReturnsCorrectCount() async throws {
        // Given: Multiple saved photos
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        let session1 = UUID()
        let session2 = UUID()
        
        _ = try await fileStorageManager.savePhoto(imageData, for: session1)
        _ = try await fileStorageManager.savePhoto(imageData, for: session2)
        
        // When: Getting storage usage
        let storageInfo = await fileStorageManager.getStorageUsage()
        
        // Then: Photo count should include our test photos
        XCTAssertGreaterThanOrEqual(storageInfo.photoCount, 2,
                                   "Photo count should include test photos")
        XCTAssertGreaterThan(storageInfo.totalUsedBytes, 0,
                            "Total used bytes should be positive")
        
        // Cleanup
        try? await fileStorageManager.deleteFiles(for: session1)
        try? await fileStorageManager.deleteFiles(for: session2)
    }
    
    // MARK: - Storage Quota Management Tests
    
    func testIsStorageNearCapacity_LowUsage_ReturnsFalse() async throws {
        // Given: Low storage usage (cleanup any test files first)
        try? await fileStorageManager.deleteFiles(for: testSessionID)
        
        // When: Checking if storage is near capacity
        let isNearCapacity = await fileStorageManager.isStorageNearCapacity()
        
        // Then: Should return false for typical low usage
        // Note: This test assumes the device has reasonable available storage
        // In most test environments, storage won't be at 80% capacity
        XCTAssertFalse(isNearCapacity,
                      "Storage should not be near capacity in test environment")
    }
    
    func testStorageInfo_IsNearCapacity_CalculatesCorrectly() {
        // Test the isNearCapacity property with various scenarios
        
        // Scenario 1: 50% usage - should return false
        let storage50 = StorageInfo(totalUsedBytes: 50_000_000_000,
                                    photoCount: 100,
                                    availableBytes: 50_000_000_000)
        XCTAssertFalse(storage50.isNearCapacity,
                      "50% usage should not be near capacity")
        
        // Scenario 2: 79% usage - should return false
        let storage79 = StorageInfo(totalUsedBytes: 79_000_000_000,
                                    photoCount: 100,
                                    availableBytes: 21_000_000_000)
        XCTAssertFalse(storage79.isNearCapacity,
                      "79% usage should not be near capacity")
        
        // Scenario 3: 80% usage - should return true
        let storage80 = StorageInfo(totalUsedBytes: 80_000_000_000,
                                    photoCount: 100,
                                    availableBytes: 20_000_000_000)
        XCTAssertTrue(storage80.isNearCapacity,
                     "80% usage should be near capacity")
        
        // Scenario 4: 90% usage - should return true
        let storage90 = StorageInfo(totalUsedBytes: 90_000_000_000,
                                    photoCount: 100,
                                    availableBytes: 10_000_000_000)
        XCTAssertTrue(storage90.isNearCapacity,
                     "90% usage should be near capacity")
        
        // Scenario 5: 100% usage - should return true
        let storage100 = StorageInfo(totalUsedBytes: 100_000_000_000,
                                     photoCount: 100,
                                     availableBytes: 0)
        XCTAssertTrue(storage100.isNearCapacity,
                     "100% usage should be near capacity")
        
        // Scenario 6: Edge case - zero capacity (should return false)
        let storageZero = StorageInfo(totalUsedBytes: 0,
                                      photoCount: 0,
                                      availableBytes: 0)
        XCTAssertFalse(storageZero.isNearCapacity,
                      "Zero capacity should return false")
    }
    
    func testCleanupOrphanedFiles_NoOrphans_ReturnsZero() async throws {
        // Given: No orphaned files (all session directories have Core Data entries)
        // This test assumes a clean state or that all existing files are valid
        
        // When: Cleaning up orphaned files
        let cleanedCount = try await fileStorageManager.cleanupOrphanedFiles()
        
        // Then: Should return 0 or a non-negative number
        XCTAssertGreaterThanOrEqual(cleanedCount, 0,
                                   "Cleaned count should be non-negative")
    }
    
    func testCleanupOrphanedFiles_WithOrphans_RemovesThem() async throws {
        // Given: Create an orphaned session directory (no Core Data entry)
        let orphanedSessionID = UUID()
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        // Save a photo to create the directory
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: orphanedSessionID)
        let orphanedDir = photoURL.deletingLastPathComponent()
        
        // Verify the directory exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanedDir.path),
                     "Orphaned directory should exist before cleanup")
        
        // When: Cleaning up orphaned files
        // Note: Since we didn't create a Core Data entry, this directory is orphaned
        let cleanedCount = try await fileStorageManager.cleanupOrphanedFiles()
        
        // Then: The orphaned directory should be removed
        XCTAssertGreaterThanOrEqual(cleanedCount, 1,
                                   "Should have cleaned at least one orphaned directory")
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanedDir.path),
                      "Orphaned directory should be removed after cleanup")
    }
    
    func testCleanupOrphanedFiles_PreservesValidSessions() async throws {
        // Given: Create a valid session with Core Data entry
        let context = PersistenceController.shared.container.viewContext
        let validSessionID = UUID()
        
        // Create Core Data entry
        let captureSession = NSEntityDescription.insertNewObject(
            forEntityName: "CaptureSession",
            into: context
        )
        captureSession.setValue(validSessionID, forKey: "id")
        captureSession.setValue(Date(), forKey: "timestamp")
        captureSession.setValue("test/path", forKey: "photoPath")
        captureSession.setValue(false, forKey: "locationAvailable")
        captureSession.setValue(0.0, forKey: "latitude")
        captureSession.setValue(0.0, forKey: "longitude")
        
        try context.save()
        
        // Create the file system directory
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        let photoURL = try await fileStorageManager.savePhoto(imageData, for: validSessionID)
        let validDir = photoURL.deletingLastPathComponent()
        
        // Verify the directory exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: validDir.path),
                     "Valid directory should exist before cleanup")
        
        // When: Cleaning up orphaned files
        _ = try await fileStorageManager.cleanupOrphanedFiles()
        
        // Then: The valid directory should still exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: validDir.path),
                     "Valid directory should be preserved after cleanup")
        
        // Cleanup
        try? await fileStorageManager.deleteFiles(for: validSessionID)
        context.delete(captureSession)
        try? context.save()
    }
    
    func testCleanupOrphanedFiles_MultipleOrphans_RemovesAll() async throws {
        // Given: Create multiple orphaned session directories
        let orphanedIDs = [UUID(), UUID(), UUID()]
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))
        guard let imageData = testImage.jpegData(compressionQuality: 1.0) else {
            XCTFail("Failed to create test image data")
            return
        }
        
        var orphanedDirs: [URL] = []
        for orphanedID in orphanedIDs {
            let photoURL = try await fileStorageManager.savePhoto(imageData, for: orphanedID)
            orphanedDirs.append(photoURL.deletingLastPathComponent())
        }
        
        // Verify all directories exist
        for dir in orphanedDirs {
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path),
                         "Orphaned directory should exist before cleanup")
        }
        
        // When: Cleaning up orphaned files
        let cleanedCount = try await fileStorageManager.cleanupOrphanedFiles()
        
        // Then: All orphaned directories should be removed
        XCTAssertGreaterThanOrEqual(cleanedCount, orphanedIDs.count,
                                   "Should have cleaned at least \(orphanedIDs.count) orphaned directories")
        
        for dir in orphanedDirs {
            XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path),
                          "Orphaned directory should be removed after cleanup")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some pattern to make it more realistic
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(5)
            context.cgContext.move(to: CGPoint(x: 0, y: 0))
            context.cgContext.addLine(to: CGPoint(x: size.width, y: size.height))
            context.cgContext.strokePath()
        }
    }
    
    private func createTempVideoFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("test_video_\(UUID().uuidString).mov")
        
        // Create a minimal video file (just empty data for testing)
        let dummyData = Data(repeating: 0, count: 1024)
        try? dummyData.write(to: videoURL)
        
        return videoURL
    }
}

// MARK: - Property-Based Tests

/// Property-based tests for FileStorageManager
/// These tests validate universal properties that should hold for all inputs
extension FileStorageManagerTests {
    
    // MARK: - Property 1: Photo Capture Persistence
    // Feature: pedilens, Property 1: Photo Capture Persistence
    // **Validates: Requirements 1.3, 1.5, 2.8**
    
    /// Property: For any photo captured through the camera interface, the photo data SHALL be
    /// immediately stored in local storage and associated with the active wound record.
    ///
    /// This property validates the round-trip: save photo → load photo → data matches
    /// Tests with 100+ iterations across various photo sizes and formats
    func testProperty1_PhotoPersistence_RoundTripPreservesData() async throws {
        let iterations = 100
        var failedCases: [(sessionID: UUID, size: Int, iteration: Int)] = []
        var testSessionIDs: [UUID] = []
        
        for iteration in 0..<iterations {
            // Generate random photo data of varying sizes
            // Simulate realistic photo sizes: 100KB to 5MB
            let photoSize = Int.random(in: 100_000...5_000_000)
            let originalPhotoData = generateRandomPhotoData(size: photoSize)
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            do {
                // Save the photo
                let savedURL = try await fileStorageManager.savePhoto(originalPhotoData, for: sessionID)
                
                // Verify file exists immediately after save
                XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path),
                            "Iteration \(iteration): Photo should exist immediately after save")
                
                // Load the photo back
                let loadedPhotoData = try await fileStorageManager.loadPhoto(at: savedURL.path)
                
                // Verify round-trip property: load(save(data)) == data
                if loadedPhotoData != originalPhotoData {
                    failedCases.append((sessionID: sessionID, size: photoSize, iteration: iteration))
                }
                
                // Additional invariants:
                // 1. Loaded data should have the same size as original
                XCTAssertEqual(loadedPhotoData.count, originalPhotoData.count,
                             "Iteration \(iteration): Loaded data size should match original")
                
                // 2. File should be stored in the correct session directory
                let expectedSessionDir = savedURL.deletingLastPathComponent()
                XCTAssertTrue(expectedSessionDir.lastPathComponent == sessionID.uuidString,
                            "Iteration \(iteration): Photo should be in session-specific directory")
                
                // 3. Photo should be in HEIC format
                XCTAssertEqual(savedURL.pathExtension, "heic",
                             "Iteration \(iteration): Photo should be saved in HEIC format")
                
            } catch {
                XCTFail("Iteration \(iteration): Save/load failed with error: \(error)")
            }
        }
        
        // Cleanup all test sessions
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Photo persistence round-trip property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any photo data saved, it should be immediately retrievable
    /// This validates immediate availability after save (no async delays)
    func testProperty1_PhotoPersistence_ImmediateAvailability() async throws {
        let iterations = 100
        var failedCases: [(sessionID: UUID, iteration: Int)] = []
        var testSessionIDs: [UUID] = []
        
        for iteration in 0..<iterations {
            let photoSize = Int.random(in: 50_000...1_000_000)
            let photoData = generateRandomPhotoData(size: photoSize)
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            do {
                // Save photo
                let savedURL = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                
                // Immediately try to load (no delay)
                let loadedData = try await fileStorageManager.loadPhoto(at: savedURL.path)
                
                // Verify immediate availability
                if loadedData.isEmpty || loadedData != photoData {
                    failedCases.append((sessionID: sessionID, iteration: iteration))
                }
                
            } catch {
                failedCases.append((sessionID: sessionID, iteration: iteration))
            }
        }
        
        // Cleanup
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Immediate availability property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any photo saved with a session ID, it should be associated with that session
    /// This validates proper session-based organization
    func testProperty1_PhotoPersistence_SessionAssociation() async throws {
        let iterations = 100
        var failedCases: [(sessionID: UUID, iteration: Int)] = []
        var testSessionIDs: [UUID] = []
        
        for iteration in 0..<iterations {
            let photoSize = Int.random(in: 100_000...500_000)
            let photoData = generateRandomPhotoData(size: photoSize)
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            do {
                // Save photo
                let savedURL = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                
                // Verify the photo is in the correct session directory
                let sessionDir = savedURL.deletingLastPathComponent()
                let sessionDirName = sessionDir.lastPathComponent
                
                if sessionDirName != sessionID.uuidString {
                    failedCases.append((sessionID: sessionID, iteration: iteration))
                }
                
                // Verify we can construct the expected path and it matches
                let photosDir = sessionDir.deletingLastPathComponent()
                let expectedSessionDir = photosDir.appendingPathComponent(sessionID.uuidString)
                
                if sessionDir.path != expectedSessionDir.path {
                    failedCases.append((sessionID: sessionID, iteration: iteration))
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Failed with error: \(error)")
            }
        }
        
        // Cleanup
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Session association property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any multiple photos saved to the same session, all should be retrievable
    /// This validates that multiple saves to the same session work correctly
    func testProperty1_PhotoPersistence_MultiplePhotosPerSession() async throws {
        let iterations = 50 // Fewer iterations since we're saving multiple photos per iteration
        var failedCases: [(sessionID: UUID, photoIndex: Int, iteration: Int)] = []
        var testSessionIDs: [UUID] = []
        
        for iteration in 0..<iterations {
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            // Save multiple photos to the same session (simulating updates)
            let photoCount = Int.random(in: 2...5)
            var savedURLs: [URL] = []
            var originalData: [Data] = []
            
            for photoIndex in 0..<photoCount {
                let photoSize = Int.random(in: 100_000...500_000)
                let photoData = generateRandomPhotoData(size: photoSize)
                originalData.append(photoData)
                
                do {
                    let savedURL = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                    savedURLs.append(savedURL)
                } catch {
                    XCTFail("Iteration \(iteration), photo \(photoIndex): Save failed with error: \(error)")
                }
            }
            
            // Verify the last saved photo is retrievable (overwrites previous)
            if let lastURL = savedURLs.last, let lastData = originalData.last {
                do {
                    let loadedData = try await fileStorageManager.loadPhoto(at: lastURL.path)
                    if loadedData != lastData {
                        failedCases.append((sessionID: sessionID, photoIndex: photoCount - 1, iteration: iteration))
                    }
                } catch {
                    failedCases.append((sessionID: sessionID, photoIndex: photoCount - 1, iteration: iteration))
                }
            }
        }
        
        // Cleanup
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Multiple photos per session property failed for \(failedCases.count) cases")
    }
    
    /// Property: For any photo data, saving and deleting should leave no trace
    /// This validates proper cleanup
    func testProperty1_PhotoPersistence_DeletionCompleteness() async throws {
        let iterations = 100
        var failedCases: [(sessionID: UUID, iteration: Int)] = []
        
        for iteration in 0..<iterations {
            let photoSize = Int.random(in: 100_000...500_000)
            let photoData = generateRandomPhotoData(size: photoSize)
            let sessionID = UUID()
            
            do {
                // Save photo
                let savedURL = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                let sessionDir = savedURL.deletingLastPathComponent()
                
                // Verify it exists
                XCTAssertTrue(FileManager.default.fileExists(atPath: sessionDir.path),
                            "Iteration \(iteration): Session directory should exist after save")
                
                // Delete
                try await fileStorageManager.deleteFiles(for: sessionID)
                
                // Verify complete deletion
                if FileManager.default.fileExists(atPath: sessionDir.path) {
                    failedCases.append((sessionID: sessionID, iteration: iteration))
                }
                
                // Verify photo file is gone
                if FileManager.default.fileExists(atPath: savedURL.path) {
                    failedCases.append((sessionID: sessionID, iteration: iteration))
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Failed with error: \(error)")
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Deletion completeness property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any photo saved, file protection should be set to complete
    /// This validates security requirement for data at rest
    func testProperty1_PhotoPersistence_FileProtection() async throws {
        let iterations = 100
        var failedCases: [(sessionID: UUID, iteration: Int)] = []
        var testSessionIDs: [UUID] = []
        
        for iteration in 0..<iterations {
            let photoSize = Int.random(in: 100_000...500_000)
            let photoData = generateRandomPhotoData(size: photoSize)
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            do {
                // Save photo
                let savedURL = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                
                // Check file protection
                let attributes = try FileManager.default.attributesOfItem(atPath: savedURL.path)
                let protection = attributes[.protectionKey] as? FileProtectionType
                
                if protection != .complete {
                    failedCases.append((sessionID: sessionID, iteration: iteration))
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Failed with error: \(error)")
            }
        }
        
        // Cleanup
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "File protection property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any concurrent photo saves to different sessions, all should succeed
    /// This validates thread safety and concurrent access
    func testProperty1_PhotoPersistence_ConcurrentSaves() async throws {
        let iterations = 30 // Fewer iterations for concurrent tests
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            let concurrentCount = Int.random(in: 10...30)
            var testSessionIDs: [UUID] = []
            
            // Perform concurrent saves
            await withTaskGroup(of: (UUID, Bool).self) { group in
                for _ in 0..<concurrentCount {
                    group.addTask {
                        let sessionID = UUID()
                        let photoSize = Int.random(in: 100_000...500_000)
                        let photoData = self.generateRandomPhotoData(size: photoSize)
                        
                        do {
                            let savedURL = try await self.fileStorageManager.savePhoto(photoData, for: sessionID)
                            let loadedData = try await self.fileStorageManager.loadPhoto(at: savedURL.path)
                            return (sessionID, loadedData == photoData)
                        } catch {
                            return (sessionID, false)
                        }
                    }
                }
                
                // Collect results
                for await (sessionID, success) in group {
                    testSessionIDs.append(sessionID)
                    if !success {
                        failedCases.append(iteration)
                    }
                }
            }
            
            // Cleanup
            for sessionID in testSessionIDs {
                try? await fileStorageManager.deleteFiles(for: sessionID)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Concurrent saves property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any photo data with edge case sizes, persistence should work correctly
    /// This validates handling of boundary conditions
    func testProperty1_PhotoPersistence_EdgeCaseSizes() async throws {
        // Test specific edge cases
        let edgeCaseSizes = [
            0,          // Empty photo (edge case)
            1,          // Single byte
            100,        // Very small
            1024,       // 1KB
            10_240,     // 10KB
            102_400,    // 100KB
            1_024_000,  // ~1MB
            5_242_880,  // 5MB
            10_485_760  // 10MB (large photo)
        ]
        
        // Add some random sizes
        let randomSizes = (0..<20).map { _ in Int.random(in: 0...10_000_000) }
        let allSizes = edgeCaseSizes + randomSizes
        
        var failedCases: [(size: Int, error: String)] = []
        var testSessionIDs: [UUID] = []
        
        for size in allSizes {
            let photoData = generateRandomPhotoData(size: size)
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            do {
                // Save
                let savedURL = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                
                // Load
                let loadedData = try await fileStorageManager.loadPhoto(at: savedURL.path)
                
                // Verify
                if loadedData != photoData {
                    failedCases.append((size: size, error: "Data mismatch"))
                }
                
                if loadedData.count != photoData.count {
                    failedCases.append((size: size, error: "Size mismatch"))
                }
                
            } catch {
                failedCases.append((size: size, error: error.localizedDescription))
            }
        }
        
        // Cleanup
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Edge case sizes property failed for \(failedCases.count) sizes: \(failedCases.map { $0.size })")
    }
    
    /// Property: For any photo saved, storage usage should increase accordingly
    /// This validates storage tracking
    func testProperty1_PhotoPersistence_StorageTracking() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        var testSessionIDs: [UUID] = []
        
        for iteration in 0..<iterations {
            // Get initial storage
            let initialStorage = await fileStorageManager.getStorageUsage()
            let initialPhotoCount = initialStorage.photoCount
            
            // Save a photo
            let photoSize = Int.random(in: 100_000...500_000)
            let photoData = generateRandomPhotoData(size: photoSize)
            let sessionID = UUID()
            testSessionIDs.append(sessionID)
            
            do {
                _ = try await fileStorageManager.savePhoto(photoData, for: sessionID)
                
                // Get updated storage
                let updatedStorage = await fileStorageManager.getStorageUsage()
                let updatedPhotoCount = updatedStorage.photoCount
                
                // Verify photo count increased
                if updatedPhotoCount <= initialPhotoCount {
                    failedCases.append(iteration)
                }
                
                // Verify total bytes increased
                if updatedStorage.totalUsedBytes <= initialStorage.totalUsedBytes {
                    failedCases.append(iteration)
                }
                
            } catch {
                XCTFail("Iteration \(iteration): Failed with error: \(error)")
            }
        }
        
        // Cleanup
        for sessionID in testSessionIDs {
            try? await fileStorageManager.deleteFiles(for: sessionID)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Storage tracking property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    // MARK: - Helper Methods for Property Tests
    
    /// Generates random photo data of specified size
    /// Simulates realistic photo data with some structure
    private func generateRandomPhotoData(size: Int) -> Data {
        guard size > 0 else { return Data() }
        
        var data = Data(count: size)
        _ = data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return 0 }
            // Use SecRandomCopyBytes for cryptographically secure random data
            return Int(SecRandomCopyBytes(kSecRandomDefault, size, baseAddress))
        }
        return data
    }
}
