//
//  PatientListView.swift
//  PediLens
//
//  Doctor role: Patient directory and list management with Liquid Glass styling
//  and adaptive layout for iPhone Duo Cover Screen & Internal Screen.
//

import SwiftUI
import CoreData

struct PatientListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.duoGeometry) private var duoGeometry
    @StateObject private var syncManager = SyncManager.shared
    
    let user: User
    
    @State private var searchText = ""
    @State private var showingAddPatient = false
    @State private var showingStorageSheet = false
    @State private var selectedPatient: Patient?
    @State private var patientToDelete: Patient?
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.name, ascending: true)],
        animation: .default
    )
    private var patients: FetchedResults<Patient>
    
    private var filteredPatients: [Patient] {
        if searchText.isEmpty {
            return Array(patients)
        } else {
            return patients.filter { patient in
                let name = patient.name ?? ""
                let id = patient.patientID ?? ""
                return name.localizedCaseInsensitiveContains(searchText) ||
                       id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var activeSelectedPatient: Patient? {
        if let selected = selectedPatient, filteredPatients.contains(where: { $0.objectID == selected.objectID }) {
            return selected
        }
        return filteredPatients.first
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            patientSidebarContent
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        } detail: {
            NavigationStack {
                if let patient = activeSelectedPatient {
                    PatientDetailView(patient: patient)
                } else {
                    splitPlaceholderView
                }
            }
        }
        .onAppear {
            if selectedPatient == nil, let first = filteredPatients.first {
                selectedPatient = first
            }
        }
        .sheet(isPresented: $showingAddPatient) {
            AddPatientView(user: user)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingStorageSheet) {
            StorageManagementView()
        }
        .alert("Delete Patient Record", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { patientToDelete = nil }
            Button("Delete", role: .destructive) {
                confirmDeletePatient()
            }
        } message: {
            if let patient = patientToDelete {
                Text("Are you sure you want to permanently delete \(patient.name ?? "this patient") and all associated wound records and photos? Biometric authentication is required.")
            } else {
                Text("Are you sure you want to delete this patient?")
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var patientSidebarContent: some View {
        VStack(spacing: 0) {
            // Sync status indicator bar
            HStack {
                SyncStatusView(syncStatus: syncManager.syncStatus)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, duoGeometry.isCoverScreen ? 4 : 6)
            
            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.bottom, duoGeometry.isCoverScreen ? 4 : 6)
                .accessibilityLabel("Search patients")
                .accessibilityHint("Enter patient name or ID to search")
            
            if filteredPatients.isEmpty {
                emptyStateView
            } else {
                List(selection: $selectedPatient) {
                    ForEach(filteredPatients, id: \.self) { patient in
                        NavigationLink(value: patient) {
                            PatientRowView(patient: patient)
                        }
                    }
                    .onDelete(perform: promptDeletePatient)
                }
                .listStyle(InsetGroupedListStyle())
                .navigationDestination(for: Patient.self) { patient in
                    PatientDetailView(patient: patient)
                }
            }
        }
        .navigationTitle("Patients")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { showingStorageSheet = true }) {
                        Image(systemName: "internaldrive")
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Storage Management")
                    .accessibilityHint("Opens storage management and cache settings")
                    
                    Button(action: { showingAddPatient = true }) {
                        Image(systemName: "plus")
                    }
                    .pediLensGlassButton()
                    .accessibilityLabel("Add new patient")
                    .accessibilityHint("Opens form to add a new patient")
                    .accessibilityInputLabels(["Add patient", "New patient", "Add"])
                }
            }
        }
    }
    
    private var splitPlaceholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.7))
            
            Text("No Patient Selected")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select a patient from the directory on the left to view comprehensive clinical records and wound assessments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pediLensGlass(cornerRadius: 20)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: duoGeometry.isCoverScreen ? 44 : 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true) // Decorative
            
            Text(searchText.isEmpty ? "No Patients" : "No Results")
                .font(duoGeometry.isCoverScreen ? .headline : .title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text(searchText.isEmpty ?
                 "Add your first patient to get started" :
                 "No patients match your search")
                .font(duoGeometry.isCoverScreen ? .caption : .body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
            
            if searchText.isEmpty {
                Button(action: { showingAddPatient = true }) {
                    Label("Add Patient", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .pediLensGlassButton(prominent: true)
                .padding(.top, duoGeometry.isCoverScreen ? 4 : 12)
                .accessibilityLabel("Add first patient")
                .accessibilityHint("Opens form to add your first patient")
                .accessibilityInputLabels(["Add patient", "Add first patient", "New patient"])
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
    
    private func promptDeletePatient(at offsets: IndexSet) {
        if let index = offsets.first {
            patientToDelete = filteredPatients[index]
            showingDeleteConfirmation = true
        }
    }
    
    private func confirmDeletePatient() {
        guard let patient = patientToDelete else { return }
        
        Task {
            do {
                try await SecurityManager.shared.authenticateUser(
                    reason: "Authenticate with Face ID or Touch ID to permanently delete patient records",
                    forcePrompt: true
                )
                try await PatientManager.shared.deletePatient(patient)
                await MainActor.run {
                    if selectedPatient?.objectID == patient.objectID {
                        selectedPatient = nil
                    }
                    patientToDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete patient: \(error.localizedDescription)"
                    showingError = true
                    patientToDelete = nil
                }
            }
        }
    }
}

struct PatientRowView: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(patient.name ?? "Unknown")
                    .font(.headline)
                
                Spacer()
                
                // Active wound count badge
                if patient.activeWoundCount > 0 {
                    Text("\(patient.activeWoundCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .pediLensGlassPill(tint: .red)
                        .accessibilityLabel("\(patient.activeWoundCount) active wound\(patient.activeWoundCount == 1 ? "" : "s")")
                }
            }
            
            HStack {
                Label(patient.patientID ?? "No ID", systemImage: "number")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Patient ID: \(patient.patientID ?? "No ID")")
                
                Spacer()
                
                Text("\(patient.totalWoundCount) wound\(patient.totalWoundCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("\(patient.totalWoundCount) total wound\(patient.totalWoundCount == 1 ? "" : "s")")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Patient: \(patient.name ?? "Unknown"), ID: \(patient.patientID ?? "No ID"), \(patient.activeWoundCount) active, \(patient.totalWoundCount) total wounds")
        .accessibilityHint("Double tap to view patient details")
        .accessibilityAction(named: "View Details") {
            // This will be triggered by the navigation link
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search by name or ID", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
