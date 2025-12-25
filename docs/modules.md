# Module Overview

ClipboardFormatter is organized into focused Lua modules under `src/` to keep
runtime behavior testable outside of Hammerspoon. This document summarizes each
module and the responsibilities it owns.

## Clipboard Layer (`src/clipboard/`)

- `io.lua`: reads and writes the primary or "find" pasteboard, falling back to
  AppleScript when Hammerspoon APIs return empty strings.
- `selection_modular.lua`: **(primary)** coordinates copy/format/paste for the
  active selection using shared Hammerspoon helpers and the main formatter
  pipeline. Implements a strategy pattern with multiple acquisition methods
  (accessibility API, menu copy, eventtap keystroke) and modular sub-components
  (`Config`, `Debug`, `SelectionStrategies`, `TextProcessor`, `PasteOperations`,
  `Results`, `Orchestrator`) for clear separation of concerns.
- `restore.lua`: simple helper that restores clipboard contents when requested
  after formatting operations.

## Detector Layer (`src/detectors/`)

Each detector constructor accepts dependencies via `detector_factory.lua` and
returns an object exposing `id`, `priority`, and `match`. Detectors can optionally
declare a `dependencies` array to enable explicit dependency injection.

- `arithmetic.lua`, `date.lua`, `pd.lua`, `combinations.lua`, `phone.lua`:
  domain-specific matchers that transform strings into formatted results.
- `registry.lua`: table-driven detector registry that enforces priority ordering
  and returns the first successful match.

## Formatter Layer (`src/formatters/`)

Formatters provide reusable transformations leveraged by detectors or the
clipboard pipeline. Each formatter accepts an optional context table so the
detectors can share cached pattern handles and other context without referencing
globals directly.

- `arithmetic.lua`: safe arithmetic evaluation (supports `+`, `-`, `*`, `/`,
  `%`, `^`, and localized decimal separators) with optional currency output
  when dollar signs are present.
- `currency.lua`: number-to-currency formatting helpers.
- `date.lua`: inclusive date range description builder (handles textual month
  names, ISO timestamps, and inferred years for partial inputs).
- `phone.lua`: annotated phone number formatter.

## Utility Layer (`src/utils/`)

- `detector_factory.lua`: factory for creating standardized detectors with
  dependency injection support. Detectors can optionally declare a `dependencies`
  array (e.g., `{"logger", "config", "formatters"}`) which will be validated and
  injected. Backward compatible - detectors work without explicit declarations.
- `hammerspoon.lua`: shared helpers for interacting with Hammerspoon APIs
  (pasteboard operations, AppleScript/eventtap copy and paste, window focus).
- `logger.lua`: lightweight structured logger used during tests and runtime.
  Supports configurable levels per sink (console/file), structured JSON output,
  and fallback mode for non-Hammerspoon environments.
- `patterns.lua`: **(unified)** centralized pattern registry with LRU cache and
  memory-aware caching. Exposes compiled helpers (`match`, `contains`, `gmatch`)
  and configuration via `configure({maxCacheSize, memoryThresholdMB, autoCleanup})`.
  Consolidates functionality from the original `patterns.lua` and
  `patterns_memory_aware.lua` modules.
- `pd_cache.lua`: memoizes PD mapping files and exposes helpers for lookup and
  cache invalidation.
- `strings.lua`: trimming, splitting, equality, and normalization utilities.

## Entry Point (`src/init.lua`)

The spoon entry point wires detectors, formatters, hooks, clipboard helpers, and
configuration values into a single object that can be loaded by Hammerspoon or
required directly by the test harness. It exposes helper methods such as
`registerDetector`, `registerFormatter`, `getFormatter`, `setLogLevel`, and
`installHotkeyHelpers`/`removeHotkeyHelpers` so runtime hooks can extend or
override behaviour without editing core modules while optionally restoring
legacy global hotkey convenience wrappers.

## Architecture Notes

### Dependency Injection
Detectors use `detector_factory.create()` which supports optional dependency
declaration:
```lua
-- Detector with explicit dependencies
return function(deps)
    return DetectorFactory.create({
        id = "my_detector",
        dependencies = {"logger", "config", "formatters"},
        deps = deps,
        ...
    })
end
```

### Pattern Caching
The `patterns` module provides automatic LRU caching with configurable memory
management:
```lua
local patterns = require("src.utils.patterns")
patterns.configure({
    maxCacheSize = 100,
    memoryThresholdMB = 10,
    autoCleanup = true,
})
```

### Selection Strategies
`selection_modular` implements multiple fallback strategies for acquiring
selected text:
1. Accessibility API (fastest, no clipboard interference)
2. Menu-based copy with clipboard polling
3. Eventtap keystroke fallback (longest delay)
