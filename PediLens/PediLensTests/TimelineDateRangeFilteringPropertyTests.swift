//
//  TimelineDateRangeFilteringPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for timeline date range filtering
//  Feature: pedilens, Property 13: Timeline Date Range Filtering
//  Validates: Requirements 3.5, 17.6
//

import XCTest
import CoreData
@testable import PediLens

/// Property-based tests for timeline date range filtering
/// These tests validate that date range filters correctly limit displayed sessions
final class TimelineDateRangeFilteringPropertyTests: XCTestCase {
    
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
    
    private func createSessionWithDate(_ date: Date, for woundRecord: WoundRecord) async throws -> CaptureSession {
        let session = try await captureSessionManager.createCaptureSession(
            photoPath: "test/photo_\(UUID().uuidString).heic",
            woundRecord: woundRecord
        )
        session.timestamp = date
        try context.save()
        return session
    }
    
    // MARK: - Property 13: Timeline Date Range Filtering
    // **Validates: Requirements 3.5, 17.6**
    
    /// Property: For any date range filter, only sessions within that range are displayed
    func testProperty13_TimelineDateRangeFiltering_OnlySessionsWithinRange() async throws {
        let iterations = 100
        var successfulFilters = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create sessions across a 30-day period
            let baseDate = Date()
            let sessionCount = Int.random(in: 5...15)
            var sessions: [CaptureSession] = []
            
            for i in 0..<sessionCount {
                let daysOffset = -Double.random(in: 0...30)
                let sessionDate = Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: baseDate)!
                let session = try await createSessionWithDate(sessionDate, for: woundRecord)
                sessions.append(session)
            }
            
            // Define a random filter range within the 30-day period
            let filterStartDays = -Double.random(in: 5...25)
            let filterEndDays = -Double.random(in: 0...Double(abs(filterStartDays)))
            let filterStart = Calendar.current.date(byAdding: .day, value: Int(filterStartDays), to: baseDate)!
            let filterEnd = Calendar.current.date(byAdding: .day, value: Int(filterEndDays), to: baseDate)!
            
            // Filter sessions manually
            let expectedSessions = sessions.filter { session in
                guard let timestamp = session.timestamp else { return false }
                return timestamp >= filterStart && timestamp <= filterEnd
            }
            
            // Create view model and apply filter
            let viewModel = await TimelineViewModel(woundRecord: woundRecord)
            await viewModel.loadSessions()
            
            await MainActor.run {
                viewModel.filterStartDate = filterStart
                viewModel.filterEndDate = filterEnd
            }
            await viewModel.applyFilters()
            
            // Verify filtered results match expected
            let filteredCount = await MainActor.run { viewModel.filteredSessions.count }
            XCTAssertEqual(filteredCount, expectedSessions.count,
                          "Iteration \(iteration): Filtered session count should match expected count")
            
            // Verify all filtered sessions are within range
            let filteredSessions = await MainActor.run { viewModel.filteredSessions }
            for session in filteredSessions {
                guard let timestamp = session.timestamp else {
                    XCTFail("Iteration \(iteration): Session should have timestamp")
                    continue
                }
                
                XCTAssertGreaterThanOrEqual(timestamp, filterStart,
                                          "Iteration \(iteration): Session timestamp should be >= filter start")
                XCTAssertLessThanOrEqual(timestamp, filterEnd,
                                       "Iteration \(iteration): Session timestamp should be <= filter end")
            }
            
            if filteredCount == expectedSessions.count {
                successfulFilters += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(successfulFilters, iterations,
                      "All date range filters should correctly limit displayed sessions")
    }
    
    /// Property: For any empty date range, no sessions are displayed
    func testProperty13_TimelineDateRangeFiltering_EmptyRangeShowsNothing() async throws {
        let iterations = 100
        var correctEmptyResults = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create sessions
            let sessionCount = Int.random(in: 3...10)
            for i in 0..<sessionCount {
                let daysOffset = -Double.random(in: 0...30)
                let sessionDate = Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: Date())!
                _ = try await createSessionWithDate(sessionDate, for: woundRecord)
            }
            
            // Create an empty date range (start > end)
            let filterEnd = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
            let filterStart = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
            
            // Create view model and apply filter
            let viewModel = await TimelineViewModel(woundRecord: woundRecord)
            await viewModel.loadSessions()
            
            await MainActor.run {
                viewModel.filterStartDate = filterStart
                viewModel.filterEndDate = filterEnd
            }
            await viewModel.applyFilters()
            
            // Verify no sessions are shown
            let filteredCount = await MainActor.run { viewModel.filteredSessions.count }
            XCTAssertEqual(filteredCount, 0,
                          "Iteration \(iteration): Empty date range should show no sessions")
            
