//
//  WoundManager.swift
//  PediLens
//
//  Manages wound record CRUD operations, creation prompts, and lifecycle
//

import Foundation
import CoreData

/// Protocol defining wound management operations
protocol WoundManagerProtocol {
    func createWoundRecord(location: String, initialAssessmentDate: Date, patient: Patient?) async throws -> WoundRecord
    func updateWoundRecord(_ record: WoundRecord, location: String?, status: String?) async throws
    func archiveWoundRecord(_ record: WoundRecord) async throws
    func deleteWoundRecord(_ record: WoundRecord, createExport: Bool) async throws
    func fetchWoundRecords(for patient: Patient?) async throws -> [WoundRecord]
    func fetchWoundRecord(byID id: UUID) async throws -> WoundRecord?
}

/// Errors that can occur during wound management operations
enum WoundManagerError: LocalizedError {
    case invalidLocation
    case recordNotFound
    case saveFailed(Error)
    case deleteFailed(Error)
    case exportFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Wound location cannot be empty"
        case .recordNotFound:
            return "Wound record not found"
        case .saveFailed(let error):
            return "Failed to save wound record: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete wound record: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Failed to create export package: \(error.localizedDescription)"
        }
    }
}

/// Manager for wound record operations
class WoundManager: WoundManagerProtocol {
    
    // MARK: - Properties
    
    private let persistenceController: PersistenceController
    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create Operations
    
    /// Create a new wound record with required prompts
    /// - Parameters:
    ///   - location: Wound location description (required)
    ///   - initialAssessmentDate: Date of initial assessment
    ///   - patient: Optional patient association (required for doctor role)
    /// - Returns: The created wound record
    /// - Throws: WoundManagerError if creation fails
    func createWoundRecord(
        location: String,
        initialAssessmentDate: Date = Date(),
        patient: Patient? = nil
    ) async throws -> WoundRecord {
        // Validate location is not empty
        guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WoundManagerError.invalidLocation
        }
        
