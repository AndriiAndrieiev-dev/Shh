//
//  PersistentMicIndicatorView.swift
//  Shh…
//
//  The small red badge that stays in a corner of the screen while any
//  selected mic is muted. Sized to feel close to a system status-bar item.
//

import SwiftUI

struct PersistentMicIndicatorView: View {
    var body: some View {
        Image(systemName: "mic.slash.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(Color.red.gradient)
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .padding(4) // breathing room so shadow doesn't get clipped
    }
}
