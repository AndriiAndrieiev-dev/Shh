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

    var body: some View {
        Form {
            hotkeySection
            popoverSection
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 380)
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
}
