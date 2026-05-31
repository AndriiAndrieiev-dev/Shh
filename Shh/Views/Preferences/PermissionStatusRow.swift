//
//  PermissionStatusRow.swift
//  Shh…
//
//  Single row in the Preferences "Permissions" section: status icon, name,
//  short explanation, and an "Open Settings" deep-link button.
//

import SwiftUI

struct PermissionStatusRow: View {
    let kind: PermissionKind
    let status: PermissionStatus
    let onOpenSettings: () -> Void

    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIconName)
                .foregroundStyle(statusColor)
                .font(.system(size: 20))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(localizedName)
                        .font(.body)
                    if !kind.isRequired {
                        Text(loc.t(.optional))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.quaternary.opacity(0.6), in: Capsule())
                    }
                }
                Text(localizedExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onOpenSettings) {
                Text(loc.t(.openSettings))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private var localizedName: String {
        switch kind {
        case .accessibility:   return loc.t(.permAccessibility)
        case .inputMonitoring: return loc.t(.permInputMonitoring)
        case .microphone:      return loc.t(.permMicrophone)
        }
    }

    private var localizedExplanation: String {
        switch kind {
        case .accessibility:   return loc.t(.permAccessibilityWhy)
        case .inputMonitoring: return loc.t(.permInputMonitoringWhy)
        case .microphone:      return loc.t(.permMicrophoneWhy)
        }
    }

    private var statusIconName: String {
        switch status {
        case .granted:        return "checkmark.circle.fill"
        case .denied:         return "xmark.circle.fill"
        case .notDetermined:  return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:        return .green
        case .denied:         return .red
        case .notDetermined:  return .secondary
        }
    }
}
