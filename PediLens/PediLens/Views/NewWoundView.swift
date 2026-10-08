//
//  NewWoundView.swift
//  PediLens
//
//  View for creating a new wound record
//

import SwiftUI
import CoreData

/// View for creating a new wound record
struct NewWoundView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let patient: Patient?
    
    @State private var footSide: FootSide = .left
    @State private var footLocation: FootLocation = .dorsal
    @State private var remarks = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(patient: Patient? = nil) {
        self.patient = patient
    }
    
    enum FootSide: String, CaseIterable {
        case left = "Left"
        case right = "Right"
    }
    
    enum FootLocation: String, CaseIterable {
        case dorsal = "Dorsal"
        case plantar = "Plantar"
    }
    
    private var formattedLocation: String {
        "\(footSide.rawValue) foot, \(footLocation.rawValue.lowercased()) surface"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wound Location")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Foot:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(FootSide.allCases, id: \.self) { side in
                                Button(action: {
                                    footSide = side
                                }) {
                                    Text(side.rawValue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(footSide == side ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(footSide == side ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(FootLocation.allCases, id: \.self) { location in
                                Button(action: {
                                    footLocation = location
                                }) {
                                    Text(location.rawValue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(footLocation == location ? Color.accentColor : Color.gray.opacity(0.2))
                                        .foregroundColor(footLocation == location ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Preview of selected location
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.accentColor)
                        Text(formattedLocation)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Remarks")) {
                    TextEditor(text: $remarks)
                        .frame(height: 100)
                        .accessibilityLabel("Wound remarks")
                }
                
                Section {
                    Text("Initial assessment date: \(Date(), style: .date)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Wound Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createWound()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createWound() {
        let wound = WoundRecord(context: viewContext)
        wound.id = UUID()
        wound.location = formattedLocation
        wound.initialAssessmentDate = Date()
        wound.lastUpdated = Date()
        wound.status = "active"
        
        // Associate with patient if provided (doctor mode)
        if let patient = patient {
            wound.patient = patient
        }
        
        // Store remarks in notes if not empty
        if !remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            wound.notes = remarks.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create wound record: \(error.localizedDescription)"
            showingError = true
        }
    }
}
