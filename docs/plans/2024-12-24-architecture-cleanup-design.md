# Architecture Cleanup Design

**Date:** 2024-12-24
**Status:** Completed 2024-12-24
**Author:** Claude Code

## Overview

This design addresses technical debt in the clipboard formatter through three focused architectural improvements:

1. **Consolidate duplicate pattern implementations** - Merge three pattern modules into one
2. **Migrate selection module** - Transition from monolithic to modular selection implementation
3. **Implement dependency injection** - Replace "god object" context with explicit dependencies

### Success Criteria

- Delete 3 pattern files, create 1 replacement
- Delete original `selection.lua` after migration
- All detectors declare dependencies explicitly
- All existing tests pass
- No performance regression

### Non-Goals (Explicitly Out of Scope)

- New detectors or formatters
- Changes to existing detection logic
- User-facing behavior changes

## 1. Pattern Consolidation

### Current State

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `patterns.lua` | Simple registry | 167 | Basic caching, clean API |
| `patterns_optimized.lua` | Batch operations | 409 | Batch matching, performance monitoring |
| `patterns_memory_aware.lua` | Memory efficiency | 476 | LRU cache, adaptive sizing, weak refs |

### New Design: Single `patterns.lua`

Create a unified module with layered architecture:

```
patterns.lua (main module)
├── Core API (backward compatible)
│   ├── register(name, pattern)
│   ├── compiled(name) → {raw, contains, match, gmatch}
│   ├── match(name, text)
│   └── contains(name, text)
├── Memory Management (opt-in via config)
│   ├── LRU cache for compiled patterns
│   ├── Memory pressure monitoring
│   └── Configurable max size (default: 100 patterns)
└── Internal (not public)
    ├── _LRUCache class
    └── _MemoryMonitor class
```

### What We're Keeping

- Simple, clean API from original `patterns.lua`
- LRU cache from `patterns_memory_aware.lua`
- Memory pressure monitoring (simplified)
- Weak reference secondary cache

### What We're Removing

- Batch operations (not used for single-clipboard operations)
- Performance monitoring/stats (overkill for this use case)
- Shared pattern optimizations (unnecessary with ~10 patterns)
- Adaptive cache sizing (too complex for this use case)

### Configuration

```lua
-- Optional config, defaults work for most use cases
patterns.configure({
    maxCacheSize = 100,        -- LRU cache size
    memoryThresholdMB = 10,    -- Trigger cleanup at 10MB
    autoCleanup = true,        -- Auto memory management
})
```

### Migration Path

1. Create new unified `patterns.lua`
2. Keep old files as `patterns_legacy.lua.bak`, `patterns_optimized.lua.bak`, `patterns_memory_aware.lua.bak`
3. Update all `require()` calls
4. Run tests to verify API compatibility
5. Delete backup files in follow-up commit

## 2. Selection Module Migration

### Current State

- `selection.lua` - Original monolithic implementation
- `selection_modular.lua` - Refactored with strategy pattern, better separation

### Migration Strategy: Parallel Migration

1. **Phase 1:** Keep both modules in place
2. **Phase 2:** Update all callers to use `selection_modular.lua`
3. **Phase 3:** Run full test suite
4. **Phase 4:** Delete original `selection.lua`

### Callers to Update

```bash
# Find all files that require selection module
grep -r "require.*selection" src/ test/
```

Expected files:
- `src/init.lua` - Main spoon interface
- `test/clipboard_spec.lua` - Test files
- Any detector/formatter that uses selection

### Testing Approach

- Run existing clipboard tests after each caller update
- Test in real Hammerspoon environment to verify behavior
- Monitor logs for any deprecation warnings

## 3. Dependency Injection

### Current State: "God Object" Context

```lua
local context = {
    logger = logger,
    config = config,
    patterns = patterns,
    pdMapping = pdMapping,
    formatters = formatters,
}

-- Detector receives entire context
local function detect(input, context)
    context.logger:debug("...")
    local pattern = context.patterns:compiled("...")
end
```

