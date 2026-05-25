//
//  MenuBarPopoverView.swift
//  Shut Your Mouth
//
//  SwiftUI content hosted inside the NSPopover anchored to the menu bar status
//  item. Opened via right-click (or Ctrl+left-click) on the menu bar icon.
//

import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var audio: AudioDeviceManager
    @ObservedObject private var preferences = PreferencesStore.shared

    var body: some View {
        VStack(spacing: 16) {
            stateCircle

            Text(audio.allInputDevicesMuted ? "Microphone OFF" : "Microphone ON")
                .font(.headline)
                .foregroundStyle(.primary)

            Button {
                audio.toggleMuteAll()
            } label: {
                Text(audio.allInputDevicesMuted ? "Unmute All" : "Mute All")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
            .disabled(audio.inputDevices.isEmpty)

            if !audio.inputDevices.isEmpty {
                Divider()
                deviceList
            }

            Spacer(minLength: 0)

            Divider()

            HStack {
                Button {
                    openPreferencesWindow()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                .help("Preferences")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 320, height: 440)
        // NSPanel is transparent (no backdrop like NSPopover provides), so
        // the SwiftUI view supplies its own Liquid-Glass blur background.
        // The slider in Preferences picks one of SwiftUI's discrete Material
        // levels — that's the API that actually changes blur intensity (an
        // alpha overlay alone barely moves the needle on bright wallpapers).
        .background(selectedMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    /// Map the 0...1 slider value to one of SwiftUI's five discrete Material
    /// variants. Lower values = more see-through; higher = more opaque.
    private var selectedMaterial: Material {
        let level = preferences.popoverTintLevel
        switch level {
        case ..<0.2: return .ultraThinMaterial
        case ..<0.4: return .thinMaterial
        case ..<0.6: return .regularMaterial
        case ..<0.8: return .thickMaterial
        default:     return .ultraThickMaterial
        }
    }

    private var stateCircle: some View {
        Button {
            audio.toggleMuteAll()
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

                Image(systemName: audio.allInputDevicesMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(audio.allInputDevicesMuted ? AnyShapeStyle(.red.opacity(0.85)) : AnyShapeStyle(.primary))
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .help(audio.allInputDevicesMuted ? "Unmute all (or click the icon in menu bar)" : "Mute all (or click the icon in menu bar)")
    }

    /// Open the Preferences window. Goes through `PreferencesWindowController`
    /// (a plain AppKit-managed NSWindow) rather than SwiftUI's Settings scene
    /// because the gear button lives inside an NSPanel — outside the Scene
    /// responder chain that `showSettingsWindow:` walks.
    private func openPreferencesWindow() {
        PreferencesWindowController.shared.show()
    }

    private func deviceIconName(for device: AudioDevice) -> String {
        guard device.isControllable else { return "mic.fill" }
        return audio.muteStates[device.uid] == true ? "mic.slash.fill" : "mic.fill"
    }

    private func deviceIconColor(for device: AudioDevice) -> AnyShapeStyle {
        guard device.isControllable else { return AnyShapeStyle(.tertiary) }
        return audio.muteStates[device.uid] == true
            ? AnyShapeStyle(.red.opacity(0.75))
            : AnyShapeStyle(.secondary)
    }

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Input Devices")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(audio.inputDevices) { device in
                HStack(spacing: 8) {
                    Image(systemName: deviceIconName(for: device))
                        .foregroundStyle(deviceIconColor(for: device))
                        .font(.system(size: 13))
                        .frame(width: 16)

                    Text(device.name)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(device.isControllable ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))

                    if device.isDefaultInput {
                        Text("default")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }

                    if !device.isControllable {
                        Text("no control")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.5), in: Capsule())
                    }

                    Spacer()
                }
            }
        }
    }
}
