//
//  HotkeyRecorderView.swift
//  Shut Your Mouth
//
//  Click → "Press a hotkey…" mode → captures the next NSEvent.keyDown into
//  a HotkeyBinding bound to the parent (typically PreferencesStore.hotkey).
//  Uses NSEvent.addLocalMonitorForEvents so capture only happens while the
//  Preferences window is key; outside clicks cancel.
//

import SwiftUI
import AppKit
import CoreGraphics

struct HotkeyRecorderView: View {
    @Binding var binding: HotkeyBinding

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            toggleRecording()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                Text(isRecording ? "Press a hotkey…" : binding.displayString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRecording ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                Spacer(minLength: 0)
                if !isRecording {
                    Image(systemName: "pencil")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 160)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isRecording ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .onDisappear { cancelRecording() }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        // Local monitor: only fires while our app is active (the Preferences
        // window). Captures the first keyDown and consumes it (returning nil
        // suppresses propagation to text fields, etc.).
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            captureEvent(event)
            return nil
        }
    }

    private func cancelRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }

    private func captureEvent(_ event: NSEvent) {
        // Allow Escape to cancel without rebinding.
        if event.keyCode == 0x35 {
            cancelRecording()
            return
        }

        let modifierMask = Self.cgFlagsMask(from: event.modifierFlags)
        binding = HotkeyBinding(
            keyCode: UInt16(event.keyCode),
            modifiers: modifierMask
        )
        cancelRecording()
    }

    /// Map NSEvent.ModifierFlags → CGEventFlags raw mask (HotkeyManager
    /// compares against `event.flags.rawValue & HotkeyBinding.modifierMask`).
    private static func cgFlagsMask(from ns: NSEvent.ModifierFlags) -> UInt64 {
        var mask: UInt64 = 0
        if ns.contains(.command)  { mask |= CGEventFlags.maskCommand.rawValue }
        if ns.contains(.shift)    { mask |= CGEventFlags.maskShift.rawValue }
        if ns.contains(.control)  { mask |= CGEventFlags.maskControl.rawValue }
        if ns.contains(.option)   { mask |= CGEventFlags.maskAlternate.rawValue }
        return mask
    }
}
