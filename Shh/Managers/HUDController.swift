//
//  HUDController.swift
//  Shh…
//
//  Owns the floating HUD NSPanel. Shows on every mute state change (toggle,
//  hotkey press, PTT down/up, click-on-icon, Mute/Unmute button in popover):
//
//    fade in 200ms → hold (configurable, default 1.5s) → fade out 400ms
//
//  Re-triggering during the hold or fade-out resets the timer so a burst of
//  toggles ends with a single dismiss animation.
//
//  Position is independent horizontal × vertical, size is one of three
//  presets — all live-configurable via Preferences.
//
//  NSPanel properties:
//    - `.statusBar` level → above normal app windows
//    - canJoinAllSpaces + fullScreenAuxiliary → visible over fullscreen apps
//    - nonactivatingPanel + ignoresMouseEvents → never steals focus or clicks
//

import AppKit
import SwiftUI

@MainActor
final class HUDController {
    static let shared = HUDController()

    private let panel: NSPanel
    private let host: NSHostingController<HUDView>
    private var hideTask: Task<Void, Never>?

    /// When true, the HUD is held open indefinitely (push-to-talk "keep HUD
    /// while live" mode) and timed `show(...)` calls are ignored so they don't
    /// fade it out.
    private var isSticky = false

    private static let fadeInDuration: TimeInterval = 0.2
    private static let fadeOutDuration: TimeInterval = 0.4

    private init() {
        let initialSize = NSSize(width: HUDSize.medium.dimension, height: HUDSize.medium.dimension)
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // SwiftUI .background draws its own; NSPanel shadow on a transparent window leaves a rectangular halo.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0

        host = NSHostingController(
            rootView: HUDView(isMuted: false, scopeLabel: "", sizeVariant: .medium)
        )
        host.sizingOptions = []
        panel.contentViewController = host
    }

    /// Show the HUD with the given state. Resets any pending fade-out so a
    /// rapid sequence of toggles collapses into a single dismissal at the
    /// end of the last one.
    func show(isMuted: Bool, scopeLabel: String) {
        // A sticky HUD owns the panel; don't let a timed flash fade it away.
        guard !isSticky else { return }

        let prefs = PreferencesStore.shared
        let sizeVariant = prefs.hudSize
        let dim = sizeVariant.dimension
        let panelSize = NSSize(width: dim, height: dim)

        host.rootView = HUDView(isMuted: isMuted, scopeLabel: scopeLabel, sizeVariant: sizeVariant)
        panel.setContentSize(panelSize)
        positionPanel(size: panelSize)

        hideTask?.cancel()
        hideTask = nil

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1.0
        }

        let hold = prefs.hudHoldDuration
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(hold * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.fadeOut()
        }
    }

    /// Show the HUD and keep it visible indefinitely (no auto fade-out).
    /// Used for the push-to-talk "keep HUD while live" mode.
    func showSticky(isMuted: Bool, scopeLabel: String) {
        isSticky = true
        hideTask?.cancel()
        hideTask = nil

        let prefs = PreferencesStore.shared
        let sizeVariant = prefs.hudSize
        let dim = sizeVariant.dimension
        let panelSize = NSSize(width: dim, height: dim)

        host.rootView = HUDView(isMuted: isMuted, scopeLabel: scopeLabel, sizeVariant: sizeVariant)
        panel.setContentSize(panelSize)
        positionPanel(size: panelSize)

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1.0
        }
    }

    /// Release a sticky HUD and fade it out.
    func hideSticky() {
        guard isSticky else { return }
        isSticky = false
        fadeOut()
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            guard let self else { return }
            context.duration = Self.fadeOutDuration
            self.panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            // Only hide if alpha is actually zero — another `show()` may have
            // raced in during the fade-out and bumped us back up.
            if self.panel.alphaValue <= 0.01 {
                self.panel.orderOut(nil)
            }
        }
    }

    private func positionPanel(size: NSSize) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 80  // distance from any chosen edge of the visible area

        let prefs = PreferencesStore.shared

        let x: CGFloat
        switch prefs.hudHorizontalAlignment {
        case .left:   x = visible.minX + margin
        case .center: x = visible.midX - size.width / 2
        case .right:  x = visible.maxX - size.width - margin
        }

        let y: CGFloat
        switch prefs.hudVerticalAlignment {
        case .top:    y = visible.maxY - size.height - margin
        case .center: y = visible.midY - size.height / 2
        case .bottom: y = visible.minY + margin
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
