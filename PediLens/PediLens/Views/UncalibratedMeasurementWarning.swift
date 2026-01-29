//
//  UncalibratedMeasurementWarning.swift
//  PediLens
//
//  Warning view for uncalibrated measurements
//  Requirements: 12.5
//

import SwiftUI

/// Warning banner displayed when measurements are taken without calibration
struct UncalibratedMeasurementWarning: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Uncalibrated Measurements")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Text("These measurements are estimates. Use a reference object for accurate measurements.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Uncalibrated measurement warning")
        .accessibilityValue("These measurements are estimates. Use a reference object for accurate measurements.")
    }
}

/// Inline warning text for uncalibrated measurements
struct UncalibratedMeasurementInlineWarning: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
            
            Text("Estimate")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .accessibilityLabel("Measurement is an estimate")
    }
}

/// Helper to check if a calibration is valid
extension MeasurementCalibration {
    /// Returns true if this calibration has a reference object (is calibrated)
    var isCalibrated: Bool {
        return referenceObject != nil
    }
}

/// Helper to check if measurements need calibration warning
extension WoundMeasurement {
    /// Returns true if this measurement was taken without calibration
    var needsCalibrationWarning: Bool {
        return !calibrationUsed.isCalibrated
    }
}

// MARK: - Previews

struct UncalibratedMeasurementWarning_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            UncalibratedMeasurementWarning()
            
            UncalibratedMeasurementInlineWarning()
        }
        .padding()
    }
}
