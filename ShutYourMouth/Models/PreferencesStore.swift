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
    }

    /// Popover background tint level in [0, 1].
    /// 0 = pure Liquid Glass blur with no darkening overlay (most transparent).
    /// 1 = maximum darkening overlay (least transparent).
    @Published var popoverTintLevel: Double {
        didSet {
            UserDefaults.standard.set(popoverTintLevel, forKey: Key.popoverTintLevel)
        }
    }

    private init() {
        let stored = UserDefaults.standard.object(forKey: Key.popoverTintLevel) as? Double
        // Default to a strongly transparent Liquid-Glass look — users who want
        // a more opaque panel can dial it up via the Preferences slider.
        self.popoverTintLevel = stored ?? 0.1
    }
}
