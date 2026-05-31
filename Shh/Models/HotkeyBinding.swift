// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  HotkeyBinding.swift
//  Shh…
//
//  Persisted hotkey binding: a key code plus an optional CGEventFlags mask
//  of modifier keys. Stored in PreferencesStore and consumed by HotkeyManager.
//

import Foundation
import CoreGraphics

struct HotkeyBinding: Codable, Hashable, Sendable {
    /// Hardware-independent virtual key code (kVK_* constants).
    let keyCode: UInt16

    /// Raw mask of modifier flags (subset of `CGEventFlags`).
    /// Only the modifier bits are meaningful — see `modifierMask`.
    let modifiers: UInt64

    /// The bits of `CGEventFlags` we treat as user-controlled modifiers.
    static let modifierMask: UInt64 =
        CGEventFlags.maskCommand.rawValue |
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskAlternate.rawValue

    /// Default hotkey: bare F4 (matches MuteKey).
    static let defaultF4 = HotkeyBinding(keyCode: 0x76, modifiers: 0)

    /// Human-readable representation: "F4", "⌘F4", "⌃⌥M", "Space", etc.
    var displayString: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl)   { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift)     { parts.append("⇧") }
        if flags.contains(.maskCommand)   { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    /// Static lookup of common key codes → display string. Covers letters,
    /// digits, F-keys, arrows, and a handful of named keys. For anything
    /// else we fall back to a `Key{N}` placeholder — good enough for v1;
    /// Phase 6 can swap in `UCKeyTranslate` for full locale awareness.
    private static let keyNames: [UInt16: String] = [
        // Letters
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
        0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
        0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
        0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
        0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y",
        0x06: "Z",
        // Digits
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
        0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        // F-row
        0x7A: "F1",  0x78: "F2",  0x63: "F3",  0x76: "F4",
        0x60: "F5",  0x61: "F6",  0x62: "F7",  0x64: "F8",
        0x65: "F9",  0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15",
        // Named keys
        0x24: "↩", 0x31: "Space", 0x33: "⌫", 0x35: "Esc", 0x30: "⇥",
        0x7E: "↑", 0x7D: "↓", 0x7B: "←", 0x7C: "→",
        0x73: "Home", 0x77: "End", 0x74: "PgUp", 0x79: "PgDn",
        0x27: "'", 0x2A: "\\", 0x29: ";", 0x2B: ",", 0x2F: ".",
        0x2C: "/", 0x32: "`", 0x1B: "-", 0x18: "=",
        0x21: "[", 0x1E: "]",
    ]

    static func keyName(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "Key\(keyCode)"
    }

    /// If this binding collides with a well-known macOS system shortcut,
    /// returns a human label naming the conflict. The list is curated, not
    /// exhaustive — just the most common shortcuts that would surprise users
    /// when their hotkey "stopped working". We don't prevent binding; the user
    /// may have disabled the system shortcut in System Settings, so refusing
    /// to bind would be over-eager.
    var systemConflict: String? {
        let cmd  = CGEventFlags.maskCommand.rawValue
        let opt  = CGEventFlags.maskAlternate.rawValue
        let ctrl = CGEventFlags.maskControl.rawValue
        let shft = CGEventFlags.maskShift.rawValue
        let m = modifiers & Self.modifierMask

        switch (keyCode, m) {
        case (0x31, cmd):              return "Spotlight (⌘Space)"
        case (0x31, cmd | ctrl):       return "Character Viewer (⌃⌘Space)"
        case (0x30, cmd):              return "App Switcher (⌘Tab)"
        case (0x32, cmd):              return "Cycle Window (⌘`)"
        case (0x0C, cmd):              return "Quit App (⌘Q)"
        case (0x0D, cmd):              return "Close Window (⌘W)"
        case (0x04, cmd):              return "Hide App (⌘H)"
        case (0x2E, cmd):              return "Minimize Window (⌘M)"
        case (0x35, cmd | opt):        return "Force Quit (⌘⌥Esc)"
        case (0x7E, ctrl):             return "Mission Control (⌃↑)"
        case (0x7D, ctrl):             return "App Exposé (⌃↓)"
        case (0x14, cmd | shft):       return "Screenshot (⌘⇧3)"
        case (0x15, cmd | shft):       return "Screenshot Area (⌘⇧4)"
        case (0x17, cmd | shft):       return "Screenshot Menu (⌘⇧5)"
        case (0x03, cmd | ctrl):       return "Toggle Fullscreen (⌃⌘F)"
        default:                       return nil
        }
    }
}