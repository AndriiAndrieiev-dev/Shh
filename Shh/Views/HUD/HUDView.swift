//
//  HUDView.swift
//  Shh…
//
//  SwiftUI content for the floating HUD overlay that briefly appears whenever
//  the mute state changes (mic icon + "Mic ON"/"Mic OFF" + scope label).
//  Scales for the user-selected `HUDSize` (small / medium / large).
//

import SwiftUI

struct HUDView: View {
    let isMuted: Bool
    let scopeLabel: String
    let sizeVariant: HUDSize

    var body: some View {
        VStack(spacing: sizeVariant == .small ? 8 : 14) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: sizeVariant.circleSize, height: sizeVariant.circleSize)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)

                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: sizeVariant.iconFontSize, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isMuted ? AnyShapeStyle(.red.opacity(0.9)) : AnyShapeStyle(.primary))
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 2) {
                Text(isMuted ? LocalizationManager.shared.t(.hudMicOff) : LocalizationManager.shared.t(.hudMicOn))
                    .font(titleFont)
                    .foregroundStyle(.primary)
                Text(scopeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(width: sizeVariant.dimension, height: sizeVariant.dimension)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var titleFont: Font {
        switch sizeVariant {
        case .small:  return .headline
        case .medium: return .title3.weight(.semibold)
        case .large:  return .title2.weight(.semibold)
        }
    }
}
