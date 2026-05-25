//
//  ToggleMode.swift
//  Shut Your Mouth
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
}
