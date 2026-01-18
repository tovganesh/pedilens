//
//  Localization.swift
//  PediLens
//
//  Localization helper for easy string access
//

import Foundation

/// Helper for accessing localized strings
enum L10n {
    
    // MARK: - App General
    enum App {
        static let name = NSLocalizedString("app.name", comment: "App name")
        static let tagline = NSLocalizedString("app.tagline", comment: "App tagline")
    }
    
    // MARK: - Authentication
    enum Auth {
        static let faceIDReason = NSLocalizedString("auth.faceID.reason", comment: "Face ID reason")
        static let touchIDReason = NSLocalizedString("auth.touchID.reason", comment: "Touch ID reason")
        static let required = NSLocalizedString("auth.required", comment: "Authentication required")
        static let failed = NSLocalizedString("auth.failed", comment: "Authentication failed")
        static let unavailable = NSLocalizedString("auth.unavailable", comment: "Auth unavailable")
        static let locked = NSLocalizedString("auth.locked", comment: "Auth locked")
    }
    
    // MARK: - Camera
    enum Camera {
        enum Permission {
            static let title = NSLocalizedString("camera.permission.title", comment: "Camera permission title")
            static let message = NSLocalizedString("camera.permission.message", comment: "Camera permission message")
            static let settings = NSLocalizedString("camera.permission.settings", comment: "Open settings")
        }
        static let unavailable = NSLocalizedString("camera.unavailable", comment: "Camera unavailable")
        static let capture = NSLocalizedString("camera.capture", comment: "Capture button")
        static let retake = NSLocalizedString("camera.retake", comment: "Retake button")
        static let use = NSLocalizedString("camera.use", comment: "Use photo button")
        static let livePhoto = NSLocalizedString("camera.livePhoto", comment: "Live photo")
        static let hdr = NSLocalizedString("camera.hdr", comment: "HDR")
        static let nightMode = NSLocalizedString("camera.nightMode", comment: "Night mode")
    }

    
    // MARK: - Location
    enum Location {
        enum Permission {
            static let title = NSLocalizedString("location.permission.title", comment: "Location permission title")
            static let message = NSLocalizedString("location.permission.message", comment: "Location permission message")
        }
    }
    
    // MARK: - Storage
    enum Storage {
        enum Warning {
            static let title = NSLocalizedString("storage.warning.title", comment: "Storage warning title")
            static func message(percentage: Int) -> String {
                String(format: NSLocalizedString("storage.warning.message", comment: "Storage warning"), percentage)
            }
        }
        static let full = NSLocalizedString("storage.full", comment: "Storage full")
        static let manage = NSLocalizedString("storage.manage", comment: "Manage storage")
    }
    
    // MARK: - Wound Records
    enum Wound {
        static let new = NSLocalizedString("wound.new", comment: "New wound")
        static let location = NSLocalizedString("wound.location", comment: "Wound location")
        static let locationPlaceholder = NSLocalizedString("wound.location.placeholder", comment: "Location placeholder")
        
        enum Status {
            static let active = NSLocalizedString("wound.status.active", comment: "Active status")
            static let healing = NSLocalizedString("wound.status.healing", comment: "Healing status")
            static let healed = NSLocalizedString("wound.status.healed", comment: "Healed status")
            static let archived = NSLocalizedString("wound.status.archived", comment: "Archived status")
        }
        
        enum Delete {
            static let title = NSLocalizedString("wound.delete.title", comment: "Delete title")
            static let message = NSLocalizedString("wound.delete.message", comment: "Delete message")
            static let export = NSLocalizedString("wound.delete.export", comment: "Export before delete")
            static let confirm = NSLocalizedString("wound.delete.confirm", comment: "Delete confirm")
        }
    }

    
    // MARK: - Measurements
    enum Measurement {
        static let length = NSLocalizedString("measurement.length", comment: "Length")
        static let width = NSLocalizedString("measurement.width", comment: "Width")
        static let area = NSLocalizedString("measurement.area", comment: "Area")
        static let depth = NSLocalizedString("measurement.depth", comment: "Depth")
        static let volume = NSLocalizedString("measurement.volume", comment: "Volume")
        static let perimeter = NSLocalizedString("measurement.perimeter", comment: "Perimeter")
        static let calibrate = NSLocalizedString("measurement.calibrate", comment: "Calibrate")
        static let uncalibratedWarning = NSLocalizedString("measurement.uncalibrated.warning", comment: "Uncalibrated warning")
        static let history = NSLocalizedString("measurement.history", comment: "History")
    }
    
