# Dependency Map

> Generated: 2025-12-24
> Source: Audit of all detectors and formatters

## Overview

This document tracks the dependency declarations and actual usage across all detectors and formatters in the ClipboardFormatter codebase.

## Detector Dependencies

### arithmetic.lua
- **Declared**: `{"patterns"}`
- **Actually Uses**: `patterns` (via injected deps)
- **Status**: ✅ Correct

### combinations.lua
- **Declared**: `{}` (explicitly empty)
- **Actually Uses**: None (self-contained)
- **Status**: ✅ Correct

### navigation.lua
- **Declared**: `{"logger"}`
- **Actually Uses**: `logger` (via `(context and context.logger) or (deps and deps.logger)`)
- **Status**: ✅ Correct

### date.lua (date_range)
- **Declared**: `{"patterns"}`
- **Actually Uses**: `patterns` (via injected deps)
- **Status**: ✅ Correct

### phone.lua
- **Declared**: `{"patterns"}`
- **Actually Uses**: `patterns` (via injected deps)
- **Status**: ✅ Correct

### pd.lua (pd_conversion)
- **Declared**: `{}`
- **Actually Uses**:
  - `deps.config` - for `benefitPerWeek`
  - `deps.formatters` - for currency formatter
  - `context.pdMapping` - for PD mapping data
- **Status**: ⚠️ **INCOMPLETE** - Should declare `{"config", "formatters"}`

### registry.lua
- **Declared**: N/A (not a detector factory creation)
- **Actually Uses**: `context.__matches`, `context.__lastMatchId`, `context.__matched`
- **Status**: N/A (registry is infrastructure, not a detector)

## Formatter Dependencies

All formatters currently have no explicit dependency declarations:
- `arithmetic.lua` - ✅ Self-contained
- `phone.lua` - ✅ Self-contained
- `currency.lua` - ✅ Self-contained
- `date.lua` - ✅ Self-contained

## Key Findings

### 1. Missing Dependency Declarations
**pd.lua** needs to declare its dependencies:
- `config` - used for PD benefit calculation
- `formatters` - used for currency formatting
- `pdMapping` - used for looking up PD values (passed via context)

### 2. Context vs Deps Access Patterns

Current access patterns found:
```lua
-- Pattern 1: Fallback pattern (pd.lua)
local benefitPerWeek = (deps and deps.config and deps.config.pd and deps.config.pd.benefitPerWeek) or 290
local formatterSource = (context and context.formatters) or (deps and deps.formatters)

-- Pattern 2: Direct context access (navigation.lua)
local logger = (context and context.logger) or (deps and deps.logger)

-- Pattern 3: Context mutation for side effects (navigation.lua)
context.__lastSideEffect = meta
context.__handledByNavigation = true
```

### 3. Recommendations

1. **Standardize declaration**: All detectors should explicitly declare dependencies
2. **Consistent access pattern**: Use `deps.XXX` for injected defaults, `context.XXX` for runtime overrides
3. **Remove verbose fallback**: The factory now handles injection, so fallback chains are unnecessary

## Dependency Injection Flow

```
Detector Registration (init.lua)
    ↓
deps = {logger, config, patterns, formatters, pdMapping}
    ↓
Detector creation: DetectorModule(deps)
    ↓
Factory validates and injects declared dependencies
    ↓
Detector receives merged context at match time
```

## Next Steps

See tasks in refactoring plan:
- Task 1.2: Standardize dependency declarations
- Task 1.3: Add validation (already exists in factory)
- Task 1.4: Standardize context/deps access patterns
