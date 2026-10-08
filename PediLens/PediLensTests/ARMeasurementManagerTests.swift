//
//  ARMeasurementManagerTests.swift
//  PediLensTests
//
//  Unit tests for ARMeasurementManager
//

import XCTest
import CoreVideo
import ARKit
@testable import PediLens

class ARMeasurementManagerTests: XCTestCase {
    
    var manager: ARMeasurementManager!
    
    override func setUp() {
        super.setUp()
        manager = ARMeasurementManager()
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Distance Classification Tests
    
    func testClassifyDistance_TooClose() {
        let status = ARMeasurementManager.classifyDistance(0.10)
        XCTAssertEqual(status, .tooClose, "Distance under 15cm should be classified as too close")
        XCTAssertFalse(status.isOptimal)
    }
    
    func testClassifyDistance_OptimalRange() {
        let status1 = ARMeasurementManager.classifyDistance(0.15)
        XCTAssertEqual(status1, .optimal, "15cm should be within optimal range")
        XCTAssertTrue(status1.isOptimal)
        
        let status2 = ARMeasurementManager.classifyDistance(0.25)
        XCTAssertEqual(status2, .optimal, "25cm should be within optimal range")
        XCTAssertTrue(status2.isOptimal)
        
        let status3 = ARMeasurementManager.classifyDistance(0.35)
        XCTAssertEqual(status3, .optimal, "35cm should be within optimal range")
        XCTAssertTrue(status3.isOptimal)
    }
    
    func testClassifyDistance_TooFar() {
        let status = ARMeasurementManager.classifyDistance(0.45)
        XCTAssertEqual(status, .tooFar, "Distance over 35cm should be classified as too far")
        XCTAssertFalse(status.isOptimal)
    }
    
    // MARK: - Buffer Reading Tests
    
    func testReadDepth_Float32Buffer_ReadsAccurateDepth() {
        var pixelBuffer: CVPixelBuffer?
        let width = 10
        let height = 10
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_DepthFloat32,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer = pixelBuffer else {
            XCTFail("Failed to allocate pixel buffer")
            return
        }
        
        // Write test depth values (0.28 meters = 28cm)
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                row[x] = 0.28
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        // Read center depth
        let depth = ARMeasurementManager.readDepth(at: CGPoint(x: 0.5, y: 0.5), from: buffer)
        XCTAssertNotNil(depth)
        XCTAssertEqual(depth ?? 0, 0.28, accuracy: 0.001)
    }
    
    func testReadDepth_Float16Buffer_ReadsAccurateDepth() {
        var pixelBuffer: CVPixelBuffer?
        let width = 4
        let height = 4
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_DepthFloat16,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer = pixelBuffer else {
            XCTFail("Failed to allocate pixel buffer")
            return
        }
        
        // Write test depth value (0.32 meters)
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt16.self)
            for x in 0..<width {
                let f16 = Float16(0.32)
                row[x] = f16.bitPattern
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        let depth = ARMeasurementManager.readDepth(at: CGPoint(x: 0.5, y: 0.5), from: buffer)
        XCTAssertNotNil(depth)
        XCTAssertEqual(Double(depth ?? 0), 0.32, accuracy: 0.01)
    }
    
    func testReadConfidence_ConfidenceMap_ReturnsNormalizedConfidence() {
        var pixelBuffer: CVPixelBuffer?
        let width = 4
        let height = 4
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width, height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer = pixelBuffer else {
            XCTFail("Failed to allocate pixel buffer")
            return
        }
        
        // Write high confidence (2)
        CVPixelBufferLockBaseAddress(buffer, [])
        let base = CVPixelBufferGetBaseAddress(buffer)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                row[x] = 2 // High confidence
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        let confidence = ARMeasurementManager.readConfidence(at: CGPoint(x: 0.5, y: 0.5), from: buffer)
        XCTAssertNotNil(confidence)
        XCTAssertEqual(confidence ?? 0, 0.95, accuracy: 0.05)
    }
    
    // MARK: - LiDAR Depth Info Optics
    
    func testLiDARDepthInfo_PixelsPerCentimeterCalculation() {
        let depthInfo = LiDARDepthInfo(
            depth: 0.30, // 30cm
            confidence: 0.95,
            fieldOfView: CGSize(width: 0.20, height: 0.15), // 20cm x 15cm FOV at 30cm
            imageSize: CGSize(width: 2000, height: 1500)
        )
        
        // 20cm wide FOV with 2000px image => 100 pixels per cm
        XCTAssertEqual(Double(depthInfo.pixelsPerCentimeter), 100.0, accuracy: 0.01)
        
        // Calibration conversion
        let calibration = MeasurementCalibration.fromLiDAR(depthInfo)
        XCTAssertEqual(calibration.pixelsPerMillimeter, 10.0, accuracy: 0.01)
        XCTAssertEqual(calibration.accuracy, .high)
    }
}
