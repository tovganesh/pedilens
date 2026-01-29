//
//  DataIntegrityManager.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import CryptoKit

// MARK: - File Checksum Entry

struct FileChecksumEntry: Codable {
    let filePath: String
    let checksum: String
    let algorithm: String
    let fileSize: Int64
    let lastVerified: Date
    let createdAt: Date
}

// MARK: - Data Integrity Manager

class DataIntegrityManager {
    static let shared = DataIntegrityManager()
    
    private let checksumDirectory: URL
    private let checksumFileName = "file_checksums.json"
    private var checksumCache: [String: FileChecksumEntry] = [:]
    private let queue = DispatchQueue(label: "com.pedilens.dataintegrity", qos: .utility)
    
    private init() {
        // Create checksums directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.checksumDirectory = documentsPath.appendingPathComponent("PediLens/Checksums", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: checksumDirectory, withIntermediateDirectories: true)
        
        // Load existing checksums
        loadChecksums()
    }
    
    // MARK: - Public Methods
    
    /// Generate and store checksum for a file
    func generateChecksum(for fileURL: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DataIntegrityError.fileNotFound(path: fileURL.path)
        }
        
        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        
        // Calculate SHA-256 checksum
        let hash = SHA256.hash(data: fileData)
        let checksum = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Create checksum entry
        let entry = FileChecksumEntry(
            filePath: fileURL.path,
            checksum: checksum,
            algorithm: "SHA-256",
            fileSize: fileSize,
            lastVerified: Date(),
            createdAt: Date()
        )
        
        // Store in cache and persist
        queue.async {
            self.checksumCache[fileURL.path] = entry
            self.saveChecksums()
        }
        
