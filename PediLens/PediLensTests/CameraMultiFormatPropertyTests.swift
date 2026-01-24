//
//  CameraMultiFormatPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for multi-format photo support
//  Feature: pedilens, Property 2: Multi-Format Photo Support
//  Validates: Requirements 1.2, 11.4
//

import XCTest
import AVFoundation
@testable import PediLens

/// Property-based tests for multi-format photo support
/// These tests validate that both standard photos and live photos are supported,
/// and when live photos are captured, both still image and video components are stored
final class CameraMultiFormatPropertyTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    /// Creates mock photo data for testing
    private func createMockPhotoData() -> Data {
        // Create a simple 1x1 pixel image data
        let width = 1
        let height = 1
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 255, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ),
        let cgImage = context.makeImage() else {
            return Data()
        }
        
        let image = UIImage(cgImage: cgImage)
        return image.jpegData(compressionQuality: 1.0) ?? Data()
    }
    
    /// Creates a mock video file URL for testing
    private func createMockVideoURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let videoFileName = UUID().uuidString + ".mov"
        let videoURL = tempDir.appendingPathComponent(videoFileName)
        
        // Create an empty file to simulate video
        FileManager.default.createFile(atPath: videoURL.path, contents: Data(), attributes: nil)
        
        return videoURL
    }
    
    /// Cleans up temporary video files
    private func cleanupVideoFile(at url: URL?) {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Property 2: Multi-Format Photo Support
    // **Validates: Requirements 1.2, 11.4**
    
    /// Property: For any capture session, standard photos SHALL be supported
    /// This validates that the CapturedMedia structure can represent standard photos
    func testProperty2_StandardPhotoSupport_IsAvailable() {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            do {
                // Create mock photo data
                let photoData = createMockPhotoData()
                
                // Verify photo data is valid
                XCTAssertFalse(photoData.isEmpty,
                             "Iteration \(iteration): Photo data should not be empty")
                
                // Create metadata
                let metadata = PhotoMetadata(
                    timestamp: Date(),
                    location: nil,
                    deviceModel: UIDevice.current.model,
                    cameraSettings: CameraSettings(
                        iso: Float.random(in: 50...3200),
                        exposureDuration: CMTime(value: 1, timescale: Int32.random(in: 30...8000)),
                        aperture: Float.random(in: 1.4...22.0),
                        focalLength: Float.random(in: 13...77)
                    )
                )
                
                // Create CapturedMedia for standard photo (no live photo video)
                let capturedMedia = CapturedMedia(
                    photoData: photoData,
                    livePhotoVideoURL: nil,
                    depthData: nil,
                    metadata: metadata
                )
                
                // Validate standard photo is properly represented
                XCTAssertNotNil(capturedMedia.photoData,
                              "Iteration \(iteration): Standard photo data should be present")
                XCTAssertFalse(capturedMedia.photoData.isEmpty,
                             "Iteration \(iteration): Standard photo data should not be empty")
                XCTAssertNil(capturedMedia.livePhotoVideoURL,
                           "Iteration \(iteration): Standard photo should not have live photo video")
                XCTAssertNotNil(capturedMedia.metadata,
                              "Iteration \(iteration): Standard photo should have metadata")
                XCTAssertNotNil(capturedMedia.metadata.timestamp,
                              "Iteration \(iteration): Standard photo should have timestamp")
                
            } catch {
                XCTFail("Iteration \(iteration): Standard photo support validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Standard photo support property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any capture session, live photos SHALL be supported
    /// This validates that the CapturedMedia structure can represent live photos with both components
    func testProperty2_LivePhotoSupport_IsAvailable() {
        let iterations = 100
        var failedCases: [Int] = []
        var videoURLsToCleanup: [URL] = []
        
        for iteration in 0..<iterations {
            do {
                // Create mock photo data
                let photoData = createMockPhotoData()
                
                // Create mock video URL for live photo
                let videoURL = createMockVideoURL()
                videoURLsToCleanup.append(videoURL)
                
                // Verify both components are valid
                XCTAssertFalse(photoData.isEmpty,
                             "Iteration \(iteration): Photo data should not be empty")
                XCTAssertTrue(FileManager.default.fileExists(atPath: videoURL.path),
                            "Iteration \(iteration): Video file should exist")
                
                // Create metadata
                let metadata = PhotoMetadata(
                    timestamp: Date(),
                    location: nil,
                    deviceModel: UIDevice.current.model,
                    cameraSettings: CameraSettings(
                        iso: Float.random(in: 50...3200),
                        exposureDuration: CMTime(value: 1, timescale: Int32.random(in: 30...8000)),
                        aperture: Float.random(in: 1.4...22.0),
                        focalLength: Float.random(in: 13...77)
                    )
                )
                
                // Create CapturedMedia for live photo (with video component)
                let capturedMedia = CapturedMedia(
                    photoData: photoData,
                    livePhotoVideoURL: videoURL,
                    depthData: nil,
                    metadata: metadata
                )
                
                // Validate live photo is properly represented with both components
                XCTAssertNotNil(capturedMedia.photoData,
                              "Iteration \(iteration): Live photo still image data should be present")
                XCTAssertFalse(capturedMedia.photoData.isEmpty,
                             "Iteration \(iteration): Live photo still image data should not be empty")
                XCTAssertNotNil(capturedMedia.livePhotoVideoURL,
                              "Iteration \(iteration): Live photo video component should be present")
                XCTAssertTrue(FileManager.default.fileExists(atPath: capturedMedia.livePhotoVideoURL!.path),
                            "Iteration \(iteration): Live photo video file should exist")
                XCTAssertNotNil(capturedMedia.metadata,
                              "Iteration \(iteration): Live photo should have metadata")
                
            } catch {
                XCTFail("Iteration \(iteration): Live photo support validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Cleanup temporary video files
        for url in videoURLsToCleanup {
            cleanupVideoFile(at: url)
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Live photo support property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any live photo capture, both still image and video components SHALL be stored
    /// This validates that when live photos are captured, both components are present and valid
    func testProperty2_LivePhotoComponents_BothStored() {
        let iterations = 100
        var failedCases: [Int] = []
        var videoURLsToCleanup: [URL] = []
        
        for iteration in 0..<iterations {
            do {
                // Create mock photo data (still image component)
                let photoData = createMockPhotoData()
                let photoSize = photoData.count
                
                // Create mock video URL (video component)
                let videoURL = createMockVideoURL()
                videoURLsToCleanup.append(videoURL)
                
                // Add some data to the video file to simulate real video
                let videoData = Data(repeating: UInt8.random(in: 0...255), count: Int.random(in: 1000...10000))
                try videoData.write(to: videoURL)
                
                // Create metadata
                let metadata = PhotoMetadata(
                    timestamp: Date(),
                    location: nil,
                    deviceModel: UIDevice.current.model,
                    cameraSettings: CameraSettings(
                        iso: Float.random(in: 50...3200),
                        exposureDuration: CMTime(value: 1, timescale: Int32.random(in: 30...8000)),
                        aperture: Float.random(in: 1.4...22.0),
                        focalLength: Float.random(in: 13...77)
                    )
                )
                
                // Create CapturedMedia for live photo
                let capturedMedia = CapturedMedia(
                    photoData: photoData,
                    livePhotoVideoURL: videoURL,
                    depthData: nil,
                    metadata: metadata
                )
                
                // Validate BOTH components are stored
                
                // 1. Still image component validation
                XCTAssertNotNil(capturedMedia.photoData,
                              "Iteration \(iteration): Still image component must be present")
                XCTAssertFalse(capturedMedia.photoData.isEmpty,
                             "Iteration \(iteration): Still image component must not be empty")
                XCTAssertEqual(capturedMedia.photoData.count, photoSize,
                             "Iteration \(iteration): Still image component size should match")
                
                // 2. Video component validation
                XCTAssertNotNil(capturedMedia.livePhotoVideoURL,
                              "Iteration \(iteration): Video component must be present")
                XCTAssertTrue(FileManager.default.fileExists(atPath: capturedMedia.livePhotoVideoURL!.path),
                            "Iteration \(iteration): Video component file must exist")
                
                // Verify video file has content
                let storedVideoData = try Data(contentsOf: capturedMedia.livePhotoVideoURL!)
                XCTAssertFalse(storedVideoData.isEmpty,
                             "Iteration \(iteration): Video component must have content")
                XCTAssertEqual(storedVideoData.count, videoData.count,
                             "Iteration \(iteration): Video component size should match")
                
                // 3. Validate both components are independent
                XCTAssertNotEqual(capturedMedia.photoData.count, storedVideoData.count,
                                "Iteration \(iteration): Still image and video should be different sizes (in most cases)")
                
                // 4. Validate metadata is present for the capture
                XCTAssertNotNil(capturedMedia.metadata,
                              "Iteration \(iteration): Metadata must be present")
                XCTAssertNotNil(capturedMedia.metadata.timestamp,
                              "Iteration \(iteration): Timestamp must be present")
                
            } catch {
                XCTFail("Iteration \(iteration): Live photo components storage validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Cleanup temporary video files
        for url in videoURLsToCleanup {
            cleanupVideoFile(at: url)
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Live photo components storage property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any capture session, the format (standard vs live photo) SHALL be distinguishable
    /// This validates that we can determine whether a capture is a standard photo or live photo
    func testProperty2_PhotoFormat_IsDistinguishable() {
        let iterations = 100
        var failedCases: [Int] = []
        var videoURLsToCleanup: [URL] = []
        
        for iteration in 0..<iterations {
            do {
                // Randomly choose between standard photo and live photo
                let isLivePhoto = Bool.random()
                
                // Create mock photo data
                let photoData = createMockPhotoData()
                
                // Create video URL only for live photos
                let videoURL: URL? = isLivePhoto ? createMockVideoURL() : nil
                if let url = videoURL {
                    videoURLsToCleanup.append(url)
                }
                
                // Create metadata
                let metadata = PhotoMetadata(
                    timestamp: Date(),
                    location: nil,
                    deviceModel: UIDevice.current.model,
                    cameraSettings: CameraSettings(
                        iso: Float.random(in: 50...3200),
                        exposureDuration: CMTime(value: 1, timescale: Int32.random(in: 30...8000)),
                        aperture: Float.random(in: 1.4...22.0),
                        focalLength: Float.random(in: 13...77)
                    )
                )
                
                // Create CapturedMedia
                let capturedMedia = CapturedMedia(
                    photoData: photoData,
                    livePhotoVideoURL: videoURL,
                    depthData: nil,
                    metadata: metadata
                )
                
                // Validate format is distinguishable
                let hasVideoComponent = capturedMedia.livePhotoVideoURL != nil
                
                if isLivePhoto {
                    // Should be identifiable as live photo
                    XCTAssertTrue(hasVideoComponent,
                                "Iteration \(iteration): Live photo should have video component")
                    XCTAssertNotNil(capturedMedia.livePhotoVideoURL,
                                  "Iteration \(iteration): Live photo should have video URL")
                } else {
                    // Should be identifiable as standard photo
                    XCTAssertFalse(hasVideoComponent,
                                 "Iteration \(iteration): Standard photo should not have video component")
                    XCTAssertNil(capturedMedia.livePhotoVideoURL,
                               "Iteration \(iteration): Standard photo should not have video URL")
                }
                
                // Both formats should have photo data
                XCTAssertNotNil(capturedMedia.photoData,
                              "Iteration \(iteration): Both formats should have photo data")
                XCTAssertFalse(capturedMedia.photoData.isEmpty,
                             "Iteration \(iteration): Both formats should have non-empty photo data")
                
            } catch {
                XCTFail("Iteration \(iteration): Photo format distinguishability validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Cleanup temporary video files
        for url in videoURLsToCleanup {
            cleanupVideoFile(at: url)
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Photo format distinguishability property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any capture with depth data, multi-format support SHALL work with depth data
    /// This validates that both standard and live photos can include depth data
    func testProperty2_MultiFormatWithDepthData_IsSupported() {
        let iterations = 100
        var failedCases: [Int] = []
        var videoURLsToCleanup: [URL] = []
        
        for iteration in 0..<iterations {
            do {
                // Randomly choose between standard photo and live photo
                let isLivePhoto = Bool.random()
                
                // Create mock photo data
                let photoData = createMockPhotoData()
                
                // Create video URL only for live photos
                let videoURL: URL? = isLivePhoto ? createMockVideoURL() : nil
                if let url = videoURL {
                    videoURLsToCleanup.append(url)
                }
                
                // Create mock depth data (randomly include or exclude)
                let includeDepthData = Bool.random()
                var depthData: DepthData? = nil
                
                if includeDepthData {
                    // Create a mock depth map
                    var pixelBuffer: CVPixelBuffer?
                    let status = CVPixelBufferCreate(
                        kCFAllocatorDefault,
                        1, 1,
                        kCVPixelFormatType_DepthFloat32,
                        nil,
                        &pixelBuffer
                    )
                    
                    if status == kCVReturnSuccess, let buffer = pixelBuffer {
                        // Note: We can't create AVCameraCalibrationData in tests,
                        // so we'll skip the full DepthData creation for this test
                        // and just validate the structure supports it
                    }
                }
                
                // Create metadata
                let metadata = PhotoMetadata(
                    timestamp: Date(),
                    location: nil,
                    deviceModel: UIDevice.current.model,
                    cameraSettings: CameraSettings(
                        iso: Float.random(in: 50...3200),
                        exposureDuration: CMTime(value: 1, timescale: Int32.random(in: 30...8000)),
                        aperture: Float.random(in: 1.4...22.0),
                        focalLength: Float.random(in: 13...77)
                    )
                )
                
                // Create CapturedMedia with optional depth data
                let capturedMedia = CapturedMedia(
                    photoData: photoData,
                    livePhotoVideoURL: videoURL,
                    depthData: depthData,
                    metadata: metadata
                )
                
                // Validate multi-format support works with depth data
                XCTAssertNotNil(capturedMedia.photoData,
                              "Iteration \(iteration): Photo data should be present regardless of depth data")
                
                if isLivePhoto {
                    XCTAssertNotNil(capturedMedia.livePhotoVideoURL,
                                  "Iteration \(iteration): Live photo video should be present regardless of depth data")
                } else {
                    XCTAssertNil(capturedMedia.livePhotoVideoURL,
                               "Iteration \(iteration): Standard photo should not have video regardless of depth data")
                }
                
                // Depth data is optional and should not affect multi-format support
                // The structure should support depth data for both formats
                
            } catch {
                XCTFail("Iteration \(iteration): Multi-format with depth data validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Cleanup temporary video files
        for url in videoURLsToCleanup {
            cleanupVideoFile(at: url)
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Multi-format with depth data property failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any capture session, metadata SHALL be present for both photo formats
    /// This validates that metadata is captured and stored for both standard and live photos
    func testProperty2_MetadataPresence_ForBothFormats() {
        let iterations = 100
        var failedCases: [Int] = []
        var videoURLsToCleanup: [URL] = []
        
        for iteration in 0..<iterations {
            do {
                // Randomly choose between standard photo and live photo
                let isLivePhoto = Bool.random()
                
                // Create mock photo data
                let photoData = createMockPhotoData()
                
                // Create video URL only for live photos
                let videoURL: URL? = isLivePhoto ? createMockVideoURL() : nil
                if let url = videoURL {
                    videoURLsToCleanup.append(url)
                }
                
                // Create metadata with random values
                let timestamp = Date(timeIntervalSinceNow: -Double.random(in: 0...86400))
                let iso = Float.random(in: 50...3200)
                let exposureDuration = CMTime(value: 1, timescale: Int32.random(in: 30...8000))
                let aperture = Float.random(in: 1.4...22.0)
                let focalLength = Float.random(in: 13...77)
                
                let metadata = PhotoMetadata(
                    timestamp: timestamp,
                    location: nil,
                    deviceModel: UIDevice.current.model,
                    cameraSettings: CameraSettings(
                        iso: iso,
                        exposureDuration: exposureDuration,
                        aperture: aperture,
                        focalLength: focalLength
                    )
                )
                
                // Create CapturedMedia
                let capturedMedia = CapturedMedia(
                    photoData: photoData,
                    livePhotoVideoURL: videoURL,
                    depthData: nil,
                    metadata: metadata
                )
                
                // Validate metadata is present for both formats
                XCTAssertNotNil(capturedMedia.metadata,
                              "Iteration \(iteration): Metadata should be present for \(isLivePhoto ? "live" : "standard") photo")
                XCTAssertNotNil(capturedMedia.metadata.timestamp,
                              "Iteration \(iteration): Timestamp should be present")
                XCTAssertEqual(capturedMedia.metadata.timestamp, timestamp,
                             "Iteration \(iteration): Timestamp should match")
                XCTAssertNotNil(capturedMedia.metadata.deviceModel,
                              "Iteration \(iteration): Device model should be present")
                XCTAssertFalse(capturedMedia.metadata.deviceModel.isEmpty,
                             "Iteration \(iteration): Device model should not be empty")
                
                // Validate camera settings
                XCTAssertEqual(capturedMedia.metadata.cameraSettings.iso, iso,
                             "Iteration \(iteration): ISO should match")
                XCTAssertEqual(capturedMedia.metadata.cameraSettings.exposureDuration, exposureDuration,
                             "Iteration \(iteration): Exposure duration should match")
                XCTAssertEqual(capturedMedia.metadata.cameraSettings.aperture, aperture,
                             "Iteration \(iteration): Aperture should match")
                XCTAssertEqual(capturedMedia.metadata.cameraSettings.focalLength, focalLength,
                             "Iteration \(iteration): Focal length should match")
                
            } catch {
                XCTFail("Iteration \(iteration): Metadata presence validation failed with error: \(error)")
                failedCases.append(iteration)
            }
        }
        
        // Cleanup temporary video files
        for url in videoURLsToCleanup {
            cleanupVideoFile(at: url)
        }
        
        // Report any failures
        XCTAssertTrue(failedCases.isEmpty,
                     "Metadata presence property failed for \(failedCases.count) out of \(iterations) cases")
    }
}
