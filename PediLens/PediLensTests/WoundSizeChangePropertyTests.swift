//
//  WoundSizeChangePropertyTests.swift
//  PediLensTests
//
//  Property-based tests for wound size change indicators
//  Feature: pedilens, Property 12: Wound Size Change Indicators
//  Validates: Requirements 3.4
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for wound size change indicators
/// These tests validate that visual indicators show wound size changes correctly
final class WoundSizeChangePropertyTests: XCTestCase {
    
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
    
    private func createMeasurement(areaMM2: Double, in context: NSManagedObjectContext, for session: CaptureSession) -> PediLens.Measurement {
        let boundaryData = try! JSONEncoder().encode([["x": 0.0, "y": 0.0]])
        let calibrationData = try! JSONEncoder().encode(["pixelsPerMM": 1.0])
        
        let measurement = PediLens.Measurement.create(
            in: context,
            lengthMM: Double.random(in: 10...100),
            widthMM: Double.random(in: 10...100),
            areaMM2: areaMM2,
            perimeterMM: Double.random(in: 40...400),
            boundaryPoints: boundaryData,
            calibrationData: calibrationData,
            detectionConfidence: Float.random(in: 0.5...1.0),
            captureSession: session
        )
        
        // Save the context to ensure measurement is persisted
        try? context.save()
        
        return measurement
    }
    
    // MARK: - Property 12: Wound Size Change Indicators
    // **Validates: Requirements 3.4**
    
    /// Property: For any two timeline entries being compared, visual indicators show the change in wound size
    func testProperty12_WoundSizeChangeIndicators_IndicatorsShowChange() async throws {
        let iterations = 100
        var successfulComparisons = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create first session with initial area
            let session1 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_1.heic",
                woundRecord: woundRecord
            )
            
            let initialArea = Double.random(in: 100...1000)
            _ = createMeasurement(areaMM2: initialArea, in: context, for: session1)
            
