#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
cd "${ROOT_DIR}"

LUA_VERSION="${LUA_VERSION:-5.4}"
ROCKS_TREE="${ROCKS_TREE:-${HOME}/.luarocks}"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-1}"

if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is required on macOS for bootstrap" >&2
    exit 1
fi

echo "Installing Homebrew dependencies (lua@${LUA_VERSION}, luarocks)..."
brew install "lua@${LUA_VERSION}" luarocks

if [ -d "/opt/homebrew/opt/lua@${LUA_VERSION}" ]; then
    LUA_DIR="/opt/homebrew/opt/lua@${LUA_VERSION}"
elif [ -d "/usr/local/opt/lua@${LUA_VERSION}" ]; then
    LUA_DIR="/usr/local/opt/lua@${LUA_VERSION}"
else
    echo "Error: Could not locate Homebrew lua@${LUA_VERSION} installation" >&2
    exit 1
fi

echo "Configuring LuaRocks user scope for Lua ${LUA_VERSION}..."
luarocks --lua-version="${LUA_VERSION}" config --scope user lua_dir "${LUA_DIR}"

# Some machines inherit a LIBFLAG with -all_load that breaks rock shared object builds.
luarocks --lua-version="${LUA_VERSION}" config --scope user variables.LIBFLAG -- '-bundle -undefined dynamic_lookup'

echo "Installing pinned test rocks into ${ROCKS_TREE}..."
LUA_VERSION="${LUA_VERSION}" LUA_DIR="${LUA_DIR}" ROCKS_TREE="${ROCKS_TREE}" \
    "${SCRIPT_DIR}/install_test_deps.sh"

echo "Bootstrap complete."
echo "If needed, add this to your shell profile:"
echo "  export PATH=\"${HOME}/.luarocks/bin:\$PATH\""

if [ "${RUN_SMOKE_TESTS}" = "1" ]; then
    echo "Running smoke tests..."
    ./scripts/test.sh test/detectors_spec.lua test/init_spec.lua
fi
