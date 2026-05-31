# Shh…

Native macOS menu-bar app to mute/unmute your microphones with a global hotkey. Apple Silicon native, no Rosetta. Built for macOS Tahoe 26 with a Liquid-Glass UI.

A modern alternative to [MuteKey](https://muterkey.app/), which is x86_64-only and stops working once Rosetta is removed.

---

## Features

- **Global hotkey** (default `F4`) — `Toggle`, `Hold to mute`, or `Hold to talk` (push-to-talk)
- **Per-device selection** — mute all input devices, or pick a subset with checkboxes
- **Menu-bar icon** — white mic when live, red slashed mic when muted; left-click toggles, right-click opens the panel
- **HUD overlay** on every mute change — 9 placement cells, 3 sizes, adjustable duration, with a live preview while you tune it
- **Persistent indicator** — a small red badge stays in a screen corner while muted (works over fullscreen apps)
- **Sound feedback** — optional Pop/Tink tone on mute change
- **Hotkey conflict warning** — flags bindings that clash with common macOS shortcuts
- **Hot-plug aware** — USB mics / AirPods appear in the list live; a device plugged in while muted inherits the muted state
- **Launch at login**
- **Live permission status** for Accessibility / Input Monitoring / Microphone, with one-click deep-links to System Settings

---

## Installation (unsigned build)

Shh… is distributed **unsigned** (no Apple Developer certificate). macOS Gatekeeper will block it on first launch — that's expected. Pick one of the two methods below to get past it. This is a one-time step.

### 1. Download & move

1. Download `Shh.dmg` from the [Releases](https://github.com/) page.
2. Open the DMG and drag **Shh** into your **Applications** folder.

### 2. Get past Gatekeeper (one-time)

Because the app isn't signed by an Apple-registered developer, a plain double-click shows *"Shh… cannot be opened because it is from an unidentified developer"* or *"…is damaged"*. Use **either** method:

**Method A — System Settings (no terminal):**
1. Double-click **Shh** in Applications (the warning appears — that's fine, dismiss it).
2. Open **System Settings → Privacy & Security**.
3. Scroll to the **Security** section — you'll see *"Shh was blocked from use…"* with an **Open Anyway** button. Click it.
4. Confirm with Touch ID / password. The app launches.

**Method B — Terminal (one command):**
```sh
xattr -dr com.apple.quarantine /Applications/Shh.app
```
Then double-click the app normally. This strips the "downloaded from the internet" quarantine flag that triggers the block.

### 3. Grant permissions

On first launch a welcome window walks you through the permissions Shh… needs:

| Permission | Required? | Why |
| --- | --- | --- |
| **Accessibility** | ✅ Yes | Captures the global hotkey |
| **Input Monitoring** | ✅ Yes | Lets keyboard events reach the hotkey listener |
| **Microphone** | ⚪️ Optional | Only for a future "mic in use" indicator — not needed for muting |

Click **Open Settings** next to each, flip the toggle on, and return to Shh…. The hotkey activates the moment Accessibility is granted — no restart needed.

> The app lives in the menu bar only (no Dock icon). Look for the microphone icon near the clock.

---

## Building from source

### Prerequisites
- macOS 26 Tahoe (Apple Silicon)
- **Xcode 16+** — full `Xcode.app` from the App Store (Command Line Tools alone is **not** enough)
- **xcodegen** — `brew install xcodegen`

### Quick build & run
```sh
# one-time: create the stable self-signed dev certificate
./scripts/make-dev-cert.sh

# build → install to /Applications → re-sign → launch
./scripts/dev-run.sh
```

`dev-run.sh` signs every build with a stable self-signed **"Shh Dev"** certificate. This keeps the code signature constant across rebuilds, so macOS **doesn't drop your Accessibility / Input Monitoring grants** every time you rebuild — grant once, never again.

To open in Xcode instead:
```sh
xcodegen generate
open Shh.xcodeproj   # ⌘R to run
```

### Packaging a DMG
```sh
./scripts/build-dmg.sh   # produces build/Shh.dmg
```

---

## Bundle info

- Bundle ID: `com.andrieiev.shh`
- Display name: **Shh…**
- Min macOS: 26.0 (Tahoe)
- Architecture: arm64

---

## Known limitations

- **Bluetooth headset play/pause button can't toggle mute.** Headsets like the Sony WH-CH520 and AirPods route their play/pause button through AVRCP → the MediaRemote framework straight to the active music app; the press never surfaces as a system media-key event, so a menu-bar utility can't intercept it. Use the keyboard hotkey instead — it works fine while wearing headphones.
- **Virtual / loopback "mics" (e.g. "Microsoft Teams Audio") can be muted in the UI but it has no effect on the actual call,** because apps capture from the physical device, not their own loopback. Mute the real device (or "All Devices") instead. Such devices are still shown for transparency, tagged "no control" when they expose no usable mute.

## License

TBD (private project for now).
