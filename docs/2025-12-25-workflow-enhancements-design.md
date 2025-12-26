# Workflow Enhancements Design

**Date:** 2025-12-25
**Status:** Draft
**Author:** Design Review

## Overview

This document outlines a comprehensive roadmap for enhancing the ClipboardFormatter spoon to better support the core workflow: allowing users to type text, press a hotkey, and have transformations applied inline without breaking their flow.

## Goals

1. Refactor existing code to reduce complexity and improve maintainability
2. Add new detectors for time calculations, unit conversions, and percentage arithmetic
3. Improve detector error reporting and pattern dependency documentation

## Current State Analysis

### Strengths

- Modular detector/registry pattern with dependency injection
- Unified pattern registry with LRU caching
- Hook system for runtime extension
- Multiple hotkey modes (full clipboard, seed extraction, selection)
- Comprehensive test coverage

### Technical Debt

1. **`extractSeed()` complexity** (~130 lines in `src/utils/strings.lua`)
   - Deeply nested logic for multiple extraction strategies
   - Difficult to test and reason about

2. **Arithmetic formatter dual-path evaluation** (`src/formatters/arithmetic.lua`)
   - Uses both `load()` and custom tokenizer
   - Conditional logic based on operator types
   - Tokenizer doesn't support parentheses

3. **Navigation detector side effects** (`src/detectors/navigation.lua`)
   - "Arithmetic lookahead" to prevent false matches is a workaround

4. **Missing error context**
   - Detectors return `nil` without clear failure indication

5. **Pattern compilation**
   - Pattern dependencies not explicitly documented

## Refactoring Recommendations

### R1. Simplify `extractSeed()` with Strategy Pattern

Extract the ~130 line function into focused strategies:

```
src/utils/seed_strategies.lua
├── date_range_strategy    -- Date range position finding
├── arithmetic_strategy    -- Pure arithmetic and prefix arithmetic
├── separator_strategy     -- =, :, (, [, { separators
├── whitespace_strategy    -- Last whitespace split
└── fallback_strategy      -- Entire string is seed
```

Each strategy returns `{prefix, seed}` or `nil`. Strategies are tried in order.

### R2. Unify Arithmetic Evaluation

1. Extend tokenizer to support parentheses
2. Use tokenizer as single evaluation path
3. Remove `load()` fallback (or keep as fast-path for simple expressions)

### R3. Improve Detector Error Reporting

Add optional structured error context:

```lua
{
    formatted = string,
    matchedId = string,
    rawResult = any,
    sideEffect = table,
    errors = {  -- New
        { detector = "id", message = "...", input = "..." }
    }
}
```

### R4. Document Pattern Dependencies

Each detector declares `patternDependencies` array:

```lua
return DetectorFactory.create({
    id = "arithmetic",
    patternDependencies = { "arithmetic_candidate", "date_full", "localized_number" },
    -- ...
})
```

## New Detectors

### T1. Time/Date Calculations

**File:** `src/detectors/time_calc.lua`
**Utility:** `src/utils/time_math.lua`

**Patterns:**
- `<time> +/- <duration>`: `9am + 2h`, `14:30 - 45m`
- `now +/- <duration>`: `now + 30m`
- Time normalization: `5pm` → `5:00 PM`

**Implementation:**
- Parse 12h (am/pm) and 24h time formats
- Parse durations: `30m`, `2h`, `1h30m`, `45min`
- Use `os.time()` and `os.date()` for calculation
- Format output to match input style (12h/24h)

**Edge cases:**
- `now` returns actual evaluation time
- Day wrap: `11pm + 2h` → `1:00 AM` (next day)
- Time zone suffixes: `5pm CST` (preserve in output)

### U1. Unit Conversions

**File:** `src/detectors/units.lua`

**Conversion categories:**

| Type | Units |
|------|-------|
| Length | m, km, mi, ft, in, cm, mm |
| Weight | kg, g, lb, oz |
| Temperature | C, F, K |
| Data | MB, GB, TB |
| Speed | mph, kph, m/s |

**Pattern:** `<value><fromUnit> (to|in) <toUnit>`

**Examples:**
- `100km to mi` → `62.14 mi`
- `150lb to kg` → `68.03 kg`
- `72F to C` → `22.22°C`
- `1TB in GB` → `1000 GB`

**Implementation:**
- Static conversion factors (no external API)
- Chain conversions through base unit
- Preserve significant figures

### P1. Percentage Arithmetic

**Modifies:** `src/formatters/arithmetic.lua`

**New patterns:**

| Input | Output |
|-------|--------|
| `15% of 24000` | `3600` |
| `24000 + 15%` | `27600` |
| `24000 - 25%` | `18000` |
| `$24000 - 15%` | `$20,400` |

**Implementation:**
1. Add patterns to `src/utils/patterns.lua`:
   - `percentage_of`: `(%d+%%) of (%d+)`
   - `percentage_add`: `(%d+) %+ (%d+%%)`
   - `percentage_sub`: `(%d+) %- (%d+%%)`

2. Pre-process expressions:
   - `X% of Y` → `X / 100 * Y`
   - `Y + X%` → `Y * (1 + X/100)`
   - `Y - X%` → `Y * (1 - X/100)`

3. Feed to existing arithmetic evaluator

**Design decision:** Extend arithmetic detector rather than creating separate detector. These are fundamentally arithmetic operations and should benefit from existing currency handling and localization.

## Implementation Roadmap

### Phase 1: Foundation Refactoring

1. Extract seed strategies from `extractSeed()`
2. Unify arithmetic evaluation
3. Add pattern dependency declarations

### Phase 2: Percentage Arithmetic

4. Add percentage patterns
5. Implement percentage pre-processor

### Phase 3: Unit Conversions

6. Create units detector
7. Add unit conversion tests

### Phase 4: Time Calculations

8. Create time utilities
9. Create time calculations detector
10. Add time calculation tests

### Phase 5: Integration & Polish

11. Update documentation
12. Integration testing

## Priority Summary

| Detector | Complexity | Value | Order |
|----------|------------|-------|-------|
| Time calculations | Medium | High | 1st |
| Unit conversions | Low | High | 2nd |
| Percentage arithmetic | Low | Medium | 3rd |

## Files to Create

- `src/utils/seed_strategies.lua`
- `src/utils/time_math.lua`
- `src/detectors/time_calc.lua`
- `src/detectors/units.lua`
- Test files for each new module

## Files to Modify

- `src/utils/strings.lua` (refactor `extractSeed`)
- `src/formatters/arithmetic.lua` (unify eval, add percentages)
- `src/utils/patterns.lua` (add percentage, time, unit patterns)
- `src/utils/detector_factory.lua` (pattern dependencies)
- `src/detectors/registry.lua` (error context)
- All existing detectors (declare pattern dependencies)
- Documentation files
