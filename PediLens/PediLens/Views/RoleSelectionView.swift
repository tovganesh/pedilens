//
//  RoleSelectionView.swift
//  PediLens
//
//  First-launch onboarding view for user role selection with Liquid Glass styling
//

import SwiftUI

struct RoleSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @ScaledMetric private var iconSize: CGFloat = 80
    @Namespace private var glassNamespace
    
    let onRoleSelected: (UserRole) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true) // Decorative
                    
                    Text("Welcome to PediLens")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Please select your role to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 40)
                
                // Role Selection Cards wrapped in Glass Effect Container
                PediLensGlassContainer(spacing: 20) {
                    VStack(spacing: 20) {
                        RoleCard(
                            role: .doctor,
                            icon: "stethoscope",
                            title: "Doctor / Care Provider",
                            description: "Manage multiple patients and track their wound healing progress",
                            isSelected: selectedRole == .doctor
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedRole = .doctor
                            }
                        }
                        .pediLensGlassID("doctorRoleCard", in: glassNamespace)
                        
                        RoleCard(
                            role: .patient,
                            icon: "person.fill",
                            title: "Patient",
                            description: "Track your own wound healing journey",
                            isSelected: selectedRole == .patient
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedRole = .patient
                            }
                        }
                        .pediLensGlassID("patientRoleCard", in: glassNamespace)
                    }
                    .padding(.horizontal)
                }
                .accessibilityElement(children: .contain)
                
                Spacer()
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .accessibilityLabel("Error: \(errorMessage)")
                }
                
                // Continue Button
                Button(action: confirmSelection) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .accessibilityLabel("Saving role selection")
                        } else {
                            Text("Continue")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .pediLensGlass(
                    cornerRadius: 14,
                    tint: selectedRole != nil ? Color.accentColor : nil,
                    interactive: true
                )
                .foregroundColor(selectedRole != nil ? .accentColor : .secondary)
                .disabled(selectedRole == nil || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 30)
                .accessibilityLabel("Continue with selected role")
                .accessibilityHint(selectedRole == nil ? "Select a role first" : "Confirms your role selection and continues")
                .accessibilityInputLabels(["Continue", "Next", "Confirm"])
            }
            .navigationBarHidden(true)
        }
    }
    
    private func confirmSelection() {
        guard let role = selectedRole else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await UserManager.shared.setUserRole(role)
                
                await MainActor.run {
                    onRoleSelected(role)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save role: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct RoleCard: View {
    let role: UserRole
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    @ScaledMetric private var iconSize: CGFloat = 40
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 60)
                    .accessibilityHidden(true) // Decorative
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .accessibilityLabel("Selected")
                }
            }
            .padding()
            .pediLensGlass(
                cornerRadius: 16,
                tint: isSelected ? .accentColor : nil,
                interactive: true
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Double tap to select this role")
        .accessibilityInputLabels([title, role == .doctor ? "Doctor" : "Patient", "Select \(title)"])
    }
}

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView { role in
            print("Selected role: \(role)")
        }
    }
}
