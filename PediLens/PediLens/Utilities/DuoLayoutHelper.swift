//
//  DuoLayoutHelper.swift
//  PediLens
//
//  Comprehensive layout adaptation helpers for iPhone Duo and foldable/dual-screen devices.
//  Provides seamless ergonomics for both the compact outer Cover Screen (466x678 pt)
//  and the expansive inner Internal Screen (669x951 pt portrait / 951x669 pt landscape).
//

import SwiftUI
import Combine

// MARK: - Display Mode

/// Represents the active screen form factor and posture of iPhone Duo or standard devices
public enum DuoDisplayMode: String, CaseIterable, Sendable {
    /// iPhone Duo outer cover screen (approx. 466 x 678 pt) or compact single-screen mode
    case cover
    /// iPhone Duo inner unfolded screen (approx. 669 x 951 pt portrait / 951 x 669 pt landscape) or expanded tablet canvas
    case internalExpanded
    /// Standard single-screen phone (e.g. iPhone 16/17, approx. 393 x 852 pt)
    case standardPhone
}

// MARK: - Screen Geometry Evaluation

/// Evaluates screen dimensions, size classes, and hinge geometry
public struct DuoScreenGeometry: Equatable {
    public let size: CGSize
    public let isRegularWidth: Bool
    public let isRegularHeight: Bool
    
    public init(size: CGSize, isRegularWidth: Bool, isRegularHeight: Bool) {
        self.size = size
        self.isRegularWidth = isRegularWidth
        self.isRegularHeight = isRegularHeight
    }
    
    public init(size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?, verticalSizeClass: UserInterfaceSizeClass?) {
        self.size = size
        self.isRegularWidth = horizontalSizeClass == .regular
        self.isRegularHeight = verticalSizeClass == .regular
    }
    
    /// Evaluates the active display mode based on exact display metrics
    public var displayMode: DuoDisplayMode {
        let width = size.width
        let height = size.height
        
        // When unfolded:
        // In portrait: width ~ 669 pt, height ~ 951 pt
        // In landscape: width ~ 951 pt, height ~ 669 pt
        // A container or screen is only internalExpanded if its width actually spans >= 550 pt
        if width >= 550 {
            return .internalExpanded
        }
        
        // iPhone Duo Cover Screen:
        // Dimensions: 466 x 678 pt (@3x: 1398 x 2034 px)
        // Shorter vertical height (height <= 750) with wide compact width (420 - 520 pt)
        if (width >= 420 && width <= 520 && height <= 750) || (height <= 720 && width >= 420 && width < 550) {
            return .cover
        }
        
        // Standard iPhone (390-430 pt width, 840-932 pt height) or narrow pane/sheet
        return .standardPhone
    }
    
    /// Whether the device is currently rendering on the iPhone Duo outer cover screen
    public var isCoverScreen: Bool {
        displayMode == .cover
    }
    
    /// Whether the device is currently rendering on the unfolded internal screen
    public var isInternalExpanded: Bool {
        displayMode == .internalExpanded
    }
    
    /// Whether the container has sufficient width to comfortably render side-by-side dual panes (requires >= 600 pt)
    public var canDisplayDualPane: Bool {
        size.width >= 600
    }
    
    /// Whether the current screen orientation is landscape
    public var isLandscape: Bool {
        size.width > size.height
    }
    
    /// Approximate physical hinge / crease rectangle in local coordinates
    /// Used to prevent rendering interactive buttons or typography across the physical fold
    public var hingeCreaseRect: CGRect? {
        guard isInternalExpanded else { return nil }
        let gutterWidth: CGFloat = 20.0
        
        if isLandscape {
            // Horizontal hinge line across middle of height
            let midY = size.height / 2.0
            return CGRect(x: 0, y: midY - (gutterWidth / 2.0), width: size.width, height: gutterWidth)
        } else {
            // Vertical hinge line across middle of width (at ~334.5 pt)
            let midX = size.width / 2.0
            return CGRect(x: midX - (gutterWidth / 2.0), y: 0, width: gutterWidth, height: size.height)
        }
    }
    
    /// Optimal master pane width for dual-pane layouts on internal screen
    public var masterPaneWidth: CGFloat {
        if isLandscape {
            return min(360, size.width * 0.38)
        } else {
            // Split evenly or slightly favored to sidebar in portrait (approx 320 pt)
            return min(330, max(280, size.width * 0.46))
        }
    }
    
