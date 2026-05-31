// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  MenuBarController.swift
//  Shh…
//
//  Owns the NSStatusItem and a borderless NSPanel used as the menu bar
//  dropdown. We use NSPanel instead of NSPopover because NSPopover's
//  internal layout pass keeps re-anchoring the popover to the status item
//  button bounds — and those bounds shift on macOS Tahoe whenever the system
//  microphone-muted privacy indicator appears or disappears, which makes the
//  popover visibly slide sideways on every mute toggle. NSPanel gives us full
//  control over position, so we cache the origin once and reuse it forever.
//
//  Click behavior on the menu bar icon:
//
//    - Left-click        → instant mute toggle (no panel)
//    - Right-click       → opens / closes the SwiftUI panel
//    - Ctrl + left-click → same as right-click
//
//  This is also the AppKit foundation for Phase 3 (CGEventTap global hotkeys)
//  and Phase 5 (NSPanel-based HUD overlay).
//

import AppKit
import SwiftUI
import Combine
import OSLog

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private let audio: AudioDeviceManager
    private let log = Logger(subsystem: "com.andrieiev.shh", category: "MenuBarController")
    private var cancellables = Set<AnyCancellable>()
    private var panelHost: NSHostingController<MenuBarPopoverView>?

    /// Screen-coordinate origin of the panel captured the first time it is
    /// shown. Reused forever so menu bar reshuffles (system mute indicator
    /// appearing / disappearing) can't shift the panel sideways.
    private var cachedPanelOrigin: NSPoint?

    /// Global mouse-down monitor for "click outside the panel → close" UX,
    /// replicating NSPopover.behavior == .transient.
    private var clickAwayMonitor: Any?

    override init() {
        self.audio = AudioDeviceManager.shared
        // Fixed square length so the menu bar button doesn't change width when
        // the icon switches between mic.fill / mic.slash.fill.
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 440),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configureStatusItem()
        configurePanel()
        observeMuteChanges()
    }

    // MARK: - Configuration

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        updateIcon()
        button.toolTip = "Shh… — click to toggle mute, right-click for menu"
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePanel() {
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSHostingController(rootView: MenuBarPopoverView(audio: audio))
        host.sizingOptions = []
        panel.contentViewController = host
        panelHost = host
    }

    private func observeMuteChanges() {
        // Mirror mute state into the menu bar icon. The panel's SwiftUI view
        // refreshes itself via `.onReceive($muteStates)` + an `.id()` bump.
        //
        // `.receive(on: DispatchQueue.main)` defers the sink to the next
        // runloop tick. Without it, @Published emits the new value during
        // `willSet` — at which point `audio.muteStates` (and computed
        // `allInputDevicesMuted`) still hold the OLD value, producing an
        // "inverted icon" glitch.
        audio.$muteStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.updateIcon()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        // Muted   → red `mic.slash.fill` (palette, isTemplate=false)
        // Unmuted → standard `mic.fill` (template, auto-tinted by menu bar)
        let baseConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        if audio.isActiveSelectionMuted {
            let coloredConfig = baseConfig.applying(
                NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            )
            let image = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(coloredConfig)
            button.image = image
            // isTemplate must be false so the palette color survives the
            // menu bar's automatic tinting.
            button.image?.isTemplate = false
        } else {
            let image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(baseConfig)
            button.image = image
            button.image?.isTemplate = true
        }
    }

    // MARK: - Click handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick =
            event.type == .rightMouseUp ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))

        log.info("handleClick: type=\(String(describing: event.type)) isRightClick=\(isRightClick) currentMuted=\(self.audio.isActiveSelectionMuted)")

        if isRightClick {
            togglePanel(sender)
        } else {
            audio.toggleMuteActive()
            log.info("  after toggle: allMuted=\(self.audio.isActiveSelectionMuted)")
        }
    }

    private func togglePanel(_ sender: NSStatusBarButton) {
        if panel.isVisible {
            hidePanel()
            return
        }
        showPanel(anchoredTo: sender)
    }

    private func showPanel(anchoredTo button: NSStatusBarButton) {
        if cachedPanelOrigin == nil, let buttonWindow = button.window {
            let buttonRectInScreen = buttonWindow.convertToScreen(button.frame)
            let panelSize = panel.frame.size
            // Horizontally center the panel under the button, vertically place
            // it just below the menu bar with a small gap.
            let x = buttonRectInScreen.midX - panelSize.width / 2
            let y = buttonRectInScreen.minY - panelSize.height - 4
            cachedPanelOrigin = NSPoint(x: x, y: y)
        }
        if let origin = cachedPanelOrigin {
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
        installClickAwayMonitor()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        removeClickAwayMonitor()
    }

    private func installClickAwayMonitor() {
        removeClickAwayMonitor()
        // Global monitor fires only for events in OTHER apps — clicks within
        // our own panel or status item don't trigger it. Anything outside us
        // dismisses the panel, replicating .transient NSPopover behavior.
        clickAwayMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func removeClickAwayMonitor() {
        if let monitor = clickAwayMonitor {
            NSEvent.removeMonitor(monitor)
            clickAwayMonitor = nil
        }
    }
}