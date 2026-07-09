#!/usr/bin/env bash
set -euo pipefail
# Ensure `scripts/install_test_deps.sh` has been run so LuaRocks dependencies are available.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
cd "${ROOT_DIR}"

LUA_VERSION="${LUA_VERSION:-5.4}"
if [ -d "/opt/homebrew/opt/lua@5.4" ]; then
    LUA_DIR="/opt/homebrew/opt/lua@5.4"
else
    LUA_DIR="${LUA_DIR:-}"
fi

# Ensure LuaRocks paths (including busted modules) are available
if command -v luarocks >/dev/null 2>&1; then
    if [ -n "${LUA_DIR}" ]; then
        eval "$(luarocks --lua-version="${LUA_VERSION}" --lua-dir="${LUA_DIR}" path)"
    else
        eval "$(luarocks --lua-version="${LUA_VERSION}" path)"
    fi
fi

BUSTED_BIN=""
if [ -x "${HOME}/.luarocks/bin/busted" ]; then
    BUSTED_BIN="${HOME}/.luarocks/bin/busted"
elif command -v busted >/dev/null 2>&1; then
    BUSTED_BIN="$(command -v busted)"
fi

if [ -z "${BUSTED_BIN}" ]; then
    echo "Error: busted is required to run tests" >&2
    echo "Run: ./scripts/install_test_deps.sh" >&2
    exit 1
fi

# Ensure project sources and test helpers are discoverable via require
export LUA_PATH="${ROOT_DIR}/src/?.lua;${ROOT_DIR}/src/?/init.lua;${ROOT_DIR}/test/?.lua;${ROOT_DIR}/test/?/init.lua;${LUA_PATH:-}"

if [ "$#" -eq 0 ]; then
    set -- test
fi

# Load spec_helper for custom module loader
"${BUSTED_BIN}" --helper=spec_helper "$@"
