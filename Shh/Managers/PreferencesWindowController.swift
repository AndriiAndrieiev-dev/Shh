//
//  PreferencesWindowController.swift
//  Shh…
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
            win.title = "Shh… — Preferences"
            // `.resizable` lets the user drag the window taller/shorter — the
            // content Form scrolls, so on short displays it no longer gets
            // stuck under the Dock with no way to reach the bottom rows.
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]

            // Pick an initial height that fits the screen (capped so it never
            // spawns underneath the Dock), then anchor to the top-left.
            if let screen = NSScreen.main {
                let visible = screen.visibleFrame
                let margin: CGFloat = 40
                let width: CGFloat = 540
                let desiredHeight: CGFloat = 900
                let height = min(desiredHeight, visible.height - margin * 2)
                win.setContentSize(NSSize(width: width, height: height))
                win.setFrameTopLeftPoint(NSPoint(
                    x: visible.minX + margin,
                    y: visible.maxY - margin
                ))
            }
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
        // Belt-and-suspenders: `orderFrontRegardless` ignores the app's active
        // state so the window comes to the front even if activation didn't
        // fully take (a quirk we've seen on LSUIElement-only apps).
        window?.orderFrontRegardless()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
