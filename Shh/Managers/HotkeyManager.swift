//
//  HotkeyManager.swift
//  Shh…
//
//  Global keyboard hotkey via CGEventTap at session level. Reads the binding
//  from PreferencesStore — `HotkeyBinding` (keyCode + modifier mask).
//
//  Fires two callbacks:
//    - `onKeyDown` — fired once per press (auto-repeat filtered out)
//    - `onKeyUp`   — fired on release
//
//  The mode (toggle vs push-to-talk) lives outside this class: AppDelegate
//  wires these callbacks into AudioDeviceManager according to the current
//  `ToggleMode` in PreferencesStore.
//
//  Requires Accessibility permission. We trigger the native consent alert
//  via `AXIsProcessTrustedWithOptions(prompt: true)` on first launch; the
//  user must grant the permission in System Settings and relaunch.
//

import AppKit
import CoreGraphics
import OSLog

final class HotkeyManager: @unchecked Sendable {
    static let shared = HotkeyManager()

    private let log = Logger(subsystem: "com.andrieiev.shh", category: "HotkeyManager")

    /// Current binding. Mutated only on the main thread; read from both main
    /// and the CGEventTap callback thread (the latter without synchronization
    /// — a stale read for one cycle is harmless).
    private var binding: HotkeyBinding = .defaultF4

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Fired on a fresh (non-autorepeat) keyDown of the bound hotkey.
    @MainActor var onKeyDown: (() -> Void)?

    /// Fired on keyUp of the bound hotkey.
    @MainActor var onKeyUp: (() -> Void)?

    private init() {}

    // MARK: - Public API

    @MainActor
    func start(binding: HotkeyBinding) {
        self.binding = binding

        guard eventTap == nil else { return }
        guard ensureAccessibilityPermission() else {
            log.warning("Accessibility permission missing — hotkey disabled. User must enable in System Settings → Privacy & Security → Accessibility and relaunch.")
            return
        }
        installEventTap()
    }

    @MainActor
    func updateBinding(_ binding: HotkeyBinding) {
        self.binding = binding
        log.info("Hotkey rebound to \(binding.displayString, privacy: .public)")
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
        log.info("HotkeyManager started — listening for \(self.binding.displayString, privacy: .public)")
    }

    @discardableResult
    private func ensureAccessibilityPermission() -> Bool {
        // `kAXTrustedCheckOptionPrompt` is a CFString global the Swift 6
        // concurrency checker refuses to import; its underlying value is the
        // literal string below.
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
        // Re-arm tap if the system disabled it (timeout / user-input flood).
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

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let currentModifiers = event.flags.rawValue & HotkeyBinding.modifierMask

        guard keyCode == binding.keyCode && currentModifiers == binding.modifiers else {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !isRepeat {
                DispatchQueue.main.async { [weak self] in
                    self?.onKeyDown?()
                }
            }
        } else if type == .keyUp {
            DispatchQueue.main.async { [weak self] in
                self?.onKeyUp?()
            }
        }

        // Suppress the original event so the system / focused app doesn't
        // also react (e.g. F4 → Launchpad).
        return nil
    }
}
