//
//  AppDelegate.swift
//  Shh…
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
        observeAccessibilityGrant()

        // Triggers the native Accessibility consent alert on first launch if
        // the permission hasn't been granted yet.
        HotkeyManager.shared.start(binding: PreferencesStore.shared.hotkey)

        // Sync the live launch-at-login status into LaunchAtLoginManager
        // (the user might have toggled it in System Settings while we were
        // not running).
        LaunchAtLoginManager.shared.refresh()

        // Permission statuses re-read on every app-became-active.
        PermissionsManager.shared.start()

        // Show the welcome window on first launch (gated by firstLaunchCompleted).
        OnboardingWindowController.shared.showIfNeeded()

        // Persistent floating mic indicator — visible while muted if the
        // user enables the toggle in Preferences.
        PersistentMicIndicatorController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
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

    /// When Accessibility flips to granted (e.g. the user just enabled it in
    /// the onboarding flow or System Settings), (re)install the event tap.
    /// `HotkeyManager.start(binding:)` is idempotent — it no-ops if the tap is
    /// already installed — so this safely covers the "granted after launch"
    /// case without requiring an app restart.
    private func observeAccessibilityGrant() {
        PermissionsManager.shared.$accessibility
            .receive(on: DispatchQueue.main)
            .sink { status in
                if status == .granted {
                    HotkeyManager.shared.start(binding: PreferencesStore.shared.hotkey)
                }
            }
            .store(in: &cancellables)
    }

    /// Show the floating HUD overlay AND/or play a short system sound on
    /// every mute state change, regardless of trigger (hotkey, click-on-icon,
    /// popover button). Both are gated by individual prefs and drop the
    /// initial emission so we don't fire at app launch.
    private func observeMuteForHUD() {
        AudioDeviceManager.shared.$muteStates
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { _ in
                let audio = AudioDeviceManager.shared
                let prefs = PreferencesStore.shared

                if prefs.showHUD {
                    HUDController.shared.show(
                        isMuted: audio.isActiveSelectionMuted,
                        scopeLabel: Self.makeScopeLabel(audio: audio)
                    )
                }

                if prefs.playSoundFeedback {
                    // Two different sounds so the user can tell mute vs unmute
                    // by ear alone — useful when the HUD is hidden or behind a
                    // fullscreen app.
                    let soundName: NSSound.Name = audio.isActiveSelectionMuted ? "Pop" : "Tink"
                    NSSound(named: soundName)?.play()
                }
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
