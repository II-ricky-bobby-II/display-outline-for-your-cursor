#!/usr/bin/env bash
set -euo pipefail

hs_dir="$HOME/.hammerspoon"
app_link="$hs_dir/display-outline-for-your-cursor"
hs_init="$hs_dir/init.lua"
user_cfg="$hs_dir/display-outline-for-your-cursor.config.lua"

if [ -L "$app_link" ]; then
  rm "$app_link"
fi

if [ -f "$hs_init" ]; then
  perl -0777 -i -pe 's/\n?-- DISPLAY_OUTLINE_FOR_CURSOR:START.*?-- DISPLAY_OUTLINE_FOR_CURSOR:END\n?//sg' "$hs_init"
fi

if [ -f "$user_cfg" ]; then
  backup="$hs_dir/display-outline-for-your-cursor.config.backup-$(date +%Y%m%d-%H%M%S).lua"
  mv "$user_cfg" "$backup"
fi

open -g "hammerspoon://reload" || true

echo "Uninstalled: $app_link"
