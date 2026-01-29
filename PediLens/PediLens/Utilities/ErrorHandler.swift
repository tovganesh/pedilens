//
//  ErrorHandler.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import CoreData

// MARK: - PediLens Error Types

enum PediLensError: LocalizedError {
    // Camera Errors
    case cameraPermissionDenied
    case cameraUnavailable
    case photoCaptureFailedAfterRetries(attempts: Int)
    case depthDataUnavailable
    case lowStorageSpace(availableBytes: Int64)
    
    // Detection Errors
    case coreMLModelLoadFailed(modelName: String)
    case detectionConfidenceTooLow(confidence: Float)
    case detectionTimeout
    case invalidImageFormat
    
    // Storage Errors
    case diskFull(requiredBytes: Int64, availableBytes: Int64)
    case fileWriteFailed(path: String, underlyingError: Error?)
    case coreDataSaveFailed(underlyingError: Error)
    case encryptionKeyUnavailable
    case fileCorrupted(path: String, checksum: String?)
    
    // Sync Errors
    case networkUnavailable
    case iCloudQuotaExceeded
    case authenticationFailed
    case syncConflict(localVersion: String, cloudVersion: String)
    case cloudKitRateLimit
    
    // Measurement Errors
    case noCalibrationAvailable
    case invalidBoundary(reason: String)
    case depthDataQualityInsufficient
    case calculationOverflow
    
    // Export Errors
    case pdfGenerationFailed(underlyingError: Error?)
    case exportFileTooLarge(sizeBytes: Int64, maxBytes: Int64)
    case shareSheetUnavailable
    case insufficientPermissions(permission: String)
    
