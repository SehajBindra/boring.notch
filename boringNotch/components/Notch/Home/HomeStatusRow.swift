//
//  HomeStatusRow.swift
//  boringNotch
//
//  Focus toggle, CPU glance, quick-launch search, plus the once-per-session suggestion.
//

import Defaults
import SwiftUI

struct HomeStatusRow: View {
    @ObservedObject private var focus = FocusModeManager.shared
    @ObservedObject private var stats = SystemStatsMonitor.shared
    @ObservedObject private var suggestions = HomeSuggestionEngine.shared
    @Default(.homeShowCPU) private var showCPU
    var showChips = true

    var body: some View {
        HStack(spacing: 6) {
            if showChips {
                Button {
                    BoringViewCoordinator.shared.pokeNavGrace()
                    withAnimation(.smooth) { focus.toggle() }
                } label: {
                    HomeChip(active: focus.isEnabled) {
                        Image(systemName: focus.isEnabled ? "moon.fill" : "moon")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Focus")
                    }
                }
                .buttonStyle(HomeTileButtonStyle())
                .help(focus.isEnabled ? "Focus on — notch interruptions paused" : "Pause notch interruptions")
                .accessibilityLabel("Focus")
                .accessibilityValue(focus.isEnabled ? "On" : "Off")

                if showCPU {
                    Button {
                        BoringViewCoordinator.shared.navigate(to: .stats)
                    } label: {
                        HomeChip {
                            Image(systemName: "cpu")
                                .font(.system(size: 10, weight: .semibold))
                            Text("\(Int((stats.cpuUsage * 100).rounded()))%")
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    .buttonStyle(HomeTileButtonStyle())
                    .help("CPU usage — open Stats")
                    .accessibilityLabel("CPU \(Int((stats.cpuUsage * 100).rounded())) percent")
                }
            }

            HomeSearchField()

            Spacer(minLength: 8)

            if let suggestion = suggestions.current {
                HomeSuggestionChip(suggestion: suggestion)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.smooth, value: suggestions.current)
        .animation(.smooth, value: stats.cpuUsage)
    }
}

private struct HomeSuggestionChip: View {
    let suggestion: HomeSuggestion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: suggestion.icon)
                .font(.system(size: 10, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(suggestion.text)
                .font(.geist(10, .medium))
                .lineLimit(1)
            if let title = suggestion.actionTitle, case .navigate(let view) = suggestion.action {
                Button {
                    HomeSuggestionEngine.shared.dismiss()
                    BoringViewCoordinator.shared.navigate(to: view)
                } label: {
                    Text(title)
                        .font(.geist(10, .semibold))
                        .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Color.primary, in: Capsule())
                }
                .buttonStyle(HomeTileButtonStyle())
            }
            Button {
                BoringViewCoordinator.shared.pokeNavGrace()
                HomeSuggestionEngine.shared.dismiss()
            } label: {
                Image(systemName: suggestion.action == .dismissOnly ? "checkmark" : "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.gray)
                    .frame(width: 16, height: 16)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(HomeTileButtonStyle())
            .accessibilityLabel(suggestion.action == .dismissOnly ? "Done" : "Dismiss")
        }
        .foregroundStyle(.primary)
        .padding(.leading, 9)
        .padding(.trailing, 4)
        .frame(height: 24)
        .background(Color.primary.opacity(0.07), in: Capsule())
    }
}

// Home quick launcher: searches every feature by title and keywords ("pdf" → Files).
// ↑/↓ move, Return opens, Esc clears. ⌘K / the global launcher shortcut focus it.
struct HomeSearchField: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var focused: Bool

    private var matches: [NotchViews] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        func rank(_ view: NotchViews) -> Int? {
            let title = view.protoTitle.lowercased()
            if title.hasPrefix(q) { return 0 }
            if title.contains(q) { return 1 }
            if view.protoKeywords.contains(where: { $0.hasPrefix(q) }) { return 2 }
            if view.protoKeywords.contains(where: { $0.contains(q) }) { return 3 }
            return nil
        }
        return NotchViews.dockItems
            .compactMap { view in rank(view).map { (view, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    // Every feature is searchable; the list scrolls instead of truncating.
    private var visibleMatches: [NotchViews] { matches }

    // Results open upward from the field; cap the height so they stay clear of the notch.
    private let rowHeight: CGFloat = 25
    private let maxVisibleRows = 4

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.gray)
            TextField("Search", text: $query)
                .textFieldStyle(.plain)
                .font(.geist(11))
                .foregroundStyle(.primary)
                .focused($focused)
                .onSubmit { open(at: highlighted) }
                .onKeyPress(.downArrow) {
                    guard !visibleMatches.isEmpty else { return .ignored }
                    highlighted = min(highlighted + 1, visibleMatches.count - 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard !visibleMatches.isEmpty else { return .ignored }
                    highlighted = max(highlighted - 1, 0)
                    return .handled
                }
                .onKeyPress(.escape) {
                    query = ""
                    focused = false
                    return .handled
                }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            if query.isEmpty || !focused {
                Text("⌘K")
                    .font(.geist(9, .medium))
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: 220)
        .frame(height: 24)
        .background(Color.primary.opacity(focused ? 0.14 : 0.1))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture { focused = true }
        .onChange(of: query) { _, _ in highlighted = 0 }
        .onChange(of: coordinator.focusSearchToken) { _, _ in consumePendingFocus() }
        .onAppear { consumePendingFocus() }
        .overlay(alignment: .bottomLeading) {
            if !visibleMatches.isEmpty {
                ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: visibleMatches.count > maxVisibleRows) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(visibleMatches.enumerated()), id: \.element) { index, m in
                        Button {
                            open(at: index)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: m.protoIcon)
                                    .font(.system(size: 11))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(index == highlighted ? Color.primary : Color.gray)
                                    .frame(width: 16)
                                Text(m.protoTitle)
                                    .font(.geist(11, .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if index == highlighted {
                                    Image(systemName: "return")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.gray)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Color.primary.opacity(index == highlighted ? 0.1 : 0.03),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(height: rowHeight - 1)
                        .id(m)
                        .onHover { if $0 { highlighted = index } }
                    }
                }
                .padding(5)
                }
                .frame(height: CGFloat(min(visibleMatches.count, maxVisibleRows)) * rowHeight + 10 - 1)
                .onChange(of: highlighted) { _, i in
                    guard visibleMatches.indices.contains(i) else { return }
                    proxy.scrollTo(visibleMatches[i])
                }
                }
                .frame(width: 180)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.12))
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                .offset(y: -30)
                .zIndex(10)
            }
        }
    }

    private func consumePendingFocus() {
        guard coordinator.pendingSearchFocus else { return }
        coordinator.pendingSearchFocus = false
        focused = true
    }

    private func open(at index: Int) {
        guard visibleMatches.indices.contains(index) else { return }
        coordinator.navigate(to: visibleMatches[index])
        query = ""
        focused = false
    }
}
