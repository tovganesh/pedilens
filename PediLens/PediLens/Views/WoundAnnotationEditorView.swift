//
//  WoundAnnotationEditorView.swift
//  PediLens
//
//  Created by PediLens Team
//  Modal editor for individual wound clinical annotations
//

import SwiftUI

struct WoundAnnotationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var wound: AnnotatedWound
    let onSave: (AnnotatedWound) -> Void
    
    @State private var customLocation: String = ""
    @State private var isCustomLocation: Bool = false
    
    init(wound: AnnotatedWound, onSave: @escaping (AnnotatedWound) -> Void) {
        self._wound = State(initialValue: wound)
        self.onSave = onSave
        let matchesPreset = ClinicalAnnotationPresets.anatomicalLocations.contains(wound.anatomicalLocation)
        self._isCustomLocation = State(initialValue: !matchesPreset && !wound.anatomicalLocation.isEmpty)
        self._customLocation = State(initialValue: matchesPreset ? "" : wound.anatomicalLocation)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Section 1: Identification & Physical Metrics
                Section(header: Text("Wound Identification")) {
                    HStack {
                        Circle()
                            .fill(wound.displayColor)
                            .frame(width: 14, height: 14)
                        TextField("Wound Label", text: $wound.label)
                            .font(.body.weight(.semibold))
                    }
                    
                    // Color Palette Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Marker Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(AnnotatedWound.colorPalette, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: wound.colorHex.caseInsensitiveCompare(hex) == .orderedSame ? 2.5 : 0)
                                    )
                                    .onTapGesture {
                                        wound.colorHex = hex
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 2: Computed Measurements Card
                Section(header: Text("Measured Metrics")) {
                    HStack {
                        Label("Surface Area", systemImage: "square.dashed")
                        Spacer()
                        Text(String(format: "%.2f cm² (%.1f mm²)", wound.areaCM2, wound.areaMM2))
                            .fontWeight(.medium)
                    }
                    HStack {
                        Label("Dimensions (L × W)", systemImage: "arrow.left.and.right")
                        Spacer()
                        Text(String(format: "%.1f × %.1f mm", wound.lengthMM, wound.widthMM))
                            .fontWeight(.medium)
                    }
                    HStack {
                        Label("Perimeter", systemImage: "circle.dashed")
                        Spacer()
                        Text(String(format: "%.1f mm", wound.perimeterMM))
                            .foregroundColor(.secondary)
                    }
                    if wound.depthMM > 0 {
                        HStack {
                            Label("Depth", systemImage: "arrow.down.to.line")
                            Spacer()
                            Text(String(format: "%.1f mm", wound.depthMM))
                        }
                    }
                    if wound.volumeMM3 > 0 {
                        HStack {
                            Label("Volume", systemImage: "cube")
                            Spacer()
                            Text(String(format: "%.1f mm³", wound.volumeMM3))
                        }
                    }
                }
                
                // Section 3: Clinical Staging & Assessment
                Section(header: Text("Clinical Assessment")) {
                    // Anatomical Location
                    Picker("Anatomical Location", selection: $wound.anatomicalLocation) {
                        ForEach(ClinicalAnnotationPresets.anatomicalLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .onChange(of: wound.anatomicalLocation) { newLoc in
                        if newLoc == "Other" {
                            isCustomLocation = true
                        }
                    }
                    
                    if isCustomLocation || wound.anatomicalLocation == "Other" {
                        TextField("Specify anatomical site", text: $customLocation)
                            .onChange(of: customLocation) { val in
                                if !val.isEmpty {
                                    wound.anatomicalLocation = val
                                }
                            }
                    }
                    
                    // Wagner Classification
                    Picker("Wagner Grade", selection: $wound.stageWagner) {
                        ForEach(ClinicalAnnotationPresets.wagnerGrades, id: \.self) { grade in
                            Text(grade).tag(grade)
                        }
                    }
                    
                    // Tissue Type
                    Picker("Wound Bed Tissue", selection: $wound.tissueType) {
                        ForEach(ClinicalAnnotationPresets.tissueTypes, id: \.self) { tissue in
                            Text(tissue).tag(tissue)
                        }
                    }
                    
                    // Exudate
                    Picker("Exudate Level", selection: $wound.exudate) {
                        ForEach(ClinicalAnnotationPresets.exudateLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    
                    // Periwound Condition
                    Picker("Periwound Status", selection: $wound.periwoundCondition) {
                        ForEach(ClinicalAnnotationPresets.periwoundConditions, id: \.self) { peri in
                            Text(peri).tag(peri)
                        }
                    }
                }
                
                // Section 4: Clinical Notes
                Section(header: Text("Clinical Notes / Instructions")) {
                    TextEditor(text: $wound.notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Annotate Wound #\(wound.woundNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if isCustomLocation && !customLocation.trimmingCharacters(in: .whitespaces).isEmpty {
                            wound.anatomicalLocation = customLocation.trimmingCharacters(in: .whitespaces)
                        }
                        onSave(wound)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}
