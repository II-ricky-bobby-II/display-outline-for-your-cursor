# Contributing

## Development setup

1. Clone this repo.
2. Open `/Users/blake/Documents/display-outline-for-your-cursor/macos-app/CursorOutline.xcodeproj` in Xcode.
3. Build and run the `CursorOutline` scheme.

## Before opening a PR

Run from repo root:

```bash
plutil -lint macos-app/CursorOutline/Info.plist
xcodebuild -project macos-app/CursorOutline.xcodeproj -scheme CursorOutline -configuration Debug build CODE_SIGNING_ALLOWED=NO
./scripts/check_native_surface.sh
```

## Pull requests

- Keep changes focused and explain user-facing behavior changes.
- Include screenshots or short recordings for visual behavior changes.
- Note any display/lifecycle scenarios you manually tested (multi-display, sleep/wake, Spaces, hot-plug).

## Maintainer release notes

Releases are created from tags matching `vX.Y.Z` and handled by `/Users/blake/Documents/display-outline-for-your-cursor/.github/workflows/release.yml`.

Required GitHub Actions secrets:
- `APPLE_CERTIFICATE_P12` (base64-encoded `.p12` Developer ID Application certificate)
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY` (full identity string shown by `security find-identity -v -p codesigning`)
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
