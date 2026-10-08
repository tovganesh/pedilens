//
//  FileStorageManager.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import UIKit
import CoreData

/// Protocol defining file storage operations
protocol FileStorageManagerProtocol {
    func savePhoto(_ data: Data, for sessionID: UUID) async throws -> URL
    func saveLivePhotoVideo(_ url: URL, for sessionID: UUID) async throws -> URL
    func saveDepthData(_ data: Data, for sessionID: UUID) async throws -> URL
    func loadPhoto(at path: String) async throws -> Data
    func deleteFiles(for sessionID: UUID) async throws
    func getStorageUsage() async -> StorageInfo
    func isStorageNearCapacity() async -> Bool
    func cleanupOrphanedFiles() async throws -> Int
}

/// Information about storage usage
struct StorageInfo {
    let totalUsedBytes: Int64
    let photoCount: Int
    let availableBytes: Int64
    
    /// Returns true if storage usage is at or above 80% capacity
    var isNearCapacity: Bool {
        let totalCapacity = totalUsedBytes + availableBytes
        guard totalCapacity > 0 else { return false }
        let usagePercentage = Double(totalUsedBytes) / Double(totalCapacity)
        return usagePercentage >= 0.80
    }
}

/// Errors that can occur during file storage operations
enum FileStorageError: LocalizedError {
    case deletionFailed(String)
    case overwriteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .deletionFailed(let message):
            return "File deletion failed: \(message)"
        case .overwriteFailed(let message):
            return "File overwrite failed: \(message)"
        }
    }
}

/// Manages file storage for photos, live photos, and depth data
class FileStorageManager: FileStorageManagerProtocol {
    static let shared = FileStorageManager()
    
    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let photosDirectory: URL
    private let exportsDirectory: URL
    
    private init() {
        // Get the app's Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access Documents directory")
        }
        
