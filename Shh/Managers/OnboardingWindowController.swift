//
//  OnboardingWindowController.swift
//  Shh…
//
//  Owns the first-launch onboarding NSWindow. Shown only when
//  `PreferencesStore.firstLaunchCompleted == false`, dismissed when the
//  user clicks "Get started" (which flips that flag).
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    /// Show the onboarding window only if the user hasn't completed it yet.
    func showIfNeeded() {
        guard !PreferencesStore.shared.firstLaunchCompleted else { return }
        show()
    }

    func show() {
        if window == nil {
            let host = NSHostingController(
                rootView: OnboardingView { [weak self] in
                    self?.complete()
                }
            )
            let win = NSWindow(contentViewController: host)
            win.title = "Shh… — Welcome"
            win.styleMask = [.titled, .closable]
            // Center on the main display.
            win.center()
            win.isReleasedWhenClosed = false
            win.delegate = self
            window = win
        }
        // Same activation dance as PreferencesWindowController — LSUIElement
        // apps can't bring a window to the front from `.accessory` policy.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func complete() {
        PreferencesStore.shared.firstLaunchCompleted = true
        window?.close()
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
