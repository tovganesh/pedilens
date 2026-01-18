//
//  FileStorageManager.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import UIKit

/// Protocol defining file storage operations
protocol FileStorageManagerProtocol {
    func savePhoto(_ data: Data, for sessionID: UUID) async throws -> URL
    func saveLivePhotoVideo(_ url: URL, for sessionID: UUID) async throws -> URL
    func saveDepthData(_ data: Data, for sessionID: UUID) async throws -> URL
    func loadPhoto(at path: String) async throws -> Data
    func deleteFiles(for sessionID: UUID) async throws
    func getStorageUsage() async -> StorageInfo
}

/// Information about storage usage
struct StorageInfo {
    let totalUsedBytes: Int64
    let photoCount: Int
    let availableBytes: Int64
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
                    try fileManager.createDirectory(at: directory,
                                                   withIntermediateDirectories: true,
                                                   attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
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
        
        // Generate and save thumbnail
        if let image = UIImage(data: data) {
            let thumbnail = generateThumbnail(from: image, size: CGSize(width: 300, height: 300))
            if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
                let thumbnailURL = sessionDir.appendingPathComponent("thumbnail.jpg")
                try thumbnailData.write(to: thumbnailURL, options: [.completeFileProtection])
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
    
    /// Delete all files for a session
    func deleteFiles(for sessionID: UUID) async throws {
        let sessionDir = sessionDirectory(for: sessionID)
        
        if fileManager.fileExists(atPath: sessionDir.path) {
            try fileManager.removeItem(at: sessionDir)
        }
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
    
    /// Generate a thumbnail from an image
    private func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Get the exports directory URL
    func getExportsDirectory() -> URL {
        return exportsDirectory
    }
}
