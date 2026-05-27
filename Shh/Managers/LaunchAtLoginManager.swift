//
//  LaunchAtLoginManager.swift
//  Shh…
//
//  Thin wrapper around `SMAppService.mainApp` (macOS 13+) — the modern
//  replacement for the deprecated `SMLoginItemSetEnabled`. The source of
//  truth is the system service's `status`; we mirror it into an
//  `@Published isEnabled` so SwiftUI Toggles can bind to it directly.
//

import Foundation
import ServiceManagement
import OSLog
import Combine

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    private let log = Logger(subsystem: "com.andrieiev.shh", category: "LaunchAtLogin")

    /// Whether the app is currently configured to launch at login.
    /// Mutating this calls into `SMAppService` and re-reads the live status.
    @Published var isEnabled: Bool {
        didSet {
            // Avoid re-entering when we're syncing `isEnabled` from a live
            // status read inside `apply(_:)`.
            guard !isApplying else { return }
            apply(isEnabled)
        }
    }

    private var isApplying = false

    private init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Re-read the live status from `SMAppService` (e.g. when the user toggled
    /// the corresponding switch in System Settings → General → Login Items).
    func refresh() {
        let actual = SMAppService.mainApp.status == .enabled
        if actual != isEnabled {
            isApplying = true
            isEnabled = actual
            isApplying = false
        }
    }

    private func apply(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                log.info("Registered for launch-at-login")
            } else {
                try SMAppService.mainApp.unregister()
                log.info("Unregistered from launch-at-login")
            }
        } catch {
            log.error("Launch-at-login change failed: \(error.localizedDescription, privacy: .public)")
        }

        // Pull the live status back so `isEnabled` reflects reality (in case
        // the system rejected our request, e.g. SMAppService.Status.requiresApproval).
        let actual = SMAppService.mainApp.status == .enabled
        if actual != isEnabled {
            isApplying = true
            isEnabled = actual
            isApplying = false
        }
    }
}
