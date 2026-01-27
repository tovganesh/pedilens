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
    @StateObject private var viewModel: PatientListViewModel
    
    init(user: User) {
        _viewModel = StateObject(wrappedValue: PatientListViewModel(user: user))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                
                if viewModel.isLoading {
                    ProgressView("Loading patients...")
                        .padding()
                } else if viewModel.filteredPatients.isEmpty {
                    emptyStateView
                } else {
                    patientList
                }
            }
            .navigationTitle("Patients")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingAddPatient = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddPatient) {
                AddPatientView(user: viewModel.user)
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                viewModel.loadPatients()
            }
        }
    }
    
    private var patientList: some View {
        List {
            ForEach(viewModel.filteredPatients, id: \.id) { patient in
                NavigationLink(destination: PatientDetailView(patient: patient)) {
                    PatientRowView(patient: patient)
                }
            }
            .onDelete(perform: viewModel.deletePatients)
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(viewModel.searchText.isEmpty ? "No Patients" : "No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.searchText.isEmpty ?
                 "Add your first patient to get started" :
                 "No patients match your search")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if viewModel.searchText.isEmpty {
                Button(action: { viewModel.showingAddPatient = true }) {
                    Label("Add Patient", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
        .padding()
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
                }
            }
            
            HStack {
                Label(patient.patientID ?? "No ID", systemImage: "number")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(patient.totalWoundCount) wound\(patient.totalWoundCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search patients...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - ViewModel

@MainActor
class PatientListViewModel: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var showingAddPatient: Bool = false
    
    let user: User
    private let patientManager: PatientManager
    
    init(user: User, patientManager: PatientManager = .shared) {
        self.user = user
        self.patientManager = patientManager
    }
    
    var filteredPatients: [Patient] {
        if searchText.isEmpty {
            return patients
        } else {
            return patients.filter { patient in
                let name = patient.name ?? ""
                let id = patient.patientID ?? ""
                return name.localizedCaseInsensitiveContains(searchText) ||
                       id.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func loadPatients() {
        isLoading = true
        Task {
            do {
                patients = try await patientManager.fetchPatients(for: user)
                isLoading = false
            } catch {
                print("Error loading patients: \(error)")
                isLoading = false
            }
        }
    }
    
    func deletePatients(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let patient = filteredPatients[index]
                do {
                    try await patientManager.deletePatient(patient)
                    loadPatients()
                } catch {
                    print("Error deleting patient: \(error)")
                }
            }
        }
    }
}

struct PatientListView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User.create(in: context, role: .doctor)
        
        return PatientListView(user: user)
            .environment(\.managedObjectContext, context)
    }
}
