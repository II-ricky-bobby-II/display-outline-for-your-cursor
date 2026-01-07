cd "/Users/blake/Documents/Display Outline for Cursor"
cat > README.md <<'EOF'
# Display Outline for Cursor (Hammerspoon)

## Install
1) Install Hammerspoon
2) Download and unzip this repo
3) In Terminal, run:
   ./install.sh

## Configure
Copy the example config:
cp config.example.lua config.lua
Then edit config.lua and reload:
open -g "hammerspoon://reload"

## Uninstall
./uninstall.sh
EOF
