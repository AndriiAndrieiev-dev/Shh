# Shh…

Native macOS app to mute/unmute microphones via a global hotkey. Apple Silicon native, no Rosetta. Designed for macOS Tahoe 26 with Liquid Glass UI.

Alternative to [MuteKey](https://muterkey.app/), which is x86_64-only and will stop working when Rosetta is removed.

## Prerequisites

- macOS 26 Tahoe (Apple Silicon)
- **Xcode 16+** — install the full `Xcode.app` from the App Store. Command Line Tools alone is **not** sufficient.
- **xcodegen** — `brew install xcodegen`

## Quick start

```sh
xcodegen generate
open Shh.xcodeproj
# In Xcode: ⌘R to run
```

The app appears in the menu bar (no Dock icon — `LSUIElement` is on).

## Bundle info

- Bundle ID: `com.andrieiev.shh`
- Display name: **Shh…**
- Min macOS: 26.0 (Tahoe)
- Architecture: arm64

## Features

- Global hotkey (default `F4`) — toggle, hold-to-mute, or hold-to-talk (push-to-talk)
- Per-device selection: mute all input devices or pick a subset via checkboxes
- Hot-plug listener: USB mics / AirPods plug-in/out updates the device list live
- HUD overlay on every mute change — position (9 grid cells), size (3 levels), duration, on/off — all configurable
- Launch at login (SMAppService)
- Auto-mute on sleep + restore on wake (mic returns to its pre-sleep state)
- Live permission status (Accessibility / Input Monitoring / Microphone) with deep-link to System Settings
- Menu bar UI with translucent Liquid-Glass popover (transparency slider)

## License

TBD (private project for now).
