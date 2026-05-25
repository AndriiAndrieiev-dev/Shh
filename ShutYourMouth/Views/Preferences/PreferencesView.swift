//
//  PreferencesView.swift
//  Shut Your Mouth
//
//  Hosted by the SwiftUI `Settings` scene. Phase 2 ships a single slider for
//  popover transparency; Phase 6 will grow this into the full preferences UI
//  (launch at login, HUD options, hotkey binding, mode, sleep auto-mute…).
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesStore.shared

    var body: some View {
        Form {
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
        .formStyle(.grouped)
        .frame(width: 460, height: 240)
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
