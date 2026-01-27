//
//  PatientSearchPropertyTests.swift
//  PediLensTests
//
//  Property-based tests for patient search partial matching
//

import XCTest
import CoreData
@testable import PediLens

final class PatientSearchPropertyTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var patientManager: PatientManager!
    var context: NSManagedObjectContext!
    var testUser: User!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        patientManager = PatientManager(persistenceController: persistenceController)
        context = persistenceController.container.viewContext
        
        // Create test user with doctor role
        testUser = User.create(in: context, role: .doctor)
        try? context.save()
    }
    
    override func tearDown() {
        testUser = nil
        context = nil
        patientManager = nil
        persistenceController = nil
        
        super.tearDown()
    }
    
    // MARK: - Property 46: Patient Search Partial Matching
    // **Validates: Requirements 17.4**
    
    /// Property: For any search query, results SHALL include all patients with names or IDs that partially match the query
    func testProperty46_PatientSearch_PartialNameMatching() async throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        // Test data with various name patterns
        let testNames = [
            "John Doe", "Jane Doe", "Bob Smith", "Alice Johnson",
            "Michael Brown", "Sarah Davis", "David Wilson", "Emma Martinez",
            "Christopher Anderson", "Olivia Taylor", "James Thomas", "Sophia Moore"
        ]
        
        for iteration in 0..<iterations {
            // Create patients with test names
            var createdPatients: [Patient] = []
            for (index, name) in testNames.enumerated() {
                let patient = try await patientManager.createPatient(
                    name: name,
                    patientID: "PID-\(iteration)-\(index)",
                    for: testUser
                )
                createdPatients.append(patient)
            }
            
            // Test partial matching with various search queries
            let searchQueries = ["Doe", "John", "Smith", "son", "Brown", "Davis", "Wil", "Mar"]
            
            for query in searchQueries {
                let results = try await patientManager.searchPatients(query, for: testUser)
                
                // Verify all matching patients are in results
                let expectedMatches = createdPatients.filter { patient in
                    let name = patient.name ?? ""
                    return name.localizedCaseInsensitiveContains(query)
                }
                
                if results.count != expectedMatches.count {
                    failedCases.append(iteration)
                }
                
                // Verify each expected match is in results
                for expected in expectedMatches {
                    if !results.contains(where: { $0.id == expected.id }) {
                        failedCases.append(iteration)
                    }
                }
            }
            
            // Clean up
            for patient in createdPatients {
                try? await patientManager.deletePatient(patient)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient search partial name matching failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: For any search query, results SHALL include patients with IDs that partially match
    func testProperty46_PatientSearch_PartialIDMatching() async throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create patients with various ID patterns
            let idPatterns = ["P12345", "P67890", "ABC123", "XYZ789", "TEST001", "DEMO999"]
            var createdPatients: [Patient] = []
            
            for (index, patientID) in idPatterns.enumerated() {
                let patient = try await patientManager.createPatient(
                    name: "Patient \(iteration)-\(index)",
                    patientID: patientID,
                    for: testUser
                )
                createdPatients.append(patient)
            }
            
            // Test partial ID matching
            let searchQueries = ["123", "789", "P", "ABC", "TEST", "999", "XYZ"]
            
            for query in searchQueries {
                let results = try await patientManager.searchPatients(query, for: testUser)
                
                // Verify all matching patients are in results
                let expectedMatches = createdPatients.filter { patient in
                    let id = patient.patientID ?? ""
                    return id.localizedCaseInsensitiveContains(query)
                }
                
                if results.count < expectedMatches.count {
                    failedCases.append(iteration)
                }
                
                // Verify each expected match is in results
                for expected in expectedMatches {
                    if !results.contains(where: { $0.id == expected.id }) {
                        failedCases.append(iteration)
                    }
                }
            }
            
            // Clean up
            for patient in createdPatients {
                try? await patientManager.deletePatient(patient)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Patient search partial ID matching failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Search SHALL be case-insensitive for both names and IDs
    func testProperty46_PatientSearch_CaseInsensitiveMatching() async throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create patients with mixed case names and IDs
            let patient1 = try await patientManager.createPatient(
                name: "John DOE",
                patientID: "ABC123",
                for: testUser
            )
            
            let patient2 = try await patientManager.createPatient(
                name: "jane smith",
                patientID: "xyz789",
                for: testUser
            )
            
            let patient3 = try await patientManager.createPatient(
                name: "Bob JOHNSON",
                patientID: "Test001",
                for: testUser
            )
            
            // Test case-insensitive search with various case combinations
            let testCases: [(query: String, expectedCount: Int)] = [
                ("john", 1),      // Should match "John DOE"
                ("JOHN", 1),      // Should match "John DOE"
                ("JoHn", 1),      // Should match "John DOE"
                ("doe", 1),       // Should match "John DOE"
                ("DOE", 1),       // Should match "John DOE"
                ("jane", 1),      // Should match "jane smith"
                ("JANE", 1),      // Should match "jane smith"
                ("smith", 1),     // Should match "jane smith"
                ("SMITH", 1),     // Should match "jane smith"
                ("abc", 1),       // Should match "ABC123"
                ("ABC", 1),       // Should match "ABC123"
                ("xyz", 1),       // Should match "xyz789"
                ("XYZ", 1),       // Should match "xyz789"
                ("test", 1),      // Should match "Test001"
                ("TEST", 1),      // Should match "Test001"
            ]
            
            for testCase in testCases {
                let results = try await patientManager.searchPatients(testCase.query, for: testUser)
                
                if results.count != testCase.expectedCount {
                    failedCases.append(iteration)
                }
            }
            
            // Clean up
            try? await patientManager.deletePatient(patient1)
            try? await patientManager.deletePatient(patient2)
            try? await patientManager.deletePatient(patient3)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Case-insensitive search failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Search SHALL match substrings anywhere in the name or ID
    func testProperty46_PatientSearch_SubstringMatching() async throws {
        let iterations = 100
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create patients
            let patient = try await patientManager.createPatient(
                name: "Christopher Anderson",
                patientID: "PATIENT12345",
                for: testUser
            )
            
            // Test substring matching at different positions
            let substringTests: [(query: String, shouldMatch: Bool)] = [
                // Name substrings
                ("Chris", true),        // Beginning of first name
                ("topher", true),       // Middle of first name
                ("pher", true),         // End of first name
                ("Ander", true),        // Beginning of last name
                ("erson", true),        // End of last name
                ("opher And", true),    // Across names
                
                // ID substrings
                ("PATIENT", true),      // Beginning of ID
                ("12345", true),        // End of ID
                ("TIENT", true),        // Middle of ID
                ("ENT123", true),       // Across ID parts
                
                // Non-matching
                ("xyz", false),         // Not in name or ID
                ("999", false),         // Not in name or ID
            ]
            
            for test in substringTests {
                let results = try await patientManager.searchPatients(test.query, for: testUser)
                
                let patientFound = results.contains(where: { $0.id == patient.id })
                
                if patientFound != test.shouldMatch {
                    failedCases.append(iteration)
                }
            }
            
            // Clean up
            try? await patientManager.deletePatient(patient)
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Substring matching failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Empty search query SHALL return all patients for the user
    func testProperty46_PatientSearch_EmptyQueryReturnsAll() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create random number of patients (1-10)
            let patientCount = Int.random(in: 1...10)
            var createdPatients: [Patient] = []
            
            for i in 0..<patientCount {
                let patient = try await patientManager.createPatient(
                    name: "Patient \(iteration)-\(i)",
                    patientID: "PID-\(iteration)-\(i)",
                    for: testUser
                )
                createdPatients.append(patient)
            }
            
            // Search with empty query
            let results = try await patientManager.searchPatients("", for: testUser)
            
            // Should return all patients
            if results.count != patientCount {
                failedCases.append(iteration)
            }
            
            // Verify all created patients are in results
            for patient in createdPatients {
                if !results.contains(where: { $0.id == patient.id }) {
                    failedCases.append(iteration)
                }
            }
            
            // Clean up
            for patient in createdPatients {
                try? await patientManager.deletePatient(patient)
            }
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "Empty query search failed for \(failedCases.count) out of \(iterations) cases")
    }
    
    /// Property: Search results SHALL only include patients belonging to the specified user
    func testProperty46_PatientSearch_UserIsolation() async throws {
        let iterations = 50
        var failedCases: [Int] = []
        
        for iteration in 0..<iterations {
            // Create a second user
            let user2 = User.create(in: context, role: .doctor)
            try context.save()
            
            // Refresh the user object to ensure it's fully initialized in the context
            context.refresh(user2, mergeChanges: false)
            
            // Ensure the context processes pending changes
            context.processPendingChanges()
            
            // Create patients for first user
            let patient1 = try await patientManager.createPatient(
                name: "User1 Patient",
                patientID: "U1-P1",
                for: testUser
            )
            
            // Create patients for second user
            let patient2 = try await patientManager.createPatient(
                name: "User2 Patient",
                patientID: "U2-P1",
                for: user2
            )
            
            // Search for first user
            let results1 = try await patientManager.searchPatients("Patient", for: testUser)
            
            // Should only return first user's patients
            if !results1.contains(where: { $0.id == patient1.id }) {
                failedCases.append(iteration)
            }
            
            if results1.contains(where: { $0.id == patient2.id }) {
                failedCases.append(iteration)
            }
            
            // Search for second user
            let results2 = try await patientManager.searchPatients("Patient", for: user2)
            
            // Should only return second user's patients
            if !results2.contains(where: { $0.id == patient2.id }) {
                failedCases.append(iteration)
            }
            
            if results2.contains(where: { $0.id == patient1.id }) {
                failedCases.append(iteration)
            }
            
            // Clean up
            try? await patientManager.deletePatient(patient1)
            try? await patientManager.deletePatient(patient2)
            context.delete(user2)
            try? context.save()
        }
        
        XCTAssertTrue(failedCases.isEmpty,
                     "User isolation in search failed for \(failedCases.count) out of \(iterations) cases")
    }
}
