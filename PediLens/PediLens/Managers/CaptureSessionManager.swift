//
//  CaptureSessionManager.swift
//  PediLens
//
//  Manages capture session operations including creation, storage, and metadata
//

import Foundation
import CoreData
import CoreLocation

/// Protocol defining capture session management operations
protocol CaptureSessionManagerProtocol {
    func createCaptureSession(photoPath: String, livePhotoVideoPath: String?, depthDataPath: String?, location: CLLocation?, woundRecord: WoundRecord) async throws -> CaptureSession
    func addNote(to session: CaptureSession, text: String, category: String) async throws -> Note
    func addTag(to session: CaptureSession, tag: String) async throws
    func fetchCaptureSessions(for woundRecord: WoundRecord) async throws -> [CaptureSession]
    func fetchCaptureSession(byID id: UUID) async throws -> CaptureSession?
}

/// Errors that can occur during capture session management
enum CaptureSessionManagerError: LocalizedError {
    case invalidPhotoPath
    case sessionNotFound
    case saveFailed(Error)
    case invalidNoteText
    
    var errorDescription: String? {
        switch self {
        case .invalidPhotoPath:
            return "Photo path cannot be empty"
        case .sessionNotFound:
            return "Capture session not found"
        case .saveFailed(let error):
            return "Failed to save capture session: \(error.localizedDescription)"
        case .invalidNoteText:
            return "Note text cannot be empty"
        }
    }
}

/// Manager for capture session operations
class CaptureSessionManager: CaptureSessionManagerProtocol {
    
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
    
    /// Create a new capture session
    /// - Parameters:
    ///   - photoPath: Path to the photo file (required)
    ///   - livePhotoVideoPath: Optional path to live photo video
    ///   - depthDataPath: Optional path to depth data
    ///   - location: Optional location data
    ///   - woundRecord: The wound record this session belongs to
    /// - Returns: The created capture session
    /// - Throws: CaptureSessionManagerError if creation fails
    func createCaptureSession(
        photoPath: String,
        livePhotoVideoPath: String? = nil,
        depthDataPath: String? = nil,
        location: CLLocation? = nil,
        woundRecord: WoundRecord
    ) async throws -> CaptureSession {
        // Validate photo path is not empty
        guard !photoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureSessionManagerError.invalidPhotoPath
        }
        
        return try await context.perform {
            // Create the capture session
            let session = CaptureSession.create(
                in: self.context,
                photoPath: photoPath,
                livePhotoVideoPath: livePhotoVideoPath,
                depthDataPath: depthDataPath,
                location: location,
                woundRecord: woundRecord
            )
            
            // Save the context
            do {
                try self.context.save()
                return session
            } catch {
                self.context.rollback()
                throw CaptureSessionManagerError.saveFailed(error)
            }
        }
    }
    
    /// Add a note to a capture session
    /// - Parameters:
    ///   - session: The capture session to add the note to
    ///   - text: Note text content
    ///   - category: Note category (default: "general")
    /// - Returns: The created note
    /// - Throws: CaptureSessionManagerError if creation fails
    func addNote(
        to session: CaptureSession,
        text: String,
        category: String = "general"
    ) async throws -> Note {
        // Validate note text is not empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CaptureSessionManagerError.invalidNoteText
        }
        
        return try await context.perform {
            // Create the note
            let note = Note.create(
                in: self.context,
                text: text,
                category: category,
                captureSession: session
            )
            
            // Save the context
            do {
                try self.context.save()
                return note
            } catch {
                self.context.rollback()
                throw CaptureSessionManagerError.saveFailed(error)
            }
        }
    }
    
    /// Add a tag to a capture session
    /// - Parameters:
    ///   - session: The capture session to add the tag to
    ///   - tag: Tag to add
    /// - Throws: CaptureSessionManagerError if operation fails
    func addTag(to session: CaptureSession, tag: String) async throws {
        // Tags can be implemented as notes with a special category
        _ = try await addNote(to: session, text: tag, category: "tag")
    }
    
    // MARK: - Read Operations
    
    /// Fetch all capture sessions for a specific wound record
    /// - Parameter woundRecord: The wound record whose sessions to fetch
    /// - Returns: Array of capture sessions
    /// - Throws: CaptureSessionManagerError if fetch fails
    func fetchCaptureSessions(for woundRecord: WoundRecord) async throws -> [CaptureSession] {
        return try await context.perform {
            return CaptureSession.fetchCaptureSessions(for: woundRecord, in: self.context)
        }
    }
    
    /// Fetch a capture session by ID
    /// - Parameter id: The capture session's UUID
    /// - Returns: The capture session, or nil if not found
    /// - Throws: CaptureSessionManagerError if fetch fails
    func fetchCaptureSession(byID id: UUID) async throws -> CaptureSession? {
        return try await context.perform {
            return CaptureSession.fetchCaptureSession(byID: id, in: self.context)
        }
    }
    
    /// Fetch capture sessions within a date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    ///   - woundRecord: Optional wound record to filter by
    /// - Returns: Array of capture sessions
    func fetchCaptureSessions(from startDate: Date, to endDate: Date, for woundRecord: WoundRecord? = nil) async throws -> [CaptureSession] {
        return try await context.perform {
            return CaptureSession.fetchCaptureSessions(from: startDate, to: endDate, for: woundRecord, in: self.context)
        }
    }
    
    /// Fetch capture sessions with depth data
    /// - Parameter woundRecord: Optional wound record to filter by
    /// - Returns: Array of capture sessions with depth data
    func fetchCaptureSessionsWithDepthData(for woundRecord: WoundRecord? = nil) async throws -> [CaptureSession] {
        return try await context.perform {
            return CaptureSession.fetchCaptureSessionsWithDepthData(for: woundRecord, in: self.context)
        }
    }
    
    // MARK: - Update Operations
    
    /// Update capture session paths
    /// - Parameters:
    ///   - session: The capture session to update
    ///   - photoPath: New photo path (optional)
    ///   - livePhotoVideoPath: New live photo video path (optional)
    ///   - depthDataPath: New depth data path (optional)
    /// - Throws: CaptureSessionManagerError if update fails
    func updatePaths(
        for session: CaptureSession,
        photoPath: String? = nil,
        livePhotoVideoPath: String? = nil,
        depthDataPath: String? = nil
    ) async throws {
        try await context.perform {
            session.updatePaths(
                photoPath: photoPath,
                livePhotoVideoPath: livePhotoVideoPath,
                depthDataPath: depthDataPath
            )
            
            do {
                try self.context.save()
            } catch {
                self.context.rollback()
                throw CaptureSessionManagerError.saveFailed(error)
            }
        }
    }
    
    /// Update location data for a capture session
    /// - Parameters:
    ///   - session: The capture session to update
    ///   - location: The new location
    /// - Throws: CaptureSessionManagerError if update fails
    func updateLocation(for session: CaptureSession, location: CLLocation) async throws {
        try await context.perform {
            session.updateLocation(location)
            
            do {
                try self.context.save()
            } catch {
                self.context.rollback()
                throw CaptureSessionManagerError.saveFailed(error)
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a capture session
    /// - Parameter session: The capture session to delete
    /// - Throws: CaptureSessionManagerError if deletion fails
    func deleteCaptureSession(_ session: CaptureSession) async throws {
        try await context.perform {
            // Note: Associated notes and measurements will be automatically deleted
            // due to the cascade delete rule in the Core Data model
            
            // Delete the session from Core Data
            session.delete(from: self.context)
            
            do {
                try self.context.save()
            } catch {
                self.context.rollback()
                throw CaptureSessionManagerError.saveFailed(error)
            }
        }
    }
}
