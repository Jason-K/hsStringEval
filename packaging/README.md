# ClipboardFormatter Packaging

This directory contains the build system for packaging ClipboardFormatter as a distributable Hammerspoon Spoon.

## Contents

- **`make_spoon.lua`** — Automated build script for creating Spoon packages
- **`build/`** — Output directory for built packages (gitignored)

## Quick Start

### Building a Release

```bash
# Build with default version (read from src/init.lua)
lua packaging/make_spoon.lua

# Build with a specific version
lua packaging/make_spoon.lua --version 1.1.0

# Build to a custom output directory
lua packaging/make_spoon.lua --output-dir dist --version 1.1.0
```

Output artifacts:

```text
packaging/build/
  ClipboardFormatter.spoon/   ← installable Spoon bundle
  ClipboardFormatter-1.1.0.zip  ← distributable archive
```

### Testing Locally

After building, deploy to your local Hammerspoon and reload:

```bash
rsync -a --delete packaging/build/ClipboardFormatter.spoon/ \
  ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/
# Then reload Hammerspoon: ⌘⌥⌃R
```

### What the Builder Does

| Step | Action |
| ---- | ------ |
| 1 | Clean `packaging/build/ClipboardFormatter.spoon/` |
| 2 | `rsync src/` into the Spoon bundle root |
| 3 | Stamp `obj.version` in `init.lua` |
| 4 | Copy `config/user_hooks.example.lua` |
| 5 | Copy documentation (`README.md`, `docs/*.md`) |
| 6 | Generate `docs.json` via `tools/generate_docs_json.lua` |
| 7 | Write `VERSION` file |
| 8 | Write `INSTALL.md` |
| 9 | Create ZIP archive |

## Source Layout vs. Spoon Bundle

The `src/` directory maps 1-to-1 onto the Spoon bundle root:

```text
src/                           →  ClipboardFormatter.spoon/
  init.lua                     →    init.lua
  clipboard/                   →    clipboard/
  config/                      →    config/
  data/                        →    data/
  detectors/                   →    detectors/
  formatters/                  →    formatters/
  spoon/                       →    spoon/
  undo/                        →    undo/
  utils/                       →    utils/
config/user_hooks.example.lua  →    config/user_hooks.example.lua
docs/                          →    docs/
docs.json                      →    docs.json
```

No separate template `init.lua` is needed — `src/init.lua` is the Spoon entry point.
