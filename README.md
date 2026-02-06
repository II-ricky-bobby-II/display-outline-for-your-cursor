# Cursor Outline (macOS)

A lightweight cursor spotlight and active-display outline for macOS.

**Hotkey:** `Ctrl` + `Alt` + `Cmd` + `F` (hold)

This repo currently contains:
- A native macOS menu bar app (work-in-progress): `macos-app/`
- A Hammerspoon implementation: `init.lua` (install via `./install.sh`)

## Native App (WIP)
1) Open `macos-app/CursorOutline.xcodeproj` in Xcode
2) Select a signing team if Xcode prompts you
3) Run

Behavior (native app):
- Cursor spotlight shows while the hotkey is held.
- Display outline only shows when you have 2+ (non-mirrored) displays, and only on the display containing the cursor.

## Hammerspoon Version
Draws an always-on-top outline around the **active display**, plus a temporary **cursor spotlight** while holding a hotkey.

## Features
- Menubar icon with quick settings (style, color, thickness, sound).
- Auto-hide in full-screen video and screen sharing contexts (heuristic).
- Settings persist via Hammerspoon `hs.settings` (no config edits needed for most tweaks).

## Install
1) Install Hammerspoon
2) Download and unzip this repo
3) In Terminal, run:
   ./install.sh

## Configure
- The installer copies `config.example.lua` to `~/.hammerspoon/display-outline-for-your-cursor.config.lua` (if it doesn't already exist).
- Edit your config file, then reload Hammerspoon:
  `open -g "hammerspoon://reload"`

### Config Options
`~/.hammerspoon/display-outline-for-your-cursor.config.lua` returns a Lua table. Supported keys:
- `enabled` (boolean)
- `speedMultiplier` (number)
- `borderExtraPixels` (number)
- `iconPath` (string, relative to this repo)

## Manual Install (No Scripts)
1) Symlink the repo into your Hammerspoon config:
   `ln -s /path/to/display-outline-for-your-cursor ~/.hammerspoon/display-outline-for-your-cursor`
2) Add this to `~/.hammerspoon/init.lua`:
   `dofile(os.getenv("HOME") .. "/.hammerspoon/display-outline-for-your-cursor/init.lua")`
3) Reload Hammerspoon: `open -g "hammerspoon://reload"`

## Uninstall
./uninstall.sh
