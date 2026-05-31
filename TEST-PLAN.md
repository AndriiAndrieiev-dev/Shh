# Shh… — Test Plan (outstanding cases)

This lists the features that have **not yet been confirmed working** during
development (either explicitly deferred with "test later", or shipped without
an explicit pass). Already-verified behavior — basic mute/unmute, click
handling, icon state & color, popover positioning, the symbol animation, the
`F4` hotkey toggle, hotkey rebinding, the transparency slider, the HUD
appearing on toggle, and the persistent badge appearing while muted — is not
repeated here.

Legend: **▢ Pass** / **▢ Fail** — tick after running. Note the macOS build and
whether the app was launched from `/Applications` (signed via `dev-run.sh`).

---

## 1. Hotkey — push-to-talk modes

Only plain `Toggle` + rebinding were confirmed. The two PTT modes weren't.

### 1.1 Hold to mute (default on)
1. Preferences → Hotkey & mode → Mode = **Hold to mute (default on)**.
2. Mic should be **live** at rest (icon white).
3. Press **and hold** the hotkey → mic mutes (icon red) for as long as held.
4. Release → mic returns to live.
- ▢ Pass ▢ Fail

### 1.2 Hold to talk (default muted)
1. Mode = **Hold to talk (default muted)**.
2. Mic should be **muted** at rest (icon red).
3. Press and hold → mic goes live while held.
4. Release → mic mutes again.
- ▢ Pass ▢ Fail

### 1.3 Mode switches live
1. Change Mode in Preferences while the app runs (no restart).
2. The new behavior applies on the very next hotkey press.
- ▢ Pass ▢ Fail

---

## 2. Per-device selection

### 2.1 "All" blue toggle
1. Open the popover. The **All** switch (Input Devices header) is ON and visibly **blue**.
2. Toggle it off → it turns grey; back on → blue. (Custom-drawn switch.)
- ▢ Pass ▢ Fail

### 2.2 Picking a subset
1. Turn **All** off → checkboxes appear next to each controllable device.
2. Check only one device (e.g. MacBook Pro mic).
3. Button label reads **Mute Selected**.
4. Press hotkey / click icon → only the checked device mutes (verify the
   others stay live in System Settings → Sound → Input).
- ▢ Pass ▢ Fail

### 2.3 Scope label in HUD
- With **All** on → HUD subtitle reads **All Devices**.
- One device selected → HUD shows that device's name.
- Two+ selected → HUD shows **N Devices**.
- ▢ Pass ▢ Fail

### 2.4 Selection persists
1. Pick a subset, quit Shh… (popover → Quit), relaunch.
2. **All** is still off and the same devices are still checked.
- ▢ Pass ▢ Fail

---

## 3. Hot-plug behavior

### 3.1 Device list updates live
1. Open the popover (leave it open if you can, or reopen after each step).
2. Connect AirPods / a USB mic → it appears in the list within ~1 s.
3. Disconnect → it disappears.
- ▢ Pass ▢ Fail

### 3.2 State inheritance while muted
1. Mute everything (icon red).
2. Connect headphones (a new controllable mic).
3. The newly-connected mic should come up **muted** too — the aggregate stays
   red, it does NOT flip to live.
4. Counter-check: with mic **live**, connecting a device leaves it live.
- ▢ Pass ▢ Fail

---

## 4. HUD overlay configuration

### 4.1 Position grid (9 cells)
1. Preferences → HUD overlay. For each Horizontal (Left/Center/Right) ×
   Vertical (Top/Center/Bottom) combination, the live preview appears in the
   matching screen region.
- ▢ Pass ▢ Fail

### 4.2 Size variants
- Small / Medium / Large each visibly rescale the HUD (circle, icon, text).
- ▢ Pass ▢ Fail

### 4.3 Duration slider
- Set 0.5 s and 3.0 s; the HUD stays visible roughly that long before fading.
- ▢ Pass ▢ Fail

### 4.4 Show-HUD off
- Turn **Show HUD on mute change** off → toggling mute shows no HUD (icon
  still updates).
- ▢ Pass ▢ Fail

### 4.5 Live preview
- Changing any HUD setting pops a preview immediately without toggling mute.
- ▢ Pass ▢ Fail

---

## 5. Persistent indicator

