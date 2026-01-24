//
//  CaptureSession+Extensions.swift
//  PediLens
//
//  Core Data entity extensions for CaptureSession with convenience methods
//

import Foundation
import CoreData
import CoreLocation

extension CaptureSession {
    
    // MARK: - Factory Methods
    
    /// Create a new CaptureSession entity
    /// - Parameters:
    ///   - context: The managed object context
    ///   - photoPath: Path to the photo file
    ///   - livePhotoVideoPath: Optional path to live photo video
    ///   - depthDataPath: Optional path to depth data
    ///   - location: Optional location data
    ///   - woundRecord: The wound record this session belongs to
    /// - Returns: A new CaptureSession instance
    static func create(
        in context: NSManagedObjectContext,
        photoPath: String,
        livePhotoVideoPath: String? = nil,
        depthDataPath: String? = nil,
        location: CLLocation? = nil,
        woundRecord: WoundRecord? = nil
    ) -> CaptureSession {
        let session = CaptureSession(context: context)
        session.id = UUID()
        session.timestamp = Date()
        session.photoPath = photoPath
        session.livePhotoVideoPath = livePhotoVideoPath
        session.depthDataPath = depthDataPath
        
        if let location = location {
            session.latitude = location.coordinate.latitude
            session.longitude = location.coordinate.longitude
            session.locationAvailable = true
        } else {
            session.latitude = 0.0
            session.longitude = 0.0
            session.locationAvailable = false
        }
        
        session.woundRecord = woundRecord
        
        // Update the wound record's lastUpdated timestamp
        woundRecord?.markAsUpdated()
        
        return session
    }
    
    // MARK: - Fetch Requests
    
    /// Fetch all capture sessions for a specific wound record
    /// - Parameters:
    ///   - woundRecord: The wound record whose sessions to fetch
    ///   - context: The managed object context
    /// - Returns: Array of capture sessions
    static func fetchCaptureSessions(
        for woundRecord: WoundRecord,
        in context: NSManagedObjectContext
    ) -> [CaptureSession] {
        let request: NSFetchRequest<CaptureSession> = CaptureSession.fetchRequest()
        request.predicate = NSPredicate(format: "woundRecord == %@", woundRecord)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching capture sessions for wound record: \(error)")
            return []
        }
    }
    
    /// Fetch a capture session by ID
    /// - Parameters:
    ///   - id: The capture session's UUID
    ///   - context: The managed object context
    /// - Returns: The capture session, or nil if not found
    static func fetchCaptureSession(
        byID id: UUID,
        in context: NSManagedObjectContext
    ) -> CaptureSession? {
        let request: NSFetchRequest<CaptureSession> = CaptureSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let sessions = try context.fetch(request)
            return sessions.first
        } catch {
            print("Error fetching capture session by ID: \(error)")
            return nil
        }
    }
    
    /// Fetch capture sessions within a date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - woundRecord: Optional wound record to filter by
    ///   - context: The managed object context
    /// - Returns: Array of capture sessions
    static func fetchCaptureSessions(
        from startDate: Date,
        to endDate: Date,
        for woundRecord: WoundRecord? = nil,
        in context: NSManagedObjectContext
    ) -> [CaptureSession] {
        let request: NSFetchRequest<CaptureSession> = CaptureSession.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate)
        ]
        
        if let woundRecord = woundRecord {
            predicates.append(NSPredicate(format: "woundRecord == %@", woundRecord))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching capture sessions by date range: \(error)")
            return []
        }
    }
    
    /// Fetch capture sessions with depth data
    /// - Parameters:
    ///   - woundRecord: Optional wound record to filter by
    ///   - context: The managed object context
    /// - Returns: Array of capture sessions with depth data
    static func fetchCaptureSessionsWithDepthData(
        for woundRecord: WoundRecord? = nil,
        in context: NSManagedObjectContext
    ) -> [CaptureSession] {
        let request: NSFetchRequest<CaptureSession> = CaptureSession.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "depthDataPath != nil")
        ]
        
        if let woundRecord = woundRecord {
            predicates.append(NSPredicate(format: "woundRecord == %@", woundRecord))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching capture sessions with depth data: \(error)")
            return []
        }
    }
    
    /// Fetch all capture sessions
    /// - Parameter context: The managed object context
    /// - Returns: Array of all capture sessions
    static func fetchAll(in context: NSManagedObjectContext) -> [CaptureSession] {
        let request: NSFetchRequest<CaptureSession> = CaptureSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all capture sessions: \(error)")
            return []
        }
    }
    
    // MARK: - Update Methods
    
    /// Update capture session paths
    /// - Parameters:
    ///   - photoPath: New photo path
    ///   - livePhotoVideoPath: New live photo video path
    ///   - depthDataPath: New depth data path
    func updatePaths(
        photoPath: String? = nil,
        livePhotoVideoPath: String? = nil,
        depthDataPath: String? = nil
    ) {
        if let photoPath = photoPath {
            self.photoPath = photoPath
        }
        if let livePhotoVideoPath = livePhotoVideoPath {
            self.livePhotoVideoPath = livePhotoVideoPath
        }
        if let depthDataPath = depthDataPath {
            self.depthDataPath = depthDataPath
        }
    }
    
    /// Update location data
    /// - Parameter location: The new location
    func updateLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.locationAvailable = true
    }
    
    // MARK: - Computed Properties
    
    /// Get the location as a CLLocation object
    var location: CLLocation? {
        guard locationAvailable else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Get all notes as an array, sorted by creation date
    var notesArray: [Note] {
        let set = notes as? Set<Note> ?? []
        return Array(set).sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Check if the session has a live photo
    var hasLivePhoto: Bool {
        return livePhotoVideoPath != nil
    }
    
    /// Check if the session has depth data
    var hasDepthData: Bool {
        return depthDataPath != nil
    }
    
    /// Check if the session has a measurement
    var hasMeasurement: Bool {
        return measurement != nil
    }
    
    // MARK: - Delete Methods
    
    /// Delete the capture session and all associated data
    /// - Parameter context: The managed object context
    func delete(from context: NSManagedObjectContext) {
        context.delete(self)
    }
}
