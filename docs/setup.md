# End-to-End Setup

This guide walks through installing dependencies, running the automated tests,
copying the ClipboardFormatter spoon into Hammerspoon, and enabling optional
runtime features such as structured logging and global hotkey helpers.

## 1. Install Prerequisites

The project targets Lua 5.4 and expects `luarocks` to be available. On macOS you
can install both via Homebrew:

```bash
brew install lua luarocks
```

Install Hammerspoon if it is not already present:

```bash
brew install --cask hammerspoon
```

## 2. Clone the Repository

```bash
git clone https://github.com/Jason-K/Hammerflow.spoon.git
cd Hammerflow.spoon
```

## 3. Install LuaRocks Dependencies

Run the helper script once per environment. It pins the Busted test runner and
other libraries required by the suite:

```bash
scripts/install_test_deps.sh
```

Override the Lua version if you maintain multiple toolchains:

```bash
LUA_VERSION=5.4 scripts/install_test_deps.sh
```

## 4. Run the Test Suite

Execute the project tests to confirm tooling is configured correctly. The script
appends the appropriate `LUA_PATH`/`LUA_CPATH` entries so the modules resolve
without further setup.

```bash
./scripts/test.sh
```

## 5. Deploy the Spoon

Copy the `src/` directory into your Hammerspoon Spoons folder or add the project
root to `package.path`:

```bash
mkdir -p ~/.hammerspoon/Spoons/ClipboardFormatter.spoon
rsync -a src/ ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/
```

If you plan to maintain local hooks, copy the example file so it persists across
updates:

```bash
cp config/user_hooks.example.lua ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/config/user_hooks.lua
```

## 6. Configure and Load in Hammerspoon

In `~/.hammerspoon/init.lua`, load the spoon, supply any configuration overrides,
and bind hotkeys. The example below enables structured logging, installs global
helpers, and demonstrates a custom detector hook.

```lua
local ClipboardFormatter = hs.loadSpoon("ClipboardFormatter")
ClipboardFormatter:init({
    config = {
        logging = {
            level = "info",
            structured = true,
            includeTimestamp = false,
        },
        hotkeys = {
            installHelpers = true,
        },
        templates = {
            arithmetic = "${input} = ${result}",
        },
    },
    hooks = {
        detectors = function(formatter)
            formatter:registerDetector({
                id = "custom:example",
                priority = 25,
                match = function(_, text)
                    if text == "ping" then
                        return "pong"
                    end
                end,
            })
        end,
    },
})

ClipboardFormatter:bindHotkeys({
    format = { { "ctrl", "alt" }, "f" },
    formatSelection = { { "ctrl", "alt" }, "s" },
})
```

## 7. Optional Enhancements

- **Logging:** Adjust `config.logging` to change levels at runtime via
  `clipboardFormatter:setLogLevel("error")`, or set `structured = false` to
  revert to plain text output.
- **Hotkey Helpers:** When `hotkeys.installHelpers = true`, the spoon installs
  global `FormatClip()` and `FormatSelected()` functions for legacy bindings
  (remove them later with `removeHotkeyHelpers()`).
- **Hooks & Formatters:** Use `hooks.formatters` to register or override
  formatter modules before detectors run, enabling custom renderers or template
  engines without editing core files.

With these steps complete, reload Hammerspoon (⌘+⌥+⌃+R by default) and test the
bindings. The spoon will monitor clipboard or selection content and apply the
appropriate formatter based on the detectors you have enabled.
