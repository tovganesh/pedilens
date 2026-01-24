//
//  User+Extensions.swift
//  PediLens
//
//  Core Data entity extensions for User with convenience methods
//

import Foundation
import CoreData

extension User {
    
    // MARK: - Factory Methods
    
    /// Create a new User entity
    /// - Parameters:
    ///   - context: The managed object context
    ///   - role: The user role (doctor or patient)
    ///   - iCloudSyncEnabled: Whether iCloud sync is enabled
    /// - Returns: A new User instance
    static func create(
        in context: NSManagedObjectContext,
        role: UserRole,
        iCloudSyncEnabled: Bool = false
    ) -> User {
        let user = User(context: context)
        user.id = UUID()
        user.role = role.rawValue
        user.createdAt = Date()
        user.iCloudSyncEnabled = iCloudSyncEnabled
        return user
    }
    
    // MARK: - Fetch Requests
    
    /// Fetch the current user (there should only be one)
    /// - Parameter context: The managed object context
    /// - Returns: The current user, or nil if not found
    static func fetchCurrentUser(in context: NSManagedObjectContext) -> User? {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("Error fetching current user: \(error)")
            return nil
        }
    }
    
    /// Fetch all users
    /// - Parameter context: The managed object context
    /// - Returns: Array of all users
    static func fetchAll(in context: NSManagedObjectContext) -> [User] {
        let request: NSFetchRequest<User> = User.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all users: \(error)")
            return []
        }
    }
    
    // MARK: - Update Methods
    
    /// Update the user's role
    /// - Parameter role: The new role
    func updateRole(_ role: UserRole) {
        self.role = role.rawValue
    }
    
    /// Update iCloud sync setting
    /// - Parameter enabled: Whether iCloud sync should be enabled
    func updateICloudSync(enabled: Bool) {
        self.iCloudSyncEnabled = enabled
    }
    
    // MARK: - Computed Properties
    
    /// Get the user's role as a UserRole enum
    var userRole: UserRole {
        return UserRole(rawValue: role ?? "patient") ?? .patient
    }
    
    /// Get all patients as an array
    var patientsArray: [Patient] {
        let set = patients as? Set<Patient> ?? []
        return Array(set).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    // MARK: - Delete Methods
    
    /// Delete the user and all associated data
    /// - Parameter context: The managed object context
    func delete(from context: NSManagedObjectContext) {
        context.delete(self)
    }
}
