//
//  Measurement+Extensions.swift
//  PediLens
//
//  Core Data entity extensions for Measurement with convenience methods
//

import Foundation
import CoreData
import CoreGraphics

extension Measurement {
    
    // MARK: - Factory Methods
    
    /// Create a new Measurement entity
    /// - Parameters:
    ///   - context: The managed object context
    ///   - lengthMM: Length in millimeters
    ///   - widthMM: Width in millimeters
    ///   - areaMM2: Area in square millimeters
    ///   - perimeterMM: Perimeter in millimeters
    ///   - depthMM: Optional depth in millimeters
    ///   - volumeMM3: Optional volume in cubic millimeters
    ///   - boundaryPoints: Encoded boundary points data
    ///   - calibrationData: Encoded calibration data
    ///   - detectionConfidence: Detection confidence score (0-1)
    ///   - isManuallyAdjusted: Whether the measurement was manually adjusted
    ///   - captureSession: The capture session this measurement belongs to
    /// - Returns: A new Measurement instance
    static func create(
        in context: NSManagedObjectContext,
        lengthMM: Double,
        widthMM: Double,
        areaMM2: Double,
        perimeterMM: Double,
        depthMM: Double = 0.0,
        volumeMM3: Double = 0.0,
        boundaryPoints: Data,
        calibrationData: Data,
        detectionConfidence: Float,
        isManuallyAdjusted: Bool = false,
        captureSession: CaptureSession? = nil
    ) -> Measurement {
        let measurement = Measurement(context: context)
        measurement.id = UUID()
        measurement.lengthMM = lengthMM
        measurement.widthMM = widthMM
        measurement.areaMM2 = areaMM2
        measurement.perimeterMM = perimeterMM
        measurement.depthMM = depthMM
        measurement.volumeMM3 = volumeMM3
        measurement.boundaryPoints = boundaryPoints
        measurement.calibrationData = calibrationData
        measurement.detectionConfidence = detectionConfidence
        measurement.isManuallyAdjusted = isManuallyAdjusted
        measurement.captureSession = captureSession
        return measurement
    }
    
    // MARK: - Fetch Requests
    
    /// Fetch measurement for a specific capture session
    /// - Parameters:
    ///   - captureSession: The capture session
    ///   - context: The managed object context
    /// - Returns: The measurement, or nil if not found
    static func fetchMeasurement(
        for captureSession: CaptureSession,
        in context: NSManagedObjectContext
    ) -> Measurement? {
        let request: NSFetchRequest<Measurement> = Measurement.fetchRequest()
        request.predicate = NSPredicate(format: "captureSession == %@", captureSession)
        request.fetchLimit = 1
        
        do {
            let measurements = try context.fetch(request)
            return measurements.first
        } catch {
            print("Error fetching measurement for capture session: \(error)")
            return nil
        }
    }
    
    /// Fetch a measurement by ID
    /// - Parameters:
    ///   - id: The measurement's UUID
    ///   - context: The managed object context
    /// - Returns: The measurement, or nil if not found
    static func fetchMeasurement(
        byID id: UUID,
        in context: NSManagedObjectContext
    ) -> Measurement? {
        let request: NSFetchRequest<Measurement> = Measurement.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let measurements = try context.fetch(request)
            return measurements.first
        } catch {
            print("Error fetching measurement by ID: \(error)")
            return nil
        }
    }
    
    /// Fetch measurements with depth data
    /// - Parameter context: The managed object context
    /// - Returns: Array of measurements with depth data
    static func fetchMeasurementsWithDepth(
        in context: NSManagedObjectContext
    ) -> [Measurement] {
        let request: NSFetchRequest<Measurement> = Measurement.fetchRequest()
        request.predicate = NSPredicate(format: "depthMM > 0")
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching measurements with depth: \(error)")
            return []
        }
    }
    
    /// Fetch all measurements
    /// - Parameter context: The managed object context
    /// - Returns: Array of all measurements
    static func fetchAll(in context: NSManagedObjectContext) -> [Measurement] {
        let request: NSFetchRequest<Measurement> = Measurement.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all measurements: \(error)")
            return []
        }
    }
    
    // MARK: - Update Methods
    
    /// Update measurement values
    /// - Parameters:
    ///   - lengthMM: New length
    ///   - widthMM: New width
    ///   - areaMM2: New area
    ///   - perimeterMM: New perimeter
    ///   - depthMM: New depth
    ///   - volumeMM3: New volume
    func update(
        lengthMM: Double? = nil,
        widthMM: Double? = nil,
        areaMM2: Double? = nil,
        perimeterMM: Double? = nil,
        depthMM: Double? = nil,
        volumeMM3: Double? = nil
    ) {
        if let lengthMM = lengthMM {
            self.lengthMM = lengthMM
        }
        if let widthMM = widthMM {
            self.widthMM = widthMM
        }
        if let areaMM2 = areaMM2 {
            self.areaMM2 = areaMM2
        }
        if let perimeterMM = perimeterMM {
            self.perimeterMM = perimeterMM
        }
        if let depthMM = depthMM {
            self.depthMM = depthMM
        }
        if let volumeMM3 = volumeMM3 {
            self.volumeMM3 = volumeMM3
        }
    }
    
    /// Mark the measurement as manually adjusted
    func markAsManuallyAdjusted() {
        self.isManuallyAdjusted = true
    }
    
    // MARK: - Computed Properties
    
    /// Check if the measurement has depth data
    var hasDepthData: Bool {
        return depthMM > 0
    }
    
    /// Check if the measurement has volume data
    var hasVolumeData: Bool {
        return volumeMM3 > 0
    }
    
    /// Get length in centimeters
    var lengthCM: Double {
        return lengthMM / 10.0
    }
    
    /// Get width in centimeters
    var widthCM: Double {
        return widthMM / 10.0
    }
    
    /// Get area in square centimeters
    var areaCM2: Double {
        return areaMM2 / 100.0
    }
    
    /// Get depth in centimeters
    var depthCM: Double {
        return depthMM / 10.0
    }
    
    /// Get volume in cubic centimeters
    var volumeCM3: Double {
        return volumeMM3 / 1000.0
    }
    
    /// Get length in inches
    var lengthInches: Double {
        return lengthMM / 25.4
    }
    
    /// Get width in inches
    var widthInches: Double {
        return widthMM / 25.4
    }
    
    /// Get area in square inches
    var areaInches2: Double {
        return areaMM2 / 645.16
    }
    
    /// Get depth in inches
    var depthInches: Double {
        return depthMM / 25.4
    }
    
    /// Get volume in cubic inches
    var volumeInches3: Double {
        return volumeMM3 / 16387.064
    }
    
    /// Check if the measurement has calibration data
    var hasCalibration: Bool {
        guard let calibrationData = calibrationData else { return false }
        
        // Try to decode the calibration data to check if it's calibrated
        do {
            let decoder = JSONDecoder()
            let calibration = try decoder.decode(MeasurementCalibration.self, from: calibrationData)
            return calibration.isCalibrated
        } catch {
            return false
        }
    }
    
    // MARK: - Delete Methods
    
    /// Delete the measurement
    /// - Parameter context: The managed object context
    func delete(from context: NSManagedObjectContext) {
        context.delete(self)
    }
}
