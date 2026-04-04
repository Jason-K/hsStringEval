# AGENTS.md

This file provides repository-specific instructions for coding agents working on ClipboardFormatter source.

## Scope

- Canonical source path: `/Users/jason/Scripts/apps/hammerspoon/hsStringEval`
- Runtime deployment target: `/Users/jason/.config/hammerspoon/Spoons/ClipboardFormatter.spoon`
- Never edit the runtime spoon directly. Make all edits in source, then deploy.

## Required Workflow After Source Changes

1. Run tests:
   - `./scripts/test.sh`
2. Run lint:
   - `./scripts/lint.sh`
3. Regenerate docs metadata if public API/docstrings changed:
   - `lua tools/generate_docs_json.lua`
4. Deploy source to the local spoon bundle:

```bash
mkdir -p /Users/jason/.config/hammerspoon/Spoons/ClipboardFormatter.spoon
rsync -a --delete --exclude '.git' --exclude '__pycache__' --exclude '.DS_Store' \
  /Users/jason/Scripts/apps/hammerspoon/hsStringEval/src/ \
  /Users/jason/.config/hammerspoon/Spoons/ClipboardFormatter.spoon/
cp /Users/jason/Scripts/apps/hammerspoon/hsStringEval/docs.json \
  /Users/jason/.config/hammerspoon/Spoons/ClipboardFormatter.spoon/docs.json
cp /Users/jason/Scripts/apps/hammerspoon/hsStringEval/CLAUDE.md \
  /Users/jason/.config/hammerspoon/Spoons/ClipboardFormatter.spoon/CLAUDE.md
```

## Post-Deploy Verification

1. Reload Hammerspoon.
2. Trigger ClipboardFormatter from hotkey (for example `FormatClip` or `FormatSelection`).
3. Confirm no module load errors in Hammerspoon console.

## Development Notes

- Primary spoon entrypoint is `src/init.lua`.
- Keep Lua changes compatible with Hammerspoon runtime conventions.
- Do not leave placeholders or partial implementations.
