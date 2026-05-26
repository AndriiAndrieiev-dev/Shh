//
//  AppDelegate.swift
//  Shut Your Mouth
//
//  Owns the AppKit objects that back the menu bar UI and wires the global
//  hotkey into AudioDeviceManager according to the current ToggleMode.
//

import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()

        wireHotkeyCallbacks()
        observePreferencesChanges()
        observeMuteForHUD()

        // Triggers the native Accessibility consent alert on first launch if
        // the permission hasn't been granted yet.
        HotkeyManager.shared.start(binding: PreferencesStore.shared.hotkey)

        // Auto-mute when the Mac is about to sleep (respects autoMuteOnSleep).
        SleepObserver.shared.start()

        // Sync the live launch-at-login status into LaunchAtLoginManager
        // (the user might have toggled it in System Settings while we were
        // not running).
        LaunchAtLoginManager.shared.refresh()

        // Permission statuses re-read on every app-became-active.
        PermissionsManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
        SleepObserver.shared.stop()
    }

    // MARK: - Hotkey ↔ Audio wiring

    /// `onKeyDown` / `onKeyUp` are stable; what changes per mode is the
    /// action they perform on the AudioDeviceManager. Reading the mode at
    /// call time (instead of capturing it) means changing the mode in
    /// Preferences takes effect immediately without re-installing the tap.
    private func wireHotkeyCallbacks() {
        HotkeyManager.shared.onKeyDown = {
            let audio = AudioDeviceManager.shared
            switch PreferencesStore.shared.toggleMode {
            case .toggle:
                audio.toggleMuteActive()
            case .pushToTalkHoldToMute:
                // Default state is unmuted; while held → muted
                audio.setMutedActive(true)
            case .pushToTalkHoldToTalk:
                // Default state is muted; while held → unmuted
                audio.setMutedActive(false)
            }
        }
        HotkeyManager.shared.onKeyUp = {
            let audio = AudioDeviceManager.shared
            switch PreferencesStore.shared.toggleMode {
            case .toggle:
                break
            case .pushToTalkHoldToMute:
                audio.setMutedActive(false)
            case .pushToTalkHoldToTalk:
                audio.setMutedActive(true)
            }
        }
    }

    /// Forward live changes to the hotkey binding into HotkeyManager so the
    /// user doesn't have to relaunch after rebinding it in Preferences.
    private func observePreferencesChanges() {
        PreferencesStore.shared.$hotkey
            .dropFirst() // skip initial value emitted on subscribe
            .sink { binding in
                HotkeyManager.shared.updateBinding(binding)
            }
            .store(in: &cancellables)
    }

    /// Show the floating HUD overlay on every mute state change, regardless
    /// of trigger (hotkey, click-on-icon, popover button). Drops the initial
    /// emission so we don't pop up at app launch. Respects the
    /// `PreferencesStore.showHUD` toggle.
    private func observeMuteForHUD() {
        AudioDeviceManager.shared.$muteStates
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { _ in
                guard PreferencesStore.shared.showHUD else { return }
                let audio = AudioDeviceManager.shared
                HUDController.shared.show(
                    isMuted: audio.isActiveSelectionMuted,
                    scopeLabel: Self.makeScopeLabel(audio: audio)
                )
            }
            .store(in: &cancellables)
    }

    /// Human-readable label describing what the current mute action applies
    /// to: "All Devices", a single device's name, or "N Devices".
    private static func makeScopeLabel(audio: AudioDeviceManager) -> String {
        if PreferencesStore.shared.useAllDevices {
            return "All Devices"
        }
        let active = audio.activeDevices
        switch active.count {
        case 0:  return "No Selection"
        case 1:  return active[0].name
        default: return "\(active.count) Devices"
        }
    }
}
