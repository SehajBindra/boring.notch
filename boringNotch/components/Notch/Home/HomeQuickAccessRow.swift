//
//  HomeQuickAccessRow.swift
//  boringNotch
//
//  Four icon-only Quick Access tiles in a single 2×2 card, chosen by QuickAccessStore (pins + recent usage).
//

import SwiftUI

struct HomeQuickAccessRow: View {
    @ObservedObject private var store = QuickAccessStore.shared

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 6), count: 2)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(store.slots.enumerated()), id: \.element) { index, view in
                HomeQuickAccessTile(view: view, slot: index)
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: store.slots)
        .fixedSize()
        .protoCard()
    }
}

private struct HomeQuickAccessTile: View {
    let view: NotchViews
    let slot: Int

    @ObservedObject private var store = QuickAccessStore.shared
    @ObservedObject private var calendarManager = CalendarManager.shared
    @ObservedObject private var shelf = ShelfStateViewModel.shared
    @ObservedObject private var stats = SystemStatsMonitor.shared
    @AppStorage("protoScratchpadText") private var scratchpadText = ""
    @State private var hovering = false

    var body: some View {
        Button {
            BoringViewCoordinator.shared.navigate(to: view)
        } label: {
            Image(systemName: view.protoIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(hovering ? 1 : 0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if store.isPinned(view) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 6, weight: .semibold))
                            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                            .rotationEffect(.degrees(45))
                            .offset(x: -3, y: 3)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hovering = h } }
        }
        .buttonStyle(HomeTileButtonStyle())
        .help(subtitle.map { "\(view.protoTitle) — \($0)" } ?? view.protoTitle)
        .accessibilityLabel(view.protoTitle)
        .accessibilityHint(subtitle ?? "")
        .contextMenu {
            Button(store.isPinned(view) ? "Unpin" : "Pin to Home") {
                store.togglePin(view)
            }
            Menu("Replace With") {
                ForEach(NotchViews.quickAccessCandidates.filter { !store.slots.contains($0) }, id: \.self) { candidate in
                    Button {
                        store.replace(slot: slot, with: candidate)
                    } label: {
                        Label(candidate.protoTitle, systemImage: candidate.protoIcon)
                    }
                }
            }
            Divider()
            Button("Reset Quick Access") { store.reset() }
        }
    }

    private var subtitle: String? {
        switch view {
        case .calendarHub:
            guard let event = ProtoCalendarHelpers.nextHighlightEvent(in: calendarManager.upcomingEvents)
            else { return "Free this week" }
            return ProtoCalendarHelpers.nextUpLine(for: event)
        case .shelf:
            let count = shelf.items.count
            return count == 0 ? "Empty" : "\(count) item\(count == 1 ? "" : "s")"
        case .scratchpad:
            let first = scratchpadText
                .split(whereSeparator: \.isNewline)
                .first
                .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
            return first.isEmpty ? "Empty" : first
        case .stats:
            return "CPU \(Int((stats.cpuUsage * 100).rounded()))%"
        default:
            return nil
        }
    }
}
