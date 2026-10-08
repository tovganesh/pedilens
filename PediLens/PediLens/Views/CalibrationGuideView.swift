//
//  CalibrationGuideView.swift
//  PediLens
//
//  HUD overlay view that provides real-time capture distance and calibration guidance
//

import SwiftUI

/// View providing live calibration guidance during photo capture
struct CalibrationGuideView: View {
    
    // MARK: - Properties
    
    var isLiDARAvailable: Bool
    var distanceStatus: CaptureDistanceStatus
    var currentDistance: Float?
    var detectedScale: ReferenceScaleInfo?
    
    @State private var showTips: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
            // Top HUD Banner
            HStack(spacing: 12) {
                // Calibration Mode Icon
                Image(systemName: modeIcon)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(subtitleText)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // Accuracy Badge
                Text(accuracyBadgeText)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.3))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.6), lineWidth: 1)
                    )
                
                // Tips Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTips.toggle()
                    }
                }) {
                    Image(systemName: showTips ? "chevron.up.circle.fill" : "info.circle")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.65))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.4), lineWidth: 1)
            )
            
            // Expandable Clinical Guidance Tips
            if showTips {
                VStack(alignment: .leading, spacing: 6) {
                    tipRow(icon: "viewfinder", text: "Position camera 20-30 cm directly above the wound")
                    tipRow(icon: "creditcard", text: "Place a US quarter or card next to the wound for scale")
                    tipRow(icon: "sun.max", text: "Ensure bright, even lighting without heavy shadows")
                }
                .padding(10)
                .background(Color.black.opacity(0.75))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titleText). \(subtitleText). Accuracy: \(accuracyBadgeText)")
    }
    
    // MARK: - Subviews
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var modeIcon: String {
        if isLiDARAvailable {
            return "camera.metering.center.weighted"
        } else if detectedScale != nil {
            return "ruler"
        } else {
            return "exclamationmark.triangle"
        }
    }
    
    private var titleText: String {
        if isLiDARAvailable {
            if let dist = currentDistance {
                return "Distance: \(String(format: "%.1f", dist * 100)) cm"
            }
            return "LiDAR Active"
        } else if let scale = detectedScale {
            return "\(scale.objectType.displayName) Detected"
        } else {
            return "Place Reference Scale"
        }
    }
    
    private var subtitleText: String {
        if isLiDARAvailable {
            return distanceStatus.rawValue
        } else if detectedScale != nil {
            return "Ready for calibrated capture"
        } else {
            return "Use a coin or card for ±2-5mm accuracy"
        }
    }
    
    private var accuracyBadgeText: String {
        if isLiDARAvailable {
            return "HIGH (±1-2mm)"
        } else if detectedScale != nil {
            return "MED (±2-5mm)"
        } else {
            return "EST (±10-20mm)"
        }
    }
    
    private var statusColor: Color {
        if isLiDARAvailable {
            switch distanceStatus {
            case .optimal:
                return .green
            case .tooClose, .tooFar:
                return .orange
            case .measuring, .unavailable:
                return .yellow
            }
        } else if detectedScale != nil {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - Previews

struct CalibrationGuideView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            VStack(spacing: 20) {
                CalibrationGuideView(
                    isLiDARAvailable: true,
                    distanceStatus: .optimal,
                    currentDistance: 0.24,
                    detectedScale: nil
                )
                
                CalibrationGuideView(
                    isLiDARAvailable: false,
                    distanceStatus: .unavailable,
                    currentDistance: nil,
                    detectedScale: ReferenceScaleInfo(
                        objectType: .creditCard,
                        boundingBox: .zero,
                        pixelWidth: 100,
                        pixelHeight: 63,
                        confidence: 0.9,
                        detectedDimensions: nil
                    )
                )
                
                CalibrationGuideView(
                    isLiDARAvailable: false,
                    distanceStatus: .unavailable,
                    currentDistance: nil,
                    detectedScale: nil
                )
            }
        }
    }
}
