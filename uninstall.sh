set -euo pipefail

target="$HOME/.hammerspoon"
if [ -L "$target" ]; then
  rm "$target"
  echo "Removed symlink ~/.hammerspoon"
else
  echo "~/.hammerspoon is not a symlink. Not touching it."
fi

open -g "hammerspoon://reload" || true
echo "Done."
