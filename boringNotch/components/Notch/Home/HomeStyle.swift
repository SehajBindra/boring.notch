//
//  HomeStyle.swift
//  boringNotch
//
//  Shared surfaces and press/hover behaviour for Home tiles and chips.
//

import SwiftUI

struct HomeCardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    @ViewBuilder
    func homeNextUpInnerFrame(minHeight: CGFloat?) -> some View {
        let width = HomeCardMetrics.nextUpContentWidth
        if let minHeight {
            frame(width: width, alignment: .topLeading)
                .frame(minHeight: minHeight, alignment: .topLeading)
        } else {
            frame(width: width, alignment: .topLeading)
        }
    }

    /// Full card width including `homeSurface()` / `protoCard()` padding.
    @ViewBuilder
    func homeNextUpOuterFrame(minHeight: CGFloat?) -> some View {
        let width = HomeCardMetrics.nextUpCardWidth
        if let minHeight {
            frame(width: width, alignment: .topLeading)
                .frame(minHeight: minHeight, alignment: .topLeading)
        } else {
            frame(width: width, alignment: .topLeading)
        }
    }

    /// Reports this view’s height so sibling Home cards can match (e.g. Next Up ↔ Now Playing).
    func reportHomeCardHeight() -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(key: HomeCardHeightKey.self, value: geo.size.height)
            }
        }
    }
}

/// Vertical padding inside `protoCard()` / `homeSurface()` — keep in sync when matching heights.
enum HomeCardMetrics {
    static let surfacePadding: CGFloat = 8
    /// Total visible width of the Next Up tile (matches Now Playing inset from shell edges).
    static let nextUpCardWidth: CGFloat = 150
    static var nextUpContentWidth: CGFloat { nextUpCardWidth - surfacePadding * 2 }
}

/// Subtle Apple-style press: slight scale + dim on a soft spring.
struct HomeTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// Card surface matching `protoCard()`, with a hairline and brighter fill on hover.
struct HomeSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 8
    @State private var hovering = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .background(Color(nsColor: .secondarySystemFill).opacity(hovering ? 0.8 : 0.55), in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(hovering ? 0.1 : 0.04), lineWidth: 0.5))
            .contentShape(shape)
            .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }
}

extension View {
    func homeSurface(cornerRadius: CGFloat = 12, padding: CGFloat = 8) -> some View {
        modifier(HomeSurface(cornerRadius: cornerRadius, padding: padding))
    }
}

/// Capsule chip used in the Home status row.
struct HomeChip<Label: View>: View {
    var active = false
    @ViewBuilder var label: Label
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) { label }
            .font(.geist(10, .medium))
            .foregroundStyle(active ? Color(nsColor: .windowBackgroundColor) : Color.primary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                active ? Color.primary : Color.primary.opacity(hovering ? 0.12 : 0.07),
                in: Capsule())
            .contentShape(Capsule())
            .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
    }
}
