//
//  SleepObserver.swift
//  Shut Your Mouth
//
//  Listens for `NSWorkspace.willSleepNotification` / `didWakeNotification`.
//
//  On sleep:  if `PreferencesStore.autoMuteOnSleep` is on AND the mic is
//             currently live, mute every controllable input device and
//             remember that we did so.
//  On wake:   if we auto-muted on the previous sleep (and the preference is
//             still on), unmute back. Manual mutes from before sleep are
//             preserved — we only roll back our own action.
//

import AppKit
import OSLog

@MainActor
final class SleepObserver {
    static let shared = SleepObserver()

    private let log = Logger(subsystem: "com.andrieiev.shutyourmouth", category: "SleepObserver")
    private var willSleepObserver: NSObjectProtocol?
    private var didWakeObserver: NSObjectProtocol?

    /// Tracks whether the latest sleep event triggered an auto-mute from us.
    /// Cleared after the matching wake handler runs.
    private var pendingAutoUnmuteOnWake = false

    private init() {}

    func start() {
        if willSleepObserver == nil {
            willSleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    Self.shared.handleSleep()
                }
            }
        }
        if didWakeObserver == nil {
            didWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    Self.shared.handleWake()
                }
            }
        }
        log.info("SleepObserver started")
    }

    func stop() {
        if let observer = willSleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            willSleepObserver = nil
        }
        if let observer = didWakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            didWakeObserver = nil
        }
    }

    private func handleSleep() {
        guard PreferencesStore.shared.autoMuteOnSleep else {
            log.debug("Sleep observed — autoMuteOnSleep disabled, ignoring")
            return
        }
        let audio = AudioDeviceManager.shared
        // Only auto-mute if the mic is currently live — otherwise we'd have
        // nothing to "roll back" on wake, and we don't want to overwrite a
        // user's explicit manual mute.
        guard !audio.allInputDevicesMuted else {
            log.debug("Sleep observed — already muted, no auto action")
            return
        }
        log.info("Sleep observed — auto-muting all controllable input devices")
        pendingAutoUnmuteOnWake = true
        audio.setMutedAll(true)
    }

    private func handleWake() {
        guard pendingAutoUnmuteOnWake else {
            log.debug("Wake observed — no pending auto-unmute, ignoring")
            return
        }
        pendingAutoUnmuteOnWake = false

        // If the user turned the preference off between sleep and wake,
        // honor that intent — they probably don't want any auto behavior.
        guard PreferencesStore.shared.autoMuteOnSleep else {
            log.info("Wake observed — autoMuteOnSleep disabled between sleep and wake; leaving mute state as-is")
            return
        }
        log.info("Wake observed — restoring mic to pre-sleep state (unmuted)")
        AudioDeviceManager.shared.setMutedAll(false)
    }
}
