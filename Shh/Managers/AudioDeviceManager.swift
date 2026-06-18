// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  AudioDeviceManager.swift
//  Shh…
//
//  Phase 2 — CoreAudio HAL wrapper.
//
//  - Enumerates input devices via kAudioHardwarePropertyDevices + stream-config filter
//  - Reads/writes per-device mute via kAudioDevicePropertyMute on input scope
//  - Falls back to volume=0 (with restore) when a device doesn't expose mute
//

import Foundation
import CoreAudio
import OSLog
import Combine

@MainActor
final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()

    // MARK: - Observable state

    @Published private(set) var inputDevices: [AudioDevice] = []

    /// Current mute state keyed by device UID.
    @Published private(set) var muteStates: [String: Bool] = [:]

    // MARK: - Internal

    private let log = Logger(subsystem: "com.andrieiev.shh", category: "AudioDeviceManager")

    /// Saved per-device pre-mute volumes (for devices that need the volume=0 fallback).
    private var savedVolumes: [String: Float32] = [:]

    /// Retained CoreAudio listener block for hot-plug detection. Stored so it
    /// can be removed cleanly (and so ARC doesn't drop it while the system
    /// holds a weak reference).
    private var deviceListListener: AudioObjectPropertyListenerBlock?

    /// Per-device mute-property listeners, keyed by AudioDeviceID. Detect when
    /// another app (e.g. Microsoft Teams on call start/end) changes a device's
    /// mute behind our back, so we can re-enforce the user's intent.
    private var muteListeners: [AudioDeviceID: AudioObjectPropertyListenerBlock] = [:]

    /// Guards against reacting to our own mute writes (which also fire the
    /// listener). Set while `applyMute` runs.
    private var isApplyingMute = false

    private init() {
        refresh()
        installDeviceListChangeListener()
    }

    // MARK: - Public API

    /// Devices currently subject to mute actions after applying the user
    /// selection from PreferencesStore (useAllDevices vs selectedDeviceUIDs).
    /// Non-controllable devices (Continuity mics, virtual routing devices)
    /// are filtered out — they can be shown in the UI for transparency but
    /// can't actually be muted.
    var activeDevices: [AudioDevice] {
        let prefs = PreferencesStore.shared
        let controllable = inputDevices.filter(\.isControllable)
        if prefs.useAllDevices {
            return controllable
        }
        return controllable.filter { prefs.selectedDeviceUIDs.contains($0.uid) }
    }

    /// True iff every active-selection device is currently muted. Returns
    /// `false` when the selection is empty so the icon falls back to the
    /// "on" state (visually that's an empty/disabled selection).
    var isActiveSelectionMuted: Bool {
        let active = activeDevices
        guard !active.isEmpty else { return false }
        return active.allSatisfy { muteStates[$0.uid] == true }
    }

    /// Re-enumerate input devices (hot-plug). Preserves intent-based mute state
    /// for already-known devices.
    ///
    /// For *newly-seen* devices: if the current aggregate selection is muted,
    /// the new device inherits that muted state (we actively mute it) rather
    /// than picking up its hardware-default unmuted state. Rationale: if the
    /// user has Shh… set to muted and then plugs in headphones, the headset
    /// mic should also start muted — otherwise the aggregate flips to "live"
    /// and the user surprise-unmutes everything just by connecting a device.
    func refresh() {
        let wasAggregateMuted = isActiveSelectionMuted
        let newDevices = enumerateInputDevices()
        var states = muteStates
        var newlyAddedControllable: [AudioDevice] = []

        for device in newDevices where states[device.uid] == nil {
            if device.isControllable && wasAggregateMuted {
                // Inherit the muted aggregate — defer the actual write until
                // after we've updated `inputDevices` so `activeDevices`
                // resolves the new device into scope.
                states[device.uid] = true
                newlyAddedControllable.append(device)
            } else {
                // Default: read hardware state (an unmuted headset just
                // plugged in stays unmuted, matching reality).
                states[device.uid] = readMuteState(device: device)
            }
        }

        // Drop entries for devices that disappeared (unplugged).
        let presentUIDs = Set(newDevices.map(\.uid))
        states = states.filter { presentUIDs.contains($0.key) }

        inputDevices = newDevices
        muteStates = states

        // Now actually apply the inherited mute state to the new hardware.
        for device in newlyAddedControllable {
            applyMute(true, to: device)
        }

        // (Re)install per-device mute listeners for the current device set so
        // we notice external mute changes (e.g. Teams unmuting on call start).
        installMuteListeners(for: newDevices)

        log.debug("Refresh → \(self.inputDevices.count) input devices; \(newlyAddedControllable.count) inherited muted state")
    }


    /// Mute or unmute every device in the active selection.
    ///
    /// State is updated based on *intent* rather than a CoreAudio read-back.
    /// Some virtual devices (notably Microsoft Teams Audio) acknowledge the
    /// mute write via `AudioObjectSetPropertyData` but immediately reset the
    /// underlying state via their driver, so a subsequent read would falsely
    /// say the device isn't muted — breaking the toggle. Trusting our own
    /// write keeps the UI consistent with the user's last action; an explicit
    /// `refresh()` re-syncs from CoreAudio when the user wants ground truth.
    func setMutedActive(_ muted: Bool) {
        var states = muteStates
        for device in activeDevices {
            applyMute(muted, to: device)
            states[device.uid] = muted
        }
        muteStates = states
    }

    /// Toggle mute on the active-selection devices based on aggregate state.
    func toggleMuteActive() {
        setMutedActive(!isActiveSelectionMuted)
    }

    // MARK: - Hot-plug listener

    /// Subscribe to changes in the system-wide audio device list. Fires when
    /// any device (USB mic, AirPods, Continuity mic, virtual loopback) is
    /// plugged in or out. We just re-`refresh()` — the refresh method already
    /// preserves intent-based mute state for existing devices and reads
    /// initial state for any newly-seen ones.
    private func installDeviceListChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let listener: AudioObjectPropertyListenerBlock = { _, _ in
            // Listener fires on the dispatch queue we pass below; hop to
            // MainActor explicitly to satisfy strict concurrency.
            Task { @MainActor in
                AudioDeviceManager.shared.refresh()
            }
        }
        deviceListListener = listener

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            listener
        )
        if status != noErr {
            log.error("Failed to install device-list change listener: status=\(status)")
            deviceListListener = nil
        } else {
            log.info("Device-list hot-plug listener installed")
        }
    }

    // MARK: - Per-device mute listeners (external-change enforcement)

    /// Install a `kAudioDevicePropertyMute` (input scope) listener on each
    /// controllable device, removing any stale ones first. Fires when another
    /// process changes the device's mute state.
    private func installMuteListeners(for devices: [AudioDevice]) {
        removeAllMuteListeners()
        for device in devices where device.isControllable {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            guard AudioObjectHasProperty(device.id, &address) else { continue }

            let deviceID = device.id
            let listener: AudioObjectPropertyListenerBlock = { _, _ in
                Task { @MainActor in
                    AudioDeviceManager.shared.handleExternalMuteChange(deviceID: deviceID)
                }
            }
            let status = AudioObjectAddPropertyListenerBlock(
                device.id, &address, DispatchQueue.main, listener
            )
            if status == noErr {
                muteListeners[device.id] = listener
            } else {
                log.error("Failed to add mute listener for device \(device.id): \(status)")
            }
        }
    }

    private func removeAllMuteListeners() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        for (deviceID, listener) in muteListeners {
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
        }
        muteListeners.removeAll()
    }

    /// React to an external mute change on a device.
    ///
    /// Enforcement policy: while Shh's intent for a device is *muted*, any
    /// external attempt to unmute it (e.g. Microsoft Teams unmuting the mic
    /// when a call starts) is rolled back — the device is re-muted. This keeps
    /// "I muted it, so it stays muted" true until the user unmutes via Shh.
    /// When our intent is *unmuted*, we simply sync our state to reality so the
    /// UI never lies.
    private func handleExternalMuteChange(deviceID: AudioDeviceID) {
        // Ignore the listener firing as a side effect of our own write.
        guard !isApplyingMute else { return }
        guard let device = inputDevices.first(where: { $0.id == deviceID }) else { return }

        let realMuted = readMuteState(device: device)
        let intendedMuted = muteStates[device.uid] == true

        if intendedMuted && !realMuted {
            // External unmute while we intend muted → re-enforce.
            log.info("External unmute on '\(device.name, privacy: .public)' — re-enforcing mute")
            applyMute(true, to: device)
            // muteStates already true; nudge a publish so observers re-run.
            muteStates = muteStates
        } else if !intendedMuted && realMuted {
            // External mute while we intend live → reflect reality.
            log.info("External mute on '\(device.name, privacy: .public)' — syncing state")
            muteStates[device.uid] = true
        }
        // Matching states → nothing to do.
    }

    // MARK: - CoreAudio: enumerate input devices

    private func enumerateInputDevices() -> [AudioDevice] {
        let defaultInputID = readDefaultInputDeviceID()
        let allIDs = readAllAudioDeviceIDs()

        var result: [AudioDevice] = []
        for id in allIDs {
            guard hasInputStreams(deviceID: id) else { continue }
            guard let uid = readStringProperty(
                deviceID: id,
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
            ) else { continue }
            let name = readStringProperty(
                deviceID: id,
                selector: kAudioDevicePropertyDeviceNameCFString,
                scope: kAudioObjectPropertyScopeGlobal
            ) ?? "(unnamed device)"

            // Skip virtual / loopback / aggregate devices (e.g. "Microsoft
            // Teams Audio", BlackHole). They may accept a CoreAudio mute write,
            // but it has no effect on real calls — apps capture from the
            // physical mic, not their own loopback. Showing them only misleads
            // the user, so they're filtered out of the entire UI.
            if isVirtualTransport(deviceID: id) {
                log.info("Skipping virtual/loopback device '\(name, privacy: .public)' id=\(id) uid=\(uid, privacy: .public)")
                continue
            }

            // Flag non-controllable devices (e.g. some Continuity mics) so the
            // UI can show them while the toggle logic excludes them.
            let isControllable = canControlMute(deviceID: id) || canControlVolume(deviceID: id)
            if !isControllable {
                log.info("Non-controllable input device '\(name, privacy: .public)' id=\(id) uid=\(uid, privacy: .public) — will display but skip in toggle")
            }

            result.append(AudioDevice(
                id: id,
                uid: uid,
                name: name,
                isDefaultInput: id == defaultInputID,
                isControllable: isControllable
            ))
        }
        return result.sorted { lhs, rhs in
            if lhs.isDefaultInput != rhs.isDefaultInput { return lhs.isDefaultInput }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// True for virtual / loopback / aggregate transport types. These show up
    /// as input devices and may accept a mute write, but muting them does
    /// nothing useful (apps read from the physical mic), so we hide them.
    private func isVirtualTransport(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        guard status == noErr else { return false }
        return transport == kAudioDeviceTransportTypeVirtual
            || transport == kAudioDeviceTransportTypeAggregate
    }

    private func canControlMute(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(deviceID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func canControlVolume(deviceID: AudioDeviceID) -> Bool {
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var settable: DarwinBoolean = false
            let status = AudioObjectIsPropertySettable(deviceID, &address, &settable)
            if status == noErr && settable.boolValue {
                return true
            }
        }
        return false
    }

    private func readAllAudioDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        guard sizeStatus == noErr, dataSize > 0 else {
            log.error("readAllAudioDeviceIDs size failed: \(sizeStatus)")
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        )
        guard status == noErr else {
            log.error("readAllAudioDeviceIDs data failed: \(status)")
            return []
        }
        return ids
    }

    private func readDefaultInputDeviceID() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        _ = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else { return false }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { buffer.deallocate() }

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, buffer)
        guard status == noErr else { return false }

        let bufferListPtr = buffer.assumingMemoryBound(to: AudioBufferList.self)
        let listPointer = UnsafeMutableAudioBufferListPointer(bufferListPtr)
        var totalChannels: UInt32 = 0
        for audioBuffer in listPointer {
            totalChannels += audioBuffer.mNumberChannels
        }
        return totalChannels > 0
    }

    private func readStringProperty(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cfString: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &cfString)
        guard status == noErr, let value = cfString?.takeRetainedValue() else { return nil }
        return value as String
    }

    // MARK: - CoreAudio: per-device mute read / write

    private func readMuteState(device: AudioDevice) -> Bool {
        // Treat the device as muted if either:
        //  - the system mute property is set (external mute via Sound preferences), OR
        //  - input volume scalar is effectively zero (our volume-based mute).
        if let muted = readMuteProperty(deviceID: device.id), muted {
            return true
        }
        if let volume = readInputVolume(deviceID: device.id) {
            return volume <= 0.0001
        }
        return false
    }

    private func applyMute(_ muted: Bool, to device: AudioDevice) {
        // Suppress our own mute-listener callback for the duration of the write.
        isApplyingMute = true
        defer { isApplyingMute = false }

        log.info("applyMute(muted=\(muted)) → '\(device.name, privacy: .public)' id=\(device.id) uid=\(device.uid, privacy: .public)")

        let preMute = readMuteProperty(deviceID: device.id)
        let preVolume = readInputVolume(deviceID: device.id)
        log.info("  pre-state: mute=\(String(describing: preMute)), volume=\(String(describing: preVolume))")

        let mutePropertyWritten = writeMuteProperty(deviceID: device.id, muted: muted)
        log.info("  writeMuteProperty(\(muted)) returned \(mutePropertyWritten)")

        if muted {
            if !mutePropertyWritten {
                log.info("  mute property unavailable; falling back to volume=0")
                applyVolumeFallback(muted: true, device: device)
            }
        } else {
            let v = readInputVolume(deviceID: device.id) ?? -1
            log.info("  post-unmute volume read = \(v)")
            if v >= 0 && v <= 0.0001 {
                log.info("  volume is zero, restoring via fallback")
                applyVolumeFallback(muted: false, device: device)
            }
        }

        let postMute = readMuteProperty(deviceID: device.id)
        let postVolume = readInputVolume(deviceID: device.id)
        log.info("  post-state: mute=\(String(describing: postMute)), volume=\(String(describing: postVolume))")
    }

    private func readMuteProperty(deviceID: AudioDeviceID) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        guard status == noErr else { return nil }
        return muted == 1
    }

    private func writeMuteProperty(deviceID: AudioDeviceID, muted: Bool) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else {
            log.info("    writeMuteProperty: device \(deviceID) has no mute property on main element")
            return false
        }
        var settable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &address, &settable)
        guard settableStatus == noErr, settable.boolValue else {
            log.info("    writeMuteProperty: not settable (status=\(settableStatus), settable=\(settable.boolValue))")
            return false
        }

        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
        if status != noErr {
            log.error("    writeMuteProperty: AudioObjectSetPropertyData failed status=\(status)")
            return false
        }
        log.info("    writeMuteProperty: wrote value=\(value) OK")
        return true
    }

    private func readInputVolume(deviceID: AudioDeviceID) -> Float32? {
        // Try main element first, then per-channel (L/R).
        let elements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]
        for element in elements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            var volume: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
            if status == noErr {
                return volume
            }
        }
        return nil
    }

    private func applyVolumeFallback(muted: Bool, device: AudioDevice) {
        if muted {
            if let currentVolume = readInputVolume(deviceID: device.id), currentVolume > 0.0001 {
                savedVolumes[device.uid] = currentVolume
                log.info("    volumeFallback: saved volume=\(currentVolume) for uid=\(device.uid)")
            }
            let ok = writeInputVolume(0, deviceID: device.id)
            log.info("    volumeFallback: writeInputVolume(0) → \(ok)")
        } else {
            let restored = savedVolumes[device.uid] ?? 1.0
            let ok = writeInputVolume(restored, deviceID: device.id)
            log.info("    volumeFallback: writeInputVolume(\(restored)) → \(ok)")
            savedVolumes[device.uid] = nil
        }
    }

    @discardableResult
    private func writeInputVolume(_ volume: Float32, deviceID: AudioDeviceID) -> Bool {
        let clamped = max(0, min(1, volume))
        var writtenAnywhere = false
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else {
                log.info("      writeInputVolume: element \(element) has no volume property")
                continue
            }
            var settable: DarwinBoolean = false
            let settableStatus = AudioObjectIsPropertySettable(deviceID, &address, &settable)
            guard settableStatus == noErr, settable.boolValue else {
                log.info("      writeInputVolume: element \(element) not settable (status=\(settableStatus), settable=\(settable.boolValue))")
                continue
            }
            var value = clamped
            let size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
            if status == noErr {
                log.info("      writeInputVolume: element \(element) wrote \(value) OK")
                writtenAnywhere = true
            } else {
                log.error("      writeInputVolume: element \(element) AudioObjectSetPropertyData failed status=\(status)")
            }
        }
        return writtenAnywhere
    }
}