# ClipboardFormatter (Hammerspoon Spoon)

A modular, well-tested Hammerspoon spoon for intelligent clipboard and text selection formatting.

## Features

- **Clipboard Processing**: Automatically format clipboard content using detector-based pattern matching
- **Selection Formatting**: Format selected text in any application
- **Seed Extraction**: Extract and format expressions from the end of clipboard content
- **Multiple Detectors**: Arithmetic (with percentages), date ranges, time calculations, unit conversions, PD conversions, combinations, phone numbers
- **Extensible**: Register custom detectors and formatters via hooks

## Usage Examples

### Arithmetic
- `10 + 5` → `15`
- `$100 - $25` → `$75`
- `15% of 24000` → `3600`
- `24000 + 15%` → `27600`
- `50 - 20%` → `40`

### Time Calculations
- `9am + 2h` → `11:00 AM`
- `now + 30m` → [current time + 30 min]
- `14:30 - 45m` → `13:45`
- `3pm - 90m` → `1:30 PM`

### Unit Conversions
- `100km to mi` → `62.14 mi`
- `150lb to kg` → `68.03 kg`
- `72F to C` → `22.22°C`
- `10gal in L` → `37.85 L`

## Quick Start

```lua
local ClipboardFormatter = hs.loadSpoon("ClipboardFormatter")
ClipboardFormatter:init()

ClipboardFormatter:bindHotkeys({
    format = { { "ctrl", "alt" }, "f" },
    formatSelection = { { "ctrl", "alt" }, "s" },
})
```

## Installation

1. Copy `src/` to `~/.hammerspoon/Spoons/ClipboardFormatter.spoon/`
2. Add the above configuration to `~/.hammerspoon/init.lua`
3. Reload Hammerspoon

## Documentation

- **[Setup Guide](docs/setup.md)** - Installation and configuration
- **[Configuration](docs/configuration.md)** - All configuration options
- **[Modules](docs/modules.md)** - Architecture and module reference
- **[Testing](docs/testing.md)** - Running tests
- **[Hammerspoon Integration](docs/hammerspoon_integration.md)** - Development workflow

## Development

### Prerequisites

- Lua 5.4
- LuaRocks
- Hammerspoon (for runtime)

### Running Tests

```bash
# Install test dependencies
./scripts/install_test_deps.sh

# Run tests
./scripts/test.sh
```

### Project Structure

```
src/
  clipboard/           # Clipboard I/O operations
    io.lua             # Cross-platform clipboard access
    selection_modular.lua # Selection formatting with fallback strategies
    restore.lua        # Clipboard restoration

  detectors/            # Pattern detectors
    arithmetic.lua      # Arithmetic expressions (including percentages)
    date.lua            # Date ranges
    time_calc.lua       # Time calculations
    units.lua           # Unit conversions
    pd.lua              # PD (Permanent Disability) conversions
    combinations.lua    # Probability combinations
    phone.lua           # Phone numbers
    navigation.lua      # URLs and file paths
    registry.lua        # Detector coordination

  formatters/           # Output formatters
    arithmetic.lua      # Arithmetic evaluation
    currency.lua        # Currency formatting
    date.lua            # Date parsing
    phone.lua           # Phone formatting

  utils/                # Utilities
    detector_factory.lua # Detector creation with DI
    strings.lua         # String utilities (delegates to seed_strategies)
    seed_strategies.lua # Seed extraction strategies (strategy pattern)
    patterns.lua        # Pattern compilation and caching
    time_math.lua       # Time calculation utilities
    logger.lua          # Logging
    hammerspoon.lua     # Hammerspoon utilities
    pd_cache.lua        # PD mapping cache
    error_handler.lua   # Error handling
    logging_wrapper.lua # Logging wrappers
    string_processing.lua # String processing
    config_accessor.lua  # Config access
    validation.lua      # Validation

  spoon/                # Spoon-internal modules
    hooks.lua           # Hook system
    hotkeys.lua         # Hotkey helpers
    pd_mapping.lua      # PD mapping management
    clipboard.lua       # Clipboard operations
    processing.lua      # Core processing pipeline

  config/               # Configuration
    defaults.lua        # Default values
    constants.lua       # Centralized constants
    schema.lua          # Type definitions
    validator.lua       # Schema validation
    manager.lua         # Config management
```

## License

MIT - see `src/init.lua` for details
