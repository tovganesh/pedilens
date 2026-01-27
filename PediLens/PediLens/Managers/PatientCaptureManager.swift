//
//  PatientCaptureManager.swift
//  PediLens
//
//  Manages patient identification in capture workflow for doctor role
//  Requirements: 16.1, 16.2, 16.3
//

import Foundation
import CoreData
import UIKit
import UniformTypeIdentifiers
import ImageIO

/// Protocol for patient capture management
protocol PatientCaptureManagerProtocol {
    func requiresPatientIdentification(for user: User) -> Bool
    func getActivePatient() -> Patient?
    func setActivePatient(_ patient: Patient?)
    func associatePatientMetadata(with imageID: UUID, patient: Patient, context: NSManagedObjectContext)
    func getPatientMetadata(for imageID: UUID, context: NSManagedObjectContext) -> PatientMetadata?
}

/// Patient metadata structure
struct PatientMetadata: Codable, Equatable {
    let patientName: String
    let patientID: String
    let captureDate: Date
    let doctorID: String?
    
    var displayString: String {
        return "\(patientName) (ID: \(patientID))"
    }
}

/// Manages patient identification and metadata in capture workflow
class PatientCaptureManager: PatientCaptureManagerProtocol {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = PatientCaptureManager()
    
    /// Currently active patient for capture session
    private var activePatient: Patient?
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Checks if patient identification is required for the given user
    /// - Parameter user: The user performing the capture
    /// - Returns: True if patient identification is required (doctor role)
    func requiresPatientIdentification(for user: User) -> Bool {
        return user.userRole == .doctor
    }
    
    /// Gets the currently active patient for capture
    /// - Returns: The active patient, or nil if none is set
    func getActivePatient() -> Patient? {
        lock.lock()
        defer { lock.unlock() }
        return activePatient
    }
    
    /// Sets the active patient for capture
    /// - Parameter patient: The patient to set as active, or nil to clear
    func setActivePatient(_ patient: Patient?) {
        lock.lock()
        defer { lock.unlock() }
        activePatient = patient
    }
    
    /// Associates patient metadata with an image
    /// - Parameters:
    ///   - imageID: The unique identifier for the image
    ///   - patient: The patient whose metadata to associate
    ///   - context: The Core Data context
    func associatePatientMetadata(with imageID: UUID, patient: Patient, context: NSManagedObjectContext) {
        let metadata = PatientMetadata(
            patientName: patient.name ?? "Unknown",
            patientID: patient.patientID ?? "Unknown",
            captureDate: Date(),
            doctorID: patient.user?.id?.uuidString
        )
        
        // Store metadata in UserDefaults with imageID as key
        // In a real app, this would be stored in Core Data
        if let encoded = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(encoded, forKey: "patientMetadata_\(imageID.uuidString)")
        }
    }
    
    /// Retrieves patient metadata for an image
    /// - Parameters:
    ///   - imageID: The unique identifier for the image
    ///   - context: The Core Data context
    /// - Returns: The patient metadata, or nil if not found
    func getPatientMetadata(for imageID: UUID, context: NSManagedObjectContext) -> PatientMetadata? {
        // Retrieve metadata from UserDefaults
        // In a real app, this would be retrieved from Core Data
        guard let data = UserDefaults.standard.data(forKey: "patientMetadata_\(imageID.uuidString)") else {
            return nil
        }
        
        return try? JSONDecoder().decode(PatientMetadata.self, from: data)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a patient identification prompt message
    /// - Returns: A message prompting for patient identification
    func createPatientIdentificationPrompt() -> String {
        return "Please select or add a patient before capturing images."
    }
    
    /// Validates that a patient is selected for doctor users
    /// - Parameters:
    ///   - user: The user performing the capture
    ///   - patient: The currently selected patient
    /// - Returns: True if validation passes, false otherwise
    func validatePatientSelection(for user: User, patient: Patient?) -> Bool {
        if requiresPatientIdentification(for: user) {
            return patient != nil
        }
        return true
    }
}

// MARK: - Patient Selection View Model

/// View model for patient selection in capture workflow
@MainActor
class PatientSelectionViewModel: ObservableObject {
    @Published var selectedPatient: Patient?
    @Published var showingPatientSelection: Bool = false
    @Published var patients: [Patient] = []
    
    private let patientManager: PatientManager
    private let patientCaptureManager: PatientCaptureManager
    private let user: User
    
    init(user: User,
         patientManager: PatientManager = .shared,
         patientCaptureManager: PatientCaptureManager = .shared) {
        self.user = user
        self.patientManager = patientManager
        self.patientCaptureManager = patientCaptureManager
        
        // Load active patient if any
        self.selectedPatient = patientCaptureManager.getActivePatient()
    }
    
    var requiresPatientSelection: Bool {
        return patientCaptureManager.requiresPatientIdentification(for: user)
    }
    
    var isPatientSelected: Bool {
        return selectedPatient != nil
    }
    
    var patientDisplayText: String {
        if let patient = selectedPatient {
            return "\(patient.name ?? "Unknown") (ID: \(patient.patientID ?? "N/A"))"
        }
        return "No patient selected"
    }
    
    func loadPatients() {
        Task {
            do {
                patients = try await patientManager.fetchPatients(for: user)
            } catch {
                print("Error loading patients: \(error)")
            }
        }
    }
    
    func selectPatient(_ patient: Patient) {
        selectedPatient = patient
        patientCaptureManager.setActivePatient(patient)
        showingPatientSelection = false
    }
    
    func clearPatientSelection() {
        selectedPatient = nil
        patientCaptureManager.setActivePatient(nil)
    }
    
    func promptForPatientSelection() {
        if requiresPatientSelection && !isPatientSelected {
            showingPatientSelection = true
        }
    }
}
