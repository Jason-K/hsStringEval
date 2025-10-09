# ClipboardFormatter (Hammerflow.spoon)

This repository contains the refactored ClipboardFormatter spoon for
Hammerspoon together with standalone Lua modules and an automated test suite.
The code has been extracted into reusable components under `src/` so the
clipboard workflow can be tested outside of the Hammerspoon runtime.

## Features

- Clipboard and selection helpers with AppleScript/eventtap fallbacks
- Detectors for arithmetic, date ranges (textual months, ISO timestamps, and
  year inference), permanent disability (PD) conversions, combinations, and
  annotated phone numbers
- Formatter utilities for currency, dates, arithmetic (supports `%`, `^`,
  localized numbers, and configurable output templates), and phone annotations
- Cached regex helpers shared across detectors and formatters to avoid
  recompilation
- Clipboard processing throttle to skip redundant formatting requests
- Configurable hooks to extend detector and formatter behaviour at runtime
- Logging controls with configurable levels and optional structured output
- Optional global hotkey helpers (`FormatClip`, `FormatSelected`) for quick bindings
- Comprehensive Busted-based unit tests with a mocked `hs` environment

## Repository Layout

```text
src/
  clipboard/      -- clipboard IO, selection handling, restoration helpers
  detectors/      -- detector constructors used by ClipboardFormatter
  formatters/     -- formatter implementations shared by detectors
  utils/          -- string, pattern, logger, hammerspoon, and PD cache utilities
  init.lua        -- primary ClipboardFormatter spoon module

config/
  launcher-config.lua  -- example configuration for hsLauncher integration
  user_hooks.example.lua -- sample hook file loaded at runtime

docs/
  setup.md       -- end-to-end installation and integration walkthrough
  testing.md      -- instructions for installing LuaRocks dependencies and running tests
  modules.md      -- summary of module responsibilities
  configuration.md -- explanation of available settings and hooks
  release_checklist.md -- packaging steps for publishing updates

scripts/
  install_test_deps.sh -- installs the LuaRocks packages required by the tests
  test.sh               -- runs the Busted suite with appropriate paths
  lint.sh              -- runs luacheck when available

test/
  *.lua            -- unit specs covering all modules
```

## Prerequisites

- macOS with [Hammerspoon](https://www.hammerspoon.org/) (for runtime usage)
- Lua 5.4 installed via Homebrew or comparable package manager
- [`luarocks`](https://luarocks.org/) configured for your Lua installation

## Quick Start

1. Clone the repository and install the LuaRocks dependencies via `scripts/install_test_deps.sh`.
2. Verify the suite using `./scripts/test.sh` (ensures Lua paths are configured and the mocked `hs` environment works locally).
3. Copy `src/` into `~/.hammerspoon/Spoons/ClipboardFormatter.spoon/` (or add the repo to your `package.path`).
4. Optionally copy `config/user_hooks.example.lua` to `config/user_hooks.lua` and customize logging, hotkeys, templates, or additional detectors.
5. Load the spoon in `~/.hammerspoon/init.lua`, bind hotkeys or enable the global helpers, and adjust configuration overrides as needed.

See `docs/setup.md` for a detailed walkthrough that covers dependency setup, testing, deployment, and runtime configuration.

## Installing Test Dependencies

Run the helper script once per environment to install the pinned LuaRocks
packages used by the test suite:

```bash
scripts/install_test_deps.sh
```

The script targets Lua 5.4 by default. Override `LUA_VERSION` if you maintain a
compatible alternate Lua installation, for example:

```bash
LUA_VERSION=5.4 scripts/install_test_deps.sh
```

See `docs/testing.md` for the explicit package list and additional details.

## Running Tests

After installing dependencies:

```bash
./scripts/test.sh
```

`scripts/test.sh` ensures the LuaRocks paths are available and exports
`LUA_PATH` entries for the `src/` and `test/` trees so Busted can locate project
modules and helpers.

## Linting

Optionally run the luacheck configuration used in development:

```bash
./scripts/lint.sh
```

If `luacheck` is not installed, the script prints guidance on installing it via
LuaRocks.

## Continuous Integration

GitHub Actions (`.github/workflows/ci.yml`) runs `scripts/lint.sh` and
`scripts/test.sh` on pushes to `main` and feature branches, as well as on pull
requests, ensuring consistency with the local development workflow.

## Using the Spoon in Hammerspoon

1. Copy the `src/` contents into `~/.hammerspoon/Spoons/ClipboardFormatter.spoon/`
   (or use your preferred deployment flow).
2. Place any optional hook implementations under `config/` and update
   `user_hooks.lua` to require them.
3. Load the spoon from your `~/.hammerspoon/init.lua` and bind the provided
   hotkeys:

   ```lua
   local ClipboardFormatter = hs.loadSpoon("ClipboardFormatter")
   ClipboardFormatter:bindHotkeys({
       format = { { "ctrl", "alt" }, "f" },
       formatSelection = { { "ctrl", "alt" }, "s" },
   })
   ```

   Adjust the hotkeys and configuration paths as needed.

## Contributing

- Run `./scripts/test.sh` before opening a pull request to ensure unit tests
  pass, and `./scripts/lint.sh` to keep style consistent (matching the CI
  workflow).
- Keep Lua files ASCII-only unless non-ASCII characters are required for test
  coverage or functionality.
- When adding modules that reference the `ClipboardFormatter.src.*` namespace,
  ensure they can be required both within Hammerspoon and the standalone test
  harness.

## License

Distributed under the MIT License. See `LICENSE` (if present) or the header in
`src/init.lua` for details.
