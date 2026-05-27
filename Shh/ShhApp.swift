//
//  ShhApp.swift
//  Shh…
//
//  The SwiftUI App entry point is intentionally thin: it just attaches the
//  AppKit `AppDelegate`, which owns the NSStatusItem-driven menu bar UI and,
//  in later phases, the global hotkey manager and HUD overlay.
//
//  The empty Settings scene exists so SwiftUI's `openSettings` machinery can
//  host the future preferences window (added in Phase 6).
//

import SwiftUI

@main
struct ShhApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}