    /// Safe asymmetric corner insets for the cover screen
    /// The cover screen has an inner hinge corner (8pt radius) and outer curved corners (59pt radius)
    public var coverCornerPadding: EdgeInsets {
        guard isCoverScreen else {
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
        return EdgeInsets(top: 4, leading: 10, bottom: 8, trailing: 16)
    }
}

// MARK: - Environment Key & Values

private struct DuoScreenGeometryKey: EnvironmentKey {
    static let defaultValue = DuoScreenGeometry(
        size: CGSize(width: 393, height: 852),
        isRegularWidth: false,
        isRegularHeight: true
    )
}

public extension EnvironmentValues {
    var duoGeometry: DuoScreenGeometry {
        get { self[DuoScreenGeometryKey.self] }
        set { self[DuoScreenGeometryKey.self] = newValue }
    }
    
    var duoDisplayMode: DuoDisplayMode {
        duoGeometry.displayMode
    }
}

// MARK: - Geometry Reader Container

/// Container view that monitors the window geometry and injects `duoGeometry` into the SwiftUI environment
public struct DuoAdaptiveContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ViewBuilder public var content: (DuoScreenGeometry) -> Content
    
    public init(@ViewBuilder content: @escaping (DuoScreenGeometry) -> Content) {
        self.content = content
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let geometry = DuoScreenGeometry(
                size: proxy.size,
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: verticalSizeClass
            )
            
            content(geometry)
                .environment(\.duoGeometry, geometry)
        }
    }
}

// MARK: - Duo Master-Detail Split View

/// Adaptive master-detail container that provides single-column stack on cover/standard screens
/// and an ergonomic two-pane split with hinge crease protection on the internal screen
public struct DuoSplitView<Master: View, Detail: View, Placeholder: View>: View {
    @Environment(\.duoGeometry) private var duoGeometry
    
    public let master: Master
    public let detail: Detail?
    public let placeholder: Placeholder
    
    public init(
        @ViewBuilder master: () -> Master,
        @ViewBuilder detail: () -> Detail?,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.master = master()
        self.detail = detail()
        self.placeholder = placeholder()
    }
    
    public var body: some View {
        if duoGeometry.isInternalExpanded {
            // Unfolded internal screen: Dual-pane layout separated along the hinge
            HStack(spacing: 0) {
                // Master / Sidebar pane
                master
                    .frame(width: duoGeometry.masterPaneWidth)
                
                // Hinge crease separator / gutter
                ZStack {
                    Rectangle()
                        .fill(Color(uiColor: .separator).opacity(0.25))
                        .frame(width: 1)
                }
                .frame(width: 16)
                
                // Detail pane or placeholder
                Group {
                    if let detail = detail {
                        detail
                    } else {
                        placeholder
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            // Folded cover screen or standard phone: Single stack navigation
            master
        }
    }
}

// MARK: - View Modifiers

public extension View {
    
    /// Injects Duo geometry tracking to allow adaptive cover vs internal layout
    func enableDuoAdaptiveLayout() -> some View {
        DuoAdaptiveContainer { _ in
            self
        }
    }
    
    /// Applies asymmetric padding tailored to the cover screen's 8pt inner vs 59pt outer corner radii
    @ViewBuilder
    func duoCoverScreenPadding() -> some View {
        modifier(DuoCoverPaddingModifier())
    }
    
    /// Adds gutter spacing away from the central hinge crease on the internal screen
    @ViewBuilder
    func duoHingeCreaseAvoidance() -> some View {
        modifier(DuoHingeAvoidanceModifier())
    }
}

private struct DuoCoverPaddingModifier: ViewModifier {
    @Environment(\.duoGeometry) private var duoGeometry
    
    func body(content: Content) -> some View {
        if duoGeometry.isCoverScreen {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        } else {
            content
        }
    }
}

private struct DuoHingeAvoidanceModifier: ViewModifier {
    @Environment(\.duoGeometry) private var duoGeometry
    
    func body(content: Content) -> some View {
        if duoGeometry.isInternalExpanded && !duoGeometry.isLandscape {
            content
                .padding(.horizontal, 12)
        } else {
            content
        }
    }
}
