//
//  PatientDetailView.swift
//  PediLens
//
//  Patient detail view with wound records and aggregate statistics
//

import SwiftUI
import CoreData

struct PatientDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: PatientDetailViewModel
    @ScaledMetric private var iconSize: CGFloat = 50
    
    init(patient: Patient) {
        _viewModel = StateObject(wrappedValue: PatientDetailViewModel(patient: patient))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Patient Info Card
                patientInfoCard
                
                // Statistics Card
                statisticsCard
                
                // Wound Records Section
                woundRecordsSection
            }
            .padding()
        }
        .navigationTitle(viewModel.patient.name ?? "Patient")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.showingEditPatient = true }) {
                    Text("Edit")
                }
                .accessibilityLabel("Edit patient information")
                .accessibilityHint("Opens form to edit patient details")
                .accessibilityInputLabels(["Edit", "Edit patient", "Modify"])
            }
        }
        .sheet(isPresented: $viewModel.showingEditPatient) {
            EditPatientView(patient: viewModel.patient)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $viewModel.showingAddWound) {
            NewWoundView(patient: viewModel.patient)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            viewModel.loadStatistics()
        }
    }
    
    private var patientInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: iconSize))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.patient.name ?? "Unknown")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Label(viewModel.patient.patientID ?? "No ID", systemImage: "number")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let dateOfBirth = viewModel.patient.dateOfBirth {
                Divider()
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("Born: \(dateOfBirth, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let notes = viewModel.patient.notes, !notes.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(notes)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var statisticsCard: some View {
        VStack(spacing: 16) {
            Text("Wound Statistics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                StatisticView(
                    title: "Total Wounds",
                    value: "\(viewModel.statistics.totalWounds)",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                StatisticView(
                    title: "Active",
                    value: "\(viewModel.statistics.activeWounds)",
                    icon: "exclamationmark.circle.fill",
                    color: .red
                )
                
                StatisticView(
                    title: "Healed",
                    value: "\(viewModel.statistics.healedWounds)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            
            // Healing rate progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Healing Rate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.statistics.healingRate * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(viewModel.statistics.healingRate), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var woundRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wound Records")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { viewModel.showingAddWound = true }) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
                .accessibilityLabel("Add wound record")
                .accessibilityInputLabels(["Add wound", "New wound", "Add record"])
            }
            
            if viewModel.patient.woundRecordsArray.isEmpty {
                emptyWoundRecordsView
            } else {
                ForEach(viewModel.patient.woundRecordsArray, id: \.id) { woundRecord in
                    NavigationLink(destination: TimelineView(woundRecord: woundRecord)) {
                        WoundRecordRowView(woundRecord: woundRecord)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var emptyWoundRecordsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bandage")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No wound records yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: { viewModel.showingAddWound = true }) {
                Text("Add First Wound Record")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .accessibilityInputLabels(["Add wound", "Add first wound", "New wound"])
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .accessibilityHidden(true) // Decorative
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityAddTraits(.isStaticText)
    }
}

struct WoundRecordRowView: View {
    let woundRecord: WoundRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(woundRecord.location ?? "Unknown Location")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text(woundRecord.initialAssessmentDate ?? Date(), style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(woundRecord.sessionCount) session\(woundRecord.sessionCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            Text(woundRecord.status ?? "unknown")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor(for: woundRecord.status ?? "unknown"))
                .cornerRadius(8)
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wound at \(woundRecord.location ?? "Unknown Location"), status: \(woundRecord.status ?? "unknown"), \(woundRecord.sessionCount) session\(woundRecord.sessionCount == 1 ? "" : "s"), started \(woundRecord.initialAssessmentDate ?? Date(), style: .date)")
        .accessibilityHint("Double tap to view wound timeline")
        .accessibilityAction(named: "View Timeline") {
            // This will be triggered by navigation
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active":
            return .red
        case "healing":
            return .orange
        case "healed":
            return .green
        case "archived":
            return .gray
        default:
            return .blue
        }
    }
}

// MARK: - ViewModel

@MainActor
class PatientDetailViewModel: ObservableObject {
    @Published var patient: Patient
    @Published var statistics: PatientStatistics
    @Published var showingEditPatient: Bool = false
    @Published var showingAddWound: Bool = false
    
    private let patientManager: PatientManager
    
    init(patient: Patient, patientManager: PatientManager = .shared) {
        self.patient = patient
        self.patientManager = patientManager
        self.statistics = PatientStatistics(totalWounds: 0, activeWounds: 0, healedWounds: 0, healingRate: 0.0)
    }
    
    func loadStatistics() {
        statistics = patientManager.calculateStatistics(for: patient)
    }
}

// MARK: - Supporting Views

struct AddPatientView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let user: User
    
    @State private var name: String = ""
    @State private var patientID: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var notes: String = ""
    @State private var includeDateOfBirth: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Information")) {
                    TextField("Name", text: $name)
                    TextField("Patient ID", text: $patientID)
                }
                
                Section(header: Text("Optional Information")) {
                    Toggle("Include Date of Birth", isOn: $includeDateOfBirth)
                    
                    if includeDateOfBirth {
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePatient()
                    }
                    .disabled(isLoading || name.isEmpty || patientID.isEmpty)
                }
            }
        }
    }
    
    private func savePatient() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await PatientManager.shared.createPatient(
                    name: name,
                    patientID: patientID,
                    dateOfBirth: includeDateOfBirth ? dateOfBirth : nil,
                    notes: notes.isEmpty ? nil : notes,
                    for: user
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct EditPatientView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let patient: Patient
    
    @State private var name: String
    @State private var patientID: String
    @State private var dateOfBirth: Date
    @State private var notes: String
    @State private var includeDateOfBirth: Bool
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    init(patient: Patient) {
        self.patient = patient
        _name = State(initialValue: patient.name ?? "")
        _patientID = State(initialValue: patient.patientID ?? "")
        _dateOfBirth = State(initialValue: patient.dateOfBirth ?? Date())
        _notes = State(initialValue: patient.notes ?? "")
        _includeDateOfBirth = State(initialValue: patient.dateOfBirth != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient Information")) {
                    TextField("Name", text: $name)
                    TextField("Patient ID", text: $patientID)
                }
                
                Section(header: Text("Optional Information")) {
                    Toggle("Include Date of Birth", isOn: $includeDateOfBirth)
                    
                    if includeDateOfBirth {
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePatient()
                    }
                    .disabled(isLoading || name.isEmpty || patientID.isEmpty)
                }
            }
        }
    }
    
    private func savePatient() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await PatientManager.shared.updatePatient(
                    patient,
                    name: name,
                    patientID: patientID,
                    dateOfBirth: includeDateOfBirth ? dateOfBirth : nil,
                    notes: notes.isEmpty ? nil : notes
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct PatientDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User.create(in: context, role: .doctor)
        let patient = Patient.create(in: context, name: "John Doe", patientID: "P12345", user: user)
        
        return NavigationView {
            PatientDetailView(patient: patient)
                .environment(\.managedObjectContext, context)
        }
    }
}
