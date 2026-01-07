set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$HOME/.hammerspoon"

if [ -e "$target" ] || [ -L "$target" ]; then
  backup="$HOME/.hammerspoon.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$target" "$backup"
  echo "Backed up existing ~/.hammerspoon to: $backup"
fi

ln -s "$repo_dir" "$target"
echo "Linked $repo_dir -> $target"

open -a "/Applications/Hammerspoon.app" || true
open -g "hammerspoon://reload" || true

echo "Done."
