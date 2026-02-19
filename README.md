# Cursor Outline (macOS)

Cursor Outline is a native macOS menu bar app that:
- draws an outline around the display containing your cursor (only when 2+ non-mirrored displays are active)
- shows a cursor spotlight while you hold a global hotkey

No telemetry is collected. Diagnostics are local-only and exported only when you choose to export them.

## Requirements

- macOS 13 or newer
- Intel or Apple silicon Mac

## Install (GitHub Release DMG)

1. Open the latest release on [GitHub Releases](https://github.com/II-ricky-bobby-II/display-outline-for-your-cursor/releases).
2. Download `CursorOutline-<version>.dmg`.
3. Open the DMG and drag `Cursor Outline.app` into `Applications`.
4. Launch `Cursor Outline.app` from `Applications`.

## First run

- The app runs in the menu bar.
- Default hotkey is `Control + Option + Command + F` (hold).
- Open the menu bar icon for status, spotlight test, preferences, and diagnostics export.

## Preferences

Open menu bar icon -> `Preferences...`.

Available settings:
- Global hotkey (key + modifiers)
- Outline thickness and color
- Spotlight radius
- Launch at login (default OFF)

Launch at login requirement:
- The app must be installed in `/Applications` before launch-at-login can be enabled.

## Diagnostics and support

Use menu bar icon -> `Export Diagnostics...` to create a zip bundle containing:
- app version/build
- macOS version and CPU architecture
- display topology snapshot
- recent local app logs
- current app settings snapshot

When reporting bugs, attach this diagnostics archive to a GitHub issue.

## Development

### Run in Xcode

1. Open `/Users/blake/Documents/display-outline-for-your-cursor/macos-app/CursorOutline.xcodeproj`.
2. Select the `CursorOutline` scheme and `My Mac` destination.
3. Run.

### Native validation commands

From repo root:

```bash
plutil -lint macos-app/CursorOutline/Info.plist
xcodebuild -project macos-app/CursorOutline.xcodeproj -scheme CursorOutline -configuration Debug build CODE_SIGNING_ALLOWED=NO
./scripts/check_native_surface.sh
```

## Releases

- Stable releases are published from Git tags (`vX.Y.Z`).
- CI release workflow builds a universal app, signs with Developer ID, notarizes, staples, and uploads DMG assets.
- Updates are manual via GitHub Releases.