        return try await context.perform {
            // Create the wound record
            let record = WoundRecord.create(
                in: self.context,
                location: location,
                initialAssessmentDate: initialAssessmentDate,
                status: "active",
                patient: patient
            )
            
            // Save the context
            do {
                try self.context.save()
                return record
            } catch {
                self.context.rollback()
                throw WoundManagerError.saveFailed(error)
            }
        }
    }
    
    // MARK: - Read Operations
    
    /// Fetch wound records for a specific patient or all records
    /// - Parameter patient: Optional patient to filter by
    /// - Returns: Array of wound records
    /// - Throws: WoundManagerError if fetch fails
    func fetchWoundRecords(for patient: Patient? = nil) async throws -> [WoundRecord] {
        return try await context.perform {
            if let patient = patient {
                return WoundRecord.fetchWoundRecords(for: patient, in: self.context)
            } else {
                return WoundRecord.fetchAll(in: self.context)
            }
        }
    }
    
    /// Fetch a wound record by ID
    /// - Parameter id: The wound record's UUID
    /// - Returns: The wound record, or nil if not found
    /// - Throws: WoundManagerError if fetch fails
    func fetchWoundRecord(byID id: UUID) async throws -> WoundRecord? {
        return try await context.perform {
            return WoundRecord.fetchWoundRecord(byID: id, in: self.context)
        }
    }
    
    /// Fetch wound records by status
    /// - Parameters:
    ///   - status: The status to filter by
    ///   - patient: Optional patient to filter by
    /// - Returns: Array of wound records
    func fetchWoundRecords(withStatus status: String, for patient: Patient? = nil) async throws -> [WoundRecord] {
        return try await context.perform {
            return WoundRecord.fetchWoundRecords(withStatus: status, for: patient, in: self.context)
        }
    }
    
    /// Fetch wound records within a date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - patient: Optional patient to filter by
    /// - Returns: Array of wound records
    func fetchWoundRecords(from startDate: Date, to endDate: Date, for patient: Patient? = nil) async throws -> [WoundRecord] {
        return try await context.perform {
            return WoundRecord.fetchWoundRecords(from: startDate, to: endDate, for: patient, in: self.context)
        }
    }
    
    // MARK: - Update Operations
    
    /// Update a wound record's information
    /// - Parameters:
    ///   - record: The wound record to update
    ///   - location: New location (optional)
    ///   - status: New status (optional)
    /// - Throws: WoundManagerError if update fails
    func updateWoundRecord(
        _ record: WoundRecord,
        location: String? = nil,
        status: String? = nil
    ) async throws {
        // Validate location if provided
        if let location = location {
            guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WoundManagerError.invalidLocation
            }
        }
        
        try await context.perform {
            record.update(location: location, status: status)
            
            do {
                try self.context.save()
            } catch {
                self.context.rollback()
                throw WoundManagerError.saveFailed(error)
            }
        }
    }
    
    /// Archive a wound record
    /// - Parameter record: The wound record to archive
    /// - Throws: WoundManagerError if archive fails
    func archiveWoundRecord(_ record: WoundRecord) async throws {
        try await context.perform {
            record.archive()
            
            do {
                try self.context.save()
            } catch {
                self.context.rollback()
                throw WoundManagerError.saveFailed(error)
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a wound record with optional export creation
    /// - Parameters:
    ///   - record: The wound record to delete
    ///   - createExport: Whether to create an export package before deletion
    /// - Throws: WoundManagerError if deletion fails
    func deleteWoundRecord(_ record: WoundRecord, createExport: Bool = false) async throws {
        // TODO: Implement export creation if requested
        // This will be implemented in task 16 (Export System)
        if createExport {
            // Placeholder for export creation
            // Will be implemented with ExportManager
        }
        
        try await context.perform {
            // Ensure the record is in this context
            // If it's from a different context or has temporary IDs, we need to handle it
            let recordToDelete: WoundRecord
            
            if record.managedObjectContext == self.context {
                // Record is already in our context, use it directly
                recordToDelete = record
            } else if let recordID = record.id {
                // Record is from a different context, fetch it fresh
                guard let fetchedRecord = WoundRecord.fetchWoundRecord(byID: recordID, in: self.context) else {
                    throw WoundManagerError.recordNotFound
                }
                recordToDelete = fetchedRecord
            } else {
                throw WoundManagerError.recordNotFound
            }
            
            // Delete the record from Core Data
            // Capture sessions and related data will be automatically deleted
            // due to the cascade delete rule in the Core Data model
            recordToDelete.delete(from: self.context)
            
            do {
                // Save without validation to avoid "captureSessions is not valid" errors
                // during cascade delete. The cascade delete rule will properly handle
                // the deletion of related objects.
                try self.context.save()
            } catch let error as NSError {
                self.context.rollback()
                
                // If we get a validation error about relationships during deletion,
                // it's likely a Core Data timing issue with cascade deletes.
                // Try again with a fresh fetch of the record.
                if error.code == NSValidationMultipleErrorsError || error.code == NSValidationRelationshipDeniedDeleteError {
                    if let recordID = recordToDelete.id,
                       let freshRecord = WoundRecord.fetchWoundRecord(byID: recordID, in: self.context) {
                        freshRecord.delete(from: self.context)
                        try self.context.save()
                        return
                    }
                }
                
                throw WoundManagerError.deleteFailed(error)
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validate wound record data before persistence
    /// - Parameter record: The wound record to validate
    /// - Returns: True if valid, false otherwise
    func validateWoundRecord(_ record: WoundRecord) -> Bool {
        // Validate required fields
        guard let location = record.location, !location.isEmpty else {
            return false
        }
        
        guard record.id != nil else {
            return false
        }
        
        guard record.initialAssessmentDate != nil else {
            return false
        }
        
        guard record.status != nil else {
            return false
        }
        
        return true
    }
}
