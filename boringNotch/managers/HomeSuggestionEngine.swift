//
//  HomeSuggestionEngine.swift
//  boringNotch
//
//  At most one contextual suggestion per app session on Home.
//

import AppKit
import Defaults
import Foundation

struct HomeSuggestion: Identifiable, Equatable {
    enum Action: Equatable {
        case navigate(NotchViews)
        case dismissOnly
    }

    enum Kind: Equatable {
        case meeting, hydration, shelf, revenue
    }

    let id = UUID()
    let kind: Kind
    let icon: String
    let text: String
    let actionTitle: String?
    let action: Action
}

/// Revenue nudges need a real data source; the Revenue page is still a mock.
protocol RevenueSuggestionProvider {
    func suggestion() -> HomeSuggestion?
}

@MainActor
final class HomeSuggestionEngine: ObservableObject {
    static let shared = HomeSuggestionEngine()

    @Published private(set) var current: HomeSuggestion?
    private(set) var shownThisSession = false

    var revenueProvider: RevenueSuggestionProvider?

    private let hydrationInterval: TimeInterval = 90 * 60
    private var sessionStart: Date { NSRunningApplication.current.launchDate ?? Date() }

    private init() {}

    /// Called when Home appears. Picks a suggestion only once per launch.
    func evaluate(events: [EventModel], shelfCount: Int, now: Date = Date()) {
        guard Defaults[.homeSmartSuggestions], !shownThisSession else { return }
        guard let suggestion = meeting(events: events, now: now)
            ?? hydration(now: now)
            ?? shelf(count: shelfCount)
            ?? revenueProvider?.suggestion()
        else { return }

        shownThisSession = true
        if suggestion.kind == .hydration { Defaults[.lastHydrationNudge] = now }
        current = suggestion
    }

    func dismiss() {
        current = nil
    }

    private func meeting(events: [EventModel], now: Date) -> HomeSuggestion? {
        let soon = EventListView.filteredEvents(events: events).first {
            !$0.isAllDay && !$0.type.isReminder && $0.start > now && $0.start.timeIntervalSince(now) <= 10 * 60
        }
        guard let soon else { return nil }
        let minutes = max(1, Int(soon.start.timeIntervalSince(now) / 60))
        return HomeSuggestion(
            kind: .meeting, icon: "calendar.badge.clock",
            text: "\(soon.title) in \(minutes) min",
            actionTitle: "Open", action: .navigate(.calendarHub))
    }

    private func hydration(now: Date) -> HomeSuggestion? {
        let hour = Calendar.current.component(.hour, from: now)
        guard (9..<21).contains(hour) else { return nil }
        let since = max(sessionStart, Defaults[.lastHydrationNudge] ?? .distantPast)
        guard now.timeIntervalSince(since) >= hydrationInterval else { return nil }
        return HomeSuggestion(
            kind: .hydration, icon: "drop.fill",
            text: "Time for some water",
            actionTitle: nil, action: .dismissOnly)
    }

    private func shelf(count: Int) -> HomeSuggestion? {
        guard Defaults[.boringShelf], count >= 3 else { return nil }
        return HomeSuggestion(
            kind: .shelf, icon: "tray.full.fill",
            text: "Shelf has \(count) items",
            actionTitle: "Review", action: .navigate(.shelf))
    }
}
