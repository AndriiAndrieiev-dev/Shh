// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  PermissionsManager.swift
//  Shh…
//
//  Live status of the three macOS permissions the app might want:
//
//    - Accessibility    (required) — needed by CGEventTap for the hotkey
//    - Input Monitoring (required) — needed on macOS for global keyboard
//                                    events to actually reach the tap
//    - Microphone       (optional) — only used by future "mic in use by X"
//                                    detection (Phase 8 / 8+)
//
//  Status is re-read whenever the app becomes active (when the user returns
//  from System Settings after toggling a permission), so the Preferences UI
//  reflects reality without a manual refresh.
//

import Foundation
import AppKit
import AVFoundation
import IOKit.hid
import Combine
import OSLog

enum PermissionStatus: Sendable {
    case notDetermined
    case granted
    case denied
}

enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case accessibility
    case inputMonitoring
    case microphone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accessibility:   return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .microphone:      return "Microphone"
        }
    }

    var explanation: String {
        switch self {
        case .accessibility:
            return "Required to capture the global hotkey via CGEventTap."
        case .inputMonitoring:
            return "Required by macOS so keyboard events reach the hotkey listener."
        case .microphone:
            return "Optional. Reserved for the future \"mic in use by X\" indicator."
        }
    }

    var isRequired: Bool {
        switch self {
        case .accessibility, .inputMonitoring: return true
        case .microphone:                       return false
        }
    }

    /// `x-apple.systempreferences:` deep-link to the matching Privacy pane.
    /// macOS rewrites these as needed across versions; the same URL is the
    /// canonical answer for Sonoma / Sequoia / Tahoe at the time of writing.
    var deepLinkURL: URL {
        let raw: String
        switch self {
        case .accessibility:
            raw = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            raw = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .microphone:
            raw = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        }
        return URL(string: raw)!
    }
}

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    private let log = Logger(subsystem: "com.andrieiev.shh", category: "PermissionsManager")
    private var becomeActiveObserver: NSObjectProtocol?

    @Published private(set) var accessibility: PermissionStatus = .notDetermined
    @Published private(set) var inputMonitoring: PermissionStatus = .notDetermined
    @Published private(set) var microphone: PermissionStatus = .notDetermined

    private init() {
        refresh()
    }

    func start() {
        refresh()
        if becomeActiveObserver == nil {
            becomeActiveObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    PermissionsManager.shared.refresh()
                }
            }
        }
    }

    func refresh() {
        accessibility = checkAccessibility()
        inputMonitoring = checkInputMonitoring()
        microphone = checkMicrophone()
    }

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .accessibility:   return accessibility
        case .inputMonitoring: return inputMonitoring
        case .microphone:      return microphone
        }
    }

    func openSystemSettings(for kind: PermissionKind) {
        NSWorkspace.shared.open(kind.deepLinkURL)
    }

    // MARK: - Status reads

    private func checkAccessibility() -> PermissionStatus {
        // `AXIsProcessTrusted()` returns true once the user has enabled the
        // app under System Settings → Privacy & Security → Accessibility.
        // It can't distinguish "denied" from "not determined" reliably, so
        // we report `.denied` for the unset case — the UX is the same: the
        // user has to enable the toggle.
        return AXIsProcessTrusted() ? .granted : .denied
    }

    private func checkInputMonitoring() -> PermissionStatus {
        let result = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch result {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied:  return .denied
        default:                       return .notDetermined
        }
    }

    private func checkMicrophone() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:           return .granted
        case .denied, .restricted:  return .denied
        case .notDetermined:        return .notDetermined
        @unknown default:           return .notDetermined
        }
    }
}