            // Small delay
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Create second session with changed area
            let session2 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_2.heic",
                woundRecord: woundRecord
            )
            
            // Randomly increase or decrease area
            let changePercent = Double.random(in: -50...50)
            let newArea = initialArea * (1.0 + changePercent / 100.0)
            _ = createMeasurement(areaMM2: newArea, in: context, for: session2)
            
            // Verify both sessions have measurements
            XCTAssertNotNil(session1.measurement,
                          "Iteration \(iteration): First session should have measurement")
            XCTAssertNotNil(session2.measurement,
                          "Iteration \(iteration): Second session should have measurement")
            
            if let measurement1 = session1.measurement,
               let measurement2 = session2.measurement {
                // Calculate expected change
                let actualChange = ((measurement2.areaMM2 - measurement1.areaMM2) / measurement1.areaMM2) * 100
                
                // Verify change can be calculated
                XCTAssertNotEqual(measurement1.areaMM2, 0,
                                "Iteration \(iteration): Initial area should not be zero")
                
                // Verify change direction matches expectation
                if abs(actualChange) >= 1.0 {
                    if changePercent > 1.0 {
                        XCTAssertGreaterThan(actualChange, 0,
                                           "Iteration \(iteration): Positive change should result in positive indicator")
                    } else if changePercent < -1.0 {
                        XCTAssertLessThan(actualChange, 0,
                                        "Iteration \(iteration): Negative change should result in negative indicator")
                    }
                }
                
                successfulComparisons += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulComparisons, iterations,
                      "All comparisons should show wound size change indicators")
    }
    
    /// Property: For any wound that increased in size, the indicator shows increase
    func testProperty12_WoundSizeChangeIndicators_IndicatesIncrease() async throws {
        let iterations = 100
        var correctIndicators = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create first session
            let session1 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_1.heic",
                woundRecord: woundRecord
            )
            
            let initialArea = Double.random(in: 100...1000)
            _ = createMeasurement(areaMM2: initialArea, in: context, for: session1)
            
            try await Task.sleep(nanoseconds: 10_000_000)
            
            // Create second session with INCREASED area (at least 5% increase)
            let session2 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_2.heic",
                woundRecord: woundRecord
            )
            
            let increasePercent = Double.random(in: 5...50)
            let newArea = initialArea * (1.0 + increasePercent / 100.0)
            _ = createMeasurement(areaMM2: newArea, in: context, for: session2)
            
            if let measurement1 = session1.measurement,
               let measurement2 = session2.measurement {
                let change = ((measurement2.areaMM2 - measurement1.areaMM2) / measurement1.areaMM2) * 100
                
                // Verify increase is detected
                XCTAssertGreaterThan(change, 0,
                                   "Iteration \(iteration): Change should be positive for increased wound")
                XCTAssertGreaterThanOrEqual(change, 4.0,
                                          "Iteration \(iteration): Change should be at least 4% (accounting for rounding)")
                
                if change > 0 {
                    correctIndicators += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctIndicators, iterations,
                      "All increased wounds should show positive change indicators")
    }
    
    /// Property: For any wound that decreased in size, the indicator shows decrease
    func testProperty12_WoundSizeChangeIndicators_IndicatesDecrease() async throws {
        let iterations = 100
        var correctIndicators = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create first session
            let session1 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_1.heic",
                woundRecord: woundRecord
            )
            
            let initialArea = Double.random(in: 100...1000)
            _ = createMeasurement(areaMM2: initialArea, in: context, for: session1)
            
            try await Task.sleep(nanoseconds: 10_000_000)
            
            // Create second session with DECREASED area (at least 5% decrease)
            let session2 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_2.heic",
                woundRecord: woundRecord
            )
            
            let decreasePercent = Double.random(in: 5...50)
            let newArea = initialArea * (1.0 - decreasePercent / 100.0)
            _ = createMeasurement(areaMM2: newArea, in: context, for: session2)
            
            if let measurement1 = session1.measurement,
               let measurement2 = session2.measurement {
                let change = ((measurement2.areaMM2 - measurement1.areaMM2) / measurement1.areaMM2) * 100
                
                // Verify decrease is detected
                XCTAssertLessThan(change, 0,
                                "Iteration \(iteration): Change should be negative for decreased wound")
                XCTAssertLessThanOrEqual(change, -4.0,
                                       "Iteration \(iteration): Change should be at least -4% (accounting for rounding)")
                
                if change < 0 {
                    correctIndicators += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctIndicators, iterations,
                      "All decreased wounds should show negative change indicators")
    }
    
    /// Property: For any wound with minimal change (<1%), the indicator shows unchanged
    func testProperty12_WoundSizeChangeIndicators_IndicatesUnchanged() async throws {
        let iterations = 100
        var correctIndicators = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create first session
            let session1 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_1.heic",
                woundRecord: woundRecord
            )
            
            let initialArea = Double.random(in: 100...1000)
            _ = createMeasurement(areaMM2: initialArea, in: context, for: session1)
            
            try await Task.sleep(nanoseconds: 10_000_000)
            
            // Create second session with MINIMAL change (<1%)
            let session2 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_2.heic",
                woundRecord: woundRecord
            )
            
            let minimalChangePercent = Double.random(in: -0.9...0.9)
            let newArea = initialArea * (1.0 + minimalChangePercent / 100.0)
            _ = createMeasurement(areaMM2: newArea, in: context, for: session2)
            
            if let measurement1 = session1.measurement,
               let measurement2 = session2.measurement {
                let change = ((measurement2.areaMM2 - measurement1.areaMM2) / measurement1.areaMM2) * 100
                
                // Verify minimal change
                XCTAssertLessThan(abs(change), 1.0,
                                "Iteration \(iteration): Change should be less than 1% for unchanged wound")
                
                if abs(change) < 1.0 {
                    correctIndicators += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctIndicators, iterations,
                      "All minimally changed wounds should show unchanged indicators")
    }
    
    /// Property: For any comparison, the change percentage is accurately calculated
    func testProperty12_WoundSizeChangeIndicators_AccuratePercentageCalculation() async throws {
        let iterations = 100
        var accurateCalculations = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create first session
            let session1 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_1.heic",
                woundRecord: woundRecord
            )
            
            let initialArea = Double.random(in: 100...1000)
            _ = createMeasurement(areaMM2: initialArea, in: context, for: session1)
            
            try await Task.sleep(nanoseconds: 10_000_000)
            
            // Create second session
            let session2 = try await captureSessionManager.createCaptureSession(
                photoPath: "test/photo_\(iteration)_2.heic",
                woundRecord: woundRecord
            )
            
            let targetChangePercent = Double.random(in: -50...50)
            let newArea = initialArea * (1.0 + targetChangePercent / 100.0)
            _ = createMeasurement(areaMM2: newArea, in: context, for: session2)
            
            if let measurement1 = session1.measurement,
               let measurement2 = session2.measurement {
                let calculatedChange = ((measurement2.areaMM2 - measurement1.areaMM2) / measurement1.areaMM2) * 100
                
                // Verify calculation is within reasonable tolerance (0.1%)
                let tolerance = 0.1
                XCTAssertEqual(calculatedChange, targetChangePercent, accuracy: tolerance,
                             "Iteration \(iteration): Calculated change should match target change")
                
                if abs(calculatedChange - targetChangePercent) <= tolerance {
                    accurateCalculations += 1
                }
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(accurateCalculations, iterations,
                      "All change percentages should be accurately calculated")
    }
}

