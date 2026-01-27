//
//  PatientSelectionView.swift
//  PediLens
//
//  Patient selection view for capture workflow
//  Requirements: 16.1, 16.2
//

import SwiftUI
import CoreData

struct PatientSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PatientSelectionViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.patients.isEmpty {
                    emptyStateView
                } else {
                    patientList
                }
            }
            .navigationTitle("Select Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadPatients()
            }
        }
    }
    
    private var patientList: some View {
        List {
            ForEach(viewModel.patients, id: \.id) { patient in
                Button(action: {
                    viewModel.selectPatient(patient)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(patient.name ?? "Unknown")
                                .font(.headline)
                            
                            Text("ID: \(patient.patientID ?? "N/A")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if viewModel.selectedPatient?.id == patient.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Patients")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add patients in the Patients tab before capturing images")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

/// Camera view with patient identification
struct CameraViewWithPatientID: View {
    @StateObject private var viewModel: PatientSelectionViewModel
    @State private var showingPatientSelection = false
    
    let user: User
    
    init(user: User) {
        self.user = user
        _viewModel = StateObject(wrappedValue: PatientSelectionViewModel(user: user))
    }
    
    var body: some View {
        ZStack {
            // Camera preview would go here
            Color.black
                .ignoresSafeArea()
            
            VStack {
                // Patient info overlay
                if viewModel.requiresPatientSelection {
                    patientInfoOverlay
                        .padding()
                }
                
                Spacer()
                
                // Capture button
                captureButton
                    .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingPatientSelection) {
            PatientSelectionView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.promptForPatientSelection()
        }
    }
    
    private var patientInfoOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Patient")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(viewModel.patientDisplayText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                showingPatientSelection = true
            }) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    private var captureButton: some View {
        Button(action: {
            if viewModel.requiresPatientSelection && !viewModel.isPatientSelected {
                showingPatientSelection = true
            } else {
                // Perform capture
                capturePhoto()
            }
        }) {
            Circle()
                .fill(viewModel.isPatientSelected || !viewModel.requiresPatientSelection ? Color.white : Color.gray)
                .frame(width: 70, height: 70)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 80, height: 80)
                )
        }
        .disabled(viewModel.requiresPatientSelection && !viewModel.isPatientSelected)
    }
    
    private func capturePhoto() {
        // This would integrate with CameraManager
        // For now, just a placeholder
        print("Capturing photo for patient: \(viewModel.patientDisplayText)")
    }
}

struct PatientSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User.create(in: context, role: .doctor)
        let viewModel = PatientSelectionViewModel(user: user)
        
        return PatientSelectionView(viewModel: viewModel)
    }
}

struct CameraViewWithPatientID_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User.create(in: context, role: .doctor)
        
        return CameraViewWithPatientID(user: user)
    }
}