            if filteredCount == 0 {
                correctEmptyResults += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctEmptyResults, iterations,
                      "All empty date ranges should show no sessions")
    }
    
    /// Property: For any filter that includes all session dates, all sessions are displayed
    func testProperty13_TimelineDateRangeFiltering_WideRangeShowsAll() async throws {
        let iterations = 100
        var correctFullResults = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create sessions across a specific period
            let sessionCount = Int.random(in: 3...10)
            var earliestDate = Date()
            var latestDate = Date.distantPast
            
            for i in 0..<sessionCount {
                let daysOffset = -Double.random(in: 0...20)
                let sessionDate = Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: Date())!
                _ = try await createSessionWithDate(sessionDate, for: woundRecord)
                
                if sessionDate < earliestDate {
                    earliestDate = sessionDate
                }
                if sessionDate > latestDate {
                    latestDate = sessionDate
                }
            }
            
            // Create a filter range that encompasses all sessions
            let filterStart = Calendar.current.date(byAdding: .day, value: -1, to: earliestDate)!
            let filterEnd = Calendar.current.date(byAdding: .day, value: 1, to: latestDate)!
            
            // Create view model and apply filter
            let viewModel = await TimelineViewModel(woundRecord: woundRecord)
            await viewModel.loadSessions()
            
            let totalSessions = await MainActor.run { viewModel.sessions.count }
            
            await MainActor.run {
                viewModel.filterStartDate = filterStart
                viewModel.filterEndDate = filterEnd
            }
            await viewModel.applyFilters()
            
            // Verify all sessions are shown
            let filteredCount = await MainActor.run { viewModel.filteredSessions.count }
            XCTAssertEqual(filteredCount, totalSessions,
                          "Iteration \(iteration): Wide date range should show all sessions")
            
            if filteredCount == totalSessions {
                correctFullResults += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctFullResults, iterations,
                      "All wide date ranges should show all sessions")
    }
    
    /// Property: For any filter cleared, all sessions are displayed again
    func testProperty13_TimelineDateRangeFiltering_ClearFilterShowsAll() async throws {
        let iterations = 100
        var correctClearResults = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Create sessions
            let sessionCount = Int.random(in: 5...15)
            for i in 0..<sessionCount {
                let daysOffset = -Double.random(in: 0...30)
                let sessionDate = Calendar.current.date(byAdding: .day, value: Int(daysOffset), to: Date())!
                _ = try await createSessionWithDate(sessionDate, for: woundRecord)
            }
            
            // Create view model and apply a restrictive filter
            let viewModel = await TimelineViewModel(woundRecord: woundRecord)
            await viewModel.loadSessions()
            
            let totalSessions = await MainActor.run { viewModel.sessions.count }
            
            await MainActor.run {
                viewModel.filterStartDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
                viewModel.filterEndDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
            }
            await viewModel.applyFilters()
            
            // Clear the filter
            await viewModel.clearDateFilter()
            
            // Verify all sessions are shown again
            let (filteredCount, hasFilter) = await MainActor.run {
                (viewModel.filteredSessions.count, viewModel.hasDateFilter)
            }
            XCTAssertEqual(filteredCount, totalSessions,
                          "Iteration \(iteration): Clearing filter should show all sessions")
            XCTAssertFalse(hasFilter,
                         "Iteration \(iteration): hasDateFilter should be false after clearing")
            
            if filteredCount == totalSessions && !hasFilter {
                correctClearResults += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctClearResults, iterations,
                      "All cleared filters should restore full session list")
    }
    
    /// Property: For any single-day filter, only sessions from that day are displayed
    func testProperty13_TimelineDateRangeFiltering_SingleDayFilter() async throws {
        let iterations = 100
        var correctSingleDayResults = 0
        
        for iteration in 0..<iterations {
            let woundRecord = try await woundManager.createWoundRecord(
                location: generateRandomString(length: Int.random(in: 5...50))
            )
            
            // Pick a target date
            let targetDaysOffset = -Int.random(in: 5...15)
            let targetDate = Calendar.current.date(byAdding: .day, value: targetDaysOffset, to: Date())!
            
            // Create sessions on various days, including the target day
            let sessionCount = Int.random(in: 5...15)
            var targetDaySessions = 0
            
            for i in 0..<sessionCount {
                let daysOffset = -Int.random(in: 0...30)
                let sessionDate = Calendar.current.date(byAdding: .day, value: daysOffset, to: Date())!
                _ = try await createSessionWithDate(sessionDate, for: woundRecord)
                
                // Check if this session is on the target day
                if Calendar.current.isDate(sessionDate, inSameDayAs: targetDate) {
                    targetDaySessions += 1
                }
            }
            
            // Create view model and filter to single day
            let viewModel = await TimelineViewModel(woundRecord: woundRecord)
            await viewModel.loadSessions()
            
            let startOfDay = Calendar.current.startOfDay(for: targetDate)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
            
            await MainActor.run {
                viewModel.filterStartDate = startOfDay
                viewModel.filterEndDate = endOfDay
            }
            await viewModel.applyFilters()
            
            // Verify only target day sessions are shown
            let filteredCount = await MainActor.run { viewModel.filteredSessions.count }
            XCTAssertEqual(filteredCount, targetDaySessions,
                          "Iteration \(iteration): Single-day filter should show only sessions from that day")
            
            // Verify all shown sessions are from target day
            let filteredSessions = await MainActor.run { viewModel.filteredSessions }
            for session in filteredSessions {
                guard let timestamp = session.timestamp else {
                    XCTFail("Iteration \(iteration): Session should have timestamp")
                    continue
                }
                
                XCTAssertTrue(Calendar.current.isDate(timestamp, inSameDayAs: targetDate),
                            "Iteration \(iteration): All filtered sessions should be from target day")
            }
            
            if filteredCount == targetDaySessions {
                correctSingleDayResults += 1
            }
            
            // Clean up
            try await woundManager.deleteWoundRecord(woundRecord, createExport: false)
        }
        
        XCTAssertEqual(correctSingleDayResults, iterations,
                      "All single-day filters should show only sessions from that day")
    }
}
