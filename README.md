# ScrollSplit

A lightweight macOS utility that keeps Natural Scrolling on the built-in trackpad while independently reversing vertical scroll direction for an external mouse.

---

## Download

> **Normal users: download the application from GitHub Releases — not from the "Code → Download ZIP" button.**

| | |
|---|---|
| **Latest release** | [github.com/sksonip/ScrollSplit/releases/latest](https://github.com/sksonip/ScrollSplit/releases/latest) |
| **Direct DMG download** | [ScrollSplit.dmg](https://github.com/sksonip/ScrollSplit/releases/latest/download/ScrollSplit.dmg) |

---

## What ScrollSplit Does

macOS applies a single scrolling-direction preference to all pointing devices. If you enable Natural Scrolling for your trackpad, your external mouse wheel also scrolls in the Natural direction — which many people find counterintuitive.

ScrollSplit intercepts scroll events at the session level and reverses vertical scroll direction only for events that are unambiguously from a physical mouse wheel:

- **MacBook trackpad** — keeps Natural Scrolling exactly as configured in System Settings
- **External mouse vertical wheel** — direction reversed independently
- **Horizontal scrolling** — left unchanged on all devices
- **Trackpad momentum and gestures** — never modified

ScrollSplit runs as a lightweight background utility with no Dock icon and no menu-bar icon. Configure it once and leave it running.

> **Note:** Continuous scroll events without a gesture phase cannot be reliably attributed to a specific device using public macOS APIs. To avoid ever accidentally reversing the trackpad, ScrollSplit leaves ambiguous continuous events unchanged. Some smooth-scrolling mouse software may therefore remain unaffected by design.

---

## Installation

1. Download **ScrollSplit.dmg** from [Releases](https://github.com/sksonip/ScrollSplit/releases/latest).
2. Open the DMG and drag **ScrollSplit** to your **Applications** folder.
3. Eject the DMG.
4. Open **ScrollSplit** from Applications.

### First-run Gatekeeper note

> ⚠️ **This release is not Developer ID notarized.** macOS Gatekeeper may block the app on first launch with a message like *"ScrollSplit cannot be opened because Apple cannot check it for malicious software."*
>
> To approve it:
> 1. Open **System Settings → Privacy & Security**.
> 2. Scroll down to the section that mentions ScrollSplit was blocked.
> 3. Click **Open Anyway**.
> 4. Confirm in the dialog that appears.
>
> You only need to do this once. Do **not** disable Gatekeeper globally.

5. Complete the permission setup that appears on first launch (see [Permissions](#permissions)).
6. Optionally enable **Launch at Login**.
7. Close the settings window — ScrollSplit continues running in the background.

---

## Permissions

ScrollSplit requires three permissions to intercept and modify scroll events. All are requested through standard macOS dialogs:

| Permission | Why it is needed |
|---|---|
| **Input Monitoring** | Required to receive scroll-wheel events from an external mouse at the session level. |
| **Accessibility** | Required for the Core Graphics event tap to be authorised by macOS. |
| **Scroll Control** (Post Event) | Required to modify and re-post scroll events back to the system. |

ScrollSplit will guide you to the correct pane in **Privacy & Security** if any permission is missing. After granting a permission, quit and reopen ScrollSplit once, then enable **Reverse Mouse Scrolling** again.

---

## Usage

When you open ScrollSplit, the settings window shows the current state:

- **Reverse Mouse Scrolling** — main on/off toggle. Enabling it activates the scroll intercept immediately if all permissions are granted.
- **Launch at Login** — registers ScrollSplit as a login item so it starts automatically on every login. macOS may ask for confirmation the first time.
- **Closing the window does not quit ScrollSplit.** The scrolling service continues running in the background.
- To reopen the settings window, launch ScrollSplit again from Applications (or the Dock/Finder).
- **Quit ScrollSplit** fully stops the application and the scrolling service.

---

## Privacy

Verified by source-code audit:

- **No telemetry** — ScrollSplit does not report usage or events to any service.
- **No analytics** — no analytics framework or endpoint is present.
- **No network communication** — ScrollSplit makes no outbound connections of any kind.
- **No data collection** — scroll activity, timing, and device information are processed locally and immediately discarded. Nothing is stored beyond the on/off preference in your local `UserDefaults`.

---

## Requirements

| | |
|---|---|
| **macOS** | 13.0 Ventura or later |
| **Architecture** | Apple Silicon (arm64) |
| **Xcode / Command Line Tools** | Not required to run the app |

> Normal users installing `ScrollSplit.dmg` do **not** need Xcode or any developer tools.

---

## Building from Source

Building from source requires Xcode 15 or later (or the matching Command Line Tools) and macOS 13+.

```sh
# Build a release app bundle → dist/ScrollSplit.app
make app

# Build a debug app bundle
make build

# Run smoke tests (no macOS daemon or permissions required)
make test

# Remove build artifacts
make clean
```

The build script (`scripts/build-app.sh`) automatically selects a signing identity from your Keychain, preferring **Apple Development**, then **Developer ID Application**, and warns before falling back to ad-hoc signing. Set `REQUIRE_STABLE_SIGNING=1` to fail instead of using ad-hoc signing, or `CODESIGN_IDENTITY` to select a specific identity.

The built app bundle is written to `dist/ScrollSplit.app`. Copy it to `/Applications`, open it, and grant the required permissions as described under [Installation](#installation).

---

## Technical Overview

- **Language:** Swift
- **UI framework:** AppKit (programmatic, no XIB/storyboard)
- **Event interception:** Core Graphics session-level event tap (`CGEvent.tapCreate` at `.cgSessionEventTap`)
- **Scroll classification:** Stateless classifier using phase, continuity, and delta fields on each `CGEvent`
- **Preferences:** `UserDefaults` (local, no iCloud sync)
- **Launch at Login:** `SMAppService.mainApp`
- **No third-party dependencies**

---

## License

ScrollSplit is available under the [MIT License](LICENSE).