        return checksum
    }
    
    /// Verify file integrity against stored checksum
    func verifyIntegrity(for fileURL: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DataIntegrityError.fileNotFound(path: fileURL.path)
        }
        
        // Get stored checksum
        guard let storedEntry = checksumCache[fileURL.path] else {
            throw DataIntegrityError.checksumNotFound(path: fileURL.path)
        }
        
        // Calculate current checksum
        let currentChecksum = try generateChecksum(for: fileURL)
        
        // Compare checksums
        let isValid = currentChecksum == storedEntry.checksum
        
        if !isValid {
            ErrorLogger.shared.log(
                error: DataIntegrityError.checksumMismatch(
                    path: fileURL.path,
                    expected: storedEntry.checksum,
                    actual: currentChecksum
                ),
                context: "File integrity verification failed"
            )
        }
        
        // Update last verified date
        if isValid {
            queue.async {
                var updatedEntry = storedEntry
                updatedEntry = FileChecksumEntry(
                    filePath: storedEntry.filePath,
                    checksum: storedEntry.checksum,
                    algorithm: storedEntry.algorithm,
                    fileSize: storedEntry.fileSize,
                    lastVerified: Date(),
                    createdAt: storedEntry.createdAt
                )
                self.checksumCache[fileURL.path] = updatedEntry
                self.saveChecksums()
            }
        }
        
        return isValid
    }
    
    /// Verify all stored files
    func verifyAllFiles() async throws -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for (filePath, _) in checksumCache {
            let fileURL = URL(fileURLWithPath: filePath)
            
            do {
                let isValid = try verifyIntegrity(for: fileURL)
                results[filePath] = isValid
            } catch {
                results[filePath] = false
                ErrorLogger.shared.log(error: error, context: "Periodic integrity check failed for \(filePath)")
            }
        }
        
        return results
    }
    
    /// Attempt to recover corrupted file from iCloud
    func recoverFromiCloud(fileURL: URL) async throws {
        // Check if iCloud sync is enabled
        guard let syncManager = try? SyncManager() else {
            throw DataIntegrityError.recoveryFailed(reason: "iCloud sync not available")
        }
        
        let syncStatus = syncManager.getSyncStatus()
        
        switch syncStatus {
        case .synced, .syncing:
            // Trigger a sync to pull latest version from iCloud
            try await syncManager.forceSyncNow()
            
            // Wait a moment for sync to complete
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Verify integrity again
            let isValid = try verifyIntegrity(for: fileURL)
            
            if !isValid {
                throw DataIntegrityError.recoveryFailed(reason: "File still corrupted after iCloud recovery")
            }
            
        case .offline:
            throw DataIntegrityError.recoveryFailed(reason: "Device is offline, cannot recover from iCloud")
            
        case .error(let errorString):
            throw DataIntegrityError.recoveryFailed(reason: "iCloud sync error: \(errorString)")
            
        default:
            throw DataIntegrityError.recoveryFailed(reason: "Unknown sync status")
        }
    }
    
    /// Remove checksum entry for deleted file
    func removeChecksum(for fileURL: URL) {
        queue.async {
            self.checksumCache.removeValue(forKey: fileURL.path)
            self.saveChecksums()
        }
    }
    
    /// Get checksum entry for a file
    func getChecksumEntry(for fileURL: URL) -> FileChecksumEntry? {
        return checksumCache[fileURL.path]
    }
    
    /// Perform periodic integrity checks
    func performPeriodicCheck() async {
        do {
            let results = try await verifyAllFiles()
            
            let corruptedFiles = results.filter { !$0.value }
            
            if !corruptedFiles.isEmpty {
                ErrorLogger.shared.log(
                    error: DataIntegrityError.multipleFilesCorrupted(count: corruptedFiles.count),
                    context: "Periodic integrity check found \(corruptedFiles.count) corrupted files"
                )
                
                // Attempt recovery for each corrupted file
                for (filePath, _) in corruptedFiles {
                    let fileURL = URL(fileURLWithPath: filePath)
                    do {
                        try await recoverFromiCloud(fileURL: fileURL)
                    } catch {
                        ErrorLogger.shared.log(
                            error: error,
                            context: "Failed to recover corrupted file: \(filePath)"
                        )
                    }
                }
            }
        } catch {
            ErrorLogger.shared.log(error: error, context: "Periodic integrity check failed")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadChecksums() {
        let checksumFile = checksumDirectory.appendingPathComponent(checksumFileName)
        
        guard FileManager.default.fileExists(atPath: checksumFile.path),
              let data = try? Data(contentsOf: checksumFile) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let entries = try? decoder.decode([FileChecksumEntry].self, from: data) {
            checksumCache = Dictionary(uniqueKeysWithValues: entries.map { ($0.filePath, $0) })
        }
    }
    
    private func saveChecksums() {
        let checksumFile = checksumDirectory.appendingPathComponent(checksumFileName)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let entries = Array(checksumCache.values)
        
        if let data = try? encoder.encode(entries) {
            try? data.write(to: checksumFile, options: .atomic)
        }
    }
}

// MARK: - Data Integrity Errors

enum DataIntegrityError: LocalizedError {
    case fileNotFound(path: String)
    case checksumNotFound(path: String)
    case checksumMismatch(path: String, expected: String, actual: String)
    case recoveryFailed(reason: String)
    case multipleFilesCorrupted(count: Int)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .checksumNotFound(let path):
            return "No checksum found for file: \(path)"
        case .checksumMismatch(let path, let expected, let actual):
            return "Checksum mismatch for \(path). Expected: \(expected), Actual: \(actual)"
        case .recoveryFailed(let reason):
            return "File recovery failed: \(reason)"
        case .multipleFilesCorrupted(let count):
            return "\(count) files failed integrity check"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "The file may have been deleted or moved."
        case .checksumNotFound:
            return "Generate a new checksum for this file."
        case .checksumMismatch:
            return "The file may be corrupted. Attempting recovery from iCloud."
        case .recoveryFailed:
            return "Manual intervention may be required. Check iCloud sync status."
        case .multipleFilesCorrupted:
            return "Review the error log for details on which files are affected."
        }
    }
}