    // MARK: - Patient Management
    enum Patient {
        static let new = NSLocalizedString("patient.new", comment: "New patient")
        static let name = NSLocalizedString("patient.name", comment: "Patient name")
        static let id = NSLocalizedString("patient.id", comment: "Patient ID")
        static let dateOfBirth = NSLocalizedString("patient.dateOfBirth", comment: "Date of birth")
        static let notes = NSLocalizedString("patient.notes", comment: "Notes")
        static let search = NSLocalizedString("patient.search", comment: "Search")
        static let select = NSLocalizedString("patient.select", comment: "Select patient")
        static let required = NSLocalizedString("patient.required", comment: "Patient required")
        static let statistics = NSLocalizedString("patient.statistics", comment: "Statistics")
        static let totalWounds = NSLocalizedString("patient.totalWounds", comment: "Total wounds")
        static let activeWounds = NSLocalizedString("patient.activeWounds", comment: "Active wounds")
    }
    
    // MARK: - User Roles
    enum Role {
        enum Select {
            static let title = NSLocalizedString("role.select.title", comment: "Select role title")
        }
        static let doctor = NSLocalizedString("role.doctor", comment: "Doctor role")
        static let doctorDescription = NSLocalizedString("role.doctor.description", comment: "Doctor description")
        static let patient = NSLocalizedString("role.patient", comment: "Patient role")
        static let patientDescription = NSLocalizedString("role.patient.description", comment: "Patient description")
    }

    
    // MARK: - Timeline
    enum Timeline {
        static let title = NSLocalizedString("timeline.title", comment: "Timeline")
        static let empty = NSLocalizedString("timeline.empty", comment: "Empty timeline")
        static let filter = NSLocalizedString("timeline.filter", comment: "Filter")
        static let sort = NSLocalizedString("timeline.sort", comment: "Sort")
        static let compare = NSLocalizedString("timeline.compare", comment: "Compare")
    }
    
    // MARK: - Notes
    enum Note {
        static let add = NSLocalizedString("note.add", comment: "Add note")
        
        enum Category {
            static let improved = NSLocalizedString("note.category.improved", comment: "Improved")
            static let unchanged = NSLocalizedString("note.category.unchanged", comment: "Unchanged")
            static let worsened = NSLocalizedString("note.category.worsened", comment: "Worsened")
            static let general = NSLocalizedString("note.category.general", comment: "General")
        }
    }
    
    // MARK: - Export
    enum Export {
        static let title = NSLocalizedString("export.title", comment: "Export title")
        
        enum Format {
            static let pdf = NSLocalizedString("export.format.pdf", comment: "PDF format")
            static let images = NSLocalizedString("export.format.images", comment: "Images format")
            static let native = NSLocalizedString("export.format.native", comment: "Native format")
        }
        
        static let options = NSLocalizedString("export.options", comment: "Options")
        static let includePhotos = NSLocalizedString("export.includePhotos", comment: "Include photos")
        static let includeMeasurements = NSLocalizedString("export.includeMeasurements", comment: "Include measurements")
        static let includeNotes = NSLocalizedString("export.includeNotes", comment: "Include notes")
        static let anonymize = NSLocalizedString("export.anonymize", comment: "Anonymize")
        static let dateRange = NSLocalizedString("export.dateRange", comment: "Date range")
        static let hipaaWarning = NSLocalizedString("export.hipaa.warning", comment: "HIPAA warning")
        static let success = NSLocalizedString("export.success", comment: "Export success")
        static let failed = NSLocalizedString("export.failed", comment: "Export failed")
    }

    
    // MARK: - Sync
    enum Sync {
        enum Status {
            static let synced = NSLocalizedString("sync.status.synced", comment: "Synced")
            static let syncing = NSLocalizedString("sync.status.syncing", comment: "Syncing")
            static let pending = NSLocalizedString("sync.status.pending", comment: "Pending")
            static let offline = NSLocalizedString("sync.status.offline", comment: "Offline")
            static let error = NSLocalizedString("sync.status.error", comment: "Error")
        }
        
