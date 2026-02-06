#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hs_dir="$HOME/.hammerspoon"
app_link="$hs_dir/display-outline-for-your-cursor"
hs_init="$hs_dir/init.lua"
user_cfg="$hs_dir/display-outline-for-your-cursor.config.lua"

mkdir -p "$hs_dir"

if [ -e "$app_link" ] || [ -L "$app_link" ]; then
  backup="$hs_dir/display-outline-for-your-cursor.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$app_link" "$backup"
fi

ln -s "$repo_dir" "$app_link"

if [ ! -f "$user_cfg" ] && [ -f "$repo_dir/config.example.lua" ]; then
  cp "$repo_dir/config.example.lua" "$user_cfg"
fi

start_mark="-- DISPLAY_OUTLINE_FOR_CURSOR:START"
end_mark="-- DISPLAY_OUTLINE_FOR_CURSOR:END"
load_line='dofile(os.getenv("HOME") .. "/.hammerspoon/display-outline-for-your-cursor/init.lua")'

if [ ! -f "$hs_init" ]; then
  cat > "$hs_init" <<LUA
$start_mark
$load_line
$end_mark
LUA
else
  if ! grep -q "DISPLAY_OUTLINE_FOR_CURSOR:START" "$hs_init"; then
    cat >> "$hs_init" <<LUA

$start_mark
$load_line
$end_mark
LUA
  fi
fi

open -a "/Applications/Hammerspoon.app" || true
open -g "hammerspoon://reload" || true

echo "Installed: $app_link"
echo "Config: $hs_init"
echo "User config: $user_cfg"
