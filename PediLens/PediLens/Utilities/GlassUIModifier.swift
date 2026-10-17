//
//  GlassUIModifier.swift
//  PediLens
//
//  Liquid Glass design system styling and modifiers with medical-grade clarity and contrast.
//

import SwiftUI

// MARK: - Glass Container

/// A container that coordinates Liquid Glass effects and morphing animations across child views.
public struct PediLensGlassContainer<Content: View>: View {
    public var spacing: CGFloat
    @ViewBuilder public var content: () -> Content
    
    public init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - View Extensions for Glass UI

public extension View {
    
    /// Applies a clean, medical-grade Liquid Glass effect with a rounded rectangle shape.
    ///
    /// Preserves high contrast and legibility by using neutral frosted glass with optional subtle accent borders.
    ///
    /// - Parameters:
    ///   - cornerRadius: The corner radius of the glass shape.
    ///   - tint: Optional accent tint color (applied subtly to border and wash).
    ///   - interactive: Whether the glass reacts fluidly to touch and pointer interactions.
    @ViewBuilder
    func pediLensGlass(
        cornerRadius: CGFloat = 16,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            let baseGlass = Glass.regular
            let finalGlass = interactive ? baseGlass.interactive() : baseGlass
            self.glassEffect(finalGlass, in: .rect(cornerRadius: cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tint != nil ? tint!.opacity(0.06) : Color(uiColor: .secondarySystemBackground).opacity(0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(tint != nil ? tint!.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
                )
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tint != nil ? tint!.opacity(0.06) : Color(uiColor: .secondarySystemBackground).opacity(0.85))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        tint != nil ? tint!.opacity(0.3) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
    }
    
    /// Applies a Liquid Glass effect with a capsule shape (ideal for badges, status indicators, and pill buttons).
    ///
    /// - Parameters:
    ///   - tint: Optional tint color for semantic status.
    ///   - interactive: Whether the glass responds to touch interactions.
    @ViewBuilder
    func pediLensGlassPill(
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            let baseGlass = Glass.regular
            let finalGlass = interactive ? baseGlass.interactive() : baseGlass
            self.glassEffect(finalGlass, in: Capsule())
                .background(
                    Capsule()
                        .fill(tint != nil ? tint!.opacity(0.12) : Color.primary.opacity(0.04))
                )
                .overlay(
                    Capsule()
                        .stroke(tint != nil ? tint!.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
                )
        } else {
            self.background(
                Capsule()
                    .fill(tint != nil ? tint!.opacity(0.12) : Color.primary.opacity(0.05))
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(tint != nil ? tint!.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    /// Applies Apple Liquid Glass button styling when available, or a bordered prominence fallback.
    ///
    /// - Parameter prominent: When true, applies the prominent glass style for primary CTAs.
    @ViewBuilder
    func pediLensGlassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
    
    /// Associates a persistent glass identity for morphing shapes across transitions in iOS 26.0+.
    @ViewBuilder
    func pediLensGlassID<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace)
        }
    }
}
