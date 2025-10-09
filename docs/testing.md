# Testing ClipboardFormatter Modules

This project relies on Lua 5.4 and the Busted test framework. To reproduce the
local setup, install the required LuaRocks packages before running the suite.

## Prerequisites

- Homebrew Lua 5.4 (or another Lua 5.4 installation on your `PATH`)
- `luarocks` configured for that Lua 5.4 installation

## Installing LuaRocks dependencies

From the project root run:

```bash
scripts/install_test_deps.sh
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
