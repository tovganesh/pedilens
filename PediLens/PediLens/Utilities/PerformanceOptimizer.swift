//
//  PerformanceOptimizer.swift
//  PediLens
//
//  Performance optimization utilities for image processing, caching, and background operations
//

import Foundation
import UIKit
import CoreML

/// Performance optimization utilities
class PerformanceOptimizer {
    
    // MARK: - Singleton
    
    static let shared = PerformanceOptimizer()
    
    // MARK: - Properties
    
    /// Cache for detection results
    private var detectionCache = NSCache<NSString, CachedDetectionResult>()
    
    /// Background queue for image processing
    private let imageProcessingQueue = DispatchQueue(label: "com.pedilens.imageProcessing", qos: .userInitiated)
    
    /// Background queue for ML inference
    private let mlInferenceQueue = DispatchQueue(label: "com.pedilens.mlInference", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        // Configure cache limits
        detectionCache.countLimit = 50 // Cache up to 50 detection results
        detectionCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    // MARK: - Image Resizing for ML Inference
    
    /// Resizes an image for ML inference (max 1024x1024)
    /// - Parameter image: Original image
    /// - Returns: Resized image optimized for ML processing
    func resizeImageForMLInference(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async {
                let resized = self.resizeImage(image, maxDimension: 1024)
                continuation.resume(returning: resized)
            }
        }
    }
    
    /// Resizes an image to fit within a maximum dimension while maintaining aspect ratio
    /// - Parameters:
    ///   - image: Original image
    ///   - maxDimension: Maximum width or height
    /// - Returns: Resized image
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Check if resizing is needed
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Perform resize
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    // MARK: - Detection Result Caching
    
    /// Retrieves cached detection result for an image
    /// - Parameter imageIdentifier: Unique identifier for the image (e.g., file path or hash)
    /// - Returns: Cached detection result if available
    func getCachedDetection(for imageIdentifier: String) -> WoundBoundary? {
        return detectionCache.object(forKey: imageIdentifier as NSString)?.boundary
    }
    
    /// Caches a detection result
    /// - Parameters:
    ///   - boundary: Detected wound boundary
    ///   - imageIdentifier: Unique identifier for the image
    func cacheDetection(_ boundary: WoundBoundary, for imageIdentifier: String) {
        let cached = CachedDetectionResult(boundary: boundary)
        detectionCache.setObject(cached, forKey: imageIdentifier as NSString)
    }
    
    /// Clears the detection cache
    func clearDetectionCache() {
        detectionCache.removeAllObjects()
    }
    
    // MARK: - Background Processing
    
    /// Executes image processing on a background queue
    /// - Parameter operation: Processing operation to execute
    /// - Returns: Result of the operation
    func executeImageProcessing<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            imageProcessingQueue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Executes ML inference on a background queue
    /// - Parameter operation: ML inference operation to execute
    /// - Returns: Result of the operation
    func executeMLInference<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            mlInferenceQueue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generates a thumbnail asynchronously
    /// - Parameters:
    ///   - image: Original image
    ///   - size: Desired thumbnail size
    /// - Returns: Thumbnail image
    func generateThumbnail(from image: UIImage, size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async {
                let thumbnail = self.createThumbnail(from: image, size: size)
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    /// Creates a thumbnail from an image
    /// - Parameters:
    ///   - image: Original image
    ///   - size: Desired thumbnail size
    /// - Returns: Thumbnail image
    private func createThumbnail(from image: UIImage, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumbnail = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return thumbnail
    }
    
    // MARK: - Memory Management
    
    /// Compresses an image to reduce memory footprint
    /// - Parameters:
    ///   - image: Original image
    ///   - quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: Compressed image data
    func compressImage(_ image: UIImage, quality: CGFloat = 0.8) async -> Data? {
        return await withCheckedContinuation { continuation in
            imageProcessingQueue.async {
                let compressed = image.jpegData(compressionQuality: quality)
                continuation.resume(returning: compressed)
            }
        }
    }
}

// MARK: - Cached Detection Result

/// Wrapper for cached detection results
private class CachedDetectionResult {
    let boundary: WoundBoundary
    let timestamp: Date
    
    init(boundary: WoundBoundary) {
        self.boundary = boundary
        self.timestamp = Date()
    }
}

// MARK: - Lazy Loading Support

/// Protocol for lazy-loadable content
protocol LazyLoadable {
    associatedtype Content
    func loadContent() async throws -> Content
}

/// Lazy loader for managing paginated content
class LazyLoader<T> {
    private var items: [T] = []
    private var isLoading = false
    private let pageSize: Int
    private let loadPage: (Int) async throws -> [T]
    
    init(pageSize: Int = 20, loadPage: @escaping (Int) async throws -> [T]) {
        self.pageSize = pageSize
        self.loadPage = loadPage
    }
    
    /// Loads the next page of items
    func loadNextPage() async throws {
        guard !isLoading else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let currentPage = items.count / pageSize
        let newItems = try await loadPage(currentPage)
        items.append(contentsOf: newItems)
    }
    
    /// Returns all currently loaded items
    func getItems() -> [T] {
        return items
    }
    
    /// Checks if more items should be loaded based on current index
    func shouldLoadMore(currentIndex: Int) -> Bool {
        return currentIndex >= items.count - (pageSize / 2) && !isLoading
    }
}
