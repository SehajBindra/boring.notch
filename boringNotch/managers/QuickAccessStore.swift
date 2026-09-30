//
//  QuickAccessStore.swift
//  boringNotch
//
//  Picks the 4 Home Quick Access slots from pins + recency-weighted usage.
//

import Defaults
import Foundation

@MainActor
final class QuickAccessStore: ObservableObject {
    static let shared = QuickAccessStore()

    static let slotCount = 4
    private static let maxEventsPerView = 50
    private static let halfLife: TimeInterval = 7 * 24 * 60 * 60

    /// Snapshot shown on Home. Refreshed on Home appear (not live) so tiles never reshuffle under the cursor.
    @Published private(set) var slots: [NotchViews] = NotchViews.quickAccessDefaults
    @Published private(set) var pinned: [NotchViews] = []

    private init() {
        pinned = Defaults[.quickAccessPinned].compactMap(NotchViews.init(rawValue:))
        refresh()
    }

    func recordOpen(_ view: NotchViews) {
        guard view != .home else { return }
        var usage = Defaults[.quickAccessUsage]
        var events = usage[view.rawValue] ?? []
        events.append(Date().timeIntervalSince1970)
        usage[view.rawValue] = Array(events.suffix(Self.maxEventsPerView))
        Defaults[.quickAccessUsage] = usage
    }

    func score(_ view: NotchViews, now: Date = Date()) -> Double {
        let events = Defaults[.quickAccessUsage][view.rawValue] ?? []
        let t = now.timeIntervalSince1970
        return events.reduce(0) { $0 + pow(0.5, max(0, t - $1) / Self.halfLife) }
    }

    func refresh() {
        let candidates = NotchViews.quickAccessCandidates
        var result: [NotchViews] = pinned.filter { candidates.contains($0) }

        let used = candidates
            .filter { !result.contains($0) }
            .map { ($0, score($0)) }
            .filter { $0.1 > 0.01 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        for view in used where result.count < Self.slotCount { result.append(view) }
        for view in NotchViews.quickAccessDefaults where result.count < Self.slotCount && !result.contains(view) {
            result.append(view)
        }
        slots = Array(result.prefix(Self.slotCount))
    }

    func isPinned(_ view: NotchViews) -> Bool { pinned.contains(view) }

    func togglePin(_ view: NotchViews) {
        if let index = pinned.firstIndex(of: view) {
            pinned.remove(at: index)
        } else {
            pinned.append(view)
            if pinned.count > Self.slotCount { pinned.removeFirst() }
        }
        persistPins()
        refresh()
    }

    /// Replaces the tile at `slot` with `view` and pins it there.
    func replace(slot: Int, with view: NotchViews) {
        guard slots.indices.contains(slot) else { return }
        let old = slots[slot]
        pinned.removeAll { $0 == old || $0 == view }
        // Pin everything left of this slot too so the chosen tile lands where the user put it.
        var ordered = Array(slots.prefix(slot)).filter { $0 != view }
        ordered.append(view)
        for p in pinned where !ordered.contains(p) { ordered.append(p) }
        pinned = Array(ordered.prefix(Self.slotCount))
        persistPins()
        refresh()
    }

    func reset() {
        pinned = []
        Defaults[.quickAccessUsage] = [:]
        persistPins()
        refresh()
    }

    private func persistPins() {
        Defaults[.quickAccessPinned] = pinned.map(\.rawValue)
    }
}