        static let enable = NSLocalizedString("sync.enable", comment: "Enable sync")
        static let disable = NSLocalizedString("sync.disable", comment: "Disable sync")
        
        enum Conflict {
            static let title = NSLocalizedString("sync.conflict.title", comment: "Conflict title")
            static let message = NSLocalizedString("sync.conflict.message", comment: "Conflict message")
            static let local = NSLocalizedString("sync.conflict.local", comment: "Keep local")
            static let cloud = NSLocalizedString("sync.conflict.cloud", comment: "Keep cloud")
            static let both = NSLocalizedString("sync.conflict.both", comment: "Keep both")
        }
    }
    
    // MARK: - Errors
    enum Error {
        static let generic = NSLocalizedString("error.generic", comment: "Generic error")
        static let tryAgain = NSLocalizedString("error.tryAgain", comment: "Try again")
        static let cancel = NSLocalizedString("error.cancel", comment: "Cancel")
        static let ok = NSLocalizedString("error.ok", comment: "OK")
        static let network = NSLocalizedString("error.network", comment: "Network error")
        static let storage = NSLocalizedString("error.storage", comment: "Storage error")
        static let camera = NSLocalizedString("error.camera", comment: "Camera error")
        static let encryption = NSLocalizedString("error.encryption", comment: "Encryption error")
    }
    
    // MARK: - Buttons
    enum Button {
        static let save = NSLocalizedString("button.save", comment: "Save")
        static let cancel = NSLocalizedString("button.cancel", comment: "Cancel")
        static let delete = NSLocalizedString("button.delete", comment: "Delete")
        static let edit = NSLocalizedString("button.edit", comment: "Edit")
        static let done = NSLocalizedString("button.done", comment: "Done")
        static let next = NSLocalizedString("button.next", comment: "Next")
        static let back = NSLocalizedString("button.back", comment: "Back")
        static let close = NSLocalizedString("button.close", comment: "Close")
        static let share = NSLocalizedString("button.share", comment: "Share")
    }

    
    // MARK: - Units
    enum Unit {
        static let mm = NSLocalizedString("unit.mm", comment: "Millimeters")
        static let cm = NSLocalizedString("unit.cm", comment: "Centimeters")
        static let mm2 = NSLocalizedString("unit.mm2", comment: "Square millimeters")
        static let cm2 = NSLocalizedString("unit.cm2", comment: "Square centimeters")
        static let mm3 = NSLocalizedString("unit.mm3", comment: "Cubic millimeters")
        static let cm3 = NSLocalizedString("unit.cm3", comment: "Cubic centimeters")
        static let inches = NSLocalizedString("unit.inches", comment: "Inches")
        static let in2 = NSLocalizedString("unit.in2", comment: "Square inches")
        static let in3 = NSLocalizedString("unit.in3", comment: "Cubic inches")
    }
    
    // MARK: - Accessibility
    enum Accessibility {
        enum Camera {
            static let capture = NSLocalizedString("accessibility.camera.capture", comment: "Capture photo accessibility")
            static let flash = NSLocalizedString("accessibility.camera.flash", comment: "Toggle flash accessibility")
        }
        
        enum Measurement {
            static let boundary = NSLocalizedString("accessibility.measurement.boundary", comment: "Wound boundary accessibility")
        }
        
        enum Timeline {
            static func entry(date: String) -> String {
                String(format: NSLocalizedString("accessibility.timeline.entry", comment: "Timeline entry accessibility"), date)
            }
        }
    }
    
    // MARK: - Wound Detection
    enum Detection {
        static let analyzing = NSLocalizedString("detection.analyzing", comment: "Analyzing")
        static func confidence(percentage: Int) -> String {
            String(format: NSLocalizedString("detection.confidence", comment: "Detection confidence"), percentage)
        }
        static let manual = NSLocalizedString("detection.manual", comment: "Manual")
        static let automatic = NSLocalizedString("detection.automatic", comment: "Automatic")
        static let refine = NSLocalizedString("detection.refine", comment: "Refine")
        static let failed = NSLocalizedString("detection.failed", comment: "Detection failed")
    }
}
