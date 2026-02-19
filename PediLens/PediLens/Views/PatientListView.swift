//
//  PatientListView.swift
//  PediLens
//
//  Patient list view grouped by patient for doctor role
//

import SwiftUI
import CoreData

struct PatientListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    let user: User
    
    @FetchRequest private var patients: FetchedResults<Patient>
    @State private var searchText: String = ""
    @State private var showingAddPatient: Bool = false
    
    init(user: User) {
        self.user = user
        // Create fetch request filtered by user
        _patients = FetchRequest<Patient>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Patient.name, ascending: true)],
            predicate: NSPredicate(format: "user == %@", user),
            animation: .default
        )
    }
    
    var filteredPatients: [Patient] {
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
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .accessibilityLabel("Search patients")
                    .accessibilityHint("Enter patient name or ID to search")
                
                if filteredPatients.isEmpty {
                    emptyStateView
                } else {
                    patientList
                }
            }
            .navigationTitle("Patients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPatient = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new patient")
                    .accessibilityHint("Opens form to add a new patient")
                    .accessibilityInputLabels(["Add patient", "New patient", "Add"])
                }
            }
            .sheet(isPresented: $showingAddPatient) {
                AddPatientView(user: user)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private var patientList: some View {
        List {
            ForEach(filteredPatients, id: \.id) { patient in
                NavigationLink(destination: PatientDetailView(patient: patient)) {
                    PatientRowView(patient: patient)
                }
            }
            .onDelete(perform: deletePatients)
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true) // Decorative
            
            Text(searchText.isEmpty ? "No Patients" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text(searchText.isEmpty ?
                 "Add your first patient to get started" :
                 "No patients match your search")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
            
            if searchText.isEmpty {
                Button(action: { showingAddPatient = true }) {
                    Label("Add Patient", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
                .accessibilityLabel("Add first patient")
                .accessibilityHint("Opens form to add your first patient")
                .accessibilityInputLabels(["Add patient", "Add first patient", "New patient"])
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
    
    private func deletePatients(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let patient = filteredPatients[index]
                do {
                    try await PatientManager.shared.deletePatient(patient)
                } catch {
                    print("Error deleting patient: \(error)")
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(12)
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
                .accessibilityHidden(true) // Decorative
            
            TextField("Search patients...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityLabel("Search field")
                .accessibilityValue(text.isEmpty ? "Empty" : text)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Clears the search text")
                .accessibilityInputLabels(["Clear", "Clear search", "Delete"])
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

struct PatientListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User.create(in: context, role: .doctor)
        
        return PatientListView(user: user)
            .environment(\.managedObjectContext, context)
    }
}
