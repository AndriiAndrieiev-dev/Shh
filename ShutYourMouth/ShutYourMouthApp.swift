//
//  ShutYourMouthApp.swift
//  Shut Your Mouth
//
//  Phase 1 — Project bootstrap.
//  Minimal MenuBarExtra app with a placeholder mute toggle (UI-only, no audio plumbing yet).
//  Real CoreAudio integration arrives in Phase 2.
//

import SwiftUI

@main
struct ShutYourMouthApp: App {
    @State private var isMuted: Bool = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(isMuted: $isMuted)
        } label: {
            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContentView: View {
    @Binding var isMuted: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(isMuted ? AnyShapeStyle(.red.opacity(0.85)) : AnyShapeStyle(.primary))
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(isMuted ? "Microphone OFF" : "Microphone ON")
                .font(.headline)
                .foregroundStyle(.primary)

            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    isMuted.toggle()
                }
            } label: {
                Text(isMuted ? "Unmute" : "Mute")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)

            Divider()
                .padding(.vertical, 4)

            Button("Quit Shut Your Mouth") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 280)
    }
}
