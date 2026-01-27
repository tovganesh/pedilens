//
//  PatientManager.swift
//  PediLens
//
//  Created by PediLens Team
//  Patient management for doctor role with CRUD operations and search
//

import Foundation
import CoreData

/// Protocol defining patient management operations
protocol PatientManagerProtocol {
    func createPatient(name: String, patientID: String, dateOfBirth: Date?, notes: String?, for user: User) async throws -> Patient
    func updatePatient(_ patient: Patient, name: String?, patientID: String?, dateOfBirth: Date?, notes: String?) async throws
    func deletePatient(_ patient: Patient) async throws
    func fetchPatients(for user: User) async throws -> [Patient]
    func fetchPatient(byID id: UUID) async throws -> Patient?
    func searchPatients(_ searchText: String, for user: User) async throws -> [Patient]
}

/// Errors that can occur during patient management operations
enum PatientManagerError: LocalizedError {
    case patientNotFound
    case patientCreationFailed
    case patientUpdateFailed
    case patientDeletionFailed
    case invalidInput(String)
    case persistenceError(Error)
    
    var errorDescription: String? {
        switch self {
        case .patientNotFound:
            return "Patient not found in the system"
        case .patientCreationFailed:
            return "Failed to create patient"
        case .patientUpdateFailed:
            return "Failed to update patient"
        case .patientDeletionFailed:
            return "Failed to delete patient"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .persistenceError(let error):
            return "Persistence error: \(error.localizedDescription)"
        }
    }
}

/// Manages patient records for doctor users
/// Provides CRUD operations and search functionality with partial matching
class PatientManager: PatientManagerProtocol {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = PatientManager()
    
    /// Core Data persistence controller
    private let persistenceController: PersistenceController
    
    // MARK: - Initialization
    
    /// Initialize with a persistence controller
    /// - Parameter persistenceController: The Core Data persistence controller (defaults to shared instance)
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Public Methods
    
    /// Creates a new patient record
    /// - Parameters:
    ///   - name: Patient's name
    ///   - patientID: Patient's ID
    ///   - dateOfBirth: Optional date of birth
    ///   - notes: Optional notes
    ///   - user: The user (doctor) who manages this patient
    /// - Returns: The created patient
    /// - Throws: PatientManagerError if the operation fails
    func createPatient(
        name: String,
        patientID: String,
        dateOfBirth: Date? = nil,
        notes: String? = nil,
        for user: User
    ) async throws -> Patient {
        // Validate input
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PatientManagerError.invalidInput("Patient name cannot be empty")
        }
        
        guard !patientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PatientManagerError.invalidInput("Patient ID cannot be empty")
        }
        
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let patient = Patient.create(
                in: context,
                name: name,
                patientID: patientID,
                dateOfBirth: dateOfBirth,
                notes: notes,
                user: user
            )
            
            do {
                try context.save()
                return patient
            } catch {
                throw PatientManagerError.persistenceError(error)
            }
        }
    }
    
    /// Updates an existing patient record
    /// - Parameters:
    ///   - patient: The patient to update
    ///   - name: New name (optional)
    ///   - patientID: New patient ID (optional)
    ///   - dateOfBirth: New date of birth (optional)
    ///   - notes: New notes (optional)
    /// - Throws: PatientManagerError if the operation fails
    func updatePatient(
        _ patient: Patient,
        name: String? = nil,
        patientID: String? = nil,
        dateOfBirth: Date? = nil,
        notes: String? = nil
    ) async throws {
        // Validate input if provided
        if let name = name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PatientManagerError.invalidInput("Patient name cannot be empty")
        }
        
        if let patientID = patientID, patientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PatientManagerError.invalidInput("Patient ID cannot be empty")
        }
        
        let context = persistenceController.container.viewContext
        
        try await context.perform {
            patient.update(
                name: name,
                patientID: patientID,
                dateOfBirth: dateOfBirth,
                notes: notes
            )
            
            do {
                try context.save()
            } catch {
                throw PatientManagerError.persistenceError(error)
            }
        }
    }
    
    /// Deletes a patient record and all associated wound records
    /// - Parameter patient: The patient to delete
    /// - Throws: PatientManagerError if the operation fails
    func deletePatient(_ patient: Patient) async throws {
        let context = persistenceController.container.viewContext
        
        try await context.perform {
            patient.delete(from: context)
            
            do {
                try context.save()
            } catch {
                throw PatientManagerError.persistenceError(error)
            }
        }
    }
    
    /// Fetches all patients for a specific user
    /// - Parameter user: The user whose patients to fetch
    /// - Returns: Array of patients sorted by name
    /// - Throws: PatientManagerError if the operation fails
    func fetchPatients(for user: User) async throws -> [Patient] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            return Patient.fetchPatients(for: user, in: context)
        }
    }
    
    /// Fetches a patient by ID
    /// - Parameter id: The patient's UUID
    /// - Returns: The patient, or nil if not found
    /// - Throws: PatientManagerError if the operation fails
    func fetchPatient(byID id: UUID) async throws -> Patient? {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            return Patient.fetchPatient(byID: id, in: context)
        }
    }
    
    /// Searches patients by name or patient ID with partial matching
    /// - Parameters:
    ///   - searchText: The search text
    ///   - user: The user whose patients to search
    /// - Returns: Array of matching patients sorted by name
    /// - Throws: PatientManagerError if the operation fails
    func searchPatients(_ searchText: String, for user: User) async throws -> [Patient] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            return Patient.search(searchText, for: user, in: context)
        }
    }
    
    // MARK: - Statistics Methods
    
    /// Calculates aggregate statistics for a patient
    /// - Parameter patient: The patient to calculate statistics for
    /// - Returns: Patient statistics
    func calculateStatistics(for patient: Patient) -> PatientStatistics {
        let woundRecords = patient.woundRecordsArray
        let totalWounds = woundRecords.count
        let activeWounds = woundRecords.filter { $0.status == "active" }.count
        let healedWounds = woundRecords.filter { $0.status == "healed" }.count
        
        // Calculate healing trend (percentage of healed wounds)
        let healingRate = totalWounds > 0 ? Double(healedWounds) / Double(totalWounds) : 0.0
        
        return PatientStatistics(
            totalWounds: totalWounds,
            activeWounds: activeWounds,
            healedWounds: healedWounds,
            healingRate: healingRate
        )
    }
}

/// Statistics for a patient's wound records
struct PatientStatistics {
    let totalWounds: Int
    let activeWounds: Int
    let healedWounds: Int
    let healingRate: Double // 0.0 to 1.0
}
