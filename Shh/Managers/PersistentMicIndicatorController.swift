//
//  PersistentMicIndicatorController.swift
//  Shh…
//
//  Owns a small floating NSPanel — a persistent "mic muted" badge that
//  stays in the chosen corner of the main display while any device in the
//  active selection is muted. Visible over fullscreen apps and across
//  Spaces. Hides itself the moment the mic comes back live.
//
//  Distinct from `HUDController`, which appears briefly on every mute change
//  and fades out. This one is "always-on while muted".
//

import AppKit
import SwiftUI
import Combine
import OSLog

@MainActor
final class PersistentMicIndicatorController {
    static let shared = PersistentMicIndicatorController()

    private let log = Logger(subsystem: "com.andrieiev.shh", category: "PersistentIndicator")
    private let panel: NSPanel
    private let host: NSHostingController<PersistentMicIndicatorView>
    private var cancellables = Set<AnyCancellable>()

    private static let size = NSSize(width: 44, height: 44)

    private init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0

        host = NSHostingController(rootView: PersistentMicIndicatorView())
        host.sizingOptions = []
        panel.contentViewController = host
    }

    /// Wire up observers so visibility reacts to mute changes, the user
    /// toggling the indicator preference, and the corner picker.
    func start() {
        AudioDeviceManager.shared.$muteStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)

        PreferencesStore.shared.$showPersistentIndicator
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateVisibility()
            }
            .store(in: &cancellables)

        PreferencesStore.shared.$persistentIndicatorCorner
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.positionPanel()
            }
            .store(in: &cancellables)

        // Initial check in case we start up while already muted.
        updateVisibility()
    }

    // MARK: - Visibility

    private func updateVisibility() {
        let prefs = PreferencesStore.shared
        let audio = AudioDeviceManager.shared
        let shouldShow = prefs.showPersistentIndicator && audio.isActiveSelectionMuted

        if shouldShow {
            positionPanel()
            if !panel.isVisible {
                panel.alphaValue = 0
                panel.orderFrontRegardless()
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().alphaValue = 1.0
            }
        } else if panel.isVisible {
            NSAnimationContext.runAnimationGroup { [weak self] context in
                guard let self else { return }
                context.duration = 0.25
                self.panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                guard let self else { return }
                if self.panel.alphaValue <= 0.01 {
                    self.panel.orderOut(nil)
                }
            }
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = Self.size
        let margin: CGFloat = 8

        let origin: NSPoint
        switch PreferencesStore.shared.persistentIndicatorCorner {
        case .topLeft:
            origin = NSPoint(x: visible.minX + margin,
                             y: visible.maxY - size.height - margin)
        case .topRight:
            origin = NSPoint(x: visible.maxX - size.width - margin,
                             y: visible.maxY - size.height - margin)
        case .bottomLeft:
            origin = NSPoint(x: visible.minX + margin,
                             y: visible.minY + margin)
        case .bottomRight:
            origin = NSPoint(x: visible.maxX - size.width - margin,
                             y: visible.minY + margin)
        }
        panel.setFrameOrigin(origin)
    }
}
