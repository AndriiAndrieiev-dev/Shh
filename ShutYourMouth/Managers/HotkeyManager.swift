//
//  HotkeyManager.swift
//  Shut Your Mouth
//
//  Phase 3a — global keyboard hotkey to toggle mute system-wide.
//
//  Uses CGEventTap at the session level so we can capture the key BEFORE
//  any application sees it (necessary for system-reserved F-row keys like
//  F4/Launchpad on default MacBook keyboards). Requires Accessibility
//  permission — we trigger the native system alert via
//  `AXIsProcessTrustedWithOptions(prompt: true)` on first launch, after
//  which the user has to enable the app under System Settings → Privacy &
//  Security → Accessibility and restart the app.
//
//  Phase 3b will add:
//    - PTT (push-to-talk) keyDown + keyUp handling
//    - Configurable hotkey binding (currently hardcoded F4)
//

import AppKit
import CoreGraphics
import OSLog

final class HotkeyManager: @unchecked Sendable {
    static let shared = HotkeyManager()

    private let log = Logger(subsystem: "com.andrieiev.shutyourmouth", category: "HotkeyManager")

    /// Hardcoded for Phase 3a — F4 (kVK_F4 = 0x76), the same default MuteKey
    /// uses. Will be replaced by `PreferencesStore.hotkey` in Phase 3b.
    private let targetKeyCode: CGKeyCode = 0x76

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Fired on each non-repeat keyDown of the bound hotkey. Wired by
    /// `AppDelegate` to `AudioDeviceManager.toggleMuteAll`.
    @MainActor var onHotkeyToggle: (() -> Void)?

    private init() {}

    // MARK: - Public API

    @MainActor
    func start() {
        guard eventTap == nil else { return }

        // Triggers the native macOS Accessibility consent alert if permission
        // hasn't been granted yet. The app will need to be relaunched after
        // the user enables it in System Settings; we'll detect that on the
        // next launch.
        let trusted = ensureAccessibilityPermission()
        guard trusted else {
            log.warning("Accessibility permission missing — hotkey disabled. User must enable in System Settings → Privacy & Security → Accessibility and relaunch.")
            return
        }

        installEventTap()
    }

    @MainActor
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
    }

    // MARK: - Setup

    @MainActor
    private func installEventTap() {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let selfRaw = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: HotkeyManager.eventTapCallback,
            userInfo: selfRaw
        ) else {
            log.error("CGEvent.tapCreate returned nil — Accessibility permission may have been revoked between check and install")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        log.info("HotkeyManager started — listening for F4 (keyCode \(self.targetKeyCode))")
    }

    @discardableResult
    private func ensureAccessibilityPermission() -> Bool {
        // `kAXTrustedCheckOptionPrompt` is a CFString global the Swift 6
        // concurrency checker refuses to import. The underlying value is the
        // literal string below; hardcoding it avoids needing
        // `nonisolated(unsafe)` wrappers.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Event handling (runs on the CGEventTap's port queue)

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else {
            return Unmanaged.passRetained(event)
        }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
        return manager.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system can disable our tap (timeout or user input flood). Re-arm
        // it so we keep working without requiring an app restart.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { [weak self] in
                if let tap = self?.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == targetKeyCode else {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyToggle?()
                }
            }
        }

        // Suppress the event so default system handlers (Launchpad on F4) don't
        // also fire. This is the whole point of `.headInsertEventTap`.
        return nil
    }
}
