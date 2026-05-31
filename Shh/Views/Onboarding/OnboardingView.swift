// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

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
    @ObservedObject private var loc = LocalizationManager.shared
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
                Text(loc.t(.welcomeTitle))
                    .font(.largeTitle.bold())
            }
            Text(loc.t(.welcomeBody))
                .foregroundStyle(.secondary)
        }
    }

    private var permissionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(loc.t(.secPermissions))
                .font(.headline)
            Text(loc.t(.onbPermBlurb))
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
            Text(requiredGranted ? loc.t(.onbAllGranted) : loc.t(.onbGrantToContinue))
                .font(.caption)
                .foregroundStyle(requiredGranted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
            Spacer()
            Button(loc.t(.getStarted)) {
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