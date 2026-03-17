# Module Overview

ClipboardFormatter is organized into focused Lua modules under `src/` for maintainability and testability.

## Directory Structure

```
src/
├── init.lua                 # Main spoon entry point (thin forwarding layer)
├── clipboard/               # Clipboard I/O operations
├── detectors/                # Pattern detectors
├── formatters/               # Output formatters
├── utils/                    # Shared utilities
├── spoon/                    # Spoon-internal modules
└── config/                   # Configuration management
```

## Clipboard Layer (`src/clipboard/`)

### `io.lua`
Cross-platform clipboard read/write operations with AppleScript fallback.

### `selection_modular.lua`
**Primary selection formatting module.** Implements strategy pattern with multiple acquisition methods:
1. Accessibility API (fastest, no clipboard interference)
2. Menu-based copy with clipboard polling
3. Eventtap keystroke fallback (slowest but most compatible)

Key components:
- `Config` - Configuration management
- `SelectionStrategies` - Pluggable acquisition methods
- `TextProcessor` - Text transformation pipeline
- `PasteOperations` - Paste handling
- `Results` - Result formatting
- `Orchestrator` - Coordinates the workflow

### `restore.lua`
Simple helper for restoring clipboard contents after formatting operations.

## Detector Layer (`src/detectors/`)

Each detector is created via `detector_factory.create()` with optional dependency injection. Detectors expose:
- `id` - Unique identifier
- `priority` - Processing order (lower number = higher priority)
- `match()` - Pattern matching function
- `dependencies` (optional) - Explicit dependency declarations

| Detector | Purpose |
|----------|---------|
| `arithmetic.lua` | Arithmetic expressions (`+`, `-`, `*`, `/`, `%`, `^`) |
| `combinations.lua` | Probability combination calculations |
| `date.lua` | Date range detection and formatting |
| `navigation.lua` | URL and file path navigation (side effects only) |
| `pd.lua` | Permanent Disability percentage-to-weeks conversions |
| `phone.lua` | Phone number detection and formatting |
| `time_calc.lua` | Time and duration calculations (`9am + 2h`, `now + 30m`) |
| `units.lua` | Unit conversions (`100km to mi`, `72F to C`) |

### `registry.lua`
Central detector registry that processes input through all detectors in priority order. Supports early exit optimization.

## Formatter Layer (`src/formatters/`)

Formatters provide reusable transformations used by detectors.

| Formatter | Purpose |
|-----------|---------|
| `arithmetic.lua` | Safe arithmetic evaluation with localization and currency support |
| `currency.lua` | Number-to-currency formatting |
| `date.lua` | Date parsing and range description building |
| `phone.lua` | Phone number annotation and formatting |

## Utility Layer (`src/utils/`)

| Module | Purpose |
|--------|---------|
| `clipboard_operations.lua` | Clipboard read/write operation helpers |
| `config_accessor.lua` | Safe nested config access with merging |
| `detector_factory.lua` | Factory for creating detectors with dependency injection |
| `error_handler.lua` | Safe error wrapping and logging |
| `hammerspoon.lua` | Hammerspoon-specific utilities |
| `logger.lua` | Structured logging with configurable levels |
| `logging_wrapper.lua` | Null-safe logger wrappers |
| `metrics.lua` | Performance and operation metrics tracking |
| `patterns.lua` | Centralized pattern registry with LRU caching |
| `pd_cache.lua` | PD mapping file loading and caching |
| `seed_strategies.lua` | Strategy pattern for seed expression extraction |
| `string_processing.lua` | Number localization, URL encoding, expression extraction |
| `strings.lua` | String manipulation utilities (trim, extractSeed, etc.) |
| `time_math.lua` | Time parsing and arithmetic utilities (used by `time_calc` detector) |
| `validation.lua` | Reusable validation utilities |

## Spoon Internal Modules (`src/spoon/`)

These modules were extracted from the monolithic `init.lua` to improve organization:

| Module | Purpose |
|--------|---------|
| `hooks.lua` | Hook system management (`applyHooks`, `loadHooksFromFile`) |
| `hotkeys.lua` | Hotkey binding and helper installation |
| `pd_mapping.lua` | PD mapping file loading and caching |
| `clipboard.lua` | Clipboard I/O wrapper |
| `processing.lua` | Core clipboard processing pipeline |

## Configuration Layer (`src/config/`)

| Module | Purpose |
|--------|---------|
| `defaults.lua` | Default configuration values |
| `constants.lua` | Centralized constants (priorities, time, cache, paths) |
| `schema.lua` | Type definitions for all configuration sections |
| `validator.lua` | Schema-based type validation |
| `manager.lua` | Configuration loading and merging |

## Entry Point (`src/init.lua`)

Thin forwarding layer that:
- Loads all modules
- Initializes the spoon
- Provides public API methods
- Maintains backward compatibility

## Dependency Injection

Detectors can optionally declare dependencies:

```lua
return function(deps)
    return DetectorFactory.create({
        id = "my_detector",
        dependencies = {"logger", "config", "formatters"},
        deps = deps,
        match = function(self, text, context)
            -- Use context.logger, context.config, context.formatters
        end,
    })
end
```

## Pattern Caching

The `patterns` module provides automatic LRU caching with configurable memory management:

```lua
local patterns = require("utils.patterns")
patterns.configure({
    maxCacheSize = 100,
    memoryThresholdMB = 10,
    autoCleanup = true,
})
```

## Test Helpers

Located in `test/`:

| Module | Purpose |
|--------|---------|
| `spec_helper.lua` | Test environment setup and Hammerspoon mocks |
| `mock_helper.lua` | Spy, stub, mock utilities for tests |
| `property_helper.lua` | Property-based testing with random generators |
