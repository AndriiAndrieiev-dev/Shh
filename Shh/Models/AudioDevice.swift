// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  AudioDevice.swift
//  Shh…
//
//  Phase 2 — Model representing a macOS audio input device discovered via CoreAudio HAL.
//

import Foundation
import CoreAudio

/// A macOS audio input device discovered via CoreAudio HAL.
struct AudioDevice: Identifiable, Hashable, Sendable {
    /// CoreAudio's internal device ID. Can change across reboots / reconnects.
    let id: AudioDeviceID

    /// Persistent UID stable across reboots. Used as the canonical key for settings persistence.
    let uid: String

    /// Human-readable device name (e.g. "MacBook Pro Microphone", "AirPods Pro").
    let name: String

    /// True iff this is currently the system's default input device.
    let isDefaultInput: Bool

    /// True iff the device exposes either a settable mute property or settable
    /// input volume. Non-controllable devices (Continuity mics, virtual routing
    /// devices) are shown in the UI for transparency but excluded from the
    /// toggle and "all muted" logic.
    let isControllable: Bool
}