        // Set up directory structure
        baseDirectory = documentsURL.appendingPathComponent("PediLens", isDirectory: true)
        photosDirectory = baseDirectory.appendingPathComponent("Photos", isDirectory: true)
        exportsDirectory = baseDirectory.appendingPathComponent("Exports", isDirectory: true)
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
    }
    
    /// Create the directory structure if it doesn't exist
    private func createDirectoriesIfNeeded() {
        let directories = [baseDirectory, photosDirectory, exportsDirectory]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    // Use complete file protection for all directories as per requirement 5.1
                    try fileManager.createDirectory(at: directory,
                                                   withIntermediateDirectories: true,
                                                   attributes: [.protectionKey: FileProtectionType.complete])
                } catch {
                    print("Error creating directory \(directory.path): \(error)")
                }
            }
        }
    }
    
    /// Get the session directory for a given session ID
    private func sessionDirectory(for sessionID: UUID) -> URL {
        return photosDirectory.appendingPathComponent(sessionID.uuidString, isDirectory: true)
    }
    
    /// Save a photo to storage
    func savePhoto(_ data: Data, for sessionID: UUID) async throws -> URL {
        let sessionDir = sessionDirectory(for: sessionID)
        
        // Create session directory if needed
        if !fileManager.fileExists(atPath: sessionDir.path) {
            try fileManager.createDirectory(at: sessionDir,
                                           withIntermediateDirectories: true,
                                           attributes: [.protectionKey: FileProtectionType.complete])
        }
        
        // Save full resolution photo
        let photoURL = sessionDir.appendingPathComponent("photo.heic")
        try data.write(to: photoURL, options: [.completeFileProtection])
        
        // Generate and save thumbnail asynchronously (non-critical, log errors but don't fail)
        Task {
            do {
                if let image = UIImage(data: data) {
                    let thumbnail = await PerformanceOptimizer.shared.generateThumbnail(
                        from: image,
                        size: CGSize(width: 300, height: 300)
                    )
                    if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
                        let thumbnailURL = sessionDir.appendingPathComponent("thumbnail.jpg")
                        try thumbnailData.write(to: thumbnailURL, options: [.completeFileProtection])
                    }
                }
            } catch {
                // Thumbnail generation is non-critical, log but continue
                print("Warning: Failed to generate thumbnail for session \(sessionID): \(error)")
            }
        }
        
        return photoURL
    }
    
    /// Save a live photo video component
    func saveLivePhotoVideo(_ url: URL, for sessionID: UUID) async throws -> URL {
        let sessionDir = sessionDirectory(for: sessionID)
        
        // Create session directory if needed
        if !fileManager.fileExists(atPath: sessionDir.path) {
            try fileManager.createDirectory(at: sessionDir,
                                           withIntermediateDirectories: true,
                                           attributes: [.protectionKey: FileProtectionType.complete])
        }
        
        let videoURL = sessionDir.appendingPathComponent("live_video.mov")
        
        // Copy the video file
        if fileManager.fileExists(atPath: videoURL.path) {
            try fileManager.removeItem(at: videoURL)
        }
        try fileManager.copyItem(at: url, to: videoURL)
        
        // Set file protection
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: videoURL.path)
        
        return videoURL
    }
    
    /// Save depth data
    func saveDepthData(_ data: Data, for sessionID: UUID) async throws -> URL {
        let sessionDir = sessionDirectory(for: sessionID)
        
        // Create session directory if needed
        if !fileManager.fileExists(atPath: sessionDir.path) {
            try fileManager.createDirectory(at: sessionDir,
                                           withIntermediateDirectories: true,
                                           attributes: [.protectionKey: FileProtectionType.complete])
        }
        
        let depthURL = sessionDir.appendingPathComponent("depth.dat")
        try data.write(to: depthURL, options: [.completeFileProtection])
        
        return depthURL
    }
    
    /// Load a photo from storage
    func loadPhoto(at path: String) async throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }
    
    /// Delete all files for a session with secure overwrite
    func deleteFiles(for sessionID: UUID) async throws {
        let sessionDir = sessionDirectory(for: sessionID)
        
        if fileManager.fileExists(atPath: sessionDir.path) {
            // Securely delete all files in the session directory
            try await securelyDeleteDirectory(at: sessionDir)
        }
    }
    
    /// Securely delete a directory and all its contents by overwriting data before removal
    private func securelyDeleteDirectory(at url: URL) async throws {
        // Get all files in the directory
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw FileStorageError.deletionFailed("Unable to enumerate directory contents")
        }
        
        // Collect all file URLs (not directories)
        var fileURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if let isDirectory = resourceValues.isDirectory, !isDirectory {
                fileURLs.append(fileURL)
            }
        }
        
        // Securely overwrite each file before deletion
        for fileURL in fileURLs {
            try await securelyDeleteFile(at: fileURL)
        }
        
        // Now remove the directory
        try fileManager.removeItem(at: url)
    }
    
    /// Securely delete a single file by overwriting its contents before removal
    private func securelyDeleteFile(at url: URL) async throws {
        // Get file size
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resourceValues.fileSize else {
            // If we can't get the size, just delete it
            try fileManager.removeItem(at: url)
            return
        }
        
        // Don't overwrite very large files (> 100MB) to avoid performance issues
        // Just delete them directly
        if fileSize > 100 * 1024 * 1024 {
            try fileManager.removeItem(at: url)
            return
        }
        
        // Overwrite the file with random data (3 passes for secure deletion)
        for _ in 0..<3 {
            var randomData = Data(count: fileSize)
            _ = randomData.withUnsafeMutableBytes { bytes in
                SecRandomCopyBytes(kSecRandomDefault, fileSize, bytes.baseAddress!)
            }
            
            try randomData.write(to: url, options: [.atomic])
        }
        
        // Finally, remove the file
        try fileManager.removeItem(at: url)
    }
    
    /// Get storage usage information
    func getStorageUsage() async -> StorageInfo {
        var totalBytes: Int64 = 0
        var photoCount = 0
        
        // Calculate total size of photos directory
        if let enumerator = fileManager.enumerator(at: photosDirectory,
                                                   includingPropertiesForKeys: [.fileSizeKey],
                                                   options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    if let isDirectory = resourceValues.isDirectory, !isDirectory {
                        if let fileSize = resourceValues.fileSize {
                            totalBytes += Int64(fileSize)
                        }
                        if fileURL.lastPathComponent == "photo.heic" {
                            photoCount += 1
                        }
                    }
                } catch {
                    print("Error reading file size: \(error)")
                }
            }
        }
        
        // Get available space
        var availableBytes: Int64 = 0
        do {
            let systemAttributes = try fileManager.attributesOfFileSystem(forPath: baseDirectory.path)
            if let freeSize = systemAttributes[.systemFreeSize] as? NSNumber {
                availableBytes = freeSize.int64Value
            }
        } catch {
            print("Error getting available space: \(error)")
        }
        
        return StorageInfo(totalUsedBytes: totalBytes,
                          photoCount: photoCount,
                          availableBytes: availableBytes)
    }
    
    /// Generate a thumbnail from an image with aspect-fit scaling
    private func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        let aspectRatio = image.size.width / image.size.height
        let targetAspectRatio = size.width / size.height
        
        var targetSize = size
        
        // Calculate size maintaining aspect ratio (aspect fit)
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            targetSize.height = size.width / aspectRatio
        } else {
            // Image is taller than target
            targetSize.width = size.height * aspectRatio
        }
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    /// Get the exports directory URL
    func getExportsDirectory() -> URL {
        return exportsDirectory
    }
    
    /// Check if storage is at or above 80% capacity
    /// Returns true if storage usage is at or above 80% of total capacity
    func isStorageNearCapacity() async -> Bool {
        let storageInfo = await getStorageUsage()
        return storageInfo.isNearCapacity
    }
    
    /// Clean up orphaned files (session directories without Core Data references)
    /// Returns the number of orphaned sessions cleaned up
    func cleanupOrphanedFiles() async throws -> Int {
        var cleanedCount = 0
        
        // Get all session directories from file system
        guard let sessionDirs = try? fileManager.contentsOfDirectory(
            at: photosDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        // Filter to only directories
        let sessionDirectories = sessionDirs.filter { url in
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = resourceValues.isDirectory else {
                return false
            }
            return isDirectory
        }
        
        // Get all valid session IDs from Core Data
        let validSessionIDs = try await fetchAllCaptureSessionIDs()
        let validSessionIDStrings = Set(validSessionIDs.map { $0.uuidString })
        
        // Find and delete orphaned directories
        for sessionDir in sessionDirectories {
            let sessionDirName = sessionDir.lastPathComponent
            
            // Check if this session directory has a corresponding Core Data entry
            if !validSessionIDStrings.contains(sessionDirName) {
                // This is an orphaned directory - delete it
                do {
                    try fileManager.removeItem(at: sessionDir)
                    cleanedCount += 1
                    print("Cleaned up orphaned session directory: \(sessionDirName)")
                } catch {
                    print("Error deleting orphaned directory \(sessionDirName): \(error)")
                    // Continue with other directories even if one fails
                }
            }
        }
        
        return cleanedCount
    }
    
    /// Fetch all capture session IDs from Core Data
    /// This is used to identify which session directories are still valid
    private func fetchAllCaptureSessionIDs() async throws -> [UUID] {
        let context = PersistenceController.shared.container.viewContext
        
        return try await context.perform {
            let fetchRequest = NSFetchRequest<NSDictionary>(entityName: "CaptureSession")
            fetchRequest.propertiesToFetch = ["id"]
            fetchRequest.resultType = .dictionaryResultType
            
            let results = try context.fetch(fetchRequest)
            
            return results.compactMap { dict in
                return dict["id"] as? UUID
            }
        }
    }
}
