#!/usr/bin/env bash
set -euo pipefail
# Ensure `scripts/install_test_deps.sh` has been run so LuaRocks dependencies are available.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
cd "${ROOT_DIR}"

if ! command -v busted >/dev/null 2>&1; then
    echo "Error: busted is required to run tests" >&2
    exit 1
fi

# Ensure LuaRocks paths (including busted modules) are available
if command -v luarocks >/dev/null 2>&1; then
    eval "$(luarocks --lua-version=5.4 path)"
fi

# Ensure project sources and test helpers are discoverable via require
export LUA_PATH="${ROOT_DIR}/src/?.lua;${ROOT_DIR}/src/?/init.lua;${ROOT_DIR}/test/?.lua;${ROOT_DIR}/test/?/init.lua;${LUA_PATH:-}"

if [ "$#" -eq 0 ]; then
    set -- test
fi

# Load spec_helper for custom module loader
busted --helper=spec_helper "$@"
