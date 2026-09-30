//
//  FocusModeManager.swift
//  boringNotch
//
//  Home "Focus" toggle. Always pauses the notch's own interruptions (non-HUD sneak peeks);
//  optionally runs a user Shortcut so system Focus follows. The app is sandboxed, so the
//  Shortcut is launched through the shortcuts:// URL scheme rather than the CLI.
//

import AppKit
import Defaults
import Foundation

@MainActor
final class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()

    @Published private(set) var isEnabled: Bool = Defaults[.homeFocusEnabled]

    private init() {}

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        Defaults[.homeFocusEnabled] = enabled
        runLinkedShortcut(enabled: enabled)
    }

    /// Sneak peeks that are interruptions (track change, battery, downloads). Volume/brightness HUDs stay.
    func shouldSuppress(_ type: SneakContentType) -> Bool {
        guard isEnabled else { return false }
        switch type {
        case .volume, .brightness, .backlight, .mic:
            return false
        case .music, .battery, .download:
            return true
        }
    }

    func runLinkedShortcut(enabled: Bool) {
        let name = Defaults[.focusShortcutName].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: enabled ? "on" : "off"),
        ]
        guard let url = components.url else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration)
    }
}
