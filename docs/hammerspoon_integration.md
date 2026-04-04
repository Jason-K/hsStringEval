# Hammerspoon Integration Workflow

This guide documents the two integration modes for ClipboardFormatter and the
workflow for developing, testing, and deploying changes.

## Source of Truth

Treat `~/Scripts/apps/hammerspoon/hsStringEval` as the canonical source for
ClipboardFormatter code, tests, and documentation. Never edit files directly
inside `~/.hammerspoon/Spoons/ClipboardFormatter.spoon/`; always work in the
source tree and deploy from there.

## Integration Modes

### Mode 1: Direct Require (Development)

`~/.hammerspoon/init.lua` extends `package.path` to include the `hsStringEval`
root and loads the spoon with `require`:

```lua
local hsStringEvalRoot = os.getenv("HOME") .. "/Scripts/apps/hammerspoon/hsStringEval"
package.path = package.path .. ";" .. hsStringEvalRoot .. "/?.lua"
package.path = package.path .. ";" .. hsStringEvalRoot .. "/?/init.lua"

local ok, formatter = pcall(require, "src.init")
if ok and formatter then
    formatter.spoonPath = hsStringEvalRoot .. "/src"
    local instance = formatter:init({ config = { ... } })
    if instance then
        instance:installHotkeyHelpers()
    end
end
```

This mode picks up every file change immediately on Hammerspoon reload —
no rsync step needed during active development.

### Mode 2: Spoon Deploy (Production)

Build the Spoon and deploy via the packaging script:

```bash
cd ~/Scripts/apps/hammerspoon/hsStringEval
lua packaging/make_spoon.lua --version 1.0
rsync -a --delete packaging/build/ClipboardFormatter.spoon/ \
  ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/
```

Or deploy directly from source (skips the build step):

```bash
rsync -a src/ ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/
cp docs.json ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/docs.json
```

Then in `~/.hammerspoon/init.lua`:

```lua
local ClipboardFormatter = hs.loadSpoon("ClipboardFormatter")
ClipboardFormatter:init({ config = { ... } })
ClipboardFormatter:installHotkeyHelpers()
```

When loaded this way, `moduleName` resolves to `"ClipboardFormatter.init"` and
the spoon's internal requires use the `ClipboardFormatter.*` namespace
automatically.

## Local Development Loop

1. **Edit** files under `src/`, `config/`, or `docs/` in `hsStringEval`.

2. **Test** with the Busted suite:

   ```bash
   ./scripts/test.sh
   ```

3. **Reload Hammerspoon** (Mode 1 — direct require picks up changes immediately):

   ```text
   ⌘+⌥+⌃+R
   ```

4. **Commit and push** when the change is finished:

   ```bash
   git commit -am "feat: describe the change"
   git push origin main
   ```

5. **Deploy** if running in Mode 2:

   ```bash
   # Full build + deploy
   lua packaging/make_spoon.lua && \
   rsync -a --delete packaging/build/ClipboardFormatter.spoon/ \
     ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/

   # Quick deploy from source (skip the build step)
   rsync -a src/ ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/
   cp docs.json ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/docs.json
   ```

   Then reload Hammerspoon.

## Troubleshooting

- **Changes not reflected after reload:** Confirm `package.path` in
  `~/.hammerspoon/init.lua` points at the correct `hsStringEval` root and that
  no stale `.luac` bytecode files are present under `src/`.
- **`require` errors in Spoon Deploy mode:** Ensure the rsync completed
  successfully and that `init.lua` is at the bundle root
  (`ClipboardFormatter.spoon/init.lua`).
- **`spoonPath` not set:** When using direct require (Mode 1), set
  `formatter.spoonPath` before calling `:init()` so PD mapping file lookups
  resolve correctly. `hs.loadSpoon` (Mode 2) sets this automatically.
