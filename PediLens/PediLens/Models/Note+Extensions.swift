//
//  Note+Extensions.swift
//  PediLens
//
//  Core Data entity extensions for Note with convenience methods
//

import Foundation
import CoreData

extension Note {
    
    // MARK: - Factory Methods
    
    /// Create a new Note entity
    /// - Parameters:
    ///   - context: The managed object context
    ///   - text: Note text content
    ///   - category: Note category (default: "general")
    ///   - captureSession: The capture session this note belongs to
    /// - Returns: A new Note instance
    static func create(
        in context: NSManagedObjectContext,
        text: String,
        category: String = "general",
        captureSession: CaptureSession? = nil
    ) -> Note {
        let note = Note(context: context)
        note.id = UUID()
        note.text = text
        note.category = category
        note.createdAt = Date()
        note.captureSession = captureSession
        return note
    }
    
    // MARK: - Fetch Requests
    
    /// Fetch all notes for a specific capture session
    /// - Parameters:
    ///   - captureSession: The capture session whose notes to fetch
    ///   - context: The managed object context
    /// - Returns: Array of notes
    static func fetchNotes(
        for captureSession: CaptureSession,
        in context: NSManagedObjectContext
    ) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "captureSession == %@", captureSession)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching notes for capture session: \(error)")
            return []
        }
    }
    
    /// Fetch a note by ID
    /// - Parameters:
    ///   - id: The note's UUID
    ///   - context: The managed object context
    /// - Returns: The note, or nil if not found
    static func fetchNote(
        byID id: UUID,
        in context: NSManagedObjectContext
    ) -> Note? {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let notes = try context.fetch(request)
            return notes.first
        } catch {
            print("Error fetching note by ID: \(error)")
            return nil
        }
    }
    
    /// Fetch notes by category
    /// - Parameters:
    ///   - category: The category to filter by
    ///   - captureSession: Optional capture session to filter by
    ///   - context: The managed object context
    /// - Returns: Array of notes
    static func fetchNotes(
        withCategory category: String,
        for captureSession: CaptureSession? = nil,
        in context: NSManagedObjectContext
    ) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        
        var predicates: [NSPredicate] = [
            NSPredicate(format: "category == %@", category)
        ]
        
        if let captureSession = captureSession {
            predicates.append(NSPredicate(format: "captureSession == %@", captureSession))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching notes by category: \(error)")
            return []
        }
    }
    
    /// Fetch all notes
    /// - Parameter context: The managed object context
    /// - Returns: Array of all notes
    static func fetchAll(in context: NSManagedObjectContext) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all notes: \(error)")
            return []
        }
    }
    
    // MARK: - Update Methods
    
    /// Update note content
    /// - Parameters:
    ///   - text: New text content
    ///   - category: New category
    func update(
        text: String? = nil,
        category: String? = nil
    ) {
        if let text = text {
            self.text = text
        }
        if let category = category {
            self.category = category
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if the note is in the "improved" category
    var isImproved: Bool {
        return category == "improved"
    }
    
    /// Check if the note is in the "unchanged" category
    var isUnchanged: Bool {
        return category == "unchanged"
    }
    
    /// Check if the note is in the "worsened" category
    var isWorsened: Bool {
        return category == "worsened"
    }
    
    /// Check if the note is in the "general" category
    var isGeneral: Bool {
        return category == "general"
    }
    
    // MARK: - Delete Methods
    
    /// Delete the note
    /// - Parameter context: The managed object context
    func delete(from context: NSManagedObjectContext) {
        context.delete(self)
    }
}
