# Known Issues

## Outline may visually "catch up" after abrupt display topology changes

Symptom:
- During rapid monitor unplug/replug or Spaces/full-screen transitions, the outline can appear partially and then fully settle after the next cursor movement.

Workaround:
- Move the cursor once on the target display.
- If needed, toggle `Enabled` off/on from the menu.

## Hotkey conflicts with third-party tools

Symptom:
- Spotlight does not activate and status indicates hotkey is unavailable.

Workaround:
- Rebind to another hotkey in `Preferences...`.

## Launch-at-login requires app location policy

Symptom:
- Enabling launch-at-login fails when app runs outside `/Applications`.

Status:
- Intended behavior for reliability with `SMAppService`.

Workaround:
- Move app to `/Applications`, relaunch, then enable launch-at-login.
