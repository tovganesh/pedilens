//
//  DoctorBiometricLockView.swift
//  PediLens
//
//  Biometric lock screen protecting Doctor mode and sensitive patient health information (PHI)
//

import SwiftUI
import LocalAuthentication

struct DoctorBiometricLockView: View {
    let onUnlocked: () -> Void
    var onSwitchRole: (() -> Void)? = nil
    
    @State private var isAuthenticating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showingError: Bool = false
    
    private var biometryName: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return "Passcode"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }
    
    private var biometryIcon: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return "lock.shield.fill"
        }
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.shield.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Calm medical background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Doctor shield badge
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: biometryIcon)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                }
                
                // Title and HIPAA description
                VStack(spacing: 10) {
                    Text("Doctor Mode Protected")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Biometric verification is required to access patient directories, wound histories, and HIPAA-protected health records.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Error banner if any
                if let errorMessage = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 28)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 14) {
                    Button(action: authenticate) {
                        HStack(spacing: 8) {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: biometryIcon)
                                    .font(.headline)
                                Text("Unlock with \(biometryName)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .pediLensGlassButton(prominent: true)
                    .disabled(isAuthenticating)
                    
                    if let onSwitchRole = onSwitchRole {
                        Button(action: onSwitchRole) {
                            Text("Switch to Patient Mode")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await SecurityManager.shared.authenticateUser(
                    reason: "Authenticate with \(biometryName) to access Doctor patient records",
                    forcePrompt: false
                )
                await MainActor.run {
                    self.isAuthenticating = false
                    if success {
                        self.onUnlocked()
                    }
                }
            } catch let error as SecurityError {
                await MainActor.run {
                    self.isAuthenticating = false
                    switch error {
                    case .authenticationCancelled:
                        self.errorMessage = "Authentication was cancelled."
                    case .authenticationNotAvailable:
                        self.errorMessage = "Biometrics not available. Please use your device passcode."
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticating = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
