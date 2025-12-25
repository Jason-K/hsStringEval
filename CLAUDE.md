# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- Run all tests: `./scripts/test.sh`
- Run specific test file: `./scripts/test.sh test/detectors_spec.lua`
- Install test dependencies: `./scripts/install_test_deps.sh`

### Linting
- Run linter: `./scripts/lint.sh`

### Environment Setup
- Requires Lua 5.4 and LuaRocks
- The test script automatically configures Lua paths for `src/` and `test/` directories
- Use `LUA_VERSION=5.4` environment variable for different Lua versions

## Architecture Overview

This is a refactored Hammerspoon spoon for clipboard formatting with a modular architecture that separates the spoon runtime from reusable utilities.

### Core Components

**ClipboardFormatter Spoon (`src/init.lua`)**
- Main spoon interface with detector/formatter registry
- Three formatting modes: `format` (full clipboard), `formatSeed` (extract last expression), `formatSelection` (selected text)
- Hotkey helpers: `FormatClip`, `FormatClipSeed`, `FormatCutSeed`, `FormatSelected`
- Throttling mechanism to avoid redundant processing
- Hook system for runtime extension
- PD (Permanent Disability) mapping management with bundled/fallback file loading

**Detectors (`src/detectors/`)**
- Modular pattern detection system via registry pattern
- Each detector created via `detector_factory.create()` with dependency injection
- Detectors can optionally declare `dependencies` array (e.g., `{"logger", "config", "formatters"}`)
- Built-in detectors: arithmetic, date ranges, PD conversions, combinations, phone numbers, navigation
- Detectors return `{ formatted, matchedId, rawResult, sideEffect }`

**Formatters (`src/formatters/`)**
- Shared formatting utilities: arithmetic (supports `%`, `^`, localized numbers), currency, dates, phone annotations
- Configurable output templates
- Used by multiple detectors

**Utilities (`src/utils/`)**
- `detector_factory.lua`: Factory for creating detectors with dependency injection support
- `patterns.lua`: **Unified** pattern registry with LRU cache and memory-aware caching; configurable via `patterns.configure()`
- `strings.lua`: String utilities including `extractSeed()` for seed formatting
- `logger.lua`: Structured logging with configurable levels per sink
- `hammerspoon.lua`: Hammerspoon-specific utilities (timing, focus, clipboard polling)
- `pd_cache.lua`: PD mapping file loading with caching

**Clipboard/Selection (`src/clipboard/`)**
- `io.lua`: Cross-platform clipboard access with AppleScript/eventtap fallbacks
- `selection_modular.lua`: **(primary)** Selection formatting with strategy pattern, multiple fallback methods (accessibility API, menu copy, eventtap keystroke), clipboard restoration, and polling
- `restore.lua`: Clipboard restoration helper

### Key Architectural Patterns

**Module Loading**: Uses dynamic `requireFromRoot()` to work both in Hammerspoon and standalone test environments with namespace `ClipboardFormatter.src.*`

**Detector Registry**: Centralized pattern matching through `detectors/registry.lua` that processes input through all registered detectors in order

**Dependency Injection**: `detector_factory.lua` supports optional dependency declaration via `dependencies` array; validates and injects only declared dependencies

**Context Passing**: All detector/formatter calls receive a context object containing `{ logger, config, patterns, pdMapping, formatters }`

**Pattern Caching**: Unified `patterns.lua` provides LRU cache with memory pressure monitoring; configurable via `patterns.configure({maxCacheSize, memoryThresholdMB, autoCleanup})`

**Seed Processing**: The `formatSeed` methods extract expressions after `=`, `:`, or whitespace boundaries for use with Karabiner integration

**Selection Handling**: `selection_modular.lua` uses strategy pattern with multiple fallback methods (accessibility API → menu copy → eventtap keystroke) for acquiring selected text

### Configuration
- Default config in `src/config/defaults.lua`
- User hooks via `config/user_hooks.lua`
- Logging levels: `"debug"`, `"info"`, `"warn"`, `"error"`
- Processing throttle, selection timing, and PD mapping paths configurable