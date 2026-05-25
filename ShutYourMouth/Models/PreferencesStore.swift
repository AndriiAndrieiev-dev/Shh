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
    }
}
