//
//  HomeQuickAccessRow.swift
//  boringNotch
//
//  Four Quick Access tiles, chosen by QuickAccessStore (pins + recent usage).
//

import SwiftUI

struct HomeQuickAccessRow: View {
    @ObservedObject private var store = QuickAccessStore.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(store.slots.enumerated()), id: \.element) { index, view in
                HomeQuickAccessTile(view: view, slot: index)
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: store.slots)
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

    var body: some View {
        Button {
            BoringViewCoordinator.shared.navigate(to: view)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: view.protoIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 26, height: 26)
                    .background(Color.primary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(view.protoTitle)
                        .font(.geist(11, .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.geist(9))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .overlay(alignment: .topTrailing) {
                if store.isPinned(view) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.gray)
                        .rotationEffect(.degrees(45))
                        .offset(x: 2, y: -2)
                }
            }
            .homeSurface(cornerRadius: 12, padding: 9)
        }
        .buttonStyle(HomeTileButtonStyle())
        .help("Open \(view.protoTitle)")
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
            guard let event = EventListView.filteredEvents(events: calendarManager.events)
                .first(where: { !$0.isAllDay && $0.end > Date() })
            else { return "Free today" }
            return event.start.formatted(date: .omitted, time: .shortened)
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
