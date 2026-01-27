//
//  UserManagerTests.swift
//  PediLensTests
//
//  Unit tests for UserManager
//

import XCTest
import CoreData
@testable import PediLens

class UserManagerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var userManager: UserManager!
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory persistence controller for testing
        persistenceController = PersistenceController(inMemory: true)
        userManager = UserManager(persistenceController: persistenceController)
    }
    
    override func tearDown() {
        userManager = nil
        persistenceController = nil
        
        super.tearDown()
    }
    
    // MARK: - Role Management Tests
    
    func testSetUserRole_Doctor() async throws {
        // When setting user role to doctor
        try await userManager.setUserRole(.doctor)
        
        // Then the role should be persisted
        let role = userManager.getUserRole()
        XCTAssertEqual(role, .doctor, "User role should be doctor")
    }
    
    func testSetUserRole_Patient() async throws {
        // When setting user role to patient
        try await userManager.setUserRole(.patient)
        
        // Then the role should be persisted
        let role = userManager.getUserRole()
        XCTAssertEqual(role, .patient, "User role should be patient")
    }
    
    func testGetUserRole_DefaultsToPatient() {
        // Given a fresh user manager with no role set
        // When getting the user role
        let role = userManager.getUserRole()
        
        // Then it should default to patient
        XCTAssertEqual(role, .patient, "Default role should be patient")
    }
    
    func testSetUserRole_UpdatesExistingUser() async throws {
        // Given a user with doctor role
        try await userManager.setUserRole(.doctor)
        XCTAssertEqual(userManager.getUserRole(), .doctor)
        
        // When updating to patient role
        try await userManager.setUserRole(.patient)
        
        // Then the role should be updated
        let role = userManager.getUserRole()
        XCTAssertEqual(role, .patient, "Role should be updated to patient")
    }
    
    func testSetUserRole_PersistsAcrossInstances() async throws {
        // Given a user with doctor role
        try await userManager.setUserRole(.doctor)
        
        // When creating a new UserManager instance
        let newUserManager = UserManager(persistenceController: persistenceController)
        
        // Then the role should be persisted
        let role = newUserManager.getUserRole()
        XCTAssertEqual(role, .doctor, "Role should persist across instances")
    }
    
    // MARK: - Feature Access Tests
    
    func testCanAccessFeature_MultiplePatients_Doctor() async throws {
        // Given a doctor user
        try await userManager.setUserRole(.doctor)
        
        // When checking access to multiple patients feature
        let canAccess = userManager.canAccessFeature(.multiplePatients)
        
        // Then access should be granted
        XCTAssertTrue(canAccess, "Doctor should have access to multiple patients")
    }
    
    func testCanAccessFeature_MultiplePatients_Patient() async throws {
        // Given a patient user
        try await userManager.setUserRole(.patient)
        
        // When checking access to multiple patients feature
        let canAccess = userManager.canAccessFeature(.multiplePatients)
        
        // Then access should be denied
        XCTAssertFalse(canAccess, "Patient should not have access to multiple patients")
    }
    
    func testCanAccessFeature_PatientSearch_Doctor() async throws {
        // Given a doctor user
        try await userManager.setUserRole(.doctor)
        
        // When checking access to patient search feature
        let canAccess = userManager.canAccessFeature(.patientSearch)
        
        // Then access should be granted
        XCTAssertTrue(canAccess, "Doctor should have access to patient search")
    }
    
    func testCanAccessFeature_PatientSearch_Patient() async throws {
        // Given a patient user
        try await userManager.setUserRole(.patient)
        
        // When checking access to patient search feature
        let canAccess = userManager.canAccessFeature(.patientSearch)
        
        // Then access should be denied
        XCTAssertFalse(canAccess, "Patient should not have access to patient search")
    }
    
    func testCanAccessFeature_AdvancedMeasurements_BothRoles() async throws {
        // Given a doctor user
        try await userManager.setUserRole(.doctor)
        XCTAssertTrue(userManager.canAccessFeature(.advancedMeasurements),
                     "Doctor should have access to advanced measurements")
        
        // Given a patient user
        try await userManager.setUserRole(.patient)
        XCTAssertTrue(userManager.canAccessFeature(.advancedMeasurements),
                     "Patient should have access to advanced measurements")
    }
    
    func testCanAccessFeature_DataExport_BothRoles() async throws {
        // Given a doctor user
        try await userManager.setUserRole(.doctor)
        XCTAssertTrue(userManager.canAccessFeature(.dataExport),
                     "Doctor should have access to data export")
        
        // Given a patient user
        try await userManager.setUserRole(.patient)
        XCTAssertTrue(userManager.canAccessFeature(.dataExport),
                     "Patient should have access to data export")
    }
    
    func testCanAccessFeature_iCloudSync_BothRoles() async throws {
        // Given a doctor user
        try await userManager.setUserRole(.doctor)
        XCTAssertTrue(userManager.canAccessFeature(.iCloudSync),
                     "Doctor should have access to iCloud sync")
        
        // Given a patient user
        try await userManager.setUserRole(.patient)
        XCTAssertTrue(userManager.canAccessFeature(.iCloudSync),
                     "Patient should have access to iCloud sync")
    }
    
    // MARK: - Core Data Integration Tests
    
    func testSetUserRole_CreatesUserEntity() async throws {
        // Given no existing user
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        
        var usersBefore = try context.fetch(fetchRequest)
        XCTAssertEqual(usersBefore.count, 0, "Should start with no users")
        
        // When setting a role
        try await userManager.setUserRole(.doctor)
        
        // Then a user entity should be created
        var usersAfter = try context.fetch(fetchRequest)
        XCTAssertEqual(usersAfter.count, 1, "Should create one user")
        XCTAssertEqual(usersAfter.first?.role, "doctor", "User role should be doctor")
    }
    
    func testSetUserRole_UpdatesExistingUserEntity() async throws {
        // Given an existing user
        try await userManager.setUserRole(.doctor)
        
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        
        let usersBefore = try context.fetch(fetchRequest)
        XCTAssertEqual(usersBefore.count, 1, "Should have one user")
        let userId = usersBefore.first?.id
        
        // When updating the role
        try await userManager.setUserRole(.patient)
        
        // Then the same user entity should be updated
        let usersAfter = try context.fetch(fetchRequest)
        XCTAssertEqual(usersAfter.count, 1, "Should still have one user")
        XCTAssertEqual(usersAfter.first?.id, userId, "Should be the same user")
        XCTAssertEqual(usersAfter.first?.role, "patient", "User role should be updated")
    }
    
    func testSetUserRole_SetsUserProperties() async throws {
        // When creating a new user
        try await userManager.setUserRole(.doctor)
        
        // Then all user properties should be set
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        let users = try context.fetch(fetchRequest)
        
        XCTAssertEqual(users.count, 1, "Should have one user")
        
        let user = users.first!
        XCTAssertNotNil(user.id, "User should have an ID")
        XCTAssertNotNil(user.createdAt, "User should have a creation date")
        XCTAssertEqual(user.role, "doctor", "User role should be set")
        XCTAssertEqual(user.iCloudSyncEnabled, false, "iCloud sync should default to false")
    }
    
    // MARK: - Thread Safety Tests
    
    func testGetUserRole_ThreadSafe() async throws {
        // Given a user role
        try await userManager.setUserRole(.doctor)
        
        // When accessing role from multiple threads concurrently
        await withTaskGroup(of: UserRole.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    return self.userManager.getUserRole()
                }
            }
            
            // Then all accesses should return the correct role
            for await role in group {
                XCTAssertEqual(role, .doctor, "Role should be consistent across threads")
            }
        }
    }
    
    func testSetUserRole_ThreadSafe() async throws {
        // When setting role from multiple threads concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let role: UserRole = i % 2 == 0 ? .doctor : .patient
                    try? await self.userManager.setUserRole(role)
                }
            }
        }
        
        // Then the final role should be one of the valid roles
        let finalRole = userManager.getUserRole()
        XCTAssertTrue(finalRole == .doctor || finalRole == .patient,
                     "Final role should be valid")
    }
    
    // MARK: - Edge Cases
    
    func testGetUserRole_EmptyDatabase() {
        // Given an empty database
        // When getting the user role
        let role = userManager.getUserRole()
        
        // Then it should return the default role
        XCTAssertEqual(role, .patient, "Should return default patient role")
    }
    
    func testSetUserRole_MultipleRoleChanges() async throws {
        // When changing roles multiple times
        try await userManager.setUserRole(.doctor)
        XCTAssertEqual(userManager.getUserRole(), .doctor)
        
        try await userManager.setUserRole(.patient)
        XCTAssertEqual(userManager.getUserRole(), .patient)
        
        try await userManager.setUserRole(.doctor)
        XCTAssertEqual(userManager.getUserRole(), .doctor)
        
        try await userManager.setUserRole(.patient)
        
        // Then the final role should be correct
        XCTAssertEqual(userManager.getUserRole(), .patient)
    }
}
