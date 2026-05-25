//
//  AppDelegate.swift
//  Shut Your Mouth
//
//  Owns the AppKit objects that back the menu bar UI. SwiftUI's MenuBarExtra is
//  too restrictive for our needs (no custom click handling — clicking the icon
//  always opens the popover, no way to trigger an instant mute on left-click).
//  An NSStatusItem driven from AppKit gives full control over click behavior,
//  popover positioning, and (in later phases) global hotkey integration.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }
}
