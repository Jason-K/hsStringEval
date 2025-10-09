# Module Overview

ClipboardFormatter is organized into focused Lua modules under `src/` to keep
runtime behavior testable outside of Hammerspoon. This document summarizes each
module and the responsibilities it owns.

## Clipboard Layer (`src/clipboard/`)

- `io.lua`: reads and writes the primary or "find" pasteboard, falling back to
  AppleScript when Hammerspoon APIs return empty strings.
- `selection.lua`: coordinates copy/format/paste for the active selection using
  shared Hammerspoon helpers and the main formatter pipeline.
- `restore.lua`: simple helper that restores clipboard contents when requested
  after formatting operations.

## Detector Layer (`src/detectors/`)

Each detector constructor accepts dependencies (`logger`, `config`,
`formatters`, etc.) and
returns an object exposing `id`, `priority`, and `match`.

- `arithmetic.lua`, `date.lua`, `pd.lua`, `combinations.lua`, `phone.lua`:
  domain-specific matchers that transform strings into formatted results.
- `registry.lua`: table-driven detector registry that enforces priority ordering
  and returns the first successful match.

## Formatter Layer (`src/formatters/`)

Formatters provide reusable transformations leveraged by detectors or the
clipboard pipeline. Each formatter now accepts an optional `opts` table so the
detectors can share cached pattern handles and other context without
referencing globals directly.

- `arithmetic.lua`: safe arithmetic evaluation (supports `+`, `-`, `*`, `/`,
  `%`, `^`, and localized decimal separators) with optional currency output
  when dollar signs are present.
- `currency.lua`: number-to-currency formatting helpers.
- `date.lua`: inclusive date range description builder (handles textual month
  names, ISO timestamps, and inferred years for partial inputs).
- `phone.lua`: annotated phone number formatter.

## Utility Layer (`src/utils/`)

- `hammerspoon.lua`: shared helpers for interacting with Hammerspoon APIs
  (pasteboard operations, AppleScript/eventtap copy and paste, window focus).
- `logger.lua`: lightweight structured logger used during tests and runtime.
- `patterns.lua`: centralized pattern cache used by detectors and formatters to
  avoid manual regex duplication. The cache exposes compiled helpers (`match`,
  `contains`, `gmatch`) that can be passed through the processing context.
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
