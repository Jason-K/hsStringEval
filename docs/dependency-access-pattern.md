# Dependency Access Pattern

## Rule: Injected Dependencies vs Context

### Injected Dependencies (`deps`)
Default values and core utilities provided at detector creation time.

- `logger` - Logging instance for debug/info/warn/error
- `patterns` - Pattern registry for pattern matching
- `formatters` - Formatter utilities (currency, date, phone, etc.)
- `config` - Default configuration values

**Access via:** `deps.XXX`

### Context (`context`)
Runtime overrides and call-specific data passed during `match()` call.

- `config` - User configuration merged with defaults (overrides deps.config)
- `__lastSideEffect` - Side effect tracking for navigation detectors
- `__matches` - Collection of matches from previous detectors
- `pdMapping` - PD mapping data (passed via context)

**Access via:** `context.XXX`

## Access Patterns

### Configuration Access
Use context config when available, fall back to deps config:

```lua
-- CORRECT: Context overrides defaults
local benefitPerWeek = (context.config or deps.config).pd.benefitPerWeek

-- CORRECT: Safe nested access with fallback
local cfg = context.config or deps.config
local value = (cfg and cfg.pd and cfg.pd.benefitPerWeek) or 290
```

### Utility Access
Use deps directly for utilities (no context override expected):

```lua
-- CORRECT: Direct deps access for utilities
local pattern = deps.patterns.get("arithmetic")
local formatter = deps.formatters.currency

-- CORRECT: Logger with fallback to context
local logger = deps.logger or (context and context.logger)
```

### Runtime Data
Use context for call-specific data and side effects:

```lua
-- CORRECT: Context for side effects
context.__lastSideEffect = meta
context.__handledByNavigation = true

-- CORRECT: Context for runtime-provided data
local mapping = context.pdMapping or {}
```

## Examples

### Example 1: PD Detector (uses config + formatters)
```lua
return DetectorFactory.createCustom({
    id = "pd_conversion",
    dependencies = {"config", "formatters"},  -- Declared
    deps = deps,
    customMatch = function(text, context)
        -- Use deps for injected defaults
        local benefitPerWeek = (deps.config and deps.config.pd and deps.config.pd.benefitPerWeek) or 290
        local currencyFormatter = (deps.formatters and deps.formatters.currency) or defaultCurrency

        -- Use context for runtime data
        local mapping = context.pdMapping or {}

        -- Process...
    end
})
```

### Example 2: Navigation Detector (uses logger)
```lua
return DetectorFactory.createCustom({
    id = "navigation",
    dependencies = {"logger", "config"},  -- Declared
    deps = deps,
    customMatch = function(text, context)
        -- Logger from deps, context can override for testing
        local logger = deps.logger or (context and context.logger)

        -- Use context for side effects
        context.__lastSideEffect = meta

        -- Process...
    end
})
```

### Example 3: Arithmetic Detector (uses patterns)
```lua
return DetectorFactory.create({
    id = "arithmetic",
    dependencies = {"patterns"},  -- Declared
    formatterKey = "arithmetic",
    defaultFormatter = defaultFormatter,
    deps = deps,
})
-- The factory handles injecting deps.patterns into the formatter
```

## Key Principles

1. **Declare what you use** - All `deps.XXX` access should be in `dependencies` array
2. **Use deps for defaults** - Injected dependencies provide core utilities
3. **Use context for runtime data** - Call-specific data and user overrides
4. **Fallback gracefully** - When context might override, use `context.XXX or deps.XXX`
5. **Side effects go in context** - Never mutate deps, only context