    var errorDescription: String? {
        switch self {
        // Camera Errors
        case .cameraPermissionDenied:
            return "Camera access is required to capture wound photos. Please enable camera access in Settings."
        case .cameraUnavailable:
            return "Camera is currently unavailable. Please check if another app is using the camera."
        case .photoCaptureFailedAfterRetries(let attempts):
            return "Failed to capture photo after \(attempts) attempts. Please try again."
        case .depthDataUnavailable:
            return "Depth data is not available on this device. Measurements will be 2D only."
        case .lowStorageSpace(let availableBytes):
            let mb = Double(availableBytes) / 1_000_000
            return "Low storage space (\(String(format: "%.1f", mb)) MB remaining). Please free up space before capturing."
            
        // Detection Errors
        case .coreMLModelLoadFailed(let modelName):
            return "Failed to load detection model '\(modelName)'. Manual boundary marking is available."
        case .detectionConfidenceTooLow(let confidence):
            return "Automatic detection confidence is low (\(Int(confidence * 100))%). Please review and adjust the boundary manually."
        case .detectionTimeout:
            return "Wound detection timed out. Please try manual boundary marking."
        case .invalidImageFormat:
            return "Invalid image format. Please recapture the photo."
            
        // Storage Errors
        case .diskFull(let required, let available):
            let requiredMB = Double(required) / 1_000_000
            let availableMB = Double(available) / 1_000_000
            return "Insufficient storage space. Need \(String(format: "%.1f", requiredMB)) MB, but only \(String(format: "%.1f", availableMB)) MB available."
        case .fileWriteFailed(let path, let error):
            if let error = error {
                return "Failed to save file at \(path): \(error.localizedDescription)"
            }
            return "Failed to save file at \(path). Please try again."
        case .coreDataSaveFailed(let error):
            return "Failed to save data: \(error.localizedDescription). Your changes have been preserved and will be retried."
        case .encryptionKeyUnavailable:
            return "Encryption key is unavailable. Please authenticate to continue."
        case .fileCorrupted(let path, let checksum):
            if let checksum = checksum {
                return "File at \(path) is corrupted (checksum: \(checksum)). Attempting recovery from iCloud."
            }
            return "File at \(path) is corrupted. Attempting recovery."
            
        // Sync Errors
        case .networkUnavailable:
            return "Network is unavailable. Changes will sync when connection is restored."
        case .iCloudQuotaExceeded:
            return "iCloud storage is full. Please free up space or disable sync to continue using local storage."
        case .authenticationFailed:
            return "iCloud authentication failed. Please sign in to iCloud in Settings."
        case .syncConflict(let local, let cloud):
            return "Sync conflict detected between local version (\(local)) and cloud version (\(cloud)). Please resolve the conflict."
        case .cloudKitRateLimit:
            return "Too many sync requests. Sync will resume automatically in a few moments."
            
        // Measurement Errors
        case .noCalibrationAvailable:
            return "No calibration data available. Measurements are estimates only. Please add a reference object for accurate measurements."
        case .invalidBoundary(let reason):
            return "Invalid wound boundary: \(reason). Please adjust the boundary."
        case .depthDataQualityInsufficient:
            return "Depth data quality is insufficient for accurate depth/volume measurements."
        case .calculationOverflow:
            return "Measurement calculation resulted in an unreasonably large value. Please check the boundary and calibration."
            
        // Export Errors
        case .pdfGenerationFailed(let error):
            if let error = error {
                return "Failed to generate PDF: \(error.localizedDescription). Trying image-only export."
            }
            return "Failed to generate PDF. Trying image-only export."
        case .exportFileTooLarge(let size, let max):
            let sizeMB = Double(size) / 1_000_000
            let maxMB = Double(max) / 1_000_000
            return "Export file is too large (\(String(format: "%.1f", sizeMB)) MB). Maximum size is \(String(format: "%.1f", maxMB)) MB. Consider reducing the date range or excluding photos."
        case .shareSheetUnavailable:
            return "Share sheet is unavailable. Export has been saved to Files app."
        case .insufficientPermissions(let permission):
            return "Permission required: \(permission). Please grant access in Settings."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cameraPermissionDenied:
            return "Go to Settings > PediLens > Camera and enable access."
        case .cameraUnavailable:
            return "Close other apps using the camera and try again."
        case .photoCaptureFailedAfterRetries:
            return "Check camera lens for obstructions and ensure good lighting."
        case .depthDataUnavailable:
            return "This device doesn't support depth sensing. 2D measurements are still available."
        case .lowStorageSpace:
            return "Delete unused photos or apps to free up space."
        case .coreMLModelLoadFailed:
            return "Use manual boundary marking to continue documenting wounds."
        case .detectionConfidenceTooLow:
            return "Tap 'Adjust Boundary' to manually refine the detected area."
        case .detectionTimeout:
            return "Use manual boundary marking for this photo."
        case .invalidImageFormat:
            return "Recapture the photo using the in-app camera."
        case .diskFull:
            return "Free up storage space or use Storage Management in Settings."
        case .fileWriteFailed:
            return "Check available storage and try again."
        case .coreDataSaveFailed:
            return "Your data is safe. The app will retry saving automatically."
        case .encryptionKeyUnavailable:
            return "Authenticate with Face ID, Touch ID, or passcode."
        case .fileCorrupted:
            return "If iCloud sync is enabled, the file will be recovered automatically."
        case .networkUnavailable:
            return "Connect to Wi-Fi or cellular data to sync."
        case .iCloudQuotaExceeded:
            return "Manage iCloud storage in Settings or disable sync."
        case .authenticationFailed:
            return "Sign in to iCloud in Settings > [Your Name] > iCloud."
        case .syncConflict:
            return "Review both versions and choose which to keep."
        case .cloudKitRateLimit:
            return "Wait a few minutes and sync will resume automatically."
        case .noCalibrationAvailable:
            return "Place a ruler or coin in the photo for accurate measurements."
        case .invalidBoundary:
            return "Redraw the boundary ensuring it doesn't cross itself."
        case .depthDataQualityInsufficient:
            return "Recapture with better lighting or use 2D measurements."
        case .calculationOverflow:
            return "Verify the boundary is correctly drawn and calibration is accurate."
        case .pdfGenerationFailed:
            return "Export as images instead or try again later."
        case .exportFileTooLarge:
            return "Reduce the date range or uncheck 'Include Photos'."
        case .shareSheetUnavailable:
            return "Find the export in Files app > On My iPhone > PediLens > Exports."
        case .insufficientPermissions:
            return "Grant the required permission in Settings > PediLens."
        }
    }
}

