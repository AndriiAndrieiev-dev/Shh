//
//  PreferencesStore.swift
//  Shut Your Mouth
//
//  Persisted user preferences backed by `UserDefaults`. Lives as a singleton
//  ObservableObject so both AppKit (MenuBarController) and SwiftUI views can
//  observe and react to changes.
//
//  Phase 2 — only the popover tint slider lives here. Phase 6 will grow this
//  to include launch-at-login, HUD options, hotkey binding, mode, etc.
//

import Foundation
import Combine

@MainActor
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    private enum Key {
        static let popoverTintLevel = "popoverTintLevel"
        static let hotkey = "hotkey"
        static let toggleMode = "toggleMode"
        static let showHUD = "showHUD"
        static let hudHoldDuration = "hudHoldDuration"
        static let hudHorizontalAlignment = "hudHorizontalAlignment"
        static let hudVerticalAlignment = "hudVerticalAlignment"
        static let hudSize = "hudSize"
        static let autoMuteOnSleep = "autoMuteOnSleep"
    }

    /// Popover background tint level in [0, 1].
    /// 0 = pure Liquid Glass blur with no darkening overlay (most transparent).
    /// 1 = maximum darkening overlay (least transparent).
    @Published var popoverTintLevel: Double {
        didSet {
            UserDefaults.standard.set(popoverTintLevel, forKey: Key.popoverTintLevel)
        }
    }

    /// Global hotkey binding consumed by `HotkeyManager`.
    @Published var hotkey: HotkeyBinding {
        didSet {
            if let data = try? JSONEncoder().encode(hotkey) {
                UserDefaults.standard.set(data, forKey: Key.hotkey)
            }
        }
    }

    /// Behavior of the hotkey: toggle vs one of the two push-to-talk variants.
    @Published var toggleMode: ToggleMode {
        didSet {
            UserDefaults.standard.set(toggleMode.rawValue, forKey: Key.toggleMode)
        }
    }

    /// Whether the floating HUD overlay is shown on mute state changes.
    @Published var showHUD: Bool {
        didSet {
            UserDefaults.standard.set(showHUD, forKey: Key.showHUD)
        }
    }

    /// How long the HUD overlay stays fully visible before fading out, in seconds.
    @Published var hudHoldDuration: Double {
        didSet {
            UserDefaults.standard.set(hudHoldDuration, forKey: Key.hudHoldDuration)
        }
    }

    /// Horizontal placement of the HUD overlay on the main display.
    @Published var hudHorizontalAlignment: HUDHorizontalAlignment {
        didSet {
            UserDefaults.standard.set(hudHorizontalAlignment.rawValue, forKey: Key.hudHorizontalAlignment)
        }
    }

    /// Vertical placement of the HUD overlay on the main display.
    @Published var hudVerticalAlignment: HUDVerticalAlignment {
        didSet {
            UserDefaults.standard.set(hudVerticalAlignment.rawValue, forKey: Key.hudVerticalAlignment)
        }
    }

    /// HUD size variant (small / medium / large).
    @Published var hudSize: HUDSize {
        didSet {
            UserDefaults.standard.set(hudSize.rawValue, forKey: Key.hudSize)
        }
    }

    /// Mute every controllable input device when the Mac is about to sleep.
    /// On wake we deliberately do NOT auto-unmute — the user stays in control.
    @Published var autoMuteOnSleep: Bool {
        didSet {
            UserDefaults.standard.set(autoMuteOnSleep, forKey: Key.autoMuteOnSleep)
        }
    }

    private init() {
        let storedTint = UserDefaults.standard.object(forKey: Key.popoverTintLevel) as? Double
        // Default to a strongly transparent Liquid-Glass look — users who want
        // a more opaque panel can dial it up via the Preferences slider.
        self.popoverTintLevel = storedTint ?? 0.1

        if let data = UserDefaults.standard.data(forKey: Key.hotkey),
           let decoded = try? JSONDecoder().decode(HotkeyBinding.self, from: data) {
            self.hotkey = decoded
        } else {
            self.hotkey = .defaultF4
        }

        if let raw = UserDefaults.standard.string(forKey: Key.toggleMode),
           let mode = ToggleMode(rawValue: raw) {
            self.toggleMode = mode
        } else {
            self.toggleMode = .toggle
        }

        self.showHUD = UserDefaults.standard.object(forKey: Key.showHUD) as? Bool ?? true
        self.hudHoldDuration = UserDefaults.standard.object(forKey: Key.hudHoldDuration) as? Double ?? 1.5

        if let raw = UserDefaults.standard.string(forKey: Key.hudHorizontalAlignment),
           let value = HUDHorizontalAlignment(rawValue: raw) {
            self.hudHorizontalAlignment = value
        } else {
            self.hudHorizontalAlignment = .center
        }

        if let raw = UserDefaults.standard.string(forKey: Key.hudVerticalAlignment),
           let value = HUDVerticalAlignment(rawValue: raw) {
            self.hudVerticalAlignment = value
        } else {
            self.hudVerticalAlignment = .bottom
        }

        if let raw = UserDefaults.standard.string(forKey: Key.hudSize),
           let value = HUDSize(rawValue: raw) {
            self.hudSize = value
        } else {
            self.hudSize = .medium
        }

        self.autoMuteOnSleep = UserDefaults.standard.object(forKey: Key.autoMuteOnSleep) as? Bool ?? true
    }
}
