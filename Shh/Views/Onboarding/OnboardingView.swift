//
//  OnboardingView.swift
//  Shh…
//
//  First-launch welcome window. Walks the user through granting the two
//  required permissions (Accessibility + Input Monitoring) plus the
//  optional Microphone permission, and is dismissable via "Get started"
//  once the required ones are granted.
//
//  The window is shown by `OnboardingWindowController` only when
//  `PreferencesStore.firstLaunchCompleted == false`. Tapping "Get started"
//  flips that flag, so the window doesn't pop up again on subsequent runs.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var permissions = PermissionsManager.shared
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            permissionsBlock
            footer
        }
        .padding(32)
        .frame(width: 560)
        .background(.regularMaterial)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to Shh…")
                    .font(.largeTitle.bold())
            }
            Text("Mute or push-to-talk your microphone with a single keypress, system-wide.")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)
            Text("Shh… needs the two required permissions below to capture the global hotkey. Microphone access is optional and unrelated to mute itself.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 4) {
                ForEach(PermissionKind.allCases) { kind in
                    PermissionStatusRow(
                        kind: kind,
                        status: permissions.status(for: kind),
                        onOpenSettings: { permissions.openSystemSettings(for: kind) }
                    )
                    if kind != PermissionKind.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var footer: some View {
        HStack {
            Text(requiredGranted ? "All required permissions are granted." : "Grant the required permissions to continue.")
                .font(.caption)
                .foregroundStyle(requiredGranted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            Spacer()
            Button("Get started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return)
            .disabled(!requiredGranted)
        }
    }

    private var requiredGranted: Bool {
        permissions.accessibility == .granted &&
        permissions.inputMonitoring == .granted
    }
}
