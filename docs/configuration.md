# Configuration Guide

ClipboardFormatter ships with sensible defaults in `src/config/defaults.lua`,
which are merged with values supplied when `ClipboardFormatter:init(opts)` is
called. This document explains the available knobs and how to override them.

## Logger

- `loggerLevel`: Fallback log level used when `logging.level` is not provided.
- `logging.level`: Optional override for the minimum log level (`"debug"`,
  `"info"`, `"warning"`, `"error"`, etc.).
- `logging.structured` (boolean): When `true`, emits JSON-style log lines with
  level, message, and (optionally) timestamp fields for easier parsing.
- `logging.includeTimestamp` (boolean): Controls whether structured log output
  includes an ISO-8601 UTC timestamp (defaults to `true`). Set to `false` for
  deterministic output in test environments.

## Clipboard Behavior

- `restoreClipboard` (boolean): When `true`, the original clipboard contents are
  restored after formatting succeeds. Set to `false` to keep the formatted value
  in the clipboard.
- `processing.throttleMs` (number): Minimum number of milliseconds to wait
  before reprocessing the same clipboard contents. When set, repeated
  invocations within the window return the previous formatted result without
  invoking detectors.

### Selection Formatting (`config.selection`)

All values are expressed in milliseconds unless noted.

Behavior:

- **Method 1**: Tries accessibility API to read selected text directly (no clipboard interference)
- **Method 2**: Uses Edit > Copy via the frontmost app menu when available; falls back to Cmd+C when not
- **Method 3**: If still unsuccessful, final Cmd+C with longer delay for slow apps
- Briefly polls the clipboard for a change; if unchanged, waits `copyDelayMs` then proceeds
- Pastes via Edit > Paste with a keystroke fallback

| Option | Description |
| ------ | ----------- |
| `debug` | When `true`, emit selection debug logs. Default `false`. |
| `tryAccessibilityAPI` | When `true` (default), attempt accessibility API first (fastest, no clipboard). |
| `copySelection` | When `true` (default), perform the copy step before formatting. |
| `copyDelayMs` | Fallback delay after copy if polling didn't detect a change (default `300`). |
| `copyWaitTimeoutMs` | Maximum time to poll for clipboard change after copy (default `600`). |
| `fallbackKeystroke` | When `true` (default), enable final Cmd+C with longer delay for slow apps. |
| `fallbackDelayMs` | Microseconds delay for final keystroke attempt (default `20000` = 20ms). |
| `pasteDelayMs` | Delay before paste and (if restoring) before restoring the original clipboard (default `60`). |

## Permanent Disability (PD) Mapping (`config.pd`)

- `bundledFile`: Relative path (from the spoon directory) to the preferred PD
  percentage-to-weeks mapping file.
- `legacyFile`: Optional legacy file path kept for backward compatibility.
- `fallbackPath`: Absolute path outside the spoon that should be used when the
  bundled files are missing.
- `benefitPerWeek`: Default weekly benefit amount used when the PD detector
  calculates currency output.

## Templates (`config.templates`)

- `arithmetic`: Optional output template applied to arithmetic detector results.
  Supported placeholders include `${input}` (the trimmed source expression),
  `${result}` (the formatted result string, including currency symbols when
  present), and `${numeric}` (the raw numeric result). Leave unset to keep the
  default behaviour of returning only the formatted result.

## Hotkeys (`config.hotkeys`)

- `installHelpers` (boolean): When `true`, registers global helper functions
  `FormatClip()` and `FormatSelected()` that call the spoon's clipboard and
  selection formatting routines. These helpers mirror the historical API for
  quick keybinding without manually wiring spoon instances. Set to `false` to
  avoid injecting globals (default).

## Hooks

`ClipboardFormatter` accepts a `hooks` table (or function) during initialization
as well as a `hooksFile` path that can return a compatible table. Supported
callbacks include:

- `hooks(formatter)`: When a function is provided directly, it receives the
  formatter instance and can register detectors, formatters, or adjust
  configuration.
- `hooks.formatters(formatter)`: When using a table, provide a
  `formatters` function to register or override formatter modules before
  detectors are evaluated. Use `formatter:registerFormatter(id, module)` to
  expose custom logic to detectors.
- `hooks.detectors(formatter)`: When using a table, provide a `detectors`
  function to register or modify detectors before the registry runs.

### Example

```lua
local Formatter = hs.loadSpoon("ClipboardFormatter")
Formatter:init({
  hooks = {
    formatters = function(obj)
      obj:registerFormatter("shout", {
        process = function(_, text)
          return string.upper(text)
        end,
      })
    end,
    detectors = function(obj)
      obj:registerDetector({
        id = "shout",
        priority = 20,
        match = function(_, text, context)
          local fmt = context.formatters and context.formatters.shout
          if fmt and type(fmt.process) == "function" then
            return fmt.process(fmt, text)
          end
        end,
      })
    end,
  },
    },
    hooks = {
        detectors = function(obj)
            obj:registerDetector({
                id = "custom",
                priority = 20,
                match = function(_, text)
                    if text == "hello" then return "world" end
                end,
            })
        end,
    },
})
```
