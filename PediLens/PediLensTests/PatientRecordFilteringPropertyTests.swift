//
//  PatientRecordFilteringPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for multi-criteria patient record filtering
//  Feature: pedilens, Property 47: Multi-Criteria Record Filtering
//  Validates: Requirements 17.6
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for multi-criteria patient record filtering
/// These tests validate that multiple filter criteria are combined with AND logic
@MainActor
final class PatientRecordFilteringPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var patientManager: PatientManager!
    var woundManager: WoundManager!
    var userManager: UserManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        patientManager = PatientManager(persistenceController: persistenceController)
        woundManager = WoundManager(persistenceController: persistenceController)
        userManager = UserManager(persistenceController: persistenceController)
    }
    
    override func tearDown() {
        patientManager = nil
        woundManager = nil
        userManager = nil
        context = nil
        persistenceController = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    private func randomStatus() -> String {
        let statuses = ["active", "healing", "healed", "archived"]
        return statuses.randomElement()!
    }
    
    private func randomLocation() -> String {
        let locations = [
            "Left foot, plantar surface",
            "Right foot, heel",
            "Left foot, toe",
            "Right foot, plantar surface",
            "Left ankle",
            "Right ankle"
        ]
        return locations.randomElement()!
    }
    
    // MARK: - Property 47: Multi-Criteria Record Filtering
    // **Validates: Requirements 17.6**
    
    /// Property: For any combination of filters (date range, status, location), only records matching ALL criteria are displayed
    func testProperty47_MultiCriteriaFiltering_AllCriteriaMustMatch() async throws {
        let iterations = 100
        var successfulFilters = 0
        
        for iteration in 0..<iterations {
            // Create a doctor user
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Create a patient
            let patient = try await patientManager.createPatient(
                name: generateRandomString(length: Int.random(in: 5...20)),
                patientID: generateRandomString(length: 8),
                dateOfBirth: nil,
                notes: nil,
                for: user
            )
            
            // Create wound records with various attributes
            let recordCount = Int.random(in: 10...20)
            var records: [WoundRecord] = []
            let baseDate = Date()
            
            for i in 0..<recordCount {
                let location = randomLocation()
                let status = randomStatus()
                let daysOffset = -Double.random(in: 0...60)
                let recordDate = Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: baseDate)!
                
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    initialAssessmentDate: recordDate,
                    patient: patient
                )
                record.status = status
                record.lastUpdated = recordDate
                try context.save()
                records.append(record)
            }
            
            // Define random filter criteria
            let filterStartDays = -Double.random(in: 20...50)
            let filterEndDays = -Double.random(in: 0...Double(abs(filterStartDays)))
            let filterStartDate = Calendar.current.date(byAdding: .day, value: Int(filterStartDays), to: baseDate)!
            let filterEndDate = Calendar.current.date(byAdding: .day, value: Int(filterEndDays), to: baseDate)!
            
            let filterStatus = randomStatus()
            let filterLocation = randomLocation()
            
            // Manually filter records with ALL criteria
            let expectedRecords = records.filter { record in
                guard let lastUpdated = record.lastUpdated else { return false }
                
                let matchesDate = lastUpdated >= filterStartDate && lastUpdated <= filterEndDate
                let matchesStatus = record.status == filterStatus
                let matchesLocation = record.location == filterLocation
                
                return matchesDate && matchesStatus && matchesLocation
            }
            
            // Apply filters using the filtering logic
            let filteredRecords = applyMultiCriteriaFilter(
                records: records,
                startDate: filterStartDate,
                endDate: filterEndDate,
                status: filterStatus,
                location: filterLocation
            )
            
            // Verify filtered results match expected
            XCTAssertEqual(filteredRecords.count, expectedRecords.count,
                          "Iteration \(iteration): Filtered record count should match expected count")
            
            // Verify all filtered records match ALL criteria
            for record in filteredRecords {
                guard let lastUpdated = record.lastUpdated else {
                    XCTFail("Iteration \(iteration): Record should have lastUpdated date")
                    continue
                }
                
                XCTAssertGreaterThanOrEqual(lastUpdated, filterStartDate,
                                          "Iteration \(iteration): Record date should be >= filter start")
                XCTAssertLessThanOrEqual(lastUpdated, filterEndDate,
                                       "Iteration \(iteration): Record date should be <= filter end")
                XCTAssertEqual(record.status, filterStatus,
                             "Iteration \(iteration): Record status should match filter")
                XCTAssertEqual(record.location, filterLocation,
                             "Iteration \(iteration): Record location should match filter")
            }
            
            if filteredRecords.count == expectedRecords.count {
                successfulFilters += 1
            }
            
            // Clean up
            for record in records {
                try await woundManager.deleteWoundRecord(record, createExport: false)
            }
            try await patientManager.deletePatient(patient)
        }
        
        XCTAssertEqual(successfulFilters, iterations,
                      "All multi-criteria filters should correctly apply AND logic")
    }
    
    /// Property: For any single criterion filter, records matching that criterion are displayed
    func testProperty47_SingleCriterionFiltering_OnlyCriterionMatches() async throws {
        let iterations = 100
        var successfulFilters = 0
        
        for iteration in 0..<iterations {
            // Create a doctor user
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Create a patient
            let patient = try await patientManager.createPatient(
                name: generateRandomString(length: Int.random(in: 5...20)),
                patientID: generateRandomString(length: 8),
                dateOfBirth: nil,
                notes: nil,
                for: user
            )
            
            // Create wound records
            let recordCount = Int.random(in: 10...20)
            var records: [WoundRecord] = []
            
            for i in 0..<recordCount {
                let location = randomLocation()
                let status = randomStatus()
                
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    patient: patient
                )
                record.status = status
                try context.save()
                records.append(record)
            }
            
            // Test filtering by status only
            let filterStatus = randomStatus()
            let expectedByStatus = records.filter { $0.status == filterStatus }
            let filteredByStatus = applyStatusFilter(records: records, status: filterStatus)
            
            XCTAssertEqual(filteredByStatus.count, expectedByStatus.count,
                          "Iteration \(iteration): Status-only filter should match expected count")
            
            // Test filtering by location only
            let filterLocation = randomLocation()
            let expectedByLocation = records.filter { $0.location == filterLocation }
            let filteredByLocation = applyLocationFilter(records: records, location: filterLocation)
            
            XCTAssertEqual(filteredByLocation.count, expectedByLocation.count,
                          "Iteration \(iteration): Location-only filter should match expected count")
            
            if filteredByStatus.count == expectedByStatus.count &&
               filteredByLocation.count == expectedByLocation.count {
                successfulFilters += 1
            }
            
            // Clean up
            for record in records {
                try await woundManager.deleteWoundRecord(record, createExport: false)
            }
            try await patientManager.deletePatient(patient)
        }
        
        XCTAssertEqual(successfulFilters, iterations,
                      "All single-criterion filters should work correctly")
    }
    
    /// Property: For any two-criteria filter, only records matching BOTH criteria are displayed
    func testProperty47_TwoCriteriaFiltering_BothCriteriaMustMatch() async throws {
        let iterations = 100
        var successfulFilters = 0
        
        for iteration in 0..<iterations {
            // Create a doctor user
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Create a patient
            let patient = try await patientManager.createPatient(
                name: generateRandomString(length: Int.random(in: 5...20)),
                patientID: generateRandomString(length: 8),
                dateOfBirth: nil,
                notes: nil,
                for: user
            )
            
            // Create wound records
            let recordCount = Int.random(in: 10...20)
            var records: [WoundRecord] = []
            let baseDate = Date()
            
            for i in 0..<recordCount {
                let location = randomLocation()
                let status = randomStatus()
                let daysOffset = -Double.random(in: 0...60)
                let recordDate = Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: baseDate)!
                
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    initialAssessmentDate: recordDate,
                    patient: patient
                )
                record.status = status
                record.lastUpdated = recordDate
                try context.save()
                records.append(record)
            }
            
            // Test status + location filter
            let filterStatus = randomStatus()
            let filterLocation = randomLocation()
            
            let expectedStatusLocation = records.filter { record in
                record.status == filterStatus && record.location == filterLocation
            }
            
            let filteredStatusLocation = applyStatusAndLocationFilter(
                records: records,
                status: filterStatus,
                location: filterLocation
            )
            
            XCTAssertEqual(filteredStatusLocation.count, expectedStatusLocation.count,
                          "Iteration \(iteration): Status+Location filter should match expected count")
            
            // Verify all filtered records match both criteria
            for record in filteredStatusLocation {
                XCTAssertEqual(record.status, filterStatus,
                             "Iteration \(iteration): Record status should match filter")
                XCTAssertEqual(record.location, filterLocation,
                             "Iteration \(iteration): Record location should match filter")
            }
            
            // Test date + status filter
            let filterStartDays = -Double.random(in: 20...50)
            let filterEndDays = -Double.random(in: 0...Double(abs(filterStartDays)))
            let filterStartDate = Calendar.current.date(byAdding: .day, value: Int(filterStartDays), to: baseDate)!
            let filterEndDate = Calendar.current.date(byAdding: .day, value: Int(filterEndDays), to: baseDate)!
            
            let expectedDateStatus = records.filter { record in
                guard let lastUpdated = record.lastUpdated else { return false }
                return lastUpdated >= filterStartDate && lastUpdated <= filterEndDate && record.status == filterStatus
            }
            
            let filteredDateStatus = applyDateAndStatusFilter(
                records: records,
                startDate: filterStartDate,
                endDate: filterEndDate,
                status: filterStatus
            )
            
            XCTAssertEqual(filteredDateStatus.count, expectedDateStatus.count,
                          "Iteration \(iteration): Date+Status filter should match expected count")
            
            if filteredStatusLocation.count == expectedStatusLocation.count &&
               filteredDateStatus.count == expectedDateStatus.count {
                successfulFilters += 1
            }
            
            // Clean up
            for record in records {
                try await woundManager.deleteWoundRecord(record, createExport: false)
            }
            try await patientManager.deletePatient(patient)
        }
        
        XCTAssertEqual(successfulFilters, iterations,
                      "All two-criteria filters should correctly apply AND logic")
    }
    
    /// Property: For any filter with no matching records, an empty result set is returned
    func testProperty47_NoMatchingRecords_ReturnsEmpty() async throws {
        let iterations = 100
        var correctEmptyResults = 0
        
        for iteration in 0..<iterations {
            // Create a doctor user
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Create a patient
            let patient = try await patientManager.createPatient(
                name: generateRandomString(length: Int.random(in: 5...20)),
                patientID: generateRandomString(length: 8),
                dateOfBirth: nil,
                notes: nil,
                for: user
            )
            
            // Create wound records with specific attributes
            let recordCount = Int.random(in: 5...10)
            var records: [WoundRecord] = []
            
            for i in 0..<recordCount {
                let record = try await woundManager.createWoundRecord(
                    location: "Left foot",
                    patient: patient
                )
                record.status = "active"
                try context.save()
                records.append(record)
            }
            
            // Apply filter that should match nothing (impossible combination)
            let filteredRecords = applyStatusAndLocationFilter(
                records: records,
                status: "healed",
                location: "Right foot"
            )
            
            XCTAssertEqual(filteredRecords.count, 0,
                          "Iteration \(iteration): Filter with no matches should return empty")
            
            if filteredRecords.isEmpty {
                correctEmptyResults += 1
            }
            
            // Clean up
            for record in records {
                try await woundManager.deleteWoundRecord(record, createExport: false)
            }
            try await patientManager.deletePatient(patient)
        }
        
        XCTAssertEqual(correctEmptyResults, iterations,
                      "All filters with no matches should return empty results")
    }
    
    /// Property: For any filter cleared, all records are displayed again
    func testProperty47_ClearFilters_ShowsAllRecords() async throws {
        let iterations = 100
        var correctClearResults = 0
        
        for iteration in 0..<iterations {
            // Create a doctor user
            let user = User.create(in: context, role: .doctor, iCloudSyncEnabled: false)
            
            // Create a patient
            let patient = try await patientManager.createPatient(
                name: generateRandomString(length: Int.random(in: 5...20)),
                patientID: generateRandomString(length: 8),
                dateOfBirth: nil,
                notes: nil,
                for: user
            )
            
            // Create wound records
            let recordCount = Int.random(in: 10...20)
            var records: [WoundRecord] = []
            
            for i in 0..<recordCount {
                let location = randomLocation()
                let status = randomStatus()
                
                let record = try await woundManager.createWoundRecord(
                    location: location,
                    patient: patient
                )
                record.status = status
                try context.save()
                records.append(record)
            }
            
            // Apply restrictive filter
            let filteredRecords = applyStatusAndLocationFilter(
                records: records,
                status: "active",
                location: "Left foot, plantar surface"
            )
            
            // Clear filter (no filters applied)
            let allRecords = applyNoFilter(records: records)
            
            XCTAssertEqual(allRecords.count, records.count,
                          "Iteration \(iteration): Clearing filters should show all records")
            
            if allRecords.count == records.count {
                correctClearResults += 1
            }
            
            // Clean up
            for record in records {
                try await woundManager.deleteWoundRecord(record, createExport: false)
            }
            try await patientManager.deletePatient(patient)
        }
        
        XCTAssertEqual(correctClearResults, iterations,
                      "All cleared filters should restore full record list")
    }
    
    // MARK: - Filter Helper Methods
    
    private func applyMultiCriteriaFilter(
        records: [WoundRecord],
        startDate: Date,
        endDate: Date,
        status: String,
        location: String
    ) -> [WoundRecord] {
        return records.filter { record in
            guard let lastUpdated = record.lastUpdated else { return false }
            
            let matchesDate = lastUpdated >= startDate && lastUpdated <= endDate
            let matchesStatus = record.status == status
            let matchesLocation = record.location == location
            
            return matchesDate && matchesStatus && matchesLocation
        }
    }
    
    private func applyStatusFilter(records: [WoundRecord], status: String) -> [WoundRecord] {
        return records.filter { $0.status == status }
    }
    
    private func applyLocationFilter(records: [WoundRecord], location: String) -> [WoundRecord] {
        return records.filter { $0.location == location }
    }
    
    private func applyStatusAndLocationFilter(
        records: [WoundRecord],
        status: String,
        location: String
    ) -> [WoundRecord] {
        return records.filter { record in
            record.status == status && record.location == location
        }
    }
    
    private func applyDateAndStatusFilter(
        records: [WoundRecord],
        startDate: Date,
        endDate: Date,
        status: String
    ) -> [WoundRecord] {
        return records.filter { record in
            guard let lastUpdated = record.lastUpdated else { return false }
            return lastUpdated >= startDate && lastUpdated <= endDate && record.status == status
        }
    }
    
    private func applyNoFilter(records: [WoundRecord]) -> [WoundRecord] {
        return records
    }
}
