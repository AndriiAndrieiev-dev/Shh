// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  ToggleMode.swift
//  Shh…
//
//  Behavior of the global hotkey: simple toggle or one of two push-to-talk
//  variants. Persisted in PreferencesStore.
//

import Foundation

enum ToggleMode: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Press the hotkey once to flip mute state. The default; matches MuteKey.
    case toggle

    /// "Hold to mute" — default state is unmuted. While the hotkey is held,
    /// the mic is muted; released → unmuted. Useful for streamers who want
    /// to cough or sneeze silently without leaving the meeting muted.
    case pushToTalkHoldToMute

    /// "Hold to talk" — default state is muted. While the hotkey is held,
    /// the mic is live; released → muted. Classic walkie-talkie behavior.
    case pushToTalkHoldToTalk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggle:                 return "Toggle"
        case .pushToTalkHoldToMute:   return "Hold to mute (default on)"
        case .pushToTalkHoldToTalk:   return "Hold to talk (default muted)"
        }
    }

    /// True for the two push-to-talk variants, false for plain toggle.
    var isPushToTalk: Bool {
        self != .toggle
    }

    /// The mute state the mic should rest in when this mode is selected and
    /// the hotkey isn't being held. `nil` for `.toggle` (no inherent resting
    /// state — leave the mic as-is). Applied immediately when the user picks
    /// the mode so push-to-talk starts in the right state.
    var defaultMutedState: Bool? {
        switch self {
        case .toggle:                 return nil
        case .pushToTalkHoldToMute:   return false   // default ON / live
        case .pushToTalkHoldToTalk:   return true    // default muted
        }
    }
}