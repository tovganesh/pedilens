//
//  Patient+Extensions.swift
//  PediLens
//
//  Core Data entity extensions for Patient with convenience methods
//

import Foundation
import CoreData

extension Patient {
    
    // MARK: - Factory Methods
    
    /// Create a new Patient entity
    /// - Parameters:
    ///   - context: The managed object context
    ///   - name: Patient's name
    ///   - patientID: Patient's ID
    ///   - dateOfBirth: Optional date of birth
    ///   - notes: Optional notes
    ///   - user: The user who manages this patient
    /// - Returns: A new Patient instance
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        patientID: String,
        dateOfBirth: Date? = nil,
        notes: String? = nil,
        user: User? = nil
    ) -> Patient {
        let patient = Patient(context: context)
        patient.id = UUID()
        patient.name = name
        patient.patientID = patientID
        patient.dateOfBirth = dateOfBirth
        patient.notes = notes
        patient.createdAt = Date()
        patient.user = user
        return patient
    }
    
    // MARK: - Fetch Requests
    
    /// Fetch all patients for a specific user
    /// - Parameters:
    ///   - user: The user whose patients to fetch
    ///   - context: The managed object context
    /// - Returns: Array of patients
    static func fetchPatients(
        for user: User,
        in context: NSManagedObjectContext
    ) -> [Patient] {
        let request: NSFetchRequest<Patient> = Patient.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching patients for user: \(error)")
            return []
        }
    }
    
    /// Fetch a patient by ID
    /// - Parameters:
    ///   - id: The patient's UUID
    ///   - context: The managed object context
    /// - Returns: The patient, or nil if not found
    static func fetchPatient(
        byID id: UUID,
        in context: NSManagedObjectContext
    ) -> Patient? {
        let request: NSFetchRequest<Patient> = Patient.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let patients = try context.fetch(request)
            return patients.first
        } catch {
            print("Error fetching patient by ID: \(error)")
            return nil
        }
    }
    
    /// Search patients by name or patient ID (partial matching)
    /// - Parameters:
    ///   - searchText: The search text
    ///   - user: Optional user to filter by
    ///   - context: The managed object context
    /// - Returns: Array of matching patients
    static func search(
        _ searchText: String,
        for user: User? = nil,
        in context: NSManagedObjectContext
    ) -> [Patient] {
        let request: NSFetchRequest<Patient> = Patient.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Search in name or patientID
        let searchPredicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR patientID CONTAINS[cd] %@",
            searchText, searchText
        )
        predicates.append(searchPredicate)
        
        // Filter by user if provided
        if let user = user {
            predicates.append(NSPredicate(format: "user == %@", user))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error searching patients: \(error)")
            return []
        }
    }
    
    /// Fetch all patients
    /// - Parameter context: The managed object context
    /// - Returns: Array of all patients
    static func fetchAll(in context: NSManagedObjectContext) -> [Patient] {
        let request: NSFetchRequest<Patient> = Patient.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all patients: \(error)")
            return []
        }
    }
    
    // MARK: - Update Methods
    
    /// Update patient information
    /// - Parameters:
    ///   - name: New name
    ///   - patientID: New patient ID
    ///   - dateOfBirth: New date of birth
    ///   - notes: New notes
    func update(
        name: String? = nil,
        patientID: String? = nil,
        dateOfBirth: Date? = nil,
        notes: String? = nil
    ) {
        if let name = name {
            self.name = name
        }
        if let patientID = patientID {
            self.patientID = patientID
        }
        if let dateOfBirth = dateOfBirth {
            self.dateOfBirth = dateOfBirth
        }
        if let notes = notes {
            self.notes = notes
        }
    }
    
    // MARK: - Computed Properties
    
    /// Get all wound records as an array, sorted by last updated date
    var woundRecordsArray: [WoundRecord] {
        let set = woundRecords as? Set<WoundRecord> ?? []
        return Array(set).sorted { ($0.lastUpdated ?? Date.distantPast) > ($1.lastUpdated ?? Date.distantPast) }
    }
    
    /// Get count of active wound records
    var activeWoundCount: Int {
        return woundRecordsArray.filter { $0.status == "active" }.count
    }
    
    /// Get count of all wound records
    var totalWoundCount: Int {
        return woundRecordsArray.count
    }
    
    // MARK: - Delete Methods
    
    /// Delete the patient and all associated data
    /// - Parameter context: The managed object context
    func delete(from context: NSManagedObjectContext) {
        context.delete(self)
    }
}
