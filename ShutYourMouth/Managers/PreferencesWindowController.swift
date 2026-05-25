//
//  PreferencesWindowController.swift
//  Shut Your Mouth
//
//  Owns a single NSWindow that hosts `PreferencesView`. We manage this
//  window manually (instead of relying on SwiftUI's `Settings` scene + the
//  `showSettingsWindow:` selector) because:
//
//    1. Our LSUIElement-only app doesn't have a menu bar, so the standard
//       "Settings…" menu item / Cmd+, action isn't auto-wired.
//    2. The gear button lives inside an NSPanel (the menu bar dropdown),
//       which is a separate window outside the SwiftUI Scene responder
//       chain — `NSApp.sendAction(Selector("showSettingsWindow:"))` from
//       there silently no-ops.
//
//  A regular NSWindow + NSHostingController is the simplest reliable path.
//

import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: PreferencesView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "Shut Your Mouth — Preferences"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.center()
            // Keep the window instance alive across close/reopen cycles so
            // PreferencesView's @ObservedObject state stays consistent.
            win.isReleasedWhenClosed = false
            win.delegate = self
            window = win
        }
        // LSUIElement apps live as `.accessory` which can't bring windows
        // properly to the front. Temporarily promote to `.regular` (gives us
        // a Dock icon + can activate), then drop back to `.accessory` when
        // the user closes Preferences.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
