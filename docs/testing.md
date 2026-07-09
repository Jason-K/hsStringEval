# Testing ClipboardFormatter Modules

This project relies on Lua 5.4 and the Busted test framework. To reproduce the
local setup, install the required LuaRocks packages before running the suite.

## Quick Start (New Machine)

For a fresh macOS machine, run the bootstrap script:

```bash
./scripts/bootstrap_test_env.sh
```

What it does:

- Installs `lua@5.4` and `luarocks` via Homebrew.
- Configures LuaRocks user scope to use the `lua@5.4` keg path.
- Applies a safer macOS linker flag for native rocks.
- Installs pinned test dependencies (including Busted).
- Runs smoke tests (`detectors_spec.lua` and `init_spec.lua`).

Optional flags:

```bash
RUN_SMOKE_TESTS=0 ./scripts/bootstrap_test_env.sh
ROCKS_TREE="$HOME/.luarocks" ./scripts/bootstrap_test_env.sh
LUA_VERSION=5.4 ./scripts/bootstrap_test_env.sh
```

## Prerequisites

- Homebrew Lua 5.4 (or another Lua 5.4 installation on your `PATH`)
- `luarocks` configured for that Lua 5.4 installation

## Installing LuaRocks dependencies

From the project root run:

```bash
scripts/install_test_deps.sh
```

If you need to force a specific Lua installation and/or rocks tree:

```bash
LUA_VERSION=5.4 LUA_DIR=/opt/homebrew/opt/lua@5.4 ROCKS_TREE="$HOME/.luarocks" scripts/install_test_deps.sh
```

The script installs the versions verified during development:

| Rock | Version |
| ---- | ------- |
| `busted` | `2.2.0-1` |
| `lua_cliargs` | `3.0-1` |
| `luassert` | `1.9.0-1` |
| `say` | `1.4.1-3` |
| `penlight` | `1.14.0-3` |
| `lua-term` | `0.8-1` |
| `luasystem` | `0.6.3-1` |
| `mediator_lua` | `1.1.2-0` |

> The script defaults to Lua 5.4; override the `LUA_VERSION` environment
> variable if you need to target a different Lua version supported by your
> installation.

## Running the test suite

With dependencies in place:

```bash
./scripts/test.sh
```

`test.sh` automatically configures `LUA_PATH` so the Busted suite can find
project modules and helpers.

## Common macOS Issues

### `busted` points to the wrong Lua path

Symptom:

```text
/opt/homebrew/bin/busted: ... /opt/homebrew/opt/lua/bin/lua5.4: No such file or directory
```

Cause: Homebrew `busted` wrapper references `/opt/homebrew/opt/lua`, but that
may point to a different major Lua version.

Fixes:

- Prefer `~/.luarocks/bin/busted` (handled by `scripts/test.sh`).
- Re-run `./scripts/bootstrap_test_env.sh` to repair LuaRocks config.

### LuaRocks uses wrong Lua version

Symptom:

```text
Error: Lua 5.4 interpreter not found at /opt/homebrew/opt/lua
```

Fix:

```bash
luarocks --lua-version=5.4 config --scope user lua_dir /opt/homebrew/opt/lua@5.4
```

### Native rock build failures on macOS

Some environments carry an aggressive linker flag (`-all_load`) that can break
LuaRocks native builds.

Fix:

```bash
luarocks --lua-version=5.4 config --scope user variables.LIBFLAG -- '-bundle -undefined dynamic_lookup'
```

Then rerun:

```bash
scripts/install_test_deps.sh
```
