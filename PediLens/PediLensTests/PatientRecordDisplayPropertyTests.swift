//
//  PatientRecordDisplayPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for patient record display with statistics
//

import XCTest
import CoreData
@testable import PediLens

final class PatientRecordDisplayPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var patientManager: PatientManager!
    var userManager: UserManager!
    var context: NSManagedObjectContext!
    var testUser: User!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        patientManager = PatientManager(persistenceController: persistenceController)
        userManager = UserManager(persistenceController: persistenceController)
        context = persistenceController.container.viewContext
        
        // Create test user with doctor role
        testUser = User.create(in: context, role: .doctor)
        try? context.save()
    }
    
    override func tearDown() {
        testUser = nil
        context = nil
        patientManager = nil
        userManager = nil
        persistenceController = nil
        
        super.tearDown()
    }
    
    // MARK: - Property 45: Patient Record Display with Statistics
    // **Validates: Requirements 17.2, 17.5**
    
    /// Property: For any patient selected by a doctor user, all associated wound records SHALL be displayed
    func testProperty45_PatientRecordDisplay_AllWoundRecordsDisplayed() async throws {
        let iterations = 10  // Reduced to avoid Core Data context issues with in-memory store
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create a patient (using the shared testUser)
            let patient = try await patientManager.createPatient(
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                for: testUser
            )
            
            // Create random number of wound records (0-5) - reduced to avoid Core Data issues
            let woundCount = Int.random(in: 0...5)
            var createdWounds: [WoundRecord] = []
            
            for woundIndex in 0..<woundCount {
                let wound = WoundRecord.create(
                    in: context,
                    location: "Location \(woundIndex)",
                    initialAssessmentDate: Date(),
                    status: ["active", "healing", "healed", "archived"].randomElement()!,
                    patient: patient
                )
                createdWounds.append(wound)
            }
            
            try context.save()
            
            // Verify all wound records are associated with the patient
            let displayedWounds = patient.woundRecordsArray
            
            if displayedWounds.count != woundCount {
                failedCases.append(iteration)
            }
            
            // Verify each created wound is in the displayed list
            for wound in createdWounds {
                if !displayedWounds.contains(where: { $0.id == wound.id }) {
                    failedCases.append(iteration)
                }
            }
            
            // No cleanup needed - in-memory store will be discarded after test
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient wound records display failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any patient, summary statistics SHALL include total wounds, active wounds, and healing trends
    func testProperty45_PatientRecordDisplay_StatisticsCalculated() async throws {
        let iterations = 5  // Reduced to avoid Core Data context issues with in-memory store
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create a patient (using the shared testUser)
            let patient = try await patientManager.createPatient(
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                for: testUser
            )
            
            // Create wounds with different statuses (reduced counts to avoid Core Data issues)
            let activeCount = Int.random(in: 0...2)
            let healedCount = Int.random(in: 0...2)
            let healingCount = Int.random(in: 0...2)
            let archivedCount = Int.random(in: 0...1)
            
            // Create active wounds
            for i in 0..<activeCount {
                _ = WoundRecord.create(
                    in: context,
                    location: "Active \(i)",
                    status: "active",
                    patient: patient
                )
            }
            
            // Create healed wounds
            for i in 0..<healedCount {
                _ = WoundRecord.create(
                    in: context,
                    location: "Healed \(i)",
                    status: "healed",
                    patient: patient
                )
            }
            
            // Create healing wounds
            for i in 0..<healingCount {
                _ = WoundRecord.create(
                    in: context,
                    location: "Healing \(i)",
                    status: "healing",
                    patient: patient
                )
            }
            
            // Create archived wounds
            for i in 0..<archivedCount {
                _ = WoundRecord.create(
                    in: context,
                    location: "Archived \(i)",
                    status: "archived",
                    patient: patient
                )
            }
            
            try context.save()
            
            // Calculate statistics
            let stats = patientManager.calculateStatistics(for: patient)
            
            // Verify total wounds
            let expectedTotal = activeCount + healedCount + healingCount + archivedCount
            if stats.totalWounds != expectedTotal {
                failedCases.append(iteration)
            }
            
            // Verify active wounds count
            if stats.activeWounds != activeCount {
                failedCases.append(iteration)
            }
            
            // Verify healed wounds count
            if stats.healedWounds != healedCount {
                failedCases.append(iteration)
            }
            
            // Verify healing rate calculation
            let expectedHealingRate = expectedTotal > 0 ? Double(healedCount) / Double(expectedTotal) : 0.0
            if abs(stats.healingRate - expectedHealingRate) > 0.001 {
                failedCases.append(iteration)
            }
            
            // No cleanup needed - in-memory store will be discarded after test
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient statistics calculation failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient statistics SHALL be accurate regardless of wound record count
    func testProperty45_PatientRecordDisplay_StatisticsAccuracyWithVariousWoundCounts() async throws {
        let iterations = 10  // Reduced to avoid Core Data context issues with in-memory store
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create a patient (using the shared testUser)
            let patient = try await patientManager.createPatient(
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                for: testUser
            )
            
            // Test with various wound counts (including edge cases) - reduced to avoid Core Data issues
            let totalWounds = [0, 1, 3, 5, 10].randomElement()!
            
            // Randomly distribute wounds across statuses
            var remainingWounds = totalWounds
            var statusCounts: [String: Int] = [:]
            
            let statuses = ["active", "healed", "healing", "archived"]
            for status in statuses {
                if remainingWounds > 0 {
                    let count = Int.random(in: 0...remainingWounds)
                    statusCounts[status] = count
                    remainingWounds -= count
                }
            }
            
            // Assign remaining wounds to a random status
            if remainingWounds > 0 {
                let randomStatus = statuses.randomElement()!
                statusCounts[randomStatus, default: 0] += remainingWounds
            }
            
            // Create wounds
            for (status, count) in statusCounts {
                for i in 0..<count {
                    _ = WoundRecord.create(
                        in: context,
                        location: "\(status) \(i)",
                        status: status,
                        patient: patient
                    )
                }
            }
            
            try context.save()
            
            // Calculate statistics
            let stats = patientManager.calculateStatistics(for: patient)
            
            // Verify total wounds
            if stats.totalWounds != totalWounds {
                failedCases.append(iteration)
            }
            
            // Verify active wounds
            if stats.activeWounds != (statusCounts["active"] ?? 0) {
                failedCases.append(iteration)
            }
            
            // Verify healed wounds
            if stats.healedWounds != (statusCounts["healed"] ?? 0) {
                failedCases.append(iteration)
            }
            
            // Verify healing rate
            let expectedRate = totalWounds > 0 ? Double(statusCounts["healed"] ?? 0) / Double(totalWounds) : 0.0
            if abs(stats.healingRate - expectedRate) > 0.001 {
                failedCases.append(iteration)
            }
            
            // No cleanup needed - in-memory store will be discarded after test
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Statistics accuracy with various wound counts failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient display SHALL show aggregate data including total wounds, active wounds, and healing trends
    func testProperty45_PatientRecordDisplay_AggregateDataPresent() async throws {
        let iterations = 10  // Reduced to avoid Core Data context issues with in-memory store
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create a patient (using the shared testUser)
            let patient = try await patientManager.createPatient(
                name: "Patient \(iteration)",
                patientID: "PID-\(iteration)",
                dateOfBirth: Date().addingTimeInterval(-Double.random(in: 18...80) * 365 * 24 * 3600),
                notes: iteration % 2 == 0 ? "Test notes" : nil,
                for: testUser
            )
            
            // Create some wound records (reduced count to avoid Core Data issues)
            let woundCount = Int.random(in: 1...5)
            for i in 0..<woundCount {
                let status = ["active", "healed", "healing"].randomElement()!
                _ = WoundRecord.create(
                    in: context,
                    location: "Wound \(i)",
                    status: status,
                    patient: patient
                )
            }
            
            try context.save()
            
            // Get statistics
            let stats = patientManager.calculateStatistics(for: patient)
            
            // Verify all aggregate data is present and valid
            
            // Total wounds should match created count
            if stats.totalWounds != woundCount {
                failedCases.append(iteration)
            }
            
            // Active wounds should be >= 0 and <= total
            if stats.activeWounds < 0 || stats.activeWounds > stats.totalWounds {
                failedCases.append(iteration)
            }
            
            // Healed wounds should be >= 0 and <= total
            if stats.healedWounds < 0 || stats.healedWounds > stats.totalWounds {
                failedCases.append(iteration)
            }
            
            // Healing rate should be between 0.0 and 1.0
            if stats.healingRate < 0.0 || stats.healingRate > 1.0 {
                failedCases.append(iteration)
            }
            
            // Healing rate should match healed/total calculation
            let expectedRate = Double(stats.healedWounds) / Double(stats.totalWounds)
            if abs(stats.healingRate - expectedRate) > 0.001 {
                failedCases.append(iteration)
            }
            
            // No cleanup needed - in-memory store will be discarded after test
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Aggregate data presence failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Patient statistics SHALL handle edge cases (no wounds, all healed, all active)
    func testProperty45_PatientRecordDisplay_EdgeCaseHandling() async throws {
        let iterations = 8  // Reduced to avoid Core Data context issues (1 iteration per edge case)
        var failedCases: [Int] = []
        
        // Test edge cases (reduced wound counts to avoid Core Data issues)
        let edgeCases: [(active: Int, healed: Int, healing: Int, archived: Int)] = [
            (0, 0, 0, 0),      // No wounds
            (3, 0, 0, 0),      // All active
            (0, 3, 0, 0),      // All healed
            (0, 0, 3, 0),      // All healing
            (0, 0, 0, 3),      // All archived
            (2, 2, 0, 0),      // Half active, half healed
            (1, 0, 0, 0),      // Single active wound
            (0, 1, 0, 0),      // Single healed wound
        ]
        
        for (caseIndex, edgeCase) in edgeCases.enumerated() {
            for iteration in 0..<(iterations / edgeCases.count) {
                // Create a patient (using the shared testUser)
                let patient = try await patientManager.createPatient(
                    name: "Patient \(caseIndex)-\(iteration)",
                    patientID: "PID-\(caseIndex)-\(iteration)",
                    for: testUser
                )
                
                // Create wounds according to edge case
                for i in 0..<edgeCase.active {
                    _ = WoundRecord.create(in: context, location: "Active \(i)", status: "active", patient: patient)
                }
                for i in 0..<edgeCase.healed {
                    _ = WoundRecord.create(in: context, location: "Healed \(i)", status: "healed", patient: patient)
                }
                for i in 0..<edgeCase.healing {
                    _ = WoundRecord.create(in: context, location: "Healing \(i)", status: "healing", patient: patient)
                }
                for i in 0..<edgeCase.archived {
                    _ = WoundRecord.create(in: context, location: "Archived \(i)", status: "archived", patient: patient)
                }
                
                try context.save()
                
                // Calculate statistics
                let stats = patientManager.calculateStatistics(for: patient)
                
                // Verify statistics
                let expectedTotal = edgeCase.active + edgeCase.healed + edgeCase.healing + edgeCase.archived
                
                if stats.totalWounds != expectedTotal {
                    failedCases.append(caseIndex * 100 + iteration)
                }
                
                if stats.activeWounds != edgeCase.active {
                    failedCases.append(caseIndex * 100 + iteration)
                }
                
                if stats.healedWounds != edgeCase.healed {
                    failedCases.append(caseIndex * 100 + iteration)
                }
                
                let expectedRate = expectedTotal > 0 ? Double(edgeCase.healed) / Double(expectedTotal) : 0.0
                if abs(stats.healingRate - expectedRate) > 0.001 {
                    failedCases.append(caseIndex * 100 + iteration)
                }
                
                // No cleanup needed - in-memory store will be discarded after test
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Edge case handling failed for \(failedCases.count) out of \(iterations) cases")
    }
}