### 5.1 Corner placement
- Preferences → Persistent indicator → toggle on. For each corner (Top Left /
  Top Right / Bottom Left / Bottom Right), muting shows the red badge in that
  corner.
- ▢ Pass ▢ Fail

### 5.2 Visibility lifecycle
- Badge appears only while muted, disappears on unmute.
- Toggle the feature off → no badge even while muted.
- Badge stays visible over a fullscreen app (e.g. fullscreen Safari/YouTube).
- ▢ Pass ▢ Fail

---

## 6. Sound feedback
1. Preferences → General → **Play sound on mute change** on.
2. Mute → hear "Pop"; unmute → hear "Tink".
3. Turn off → silent toggles.
- ▢ Pass ▢ Fail

---

## 7. Hotkey conflict warning
1. Preferences → Hotkey → record **⌘Space** (Spotlight).
2. An orange "May conflict with Spotlight (⌘Space)" note appears under the recorder.
3. Record a plain key (e.g. `F4`) → the warning disappears.
- ▢ Pass ▢ Fail

---

## 8. Launch at login

> **How to test this properly** — two levels:

### 8.1 Registration (quick check, no reboot)
1. Preferences → General → turn **Launch at login** ON.
2. Open **System Settings → General → Login Items & Extensions**.
3. Under **Open at Login**, **Shh** should now be listed.
4. Turn the toggle OFF in Shh… → Shh disappears from that list.
- ▢ Pass ▢ Fail

### 8.2 Actual autostart (full check, needs reboot)
1. With **Launch at login** ON and Shh… running from `/Applications`, save your work.
2. **Apple menu → Restart** (or log out and back in).
3. After you log in, the Shh… mic icon should appear in the menu bar **without
   you launching it manually**.
- ▢ Pass ▢ Fail

> ⚠️ Notes:
> - `SMAppService` registers the app **by its current path**. The app must be in a
>   stable location (`/Applications/Shh.app`). If you move or rename it after
>   enabling, the login item breaks — re-toggle to re-register.
> - For an unsigned build, on the first autostart after reboot macOS may ask to
>   confirm the login item once. That's normal.
> - If it doesn't autostart: re-check System Settings → Login Items; toggle off
>   and on again in Shh… to re-register.

---

## 9. Permissions section
1. Preferences → Permissions shows three rows with traffic-light status.
2. Revoke Accessibility in System Settings → return to Shh… Preferences →
   the row flips to red ✗ within a moment (auto-refresh on app-active).
3. Re-grant → flips back to green ✓; the hotkey starts working again without
   a restart.
4. Each **Open Settings** button opens the correct Privacy pane.
- ▢ Pass ▢ Fail

---

## 10. Onboarding (first launch)
1. Reset the first-launch flag: quit Shh…, then run
   `defaults delete com.andrieiev.shh firstLaunchCompleted` in Terminal.
2. Relaunch → the welcome window appears.
3. It walks through Accessibility / Input Monitoring (required) and Microphone
   (optional); **Get started** is enabled once the required ones are granted.
4. After finishing, it does **not** reappear on the next launch.
- ▢ Pass ▢ Fail

---

## 11. App icon
- Finder → Applications → Shh shows the custom blue mic icon (not a generic
  placeholder). Same icon in ⌘-Tab if it ever appears, and in the Preferences
  window's title bar / Dock during the brief `.regular` activation.
- ▢ Pass ▢ Fail

---

## 12. Stable signature / permission survival (important)
> This validates the whole `dev-run.sh` + "Shh Dev" cert setup.
1. With permissions granted and the hotkey working, run `./scripts/dev-run.sh`
   again (rebuild + reinstall + relaunch).
2. The hotkey should **still work immediately** — no TCC reset, no re-grant,
   no "stopped reacting after rebuild".
- ▢ Pass ▢ Fail

---

## 13. Packaging & distribution
### 13.1 DMG build
- `./scripts/build-dmg.sh` produces `build/Shh.dmg`; opening it shows Shh… with
  a drag-to-Applications layout.
- ▢ Pass ▢ Fail

### 13.2 Gatekeeper bypass on a clean Mac
- On a Mac that has never seen the app: both install methods from the README
  (System Settings "Open Anyway", and the `xattr` terminal command) let the
  app launch.
- ▢ Pass ▢ Fail