**Problems:**
- Implicit dependencies - can't tell what detector needs without reading code
- Harder to test - must mock entire context
- Tight coupling - detectors can access anything

### New Design: Explicit Dependency Declaration

```lua
-- In detector constructor
local function new(opts)
    opts.inject = {
        "logger",      -- needed
        "config",      -- needed
        "patterns",    -- needed
        -- pdMapping, formatters NOT declared
    }

    -- Factory validates these exist and provides only what's declared
    -- Access via self.logger, self.config (NOT self.context.logger)

    return {
        detect = function(input)
            self.logger:debug("...")
            local pattern = self.patterns:compiled("...")
        end
    }
end
```

### Benefits

- **Explicit dependencies** - Reading constructor shows what's needed
- **Better testability** - Mock only declared dependencies
- **Reduced coupling** - Can't access undeclared context
- **Principle of least knowledge** - Each module knows only what it declares

### Implementation Changes

**Detector Factory (`src/utils/detector_factory.lua`):**
```lua
local function createDetector(detectorModule, context)
    -- Get dependency declaration from detector
    local deps = detectorModule.dependencies or {}

    -- Validate all declared dependencies exist
    for _, dep in ipairs(deps) do
        if not context[dep] then
            error(string.format("Detector requires '%s' but not provided", dep))
        end
    end

    -- Inject only declared dependencies
    local injected = {}
    for _, dep in ipairs(deps) do
        injected[dep] = context[dep]
    end

    -- Call detector constructor with injected dependencies
    return detectorModule.new(injected)
end
```

**Detector Template:**
```lua
-- Each detector declares its dependencies
local M = {
    dependencies = {"logger", "config", "patterns"},
}

function M.new(injected)
    local logger = injected.logger
    local config = injected.config
    local patterns = injected.patterns

    return {
        detect = function(input)
            -- Use injected dependencies directly
            logger:debug("Detecting: " .. input)
        end
    }
end

return M
```

### Migration Path for Existing Detectors

1. Update `detector_factory.lua` to support dependency injection
2. Add `dependencies` array to each detector
3. Update detector constructors to accept injected dependencies
4. Change `context.X` to direct `X` references
5. Run tests after each detector update

## Implementation Order

The work is organized to minimize risk - each step can be tested independently:

1. **Pattern Consolidation** (isolated, low risk)
   - Create unified `patterns.lua`
   - Update require statements
   - Verify API compatibility with tests

2. **Selection Migration** (parallel approach, medium risk)
   - Update callers one at a time
   - Test after each change
   - Delete original when complete

3. **Dependency Injection** (most invasive, most benefit)
   - Update detector factory
   - Migrate detectors one at a time
   - Test after each detector

## Testing Strategy

### Pattern Consolidation Tests
```lua
-- Verify backward compatibility
describe("Unified patterns module", function()
    it("maintains original API", function()
        assert.is_function(patterns.register)
        assert.is_function(patterns.compiled)
        assert.is_function(patterns.match)
        assert.is_function(patterns.contains)
    end)

    it("LRU cache works correctly", function()
        -- Test cache eviction
    end)

    it("memory cleanup triggers appropriately", function()
        -- Test memory pressure handling
    end)
end)
```

### Selection Migration Tests
- Use existing `test/clipboard_spec.lua` tests
- Run in actual Hammerspoon environment
- Verify no behavior changes

### Dependency Injection Tests
```lua
describe("Detector with dependency injection", function()
    it("validates required dependencies", function()
        -- Should error if missing required dep
    end)

    it("only receives declared dependencies", function()
        -- Should not have access to undeclared context
    end)
end)
```

## Rollback Plan

Each change can be independently reverted:

1. **Pattern consolidation:** Restore original `patterns.lua`, revert requires
2. **Selection migration:** Revert to original `selection.lua` (kept until verified)
3. **Dependency injection:** Revert `detector_factory.lua`, detector changes

## Open Questions

None at this time.
