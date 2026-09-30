//
//  AccessibilityHelpers.swift
//  PediLens
//
//  Accessibility helper utilities for alternative interaction methods
//

import SwiftUI

/// Provides alternative interaction methods for camera controls
struct AccessibleCameraControls {
    /// Announces camera status changes for VoiceOver users
    static func announceCameraStatus(_ status: String) {
        UIAccessibility.post(notification: .announcement, argument: status)
    }
    
    /// Announces photo capture completion
    static func announcePhotoCaptured() {
        UIAccessibility.post(notification: .announcement, argument: "Photo captured successfully")
    }
    
    /// Announces measurement completion
    static func announceMeasurementComplete(area: Double) {
        let announcement = String(format: "Measurement complete. Area: %.1f square centimeters", area / 100)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Announces wound detection status
    static func announceWoundDetection(confidence: Float) {
        let confidencePercent = Int(confidence * 100)
        let announcement = "Wound boundary detected with \(confidencePercent)% confidence"
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

/// Provides alternative interaction methods for measurement tools
struct AccessibleMeasurementTools {
    /// Announces boundary adjustment
    static func announceBoundaryAdjustment() {
        UIAccessibility.post(notification: .announcement, argument: "Boundary adjusted. Measurements updated.")
    }
    
    /// Announces calibration set
    static func announceCalibrationSet(calibrationType: String) {
        UIAccessibility.post(notification: .announcement, argument: "Calibration set using \(calibrationType)")
    }
    
    /// Provides haptic feedback for boundary interactions
    static func provideBoundaryFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Provides haptic feedback for measurement completion
    static func provideMeasurementFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

/// Custom accessibility modifier for complex gestures
struct AccessibleGestureModifier: ViewModifier {
    let label: String
    let hint: String
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAction {
                action()
            }
    }
}

extension View {
    /// Adds accessible gesture support with custom action
    func accessibleGesture(label: String, hint: String, action: @escaping () -> Void) -> some View {
        self.modifier(AccessibleGestureModifier(label: label, hint: hint, action: action))
    }
}

/// Provides alternative text input methods for accessibility
struct AccessibleTextInput: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var multiline: Bool = false
    
    var body: some View {
        Group {
            if multiline {
                TextEditor(text: $text)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .accessibilityLabel(label)
        .accessibilityValue(text.isEmpty ? "Empty" : text)
        .accessibilityHint(multiline ? "Text area for entering multiple lines" : "Text field for entering text")
    }
}

/// Provides accessible button with enhanced feedback
struct AccessibleButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    var style: ButtonStyleType = .primary
    var inputLabels: [String] = []
    
    enum ButtonStyleType {
        case primary
        case secondary
        case destructive
    }
    
    var body: some View {
        Group {
            switch style {
            case .primary:
                button.buttonStyle(.borderedProminent)
            case .secondary:
                button.buttonStyle(.bordered)
            case .destructive:
                button.buttonStyle(.bordered).tint(.red)
            }
        }
        .accessibilityLabel(title)
        .accessibilityInputLabels(inputLabels.isEmpty ? [title] : inputLabels)
        .accessibilityAddTraits(.isButton)
    }
    
    private var button: some View {
        Button(action: {
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
    }
}

/// Provides accessible slider with step-by-step adjustment
struct AccessibleSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Button(action: {
                    if value > range.lowerBound {
                        value = max(range.lowerBound, value - step)
                        announceValue()
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Decrease \(label)")
                .accessibilityHint("Decreases value by \(step) \(unit)")
                
                Slider(value: $value, in: range, step: step)
                    .accessibilityLabel(label)
                    .accessibilityValue("\(String(format: "%.1f", value)) \(unit)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment:
                            if value < range.upperBound {
                                value = min(range.upperBound, value + step)
                            }
                        case .decrement:
                            if value > range.lowerBound {
                                value = max(range.lowerBound, value - step)
                            }
                        @unknown default:
                            break
                        }
                        announceValue()
                    }
                
                Button(action: {
                    if value < range.upperBound {
                        value = min(range.upperBound, value + step)
                        announceValue()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Increase \(label)")
                .accessibilityHint("Increases value by \(step) \(unit)")
            }
            
            Text("\(String(format: "%.1f", value)) \(unit)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)
        }
    }
    
    private func announceValue() {
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(label): \(String(format: "%.1f", value)) \(unit)"
        )
    }
}

/// Provides accessible picker with clear labels
struct AccessiblePicker<T: Hashable & CustomStringConvertible>: View {
    let label: String
    @Binding var selection: T
    let options: [T]
    
    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(option.description).tag(option)
            }
        }
        .accessibilityLabel(label)
        .accessibilityValue(selection.description)
        .accessibilityHint("Picker for selecting \(label)")
    }
}

/// Provides accessible toggle with clear state announcement
struct AccessibleToggle: View {
    let label: String
    @Binding var isOn: Bool
    var hint: String? = nil
    
    var body: some View {
        Toggle(label, isOn: $isOn)
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(hint ?? "Toggle to turn \(isOn ? "off" : "on")")
            .onChange(of: isOn) { newValue in
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "\(label) \(newValue ? "enabled" : "disabled")"
                )
            }
    }
}
