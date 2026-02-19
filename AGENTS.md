# End-of-session workflow

## Run this suite at the end of every session

Execute from repo root (`/Users/blake/Documents/display-outline-for-your-cursor`):

1) Validate macOS app metadata
```
plutil -lint macos-app/CursorOutline/Info.plist
```

2) Build native app (no code signing)
```
xcodebuild -project macos-app/CursorOutline.xcodeproj -scheme CursorOutline -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

3) Verify no Hammerspoon/Lua coupling remains in native docs/app paths
```
if rg -n -S '(?i)hammerspoon|\.lua\b' README.md CONTRIBUTING.md macos-app; then
  echo "Unexpected Hammerspoon/Lua reference found"
  exit 1
fi
```

## Post-session branch/deploy workflow (manual approval required)

1. `git status --short`
2. `git add -A`
3. `git commit -m "<type>: <summary>"`
4. `git push`
5. `gh pr create --fill`
6. Review/merge PR (or use `gh pr merge`)
7. `git fetch --prune`
8. `git checkout main`
9. `git pull --ff-only`
10. Delete stale branches:
   - `git branch -d <session-branch>`
   - `git push origin --delete <session-branch>` (if remote cleanup needed)
11. Deploy target-specific release flow (manual: `/Users/blake/.codex/skills/vercel-deploy` or project-specific deploy command)
