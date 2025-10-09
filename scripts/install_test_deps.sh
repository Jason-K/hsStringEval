#!/usr/bin/env bash
set -euo pipefail

LUA_VERSION="${LUA_VERSION:-5.4}"

if ! command -v luarocks >/dev/null 2>&1; then
    echo "Error: luarocks is required to install test dependencies" >&2
    exit 1
fi

# Packages required to run the Busted test suite locally. Versions are pinned
# to match the environment used during development so future upgrades can be
# evaluated intentionally.
readonly ROCKS=(
    "busted 2.2.0-1"
    "lua_cliargs 3.0-1"
    "luassert 1.9.0-1"
    "say 1.4.1-3"
    "penlight 1.14.0-3"
    "lua-term 0.8-1"
    "luasystem 0.6.3-1"
    "mediator_lua 1.1.2-0"
)

install_rock() {
    local name="$1"
    local version="$2"
    if luarocks --lua-version="${LUA_VERSION}" show "${name}" "${version}" >/dev/null 2>&1; then
        echo "${name} ${version} already installed for Lua ${LUA_VERSION}"
        return
    fi
    echo "Installing ${name} ${version} for Lua ${LUA_VERSION}"
    luarocks --lua-version="${LUA_VERSION}" install "${name}" "${version}" --force
}

for entry in "${ROCKS[@]}"; do
    install_rock ${entry}
done

echo "Test dependencies installed for Lua ${LUA_VERSION}."
