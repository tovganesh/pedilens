//
//  WoundRecord+Extensions.swift
//  PediLens
//
//  Core Data entity extensions for WoundRecord with convenience methods
//

import Foundation
import CoreData

extension WoundRecord {
    
    // MARK: - Factory Methods
    
    /// Create a new WoundRecord entity
    /// - Parameters:
    ///   - context: The managed object context
    ///   - location: Wound location description
    ///   - initialAssessmentDate: Date of initial assessment
    ///   - status: Wound status (default: "active")
    ///   - patient: Optional patient association
    /// - Returns: A new WoundRecord instance
    static func create(
        in context: NSManagedObjectContext,
        location: String,
        initialAssessmentDate: Date = Date(),
        status: String = "active",
        patient: Patient? = nil
    ) -> WoundRecord {
        let record = WoundRecord(context: context)
        record.id = UUID()
        record.location = location
        record.initialAssessmentDate = initialAssessmentDate
        record.status = status
        record.lastUpdated = Date()
        record.patient = patient
        return record
    }
    
    // MARK: - Fetch Requests
    
    /// Fetch all wound records for a specific patient
    /// - Parameters:
    ///   - patient: The patient whose wound records to fetch
    ///   - context: The managed object context
    /// - Returns: Array of wound records
    static func fetchWoundRecords(
        for patient: Patient,
        in context: NSManagedObjectContext
    ) -> [WoundRecord] {
        let request: NSFetchRequest<WoundRecord> = WoundRecord.fetchRequest()
        request.predicate = NSPredicate(format: "patient == %@", patient)
        request.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching wound records for patient: \(error)")
            return []
        }
    }
    
    /// Fetch a wound record by ID
    /// - Parameters:
    ///   - id: The wound record's UUID
    ///   - context: The managed object context
    /// - Returns: The wound record, or nil if not found
    static func fetchWoundRecord(
        byID id: UUID,
        in context: NSManagedObjectContext
    ) -> WoundRecord? {
        let request: NSFetchRequest<WoundRecord> = WoundRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let records = try context.fetch(request)
            return records.first
        } catch {
            print("Error fetching wound record by ID: \(error)")
            return nil
        }
    }
    
    /// Fetch wound records by status
    /// - Parameters:
    ///   - status: The status to filter by
    ///   - patient: Optional patient to filter by
    ///   - context: The managed object context
    /// - Returns: Array of wound records
    static func fetchWoundRecords(
        withStatus status: String,
        for patient: Patient? = nil,
        in context: NSManagedObjectContext
    ) -> [WoundRecord] {
        let request: NSFetchRequest<WoundRecord> = WoundRecord.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "status == %@", status)
        ]
        
        if let patient = patient {
            predicates.append(NSPredicate(format: "patient == %@", patient))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching wound records by status: \(error)")
            return []
        }
    }
    
    /// Fetch wound records within a date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - patient: Optional patient to filter by
    ///   - context: The managed object context
    /// - Returns: Array of wound records
    static func fetchWoundRecords(
        from startDate: Date,
        to endDate: Date,
        for patient: Patient? = nil,
        in context: NSManagedObjectContext
    ) -> [WoundRecord] {
        let request: NSFetchRequest<WoundRecord> = WoundRecord.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "lastUpdated >= %@ AND lastUpdated <= %@", startDate as NSDate, endDate as NSDate)
        ]
        
        if let patient = patient {
            predicates.append(NSPredicate(format: "patient == %@", patient))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching wound records by date range: \(error)")
            return []
        }
    }
    
    /// Fetch all wound records
    /// - Parameter context: The managed object context
    /// - Returns: Array of all wound records
    static func fetchAll(in context: NSManagedObjectContext) -> [WoundRecord] {
        let request: NSFetchRequest<WoundRecord> = WoundRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all wound records: \(error)")
            return []
        }
    }
    
    // MARK: - Update Methods
    
    /// Update wound record information
    /// - Parameters:
    ///   - location: New location
    ///   - status: New status
    func update(
        location: String? = nil,
        status: String? = nil
    ) {
        if let location = location {
            self.location = location
        }
        if let status = status {
            self.status = status
        }
        self.lastUpdated = Date()
    }
    
    /// Mark the wound record as updated (updates lastUpdated timestamp)
    func markAsUpdated() {
        self.lastUpdated = Date()
    }
    
    /// Archive the wound record
    func archive() {
        self.status = "archived"
        self.lastUpdated = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Get all capture sessions as an array, sorted by timestamp (newest first)
    var captureSessionsArray: [CaptureSession] {
        let set = captureSessions as? Set<CaptureSession> ?? []
        return Array(set).sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
    }
    
    /// Get the most recent capture session
    var mostRecentSession: CaptureSession? {
        return captureSessionsArray.first
    }
    
    /// Get the count of capture sessions
    var sessionCount: Int {
        return captureSessionsArray.count
    }
    
    /// Check if the wound record is active
    var isActive: Bool {
        return status == "active"
    }
    
    // MARK: - Delete Methods
    
    /// Delete the wound record and all associated data
    /// - Parameter context: The managed object context
    func delete(from context: NSManagedObjectContext) {
        context.delete(self)
    }
}
