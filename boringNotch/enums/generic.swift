//
//  generic.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Foundation
import Defaults
import SwiftUI

public enum Style {
    case notch
    case floating
}

public enum ContentType: Int, Codable, Hashable, Equatable {
    case normal
    case menu
    case settings
}

public enum NotchState {
    case closed
    case open
}

public enum NotchViews: String, Codable, CaseIterable {
    case home
    case shelf
    // MARK: - Prototype hub (mock UI only, no backends)
    case revenue
    case analytics
    case scratchpad
    case calendarHub
    case timers
    case stats
    case screentime
    case weather
    case clipboard
    case notes
    case files
    case links
    case emoji
    case sounds
    case message
    case claude
    case units
}

public extension NotchViews {
    // PROTOTYPE: display metadata for quick launcher. No logic.
    var protoTitle: String {
        switch self {
        case .home: return "Home"
        case .shelf: return "Shelf"
        case .revenue: return "Revenue"
        case .analytics: return "Analytics"
        case .scratchpad: return "Scratchpad"
        case .calendarHub: return "Calendar"
        case .timers: return "Timers"
        case .stats: return "Stats"
        case .screentime: return "Screen Time"
        case .weather: return "Weather"
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .files: return "Files"
        case .links: return "Links"
        case .emoji: return "Emoji"
        case .sounds: return "Sounds"
        case .message: return "Message"
        case .claude: return "Claude"
        case .units: return "Units"
        }
    }

    var protoIcon: String {
        switch self {
        case .home: return "house.fill"
        case .shelf: return "tray.fill"
        case .revenue: return "banknote.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .scratchpad: return "square.and.pencil"
        case .calendarHub: return "calendar"
        case .timers: return "timer"
        case .stats: return "cpu.fill"
        case .screentime: return "hourglass"
        case .weather: return "cloud.sun.fill"
        case .clipboard: return "list.clipboard.fill"
        case .notes: return "note.text"
        case .files: return "folder.fill"
        case .links: return "link.circle.fill"
        case .emoji: return "face.smiling.fill"
        case .sounds: return "speaker.wave.2.fill"
        case .message: return "text.bubble.fill"
        case .claude: return "sparkles"
        case .units: return "arrow.left.arrow.right"
        }
    }

    // Apple-style tile tints for a polished launcher look.
    // B&W theme: monochrome tiles (white tile, black glyph).
    var protoTint: Color {
        .white
    }

    // Extra search terms for the quick launcher ("pdf" → Files, "pomodoro" → Timers).
    var protoKeywords: [String] {
        switch self {
        case .home: return ["dashboard", "start"]
        case .shelf: return ["drop", "tray", "airdrop", "share"]
        case .revenue: return ["stripe", "sales", "money", "income"]
        case .analytics: return ["traffic", "visitors", "metrics"]
        case .scratchpad: return ["jot", "draft", "text"]
        case .calendarHub: return ["agenda", "events", "meeting", "schedule", "reminders"]
        case .timers: return ["pomodoro", "countdown", "stopwatch", "hydration", "alarm"]
        case .stats: return ["cpu", "memory", "ram", "system", "activity"]
        case .screentime: return ["usage", "focus", "apps"]
        case .weather: return ["forecast", "temperature", "rain"]
        case .clipboard: return ["copy", "paste", "history"]
        case .notes: return ["memo", "write"]
        case .files: return ["pdf", "documents", "finder", "recent"]
        case .links: return ["bookmarks", "url", "web"]
        case .emoji: return ["symbols", "emoticon"]
        case .sounds: return ["ambient", "noise", "music"]
        case .message: return ["banner", "scroll", "text"]
        case .claude: return ["ai", "tokens", "code"]
        case .units: return ["convert", "currency", "length", "calculator"]
        }
    }

    // Features that can appear in Home's Quick Access row.
    static var quickAccessCandidates: [NotchViews] { launcherItems }

    // First-run Quick Access slots.
    static let quickAccessDefaults: [NotchViews] = [.calendarHub, .timers, .clipboard, .weather]

    static var launcherItems: [NotchViews] {
        [.revenue, .analytics, .scratchpad, .shelf, .calendarHub, .timers,
         .stats, .screentime, .weather, .clipboard, .notes, .files,
         .links, .emoji, .sounds, .message, .claude, .units]
    }

    // Bottom dock order (home first, like the reference dock).
    static var dockItems: [NotchViews] {
        [.home, .revenue, .analytics, .scratchpad, .shelf, .calendarHub, .timers,
         .stats, .screentime, .weather, .clipboard, .notes, .files,
         .links, .emoji, .sounds, .message, .claude, .units]
    }
}

enum SettingsEnum {
    case general
    case about
    case charge
    case download
    case mediaPlayback
    case hud
    case shelf
    case extensions
}

enum DownloadIndicatorStyle: String, Defaults.Serializable {
    case progress = "Progress"
    case percentage = "Percentage"
}

enum DownloadIconStyle: String, Defaults.Serializable {
    case onlyAppIcon = "Only app icon"
    case onlyIcon = "Only download icon"
    case iconAndAppIcon = "Icon and app icon"
}

enum MirrorShapeEnum: String, Defaults.Serializable {
    case rectangle = "Rectangular"
    case circle = "Circular"
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

enum SliderColorEnum: String, CaseIterable, Defaults.Serializable {
    case white = "White"
    case albumArt = "Match album art"
    case accent = "Accent color"
}