// MARK: - Error Handler

class ErrorHandler {
    static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Recovery Strategies
    
    /// Retry an operation with exponential backoff
    func retryWithBackoff<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                ErrorLogger.shared.log(error: error, context: "Retry attempt \(attempt)/\(maxAttempts)")
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2 // Exponential backoff
                }
            }
        }
        
        throw lastError ?? PediLensError.fileWriteFailed(path: "unknown", underlyingError: nil)
    }
    
    /// Queue an operation for later execution
    func queueForLater(operation: @escaping () async throws -> Void, identifier: String) {
        OperationQueue.shared.enqueue(operation: operation, identifier: identifier)
    }
    
    /// Rollback Core Data transaction
    func rollbackTransaction(context: NSManagedObjectContext) {
        context.rollback()
        ErrorLogger.shared.log(
            error: PediLensError.coreDataSaveFailed(underlyingError: NSError(domain: "PediLens", code: -1)),
            context: "Transaction rolled back"
        )
    }
    
    /// Handle error with appropriate recovery strategy
    func handle(error: Error, context: String, autoRecover: Bool = true) async -> ErrorRecoveryResult {
        ErrorLogger.shared.log(error: error, context: context)
        
        guard autoRecover else {
            return .userActionRequired(error: error)
        }
        
        // Determine recovery strategy based on error type
        if let pediLensError = error as? PediLensError {
            switch pediLensError {
            case .networkUnavailable, .cloudKitRateLimit:
                return .queued
            case .fileWriteFailed, .coreDataSaveFailed:
                return .retrying
            case .depthDataUnavailable, .detectionConfidenceTooLow:
                return .gracefulDegradation
            default:
                return .userActionRequired(error: error)
            }
        }
        
        return .userActionRequired(error: error)
    }
}

// MARK: - Error Recovery Result

enum ErrorRecoveryResult {
    case recovered
    case retrying
    case queued
    case gracefulDegradation
    case userActionRequired(error: Error)
}

// MARK: - Operation Queue

class OperationQueue {
    static let shared = OperationQueue()
    
    private var queuedOperations: [(identifier: String, operation: () async throws -> Void)] = []
    private let queue = DispatchQueue(label: "com.pedilens.operationqueue")
    
    private init() {}
    
    func enqueue(operation: @escaping () async throws -> Void, identifier: String) {
        queue.async {
            self.queuedOperations.append((identifier, operation))
            ErrorLogger.shared.log(
                error: NSError(domain: "PediLens", code: 0, userInfo: [NSLocalizedDescriptionKey: "Operation queued"]),
                context: "Queued operation: \(identifier)"
            )
        }
    }
    
    func processQueue() async {
        let operations = queue.sync { queuedOperations }
        
        for (identifier, operation) in operations {
            do {
                try await operation()
                queue.async {
                    self.queuedOperations.removeAll { $0.identifier == identifier }
                }
                ErrorLogger.shared.log(
                    error: NSError(domain: "PediLens", code: 0, userInfo: [NSLocalizedDescriptionKey: "Operation completed"]),
                    context: "Completed queued operation: \(identifier)"
                )
            } catch {
                ErrorLogger.shared.log(error: error, context: "Failed queued operation: \(identifier)")
            }
        }
    }
    
    func queueCount() -> Int {
        queue.sync { queuedOperations.count }
    }
}
