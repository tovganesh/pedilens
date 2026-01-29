//
//  TimelineView.swift
//  PediLens
//
//  Timeline view displaying capture sessions in reverse chronological order
//

import SwiftUI
import CoreData

struct TimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: TimelineViewModel
    
    init(woundRecord: WoundRecord) {
        _viewModel = StateObject(wrappedValue: TimelineViewModel(woundRecord: woundRecord))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter controls
            if viewModel.showFilters {
                filterControls
                    .padding()
                    .background(Color(.systemGray6))
            }
            
            // Timeline content
            if viewModel.isLoading {
                ProgressView("Loading timeline...")
                    .padding()
            } else if viewModel.filteredSessions.isEmpty {
                emptyStateView
            } else {
                timelineList
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.showFilters.toggle() }) {
                    Image(systemName: viewModel.showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(viewModel.showFilters ? "Hide filters" : "Show filters")
                .accessibilityHint("Toggles filter controls for timeline")
                .accessibilityInputLabels(["Filters", "Toggle filters", viewModel.showFilters ? "Hide filters" : "Show filters"])
            }
        }
        .sheet(item: $viewModel.selectedSession) { session in
            TimelineDetailView(session: session)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            viewModel.loadSessions()
        }
        .onChange(of: viewModel.sortOrder) { _ in
            viewModel.applySorting()
        }
    }
    
    private var filterControls: some View {
        VStack(spacing: 12) {
            // Sort order picker
            HStack {
                Text("Sort By")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Picker("Sort Order", selection: $viewModel.sortOrder) {
                    ForEach(TimelineViewModel.SortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Sort order")
                .accessibilityValue(viewModel.sortOrder.rawValue)
            }
            
            Divider()
            
            // Date range filter
            HStack {
                Text("Date Range")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: { viewModel.clearDateFilter() }) {
                    Text("Clear")
                        .font(.caption)
                }
                .disabled(!viewModel.hasDateFilter)
                .accessibilityLabel("Clear date filter")
                .accessibilityHint("Removes date range filter")
                .accessibilityInputLabels(["Clear", "Clear filter", "Remove filter"])
            }
            
            HStack {
                DatePicker("From", selection: $viewModel.filterStartDate, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("Filter start date")
                
                Text("to")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                DatePicker("To", selection: $viewModel.filterEndDate, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("Filter end date")
            }
            
            // Apply filter button
            Button(action: { viewModel.applyFilters() }) {
                Text("Apply Filters")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Apply date range filter")
            .accessibilityHint("Filters timeline to show only sessions within selected date range")
            .accessibilityInputLabels(["Apply", "Apply filters", "Filter"])
        }
        .accessibilityElement(children: .contain)
    }
    
    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(viewModel.filteredSessions.enumerated()), id: \.element.id) { index, session in
                    let previousSession = index < viewModel.filteredSessions.count - 1 ? viewModel.filteredSessions[index + 1] : nil
                    TimelineEntryView(session: session, previousSession: previousSession)
                        .onTapGesture {
                            viewModel.selectedSession = session
                        }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(viewModel.hasActiveFilters ? "No Sessions Match Filters" : "No Timeline Entries")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(viewModel.hasActiveFilters ?
                 "Try adjusting your filters" :
                 "Capture your first wound photo to start tracking")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if viewModel.hasActiveFilters {
                Button(action: { viewModel.clearAllFilters() }) {
                    Text("Clear All Filters")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
        }
        .padding()
    }
}

// MARK: - Timeline Entry View

struct TimelineEntryView: View {
    let session: CaptureSession
    var previousSession: CaptureSession? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            thumbnailView
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Timestamp
                Text(session.timestamp ?? Date(), style: .date)
                    .font(.headline)
                
                Text(session.timestamp ?? Date(), style: .time)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Key measurements
                if let measurement = session.measurement {
                    measurementInfo(measurement)
                    
                    // Show comparison if previous session exists
                    if let prevSession = previousSession,
                       let prevMeasurement = prevSession.measurement {
                        comparisonIndicator(current: measurement, previous: prevMeasurement)
                    }
                } else {
                    Text("No measurements")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // Location indicator
                if session.locationAvailable {
                    Label("Location recorded", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Notes indicator
                if !session.notesArray.isEmpty {
                    Label("\(session.notesArray.count) note\(session.notesArray.count == 1 ? "" : "s")", systemImage: "note.text")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to view session details")
        .accessibilityAction(named: "View Full Details") {
            // This will be triggered by the tap gesture
        }
        .accessibilityAction(named: "View Photo") {
            // Custom action for viewing photo
        }
    }
    
    private var accessibilityDescription: String {
        var description = "Capture session from \(session.timestamp?.formatted(date: .long, time: .shortened) ?? "unknown date")"
        
        if let measurement = session.measurement {
            description += ", area \(String(format: "%.1f", measurement.areaMM2 / 100)) square centimeters"
            
            if let prevSession = previousSession, let prevMeasurement = prevSession.measurement {
                let areaChange = ((measurement.areaMM2 - prevMeasurement.areaMM2) / prevMeasurement.areaMM2) * 100
                if abs(areaChange) >= 1.0 {
                    description += areaChange > 0 ? ", increased by \(String(format: "%.1f", areaChange)) percent" : ", decreased by \(String(format: "%.1f", abs(areaChange))) percent"
                }
            }
        }
        
        if session.locationAvailable {
            description += ", location recorded"
        }
        
        if !session.notesArray.isEmpty {
            description += ", \(session.notesArray.count) note\(session.notesArray.count == 1 ? "" : "s")"
        }
        
        return description
    }
    
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
            
            Image(systemName: "photo")
                .font(.title)
                .foregroundColor(.secondary)
            
            // Depth data indicator
            if session.hasDepthData {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "cube.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                .frame(width: 80, height: 80)
            }
            
            // Live photo indicator
            if session.hasLivePhoto {
                VStack {
                    HStack {
                        Image(systemName: "livephoto")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.purple)
                            .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: 80, height: 80)
            }
        }
    }
    
    private func measurementInfo(_ measurement: Measurement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                MeasurementBadge(
                    label: "Area",
                    value: String(format: "%.1f", measurement.areaMM2 / 100),
                    unit: "cm²"
                )
                
                MeasurementBadge(
                    label: "Length",
                    value: String(format: "%.1f", measurement.lengthMM / 10),
                    unit: "cm"
                )
            }
            
            if measurement.depthMM > 0 {
                HStack(spacing: 12) {
                    MeasurementBadge(
                        label: "Depth",
                        value: String(format: "%.1f", measurement.depthMM / 10),
                        unit: "cm"
                    )
                    
                    if measurement.volumeMM3 > 0 {
                        MeasurementBadge(
                            label: "Volume",
                            value: String(format: "%.2f", measurement.volumeMM3 / 1000),
                            unit: "cm³"
                        )
                    }
                }
            }
        }
    }
    
    private func comparisonIndicator(current: Measurement, previous: Measurement) -> some View {
        let areaChange = ((current.areaMM2 - previous.areaMM2) / previous.areaMM2) * 100
        let changeColor: Color
        let changeIcon: String
        let changeText: String
        
        if abs(areaChange) < 1.0 {
            // Less than 1% change - considered unchanged
            changeColor = .gray
            changeIcon = "equal.circle.fill"
            changeText = "Unchanged"
        } else if areaChange > 0 {
            // Wound increased - negative indicator
            changeColor = .red
            changeIcon = "arrow.up.circle.fill"
            changeText = String(format: "+%.1f%%", areaChange)
        } else {
            // Wound decreased - positive indicator (healing)
            changeColor = .green
            changeIcon = "arrow.down.circle.fill"
            changeText = String(format: "%.1f%%", areaChange)
        }
        
        return HStack(spacing: 4) {
            Image(systemName: changeIcon)
                .font(.caption)
                .foregroundColor(changeColor)
            
            Text(changeText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(changeColor)
            
            Text("vs previous")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(changeColor.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MeasurementBadge: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Timeline Detail View

struct TimelineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let session: CaptureSession
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo placeholder
                    photoView
                    
                    // Metadata section
                    metadataSection
                    
                    // Measurements section
                    if let measurement = session.measurement {
                        measurementsSection(measurement)
                    }
                    
                    // Notes section
                    if !session.notesArray.isEmpty {
                        notesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Session Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var photoView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 300)
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Photo: \(session.photoPath ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            
            InfoRow(label: "Date", value: session.timestamp?.formatted(date: .long, time: .omitted) ?? "Unknown")
            InfoRow(label: "Time", value: session.timestamp?.formatted(date: .omitted, time: .standard) ?? "Unknown")
            
            if session.locationAvailable, let location = session.location {
                InfoRow(label: "Location", value: String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude))
            }
            
            if session.hasLivePhoto {
                InfoRow(label: "Live Photo", value: "Yes")
            }
            
            if session.hasDepthData {
                InfoRow(label: "Depth Data", value: "Available")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func measurementsSection(_ measurement: Measurement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(.headline)
            
            // Show uncalibrated warning if needed
            if !measurement.hasCalibration {
                UncalibratedMeasurementWarning()
            }
            
            // Metric measurements
            VStack(alignment: .leading, spacing: 8) {
                Text("Metric")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                InfoRow(label: "Area", value: String(format: "%.2f cm²", measurement.areaMM2 / 100))
                InfoRow(label: "Length", value: String(format: "%.1f cm", measurement.lengthMM / 10))
                InfoRow(label: "Width", value: String(format: "%.1f cm", measurement.widthMM / 10))
                InfoRow(label: "Perimeter", value: String(format: "%.1f cm", measurement.perimeterMM / 10))
                
                if measurement.depthMM > 0 {
                    InfoRow(label: "Depth", value: String(format: "%.1f cm", measurement.depthMM / 10))
                }
                
                if measurement.volumeMM3 > 0 {
                    InfoRow(label: "Volume", value: String(format: "%.2f cm³", measurement.volumeMM3 / 1000))
                }
            }
            
            Divider()
            
            // Imperial measurements
            VStack(alignment: .leading, spacing: 8) {
                Text("Imperial")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                InfoRow(label: "Area", value: String(format: "%.2f in²", measurement.areaMM2 / 645.16))
                InfoRow(label: "Length", value: String(format: "%.2f in", measurement.lengthMM / 25.4))
                InfoRow(label: "Width", value: String(format: "%.2f in", measurement.widthMM / 25.4))
                InfoRow(label: "Perimeter", value: String(format: "%.2f in", measurement.perimeterMM / 25.4))
                
                if measurement.depthMM > 0 {
                    InfoRow(label: "Depth", value: String(format: "%.2f in", measurement.depthMM / 25.4))
                }
                
                if measurement.volumeMM3 > 0 {
                    InfoRow(label: "Volume", value: String(format: "%.3f in³", measurement.volumeMM3 / 16387.064))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            
            ForEach(session.notesArray, id: \.id) { note in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let category = note.category, !category.isEmpty {
                            Text(category.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(categoryColor(for: category))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Text(note.createdAt ?? Date(), style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(note.text ?? "")
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "improved":
            return .green
        case "unchanged":
            return .orange
        case "worsened":
            return .red
        default:
            return .blue
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - ViewModel

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var sessions: [CaptureSession] = []
    @Published var filteredSessions: [CaptureSession] = []
    @Published var isLoading: Bool = false
    @Published var showFilters: Bool = false
    @Published var selectedSession: CaptureSession?
    
    // Filter state
    @Published var filterStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var filterEndDate: Date = Date()
    @Published var hasDateFilter: Bool = false
    
    // Sorting state
    @Published var sortOrder: SortOrder = .dateDescending
    
    let woundRecord: WoundRecord
    
    init(woundRecord: WoundRecord) {
        self.woundRecord = woundRecord
    }
    
    var hasActiveFilters: Bool {
        return hasDateFilter
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case areaSizeDescending = "Largest Area"
        case areaSizeAscending = "Smallest Area"
        
        var id: String { rawValue }
    }
    
    func loadSessions() {
        isLoading = true
        
        // Get sessions from wound record (already sorted by timestamp descending)
        sessions = woundRecord.captureSessionsArray
        filteredSessions = sessions
        applySorting()
        
        isLoading = false
    }
    
    func applyFilters() {
        hasDateFilter = true
        
        filteredSessions = sessions.filter { session in
            guard let timestamp = session.timestamp else { return false }
            return timestamp >= filterStartDate && timestamp <= filterEndDate
        }
        
        applySorting()
    }
    
    func applySorting() {
        switch sortOrder {
        case .dateDescending:
            filteredSessions.sort { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
        case .dateAscending:
            filteredSessions.sort { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        case .areaSizeDescending:
            filteredSessions.sort { ($0.measurement?.areaMM2 ?? 0) > ($1.measurement?.areaMM2 ?? 0) }
        case .areaSizeAscending:
            filteredSessions.sort { ($0.measurement?.areaMM2 ?? 0) < ($1.measurement?.areaMM2 ?? 0) }
        }
    }
    
    func clearDateFilter() {
        hasDateFilter = false
        filterStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        filterEndDate = Date()
        filteredSessions = sessions
    }
    
    func clearAllFilters() {
        clearDateFilter()
    }
}

// MARK: - Previews

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let woundRecord = WoundRecord.create(in: context, location: "Left foot")
        
        // Create some sample sessions
        for i in 0..<5 {
            let session = CaptureSession.create(
                in: context,
                photoPath: "photo_\(i).heic",
                woundRecord: woundRecord
            )
            session.timestamp = Calendar.current.date(byAdding: .day, value: -i, to: Date())
        }
        
        return NavigationView {
            TimelineView(woundRecord: woundRecord)
                .environment(\.managedObjectContext, context)
        }
    }
}
