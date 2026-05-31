// Copyright (c) 2026 Andrii Andrieiev
// Licensed under the Apache License, Version 2.0. See LICENSE for details.

//
//  PreferencesView.swift
//  Shh…
//
//  Preferences window content: General, Hotkey & mode, HUD overlay,
//  Persistent indicator, Popover appearance, Language, Permissions.
//  All strings go through LocalizationManager (`loc.t(.key)`).
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesStore.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        Form {
            generalSection
            hotkeySection
            hudSection
            indicatorSection
            popoverSection
            languageSection
            permissionsSection
        }
        .formStyle(.grouped)
        // Fixed width, but flexible height: the window is resizable and the
        // Form scrolls, so the content adapts to whatever height the user (or
        // the screen-size cap) gives it instead of being clipped under the Dock.
        .frame(width: 540)
        .frame(minHeight: 360, idealHeight: 900, maxHeight: .infinity)
        // Live HUD preview when the user adjusts any HUD-layout option, so
        // they can see the effect without having to toggle mute themselves.
        .onChange(of: preferences.hudHorizontalAlignment) { _, _ in showHUDPreview() }
        .onChange(of: preferences.hudVerticalAlignment)   { _, _ in showHUDPreview() }
        .onChange(of: preferences.hudSize)                { _, _ in showHUDPreview() }
        .onChange(of: preferences.hudHoldDuration)        { _, _ in showHUDPreview() }
    }

    private func showHUDPreview() {
        // Reflect current mute state so the preview looks identical to a real
        // toggle — only the geometry/duration differs.
        HUDController.shared.show(
            isMuted: AudioDeviceManager.shared.isActiveSelectionMuted,
            scopeLabel: loc.t(.scopePreview)
        )
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Toggle(loc.t(.launchAtLogin), isOn: $launchAtLogin.isEnabled)
            Toggle(loc.t(.playSound), isOn: $preferences.playSoundFeedback)
        } header: {
            Text(loc.t(.secGeneral))
        } footer: {
            footerText(loc.t(.generalFooter))
        }
    }

    // MARK: - Hotkey & mode

    private var hotkeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(loc.t(.hotkey))
                    Spacer()
                    HotkeyRecorderView(binding: $preferences.hotkey)
                        .frame(width: 220)
                }

                Picker(loc.t(.mode), selection: $preferences.toggleMode) {
                    ForEach(ToggleMode.allCases) { mode in
                        Text(modeName(mode)).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Text(modeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(loc.t(.keepHUDLive), isOn: $preferences.keepHUDWhileLiveInPTT)
                    Text(loc.t(.keepHUDLiveDesc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(!preferences.toggleMode.isPushToTalk)
                .opacity(preferences.toggleMode.isPushToTalk ? 1 : 0.4)
            }
            .padding(.vertical, 4)
        } header: {
            Text(loc.t(.secHotkey))
        }
    }

    private func modeName(_ mode: ToggleMode) -> String {
        switch mode {
        case .toggle:               return loc.t(.modeToggle)
        case .pushToTalkHoldToMute: return loc.t(.modeHoldToMute)
        case .pushToTalkHoldToTalk: return loc.t(.modeHoldToTalk)
        }
    }

    private var modeHint: String {
        switch preferences.toggleMode {
        case .toggle:               return loc.t(.hintToggle)
        case .pushToTalkHoldToMute: return loc.t(.hintHoldToMute)
        case .pushToTalkHoldToTalk: return loc.t(.hintHoldToTalk)
        }
    }

    // MARK: - HUD overlay

    private var hudSection: some View {
        Section {
            Toggle(loc.t(.showHUD), isOn: $preferences.showHUD)

            Picker(loc.t(.horizontal), selection: $preferences.hudHorizontalAlignment) {
                ForEach(HUDHorizontalAlignment.allCases) { alignment in
                    Text(horizontalName(alignment)).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.showHUD)

            Picker(loc.t(.vertical), selection: $preferences.hudVerticalAlignment) {
                ForEach(HUDVerticalAlignment.allCases) { alignment in
                    Text(verticalName(alignment)).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.showHUD)

            Picker(loc.t(.size), selection: $preferences.hudSize) {
                ForEach(HUDSize.allCases) { size in
                    Text(sizeName(size)).tag(size)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.showHUD)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(loc.t(.displayDuration))
                    Spacer()
                    Text("\(String(format: "%.1f", preferences.hudHoldDuration)) \(loc.t(.secondsUnit))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $preferences.hudHoldDuration, in: 0.5...3.0, step: 0.1)
                    .disabled(!preferences.showHUD)
            }
            .padding(.vertical, 2)
        } header: {
            Text(loc.t(.secHUD))
        } footer: {
            footerText(loc.t(.hudFooter))
        }
    }

    private func horizontalName(_ a: HUDHorizontalAlignment) -> String {
        switch a {
        case .left:   return loc.t(.alignLeft)
        case .center: return loc.t(.alignCenter)
        case .right:  return loc.t(.alignRight)
        }
    }

    private func verticalName(_ a: HUDVerticalAlignment) -> String {
        switch a {
        case .top:    return loc.t(.alignTop)
        case .center: return loc.t(.alignCenter)
        case .bottom: return loc.t(.alignBottom)
        }
    }

    private func sizeName(_ s: HUDSize) -> String {
        switch s {
        case .small:  return loc.t(.sizeSmall)
        case .medium: return loc.t(.sizeMedium)
        case .large:  return loc.t(.sizeLarge)
        }
    }

    // MARK: - Persistent indicator

    private var indicatorSection: some View {
        Section {
            Toggle(loc.t(.showIndicator), isOn: $preferences.showPersistentIndicator)

            Picker(loc.t(.corner), selection: $preferences.persistentIndicatorCorner) {
                ForEach(ScreenCorner.allCases) { corner in
                    Text(cornerName(corner)).tag(corner)
                }
            }
            .pickerStyle(.menu)
            .disabled(!preferences.showPersistentIndicator)
        } header: {
            Text(loc.t(.secIndicator))
        } footer: {
            footerText(loc.t(.indicatorFooter))
        }
    }

    private func cornerName(_ c: ScreenCorner) -> String {
        switch c {
        case .topLeft:     return loc.t(.cornerTopLeft)
        case .topRight:    return loc.t(.cornerTopRight)
        case .bottomLeft:  return loc.t(.cornerBottomLeft)
        case .bottomRight: return loc.t(.cornerBottomRight)
        }
    }

    // MARK: - Popover appearance

    private var popoverSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(loc.t(.background))
                    Spacer()
                    Text(materialName(for: preferences.popoverTintLevel))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $preferences.popoverTintLevel, in: 0...1) {
                    Text(loc.t(.background))
                } minimumValueLabel: {
                    Image(systemName: "circle.dotted").foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "circle.fill").foregroundStyle(.secondary)
                }

                Text(loc.t(.popoverFooter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text(loc.t(.secPopover))
        }
    }

    private func materialName(for level: Double) -> String {
        switch level {
        case ..<0.2: return loc.t(.matUltraThin)
        case ..<0.4: return loc.t(.matThin)
        case ..<0.6: return loc.t(.matRegular)
        case ..<0.8: return loc.t(.matThick)
        default:     return loc.t(.matUltraThick)
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            Picker(loc.t(.language), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(loc.t(.secLanguage))
        }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            ForEach(PermissionKind.allCases) { kind in
                PermissionStatusRow(
                    kind: kind,
                    status: permissions.status(for: kind),
                    onOpenSettings: { permissions.openSystemSettings(for: kind) }
                )
            }
        } header: {
            Text(loc.t(.secPermissions))
        } footer: {
            footerText(loc.t(.permFooter))
        }
    }

    private func footerText(_ s: String) -> some View {
        Text(s).font(.caption).foregroundStyle(.secondary)
    }
}