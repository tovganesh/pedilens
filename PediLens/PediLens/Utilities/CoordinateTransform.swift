//
//  CoordinateTransform.swift
//  PediLens
//
//  Coordinate transformation utilities for aspect-fit image display
//

import CoreGraphics
import Foundation

/// Helper extension for coordinate transformations when displaying images with aspect-fit
extension CGSize {
    
    /// Calculate the actual displayed size, offset, and scale when using aspectRatio(.fit)
    /// - Parameter containerSize: The size of the container view
    /// - Returns: Tuple containing displayed size, offset from container origin, and scale factor
    func aspectFitTransform(in containerSize: CGSize) -> (size: CGSize, offset: CGPoint, scale: CGFloat) {
        // Calculate scale factors for both dimensions
        let scaleX = containerSize.width / self.width
        let scaleY = containerSize.height / self.height
        
        // Use minimum scale to maintain aspect ratio (fit mode)
        let scale = min(scaleX, scaleY)
        
        // Calculate actual displayed image size
        let displayedSize = CGSize(
            width: self.width * scale,
            height: self.height * scale
        )
        
        // Calculate offset to center the image in the container
        let offset = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2,
            y: (containerSize.height - displayedSize.height) / 2
        )
        
        return (displayedSize, offset, scale)
    }
    
    /// Transform a point from image coordinate space to view coordinate space
    /// Accounts for aspect-fit scaling and centering offset
    /// - Parameters:
    ///   - point: Point in image coordinates
    ///   - containerSize: Size of the container view
    /// - Returns: Point in view coordinates
    func imageToView(point: CGPoint, containerSize: CGSize) -> CGPoint {
        let transform = self.aspectFitTransform(in: containerSize)
        return CGPoint(
            x: point.x * transform.scale + transform.offset.x,
            y: point.y * transform.scale + transform.offset.y
        )
    }
    
    /// Transform a point from view coordinate space to image coordinate space
    /// Accounts for aspect-fit scaling and centering offset
    /// - Parameters:
    ///   - point: Point in view coordinates
    ///   - containerSize: Size of the container view
    /// - Returns: Point in image coordinates
    func viewToImage(point: CGPoint, containerSize: CGSize) -> CGPoint {
        let transform = self.aspectFitTransform(in: containerSize)
        return CGPoint(
            x: (point.x - transform.offset.x) / transform.scale,
            y: (point.y - transform.offset.y) / transform.scale
        )
    }
    
    /// Transform an array of points from image space to view space
    /// - Parameters:
    ///   - points: Array of points in image coordinates
    ///   - containerSize: Size of the container view
    /// - Returns: Array of points in view coordinates
    func imageToView(points: [CGPoint], containerSize: CGSize) -> [CGPoint] {
        return points.map { imageToView(point: $0, containerSize: containerSize) }
    }
    
    /// Transform an array of points from view space to image space
    /// - Parameters:
    ///   - points: Array of points in view coordinates
    ///   - containerSize: Size of the container view
    /// - Returns: Array of points in image coordinates
    func viewToImage(points: [CGPoint], containerSize: CGSize) -> [CGPoint] {
        return points.map { viewToImage(point: $0, containerSize: containerSize) }
    }
}

/// Helper for calculating aspect-fit geometry
struct AspectFitGeometry {
    let imageSize: CGSize
    let containerSize: CGSize
    let displayedSize: CGSize
    let offset: CGPoint
    let scale: CGFloat
    
    init(imageSize: CGSize, containerSize: CGSize) {
        self.imageSize = imageSize
        self.containerSize = containerSize
        
        let transform = imageSize.aspectFitTransform(in: containerSize)
        self.displayedSize = transform.size
        self.offset = transform.offset
        self.scale = transform.scale
    }
    
    /// Transform point from image to view coordinates
    func imageToView(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * scale + offset.x,
            y: point.y * scale + offset.y
        )
    }
    
    /// Transform point from view to image coordinates
    func viewToImage(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: (point.x - offset.x) / scale,
            y: (point.y - offset.y) / scale
        )
    }
    
    /// Check if a view point is within the displayed image bounds
    func isPointInImage(_ viewPoint: CGPoint) -> Bool {
        return viewPoint.x >= offset.x &&
               viewPoint.x <= offset.x + displayedSize.width &&
               viewPoint.y >= offset.y &&
               viewPoint.y <= offset.y + displayedSize.height
    }
}
