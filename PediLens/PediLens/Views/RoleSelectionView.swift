//
//  RoleSelectionView.swift
//  PediLens
//
//  First-launch onboarding view for user role selection
//

import SwiftUI

struct RoleSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onRoleSelected: (UserRole) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("Welcome to PediLens")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Please select your role to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Role Selection Cards
                VStack(spacing: 20) {
                    RoleCard(
                        role: .doctor,
                        icon: "stethoscope",
                        title: "Doctor / Care Provider",
                        description: "Manage multiple patients and track their wound healing progress",
                        isSelected: selectedRole == .doctor
                    ) {
                        selectedRole = .doctor
                    }
                    
                    RoleCard(
                        role: .patient,
                        icon: "person.fill",
                        title: "Patient",
                        description: "Track your own wound healing journey",
                        isSelected: selectedRole == .patient
                    ) {
                        selectedRole = .patient
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Continue Button
                Button(action: confirmSelection) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Continue")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedRole != nil ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedRole == nil || isLoading)
                .padding(.horizontal)
                .padding(.bottom, 30)
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RoleSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        RoleSelectionView { role in
            print("Selected role: \(role)")
        }
    }
}
