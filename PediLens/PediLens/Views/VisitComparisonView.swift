//
//  VisitComparisonView.swift
//  PediLens
//
//  Interactive visit-to-visit visual and numeric wound comparison workstation
//  Supports Opacity Blending, Curtain Split Wipe, Side-by-Side, and Boundary Diff
//

import SwiftUI
import CoreData

struct VisitComparisonView: View {
    let currentSession: CaptureSession
    let currentImage: UIImage
    let currentWounds: [AnnotatedWound]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var comparisonMode: ComparisonMode = .splitCurtain
    @State private var selectedHistoricalSession: CaptureSession?
    @State private var historicalImage: UIImage?
    @State private var historicalWounds: [AnnotatedWound] = []
    @State private var isLoadingHistorical: Bool = false
    
    // Interactive comparison controls
    @State private var blendOpacity: Double = 0.50
    @State private var splitCurtainPosition: CGFloat = 0.50 // 0.0 to 1.0
    @State private var showCurrentBoundaries: Bool = true
    @State private var showHistoricalBoundaries: Bool = true
    
    enum ComparisonMode: String, CaseIterable, Identifiable {
        case splitCurtain = "Split Curtain"
        case opacityBlend = "Blend Slider"
        case sideBySide = "Side-by-Side"
        case boundaryDiff = "Boundary Diff"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .splitCurtain: return "rectangle.split.2x1"
            case .opacityBlend: return "slider.horizontal.below.rectangle"
            case .sideBySide: return "square.split.2x1"
            case .boundaryDiff: return "waveform.path.ecg"
            }
        }
    }
    
    private var historicalSessions: [CaptureSession] {
        guard let record = currentSession.woundRecord else { return [] }
        return record.captureSessionsArray
            .filter { $0.id != currentSession.id }
            .sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top historical session picker and mode selector
                comparisonHeader
                
                // Visual Comparison Canvas
                ZStack {
                    Color.black.opacity(0.92)
                        .edgesIgnoringSafeArea(.all)
                    
                    if isLoadingHistorical {
                        ProgressView("Loading previous visit...")
                            .foregroundColor(.white)
                    } else if let pastImage = historicalImage {
                        visualWorkstation(pastImage: pastImage)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No historical visit selected")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 420)
                
                // Bottom Comparison Metrics & Delta Dashboard
                ScrollView {
                    VStack(spacing: 16) {
                        modeControlBar
                        numericDeltaDashboard
                        perWoundComparisonSection
                        clinicalAssessmentComparisonSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Visit Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                setupInitialHistoricalSession()
            }
        }
    }
    
    // MARK: - Header Controls
    
    private var comparisonHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Compare With:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Previous Visit", selection: $selectedHistoricalSession) {
                    ForEach(historicalSessions, id: \.id) { session in
                        Text(formatSessionDate(session))
                            .tag(Optional(session))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedHistoricalSession) { newSession in
                    if let session = newSession {
                        loadHistoricalSession(session)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Mode Selector
            Picker("Mode", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Visual Workstation
    
    @ViewBuilder
    private func visualWorkstation(pastImage: UIImage) -> some View {
        GeometryReader { geometry in
            switch comparisonMode {
            case .splitCurtain:
                curtainSplitView(pastImage: pastImage, size: geometry.size)
            case .opacityBlend:
                opacityBlendView(pastImage: pastImage, size: geometry.size)
            case .sideBySide:
                sideBySideView(pastImage: pastImage, size: geometry.size)
            case .boundaryDiff:
                boundaryDiffView(pastImage: pastImage, size: geometry.size)
            }
        }
    }
    
    // 1. Curtain Split Wipe
    private func curtainSplitView(pastImage: UIImage, size: CGSize) -> some View {
        ZStack {
            // Right Side: Current Visit Image
            Image(uiImage: currentImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
            
            // Left Side: Historical Image Clipped by split position
            Image(uiImage: pastImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                            .frame(width: max(0, size.width * splitCurtainPosition))
                        Spacer(minLength: 0)
                    }
                )
            
            // Draggable Divider Line & Handle
            let handleX = size.width * splitCurtainPosition
            Rectangle()
                .fill(Color.white)
                .frame(width: 2.5)
                .position(x: handleX, y: size.height / 2)
            
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "chevron.left.chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                )
                .shadow(color: .black.opacity(0.4), radius: 4)
                .position(x: handleX, y: size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newPos = value.location.x / size.width
                            splitCurtainPosition = max(0.05, min(0.95, newPos))
                        }
                )
            
            // Watermark labels
            VStack {
                HStack {
                    Text("Past Visit")
                        .font(.caption2.weight(.bold))
                        .padding(5)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.amberTint)
                        .cornerRadius(4)
                        .padding(8)
                    
                    Spacer()
                    
                    Text("Current Visit")
                        .font(.caption2.weight(.bold))
                        .padding(5)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                        .padding(8)
                }
                Spacer()
            }
        }
    }
    
    // 2. Opacity Blend
    private func opacityBlendView(pastImage: UIImage, size: CGSize) -> some View {
        ZStack {
            Image(uiImage: pastImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
            
            Image(uiImage: currentImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .opacity(blendOpacity)
        }
    }
    
    // 3. Side-by-Side Dual Pane
    private func sideBySideView(pastImage: UIImage, size: CGSize) -> some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                Text("Previous")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Image(uiImage: pastImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 1)
            
            VStack(spacing: 4) {
                Text("Current")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.green)
                Image(uiImage: currentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(8)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
    }
    
    // 4. Boundary Diff Overlay
    private func boundaryDiffView(pastImage: UIImage, size: CGSize) -> some View {
        ZStack {
            Image(uiImage: currentImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
            
            let fitGeometry = AspectFitGeometry(imageSize: currentImage.size, containerSize: size)
            
            Canvas { context, _ in
                // 1. Draw Historical Boundaries (Dashed Amber)
                if showHistoricalBoundaries {
                    for wound in historicalWounds {
                        guard wound.points.count >= 2 else { continue }
                        var pastPath = Path()
                        pastPath.move(to: fitGeometry.imageToView(wound.points[0]))
                        for pt in wound.points.dropFirst() {
                            pastPath.addLine(to: fitGeometry.imageToView(pt))
                        }
                        if wound.points.count > 2 { pastPath.closeSubpath() }
                        context.stroke(
                            pastPath,
                            with: .color(.amberTint),
                            style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                        )
                    }
                }
                
                // 2. Draw Current Boundaries (Solid Emerald)
                if showCurrentBoundaries {
                    for wound in currentWounds {
                        guard wound.points.count >= 2 else { continue }
                        var curPath = Path()
                        curPath.move(to: fitGeometry.imageToView(wound.points[0]))
                        for pt in wound.points.dropFirst() {
                            curPath.addLine(to: fitGeometry.imageToView(pt))
                        }
                        if wound.points.count > 2 { curPath.closeSubpath() }
                        context.stroke(
                            curPath,
                            with: .color(.green),
                            lineWidth: 3.0
                        )
                    }
                }
            }
            
            // Legend
            VStack {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.amberTint)
                            .frame(width: 14, height: 2.5)
                        Text("Past")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 14, height: 2.5)
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
                .padding(8)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Interactive Mode Controls
    
    private var modeControlBar: some View {
        Group {
            if comparisonMode == .opacityBlend {
                VStack(spacing: 6) {
                    HStack {
                        Text("Past Visit (0%)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(blendOpacity * 100))% Current")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text("Current (100%)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $blendOpacity, in: 0.0...1.0)
                        .tint(.accentColor)
                }
                .padding(12)
                .pediLensGlass(cornerRadius: 12)
            } else if comparisonMode == .boundaryDiff {
                HStack(spacing: 16) {
                    Toggle("Past Boundary", isOn: $showHistoricalBoundaries)
                        .font(.subheadline)
                        .tint(.amberTint)
                    Toggle("Current Boundary", isOn: $showCurrentBoundaries)
                        .font(.subheadline)
                        .tint(.green)
                }
                .padding(12)
                .pediLensGlass(cornerRadius: 12)
            }
        }
    }
    
    // MARK: - Numeric Delta Dashboard
    
    private var numericDeltaDashboard: some View {
        let currentTotalAreaMM2 = currentWounds.reduce(0.0) { $0 + $1.areaMM2 }
        let pastTotalAreaMM2 = historicalWounds.reduce(0.0) { $0 + $1.areaMM2 }
        
        let currentAreaCM2 = currentTotalAreaMM2 / 100.0
        let pastAreaCM2 = pastTotalAreaMM2 / 100.0
        
        let deltaCM2 = currentAreaCM2 - pastAreaCM2
        let percentChange = pastAreaCM2 > 0 ? ((currentAreaCM2 - pastAreaCM2) / pastAreaCM2) * 100.0 : 0.0
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wound Burden Comparison", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
                healingStatusBadge(percentChange: percentChange)
            }
            
            Divider().opacity(0.4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricSummaryCard(title: "Previous Area", value: String(format: "%.2f cm²", pastAreaCM2))
                metricSummaryCard(title: "Current Area", value: String(format: "%.2f cm²", currentAreaCM2))
                metricSummaryCard(
                    title: "Area Change",
                    value: String(format: "%@%.2f cm²", deltaCM2 > 0 ? "+" : "", deltaCM2),
                    subvalue: String(format: "%@%.1f%%", percentChange > 0 ? "+" : "", percentChange),
                    highlightColor: deltaCM2 < 0 ? .green : (deltaCM2 > 0 ? .red : .secondary)
                )
            }
            
            // Days elapsed
            if let pastDate = selectedHistoricalSession?.timestamp, let curDate = currentSession.timestamp {
                let days = Calendar.current.dateComponents([.day], from: pastDate, to: curDate).day ?? 0
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("\(days) days between visits (\(pastDate, style: .date) → \(curDate, style: .date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .pediLensGlass(cornerRadius: 14)
    }
    
    // MARK: - Per-Wound Comparison Section
    
    private var perWoundComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Individual Lesions Tracking", systemImage: "circles.hexagonpath")
                .font(.headline)
            
            Divider().opacity(0.4)
            
            if currentWounds.isEmpty {
                Text("No individual wound annotations recorded.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(currentWounds) { curWound in
                    let pastWound = historicalWounds.first(where: { $0.woundNumber == curWound.woundNumber })
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(curWound.displayColor)
                                .frame(width: 10, height: 10)
                            Text(curWound.label)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(curWound.anatomicalLocation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Current: \(String(format: "%.2f cm²", curWound.areaCM2)) (\(String(format: "%.0f×%.0f mm", curWound.lengthMM, curWound.widthMM)))")
                                .font(.caption)
                            
                            Spacer()
                            
                            if let past = pastWound {
                                let dArea = curWound.areaCM2 - past.areaCM2
                                Text(String(format: "%@%.2f cm²", dArea > 0 ? "+" : "", dArea))
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(dArea < 0 ? .green : (dArea > 0 ? .red : .secondary))
                            } else {
                                Text("New Lesion")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .pediLensGlass(cornerRadius: 14)
    }
    
    // MARK: - Clinical Assessment Comparison
    
    private var clinicalAssessmentComparisonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Clinical Staging Evolution", systemImage: "cross.case.fill")
                .font(.headline)
            
            Divider().opacity(0.4)
            
            if let curFirst = currentWounds.first {
                let pastFirst = historicalWounds.first
                
                VStack(spacing: 8) {
                    assessmentRow(
                        title: "Wagner Grade",
                        past: pastFirst?.stageWagner ?? "Not recorded",
                        current: curFirst.stageWagner
                    )
                    assessmentRow(
                        title: "Bed Tissue",
                        past: pastFirst?.tissueType ?? "Not recorded",
                        current: curFirst.tissueType
                    )
                    assessmentRow(
                        title: "Exudate",
                        past: pastFirst?.exudate ?? "Not recorded",
                        current: curFirst.exudate
                    )
                }
            }
        }
        .padding(14)
        .pediLensGlass(cornerRadius: 14)
    }
    
    private func assessmentRow(title: String, past: String, current: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            HStack {
                Text(past)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(current)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(6)
    }
    
    private func healingStatusBadge(percentChange: Double) -> some View {
        Group {
            if percentChange <= -5.0 {
                Label("Healing", systemImage: "arrow.down.right.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            } else if percentChange >= 5.0 {
                Label("Enlarging", systemImage: "arrow.up.right.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Label("Stable", systemImage: "equal.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
    
    private func metricSummaryCard(title: String, value: String, subvalue: String? = nil, highlightColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(highlightColor ?? .primary)
            if let sub = subvalue {
                Text(sub)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(highlightColor ?? .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }
    
    // MARK: - Logic & Loading
    
    private func setupInitialHistoricalSession() {
        if let first = historicalSessions.first {
            selectedHistoricalSession = first
            loadHistoricalSession(first)
        }
    }
    
    private func loadHistoricalSession(_ pastSession: CaptureSession) {
        isLoadingHistorical = true
        historicalImage = nil
        historicalWounds = []
        
        Task {
            // Load Historical Image
            if let photoPath = pastSession.photoPath, let sessionID = pastSession.id {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fullPath = documentsURL
                    .appendingPathComponent("PediLens")
                    .appendingPathComponent("Photos")
                    .appendingPathComponent(sessionID.uuidString)
                    .appendingPathComponent(photoPath)
                    .path
                if let data = try? await FileStorageManager.shared.loadPhoto(at: fullPath),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        self.historicalImage = img
                    }
                }
            }
            
            // Load Historical Wounds from boundaryPoints
            if let measurement = pastSession.measurement,
               let boundaryData = measurement.boundaryPoints {
                if let decoded = MultiWoundPayload.decode(from: boundaryData) {
                    await MainActor.run {
                        self.historicalWounds = decoded
                    }
                }
            }
            
            await MainActor.run {
                self.isLoadingHistorical = false
            }
        }
    }
    
    private func formatSessionDate(_ session: CaptureSession) -> String {
        let dateStr = session.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown"
        if let m = session.measurement {
            let area = m.areaMM2 / 100.0
            return "\(dateStr) (\(String(format: "%.1f cm²", area)))"
        }
        return dateStr
    }
}

extension Color {
    static let amberTint = Color(red: 0.96, green: 0.62, blue: 0.04)
}
