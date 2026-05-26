//
//  PreferencesView.swift
//  Shut Your Mouth
//
//  Preferences window content. Phase 3b adds the Hotkey & Mode section on
//  top of the popover transparency slider; Phase 6 will round it out with
//  launch-at-login, HUD options, auto-mute-on-sleep, and permission status.
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesStore.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var permissions = PermissionsManager.shared

    var body: some View {
        Form {
            generalSection
            hotkeySection
            hudSection
            popoverSection
            permissionsSection
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 820)
        // Live HUD preview when the user adjusts any HUD-layout option, so
        // they can see the effect without having to toggle mute themselves.
        .onChange(of: preferences.hudHorizontalAlignment) { _, _ in showHUDPreview() }
        .onChange(of: preferences.hudVerticalAlignment)   { _, _ in showHUDPreview() }
        .onChange(of: preferences.hudSize)                { _, _ in showHUDPreview() }
        .onChange(of: preferences.hudHoldDuration)        { _, _ in showHUDPreview() }
    }

    private func showHUDPreview() {
        // Reflect current mute state so the preview looks identical to a real
        // toggle — only the geometry/duration differs.
        HUDController.shared.show(
            isMuted: AudioDeviceManager.shared.isActiveSelectionMuted,
            scopeLabel: "Preview"
        )
    }

    // MARK: - HUD overlay

    private var hudSection: some View {
        Section {
            Toggle("Show HUD on mute change", isOn: $preferences.showHUD)

            Picker("Horizontal", selection: $preferences.hudHorizontalAlignment) {
                ForEach(HUDHorizontalAlignment.allCases) { alignment in
                    Text(alignment.displayName).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.showHUD)

            Picker("Vertical", selection: $preferences.hudVerticalAlignment) {
                ForEach(HUDVerticalAlignment.allCases) { alignment in
                    Text(alignment.displayName).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.showHUD)

            Picker("Size", selection: $preferences.hudSize) {
                ForEach(HUDSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.showHUD)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Display duration")
                    Spacer()
                    Text(String(format: "%.1f s", preferences.hudHoldDuration))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(
                    value: $preferences.hudHoldDuration,
                    in: 0.5...3.0,
                    step: 0.1
                )
                .disabled(!preferences.showHUD)
            }
            .padding(.vertical, 2)
        } header: {
            Text("HUD overlay")
        } footer: {
            Text("The floating overlay briefly appears on the main display when the mute state changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Toggle("Launch at login", isOn: $launchAtLogin.isEnabled)

            Toggle("Auto-mute when the Mac sleeps", isOn: $preferences.autoMuteOnSleep)
        } header: {
            Text("General")
        } footer: {
            Text("On sleep, all controllable mics are muted (only if they were live). On wake, they're unmuted back. Manual mutes you set before sleep are preserved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hotkey & mode

    private var hotkeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    HotkeyRecorderView(binding: $preferences.hotkey)
                        .frame(width: 220)
                }

                Picker("Mode", selection: $preferences.toggleMode) {
                    ForEach(ToggleMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Text(modeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Hotkey & mode")
        }
    }

    private var modeHint: String {
        switch preferences.toggleMode {
        case .toggle:
            return "Press the hotkey once to switch between muted and unmuted."
        case .pushToTalkHoldToMute:
            return "Mic is on by default. Hold the hotkey to mute (e.g. for a quick cough or sneeze); release to unmute."
        case .pushToTalkHoldToTalk:
            return "Mic is muted by default. Hold the hotkey to talk (walkie-talkie); release to mute."
        }
    }

    // MARK: - Popover appearance

    private var popoverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Background")
                    Spacer()
                    Text(materialName(for: preferences.popoverTintLevel))
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: $preferences.popoverTintLevel,
                    in: 0...1
                ) {
                    Text("Popover background")
                } minimumValueLabel: {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.secondary)
                }

                Text("Slide left for a strongly see-through Liquid-Glass look; slide right for a more opaque panel that stays readable on bright wallpapers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Popover appearance")
        }
    }

    private func materialName(for level: Double) -> String {
        switch level {
        case ..<0.2: return "Ultra thin"
        case ..<0.4: return "Thin"
        case ..<0.6: return "Regular"
        case ..<0.8: return "Thick"
        default:     return "Ultra thick"
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            ForEach(PermissionKind.allCases) { kind in
                PermissionStatusRow(
                    kind: kind,
                    status: permissions.status(for: kind),
                    onOpenSettings: { permissions.openSystemSettings(for: kind) }
                )
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Statuses refresh automatically each time you return to the app from System Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
