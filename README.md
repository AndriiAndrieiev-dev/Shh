# Shut Your Mouth

Native macOS app to mute/unmute microphones via a global hotkey. Apple Silicon native, no Rosetta. Designed for macOS Tahoe 26 with Liquid Glass UI.

Alternative to [MuteKey](https://muterkey.app/), which is x86_64-only and will stop working when Rosetta is removed.

## Prerequisites

- macOS 26 Tahoe (Apple Silicon)
- **Xcode 16+** — install the full `Xcode.app` from the App Store. Command Line Tools alone is **not** sufficient.
- **xcodegen** — `brew install xcodegen`

## Quick start

```sh
xcodegen generate
open ShutYourMouth.xcodeproj
# In Xcode: ⌘R to run
```

The app appears in the menu bar (no Dock icon — `LSUIElement` is on).

## Bundle info

- Bundle ID: `com.andrieiev.shutyourmouth`
- Display name: **Shut Your Mouth**
- Min macOS: 26.0 (Tahoe)
- Architecture: arm64

## Roadmap

See the full plan at `~/.claude/plans/swift-merry-bumblebee.md`.

- [x] **Phase 1** — Project bootstrap (basic MenuBarExtra, static icon)
- [ ] **Phase 2** — CoreAudio: enumerate input devices, mute/unmute
- [ ] **Phase 3** — Global hotkeys via CGEventTap (toggle + push-to-talk)
- [ ] **Phase 4** — Permissions manager + onboarding flow
- [ ] **Phase 5** — Popover + HUD overlay with Liquid Glass
- [ ] **Phase 6** — Preferences window
- [ ] **Phase 7** — Launch at Login + sleep observer
- [ ] **Phase 8** — Polish & edge cases
- [ ] **Phase 9** — Packaging (Developer ID + .dmg)

## License

TBD (private project for now).
