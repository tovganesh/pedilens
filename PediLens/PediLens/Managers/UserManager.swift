//
//  UserManager.swift
//  PediLens
//
//  Created by PediLens Team
//  User role management and feature access control
//

import Foundation
import CoreData
import Combine

/// Protocol defining user management operations
protocol UserManagerProtocol {
    func setUserRole(_ role: UserRole) async throws
    func getUserRole() -> UserRole
    func canAccessFeature(_ feature: Feature) -> Bool
}

/// Features that may have role-based access restrictions
enum Feature {
    case multiplePatients
    case patientSearch
    case advancedMeasurements
    case dataExport
    case iCloudSync
}

/// Errors that can occur during user management operations
enum UserManagerError: LocalizedError {
    case userNotFound
    case userCreationFailed
    case roleUpdateFailed
    case invalidRole
    case persistenceError(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found in the system"
        case .userCreationFailed:
            return "Failed to create user"
        case .roleUpdateFailed:
            return "Failed to update user role"
        case .invalidRole:
            return "Invalid user role specified"
        case .persistenceError(let error):
            return "Persistence error: \(error.localizedDescription)"
        }
    }
}

/// Manages user roles and feature access control for PediLens
/// Stores user role in Core Data and provides role-based feature access
class UserManager: ObservableObject, UserManagerProtocol {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = UserManager()
    
    /// Core Data persistence controller
    private let persistenceController: PersistenceController
    
    /// Cached user role for performance
    private var cachedRole: UserRole?
    
    /// Published current user role for SwiftUI binding
    @Published var currentUserRole: UserRole?
    
    /// Lock for thread-safe access to cached role
    private let cacheLock = NSLock()
    
    // MARK: - Initialization
    
    /// Initialize with a persistence controller
    /// - Parameter persistenceController: The Core Data persistence controller (defaults to shared instance)
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        
        // Load cached role on initialization
        self.cachedRole = loadRoleFromStorage()
        self.currentUserRole = cachedRole
    }
    
    // MARK: - Public Methods
    
    /// Loads the current user role and updates the published property
    func loadCurrentUser() {
        let role = getUserRole()
        DispatchQueue.main.async {
            self.currentUserRole = role
        }
    }
    
    /// Sets the user role and persists it to Core Data
    /// - Parameter role: The role to set for the user
    /// - Throws: UserManagerError if the operation fails
    func setUserRole(_ role: UserRole) async throws {
        let context = persistenceController.container.viewContext
        
        try await context.perform {
            // Fetch or create user
            let user = try self.fetchOrCreateUser(in: context)
            
            // Update role
            user.role = role.rawValue
            
            // Save changes
            do {
                try context.save()
                
                // Update cache and published property
                self.updateCachedRole(role)
                DispatchQueue.main.async {
                    self.currentUserRole = role
                }
            } catch {
                throw UserManagerError.persistenceError(error)
            }
        }
    }
    
    /// Retrieves the current user role
    /// - Returns: The current user role (defaults to .patient if not set)
    func getUserRole() -> UserRole {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // Return cached role if available
        if let cached = cachedRole {
            return cached
        }
        
        // Load from storage
        if let loaded = loadRoleFromStorage() {
            cachedRole = loaded
            return loaded
        }
        
        // Default to patient role
        return .patient
    }
    
    /// Checks if the current user can access a specific feature
    /// - Parameter feature: The feature to check access for
    /// - Returns: True if the user can access the feature, false otherwise
    func canAccessFeature(_ feature: Feature) -> Bool {
        let role = getUserRole()
        
        switch feature {
        case .multiplePatients:
            // Only doctors can manage multiple patients
            return role == .doctor
            
        case .patientSearch:
            // Only doctors need patient search
            return role == .doctor
            
        case .advancedMeasurements:
            // Both roles can access advanced measurements
            return true
            
        case .dataExport:
            // Both roles can export data
            return true
            
        case .iCloudSync:
            // Both roles can use iCloud sync
            return true
        }
    }
    
    // MARK: - Private Methods
    
    /// Fetches the existing user or creates a new one if it doesn't exist
    /// - Parameter context: The managed object context
    /// - Returns: The user entity
    /// - Throws: UserManagerError if the operation fails
    private func fetchOrCreateUser(in context: NSManagedObjectContext) throws -> User {
        // Fetch existing user
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let users = try context.fetch(fetchRequest)
            
            if let existingUser = users.first {
                return existingUser
            }
            
            // Create new user if none exists
            let newUser = User(context: context)
            newUser.id = UUID()
            newUser.role = UserRole.patient.rawValue // Default role
            newUser.createdAt = Date()
            newUser.iCloudSyncEnabled = false
            
            return newUser
        } catch {
            throw UserManagerError.persistenceError(error)
        }
    }
    
    /// Loads the user role from Core Data storage
    /// - Returns: The user role if found, nil otherwise
    private func loadRoleFromStorage() -> UserRole? {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let users = try context.fetch(fetchRequest)
            
            if let user = users.first,
               let roleString = user.role,
               let role = UserRole(rawValue: roleString) {
                return role
            }
        } catch {
            print("Failed to load user role from storage: \(error)")
        }
        
        return nil
    }
    
    /// Updates the cached role in a thread-safe manner
    /// - Parameter role: The role to cache
    private func updateCachedRole(_ role: UserRole) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        cachedRole = role
    }
}
