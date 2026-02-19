# Troubleshooting

## Hotkey does not trigger spotlight

1. Open `Preferences...` and change the hotkey to a different key/modifier combination.
2. Avoid combinations used by macOS or other utilities.
3. Check menu bar status text:
   - `Hotkey: ...` means registered.
   - `Hotkey unavailable (in use)` means conflict.

## Outline does not appear

Expected behavior:
- Outline only appears with 2 or more non-mirrored displays.
- Outline appears only on the display containing the cursor.

If it still does not appear:
1. Toggle menu item `Enabled` off and on.
2. Move cursor across display boundaries again.
3. Disconnect/reconnect external displays and retry.
4. Ensure display mirroring is off if you expect per-display behavior.

## Display changes cause delayed or stale outline

1. Wait a moment after hot-plug/sleep/wake so display topology settles.
2. Move the cursor once on the target display to force immediate active-display update.
3. If issue persists, export diagnostics and file a bug report.

## Launch at login cannot be enabled

Cause:
- App is not running from `/Applications`.

Fix:
1. Move `Cursor Outline.app` into `/Applications`.
2. Relaunch app from `/Applications`.
3. Enable `Launch at login` again in `Preferences...`.

## App fails Gatekeeper checks after download

1. Download release DMG only from GitHub Releases.
2. Ensure you are using a stable tag release (`vX.Y.Z`).
3. If Gatekeeper still blocks launch, report the release tag and attach diagnostics.

## How to file an actionable bug

1. Use menu bar icon -> `Export Diagnostics...`.
2. Open GitHub issue from menu bar -> `Report Issue`.
3. Attach the diagnostics zip and include exact steps and display setup.
