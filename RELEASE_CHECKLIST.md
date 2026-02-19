# Stable Release Checklist

All items must pass before publishing `vX.Y.Z`.

## CI and build integrity

- [ ] CI is green on main.
- [ ] `plutil -lint macos-app/CursorOutline/Info.plist` passes.
- [ ] Debug and Release `xcodebuild` checks pass.
- [ ] Native surface check passes (`./scripts/check_native_surface.sh`).

## Manual reliability matrix

- [ ] Fresh install from DMG to `/Applications` works.
- [ ] App launch and menu bar icon are present.
- [ ] Hotkey default works (press/hold/release).
- [ ] Hotkey rebind works.
- [ ] Hotkey conflict path is recoverable and user-facing.
- [ ] Single-display behavior is correct (no outline).
- [ ] Multi-display non-mirrored behavior is correct.
- [ ] Display unplug/replug behavior is stable.
- [ ] Mirroring toggle behavior is stable.
- [ ] Sleep/wake behavior is stable.
- [ ] Spaces/full-screen transitions are stable.

## Launch-at-login matrix

- [ ] Launch-at-login is OFF by default on first run.
- [ ] Enabling launch-at-login works from `/Applications`.
- [ ] Disabling launch-at-login works and persists.
- [ ] Enabling outside `/Applications` shows clear guidance.

## Diagnostics and supportability

- [ ] Diagnostics export succeeds.
- [ ] Bundle includes summary, settings, displays, and logs.
- [ ] Diagnostics contain no sensitive data.
- [ ] GitHub issue flow is functional from menu action.

## Signing and notarization

- [ ] Release workflow signs app with Developer ID.
- [ ] Notarization succeeds.
- [ ] Stapling succeeds.
- [ ] DMG passes Gatekeeper validation.

## Release publication

- [ ] DMG artifact uploaded to GitHub Release.
- [ ] Release notes include notable behavior changes and known issues.
- [ ] Post-release stabilization window and monitoring owner are assigned.
