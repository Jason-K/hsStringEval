#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
cd "${ROOT_DIR}"

if ! command -v luacheck >/dev/null 2>&1; then
    echo "luacheck not found; install it with 'luarocks install luacheck'" >&2
    exit 1
fi

luacheck src test
