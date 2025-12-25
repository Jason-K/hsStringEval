# Plan: Split Monolithic init.lua

## Overview

The current `src/init.lua` file is ~700 lines and contains multiple concerns:
- Spoon metadata and initialization
- Clipboard processing logic
- PD mapping management
- Hotkey helpers
- Hook system
- Selection formatting

This plan outlines how to split it into focused, maintainable modules.

## Current Structure Analysis

### init.lua Sections

1. **Metadata (lines 1-8)**
   - Spoon name, version, author, homepage, license

2. **Module Loading (lines 10-38)**
   - `requireFromRoot` helper
   - Dependencies (config, logger, patterns, detectors, etc.)

3. **Initialization (lines 40-91)**
   - `init()` method
   - Config loading and validation
   - Logger setup
   - Pattern/formatter loading
   - Detector registration
   - PD mapping loading
   - Hook application
   - Hotkey helper installation

4. **Clipboard Operations (lines 93-180)**
   - `loadPDMapping()`
   - `reloadPDMapping()`
   - `getClipboardContent()`

5. **Processing Core (lines 156-254)**
   - `processClipboard()`
   - Throttling logic
   - Registry processing

6. **Formatting Methods (lines 256-500)**
   - `formatClipboardDirect()`
   - `formatClipboardSeed()`
   - `formatSelection()`
   - `formatSelectionSeed()`

7. **PD Mapping UI (lines 502-588)**
   - `editPDMapping()`
   - `showPDMap()`

8. **Hotkey Helpers (lines 590-650)**
   - `installHotkeyHelpers()`
   - `FormatClip`, `FormatClipSeed`, `FormatCutSeed`, `FormatSelected`

9. **Hook System (lines 652-698)**
   - `applyHooks()`
   - `loadHooksFromFile()`

10. **Utility Methods (lines 700-end)**
    - `bindHotkeys()`
    - `registerFormatter()`
    - `getMetadata()`

## Proposed New Structure

```
src/
├── init.lua                    (thin entry point, ~50 lines)
└── spoon/
    ├── runtime.lua             (initialization logic)
    ├── hotkeys.lua             (hotkey helper functions)
    ├── hooks.lua               (hook system)
    ├── pd_mapping.lua          (PD mapping management)
    ├── clipboard.lua            (clipboard operations)
    └── processing.lua          (core processing logic)
```

## Step-by-Step Implementation Plan

### Phase 1: Create Module Infrastructure

**Step 1.1: Create spoon directory**
```bash
mkdir -p src/spoon
```

**Step 1.2: Update formatters/init.lua to include spoon modules**
```lua
-- Add exports for new spoon modules
return {
    arithmetic = arithmetic,
    currency = currency,
    date = date,
    phone = phone,
}
```

### Phase 2: Extract Hook System

**File:** `src/spoon/hooks.lua`

**Responsibility:** Manage runtime extension hooks

**Key Functions to Extract:**
- `applyHooks()` → `M.apply()`
- `loadHooksFromFile()` → `M.loadFromFile()`
- New: `M.register()`
- New: `M.execute()`

**Dependencies:** None (standalone)

### Phase 3: Extract Hotkey Helpers

**File:** `src/spoon/hotkeys.lua`

**Responsibility:** Hotkey binding and helper installation

**Key Functions to Extract:**
- `installHotkeyHelpers()` → `M.installHelpers()`
- `bindHotkeys()` → `M.bindHotkeys()`
- Global helpers: `FormatClip`, `FormatClipSeed`, `FormatCutSeed`, `FormatSelected`

**Dependencies:**
- `hs` (Hammerspoon)
- Parent spoon instance

### Phase 4: Extract PD Mapping Management

**File:** `src/spoon/pd_mapping.lua`

**Responsibility:** PD mapping file loading and caching

**Key Functions to Extract:**
- `loadPDMapping()`
- `reloadPDMapping()`
- `editPDMapping()`
- `showPDMap()`

**Dependencies:**
- `pd_cache`
- `hs` (Hammerspoon for UI)

### Phase 5: Extract Clipboard Operations

**File:** `src/spoon/clipboard.lua`

**Responsibility:** Clipboard I/O operations

**Key Functions to Extract:**
- `getClipboardContent()`
- Clipboard polling helpers

**Dependencies:**
- `clipboard.io`
- `hsUtils` (hammerspoon utilities)

### Phase 6: Extract Core Processing Logic

**File:** `src/spoon/processing.lua`

**Responsibility:** Core clipboard processing pipeline

**Key Functions to Extract:**
- `processClipboard()` - Core processing with throttling
- Registry integration
- Context management

**Dependencies:**
- `strings` (string utilities)
- `registry`

### Phase 7: Extract Runtime Initialization

**File:** `src/spoon/runtime.lua`

**Responsibility:** Spoon initialization

**Key Functions to Extract:**
- `init()` - Main initialization logic
- Dependency setup
- Detector registration
- Pattern/formatter loading

**Dependencies:**
- All other modules
- `ConfigManager`
- `loggerFactory`

### Phase 8: Simplify init.lua

**File:** `src/init.lua` (refactored)

**New Structure:**
```lua
-- Metadata
local obj = {}
obj.__index = obj
obj.name = "ClipboardFormatter"
-- ... metadata fields ...

-- Module imports
local runtime = requireFromRoot("spoon.runtime")
local hotkeys = requireFromRoot("spoon.hotkeys")
local hooks = requireFromRoot("spoon.hooks")
local pdMapping = requireFromRoot("spoon.pd_mapping")
local clipboard = requireFromRoot("spoon.clipboard")
local processing = requireFromRoot("spoon.processing")
-- ... other imports ...

-- Public API: Forward declarations
function obj:init(opts)
    return runtime.init(self, opts)
end

obj.processClipboard = processing.process
obj.getClipboardContent = clipboard.get
obj.loadPDMapping = pdMapping.load
-- ... other forwards ...

-- Hook system forwards
obj.applyHooks = hooks.apply
obj.loadHooksFromFile = hooks.loadFromFile

-- Hotkey helpers forwards
obj.installHotkeyHelpers = hotkeys.installHelpers
obj.bindHotkeys = hotkeys.bindHotkeys

return obj
```

### Phase 9: Update Tests

**Tests to Update:**
- `test/init_spec.lua` - May need adjustments for new structure
- `test/integration/*` - Should mostly work through public API
- `test/spec_helper.lua` - May need updates for module loading

**Verification:**
```bash
./scripts/test.sh
```

Expected: All 289 tests still pass

### Phase 10: Backward Compatibility Verification

**Check List:**
- [ ] All public API methods still work
- [ ] Hotkey binding still works
- [ ] Hook system still works
- [ ] PD mapping editing still works
- [ ] Configuration loading still works
- [ ] All tests pass

## Migration Strategy

### Option A: Big Bang (All at Once)
- Create all new modules
- Rewrite init.lua
- Update tests
- Single commit

**Pros:** Clean break, no intermediate states
**Cons:** High risk, hard to debug if something breaks

### Option B: Incremental (Recommended)
1. Extract `hooks.lua` first (no dependencies)
2. Extract `hotkeys.lua` (minimal dependencies)
3. Extract other modules one at a time
4. Each extraction in its own commit
5. Simplify init.lua last

**Pros:** Easier to debug, can revert individual steps
**Cons:** More commits, intermediate states

## Testing Strategy

### Unit Tests for New Modules

**test/spoon/hooks_spec.lua**
```lua
describe("Hook System", function()
    it("should register and execute hooks")
    it("should load hooks from file")
    it("should handle missing files gracefully")
end)
```

**test/spoon/hotkeys_spec.lua**
```lua
describe("Hotkey Helpers", function()
    it("should install hotkey helpers")
    it("should bind hotkeys")
    it("should create FormatClip helpers")
end)
```

### Integration Tests

Add to `test/integration/`:
- Test full initialization flow
- Test hook system integration
- Test hotkey binding
- Test PD mapping management

## Risk Assessment

### High Risk Areas
1. **Detector registration** - Must maintain exact order and priority
2. **Context passing** - Detectors depend on specific context structure
3. **Hotkey helpers** - Global namespace pollution must be preserved
4. **Hook execution order** - Must match current behavior

### Mitigation Strategies
1. **Comprehensive tests** - Run full suite after each phase
2. **Incremental commits** - Easy to revert if something breaks
3. **Feature flags** - Can enable new modules gradually
4. **Backward compatibility layer** - Keep old functions working during transition

## Success Criteria

1. All existing tests pass without modification
2. New modules have comprehensive unit tests
3. Public API remains unchanged
4. init.lua is under 100 lines
5. Each spoon module has single responsibility
6. Code is more maintainable and testable

## Estimated Effort

- **Phase 1-2:** 1 hour (setup, hook extraction)
- **Phase 3:** 1 hour (hotkeys extraction)
- **Phase 4:** 1.5 hours (PD mapping)
- **Phase 5:** 1 hour (clipboard)
- **Phase 6:** 1.5 hours (processing)
- **Phase 7:** 2 hours (runtime)
- **Phase 8:** 2 hours (init.lua refactor)
- **Phase 9-10:** 2 hours (tests, verification)

**Total:** ~12 hours of focused work

## Next Steps

1. Review and approve this plan
2. Decide on migration strategy (Big Bang vs Incremental)
3. Begin with Phase 1 (hook system extraction - lowest risk)
4. Proceed through phases incrementally
5. Run tests after each phase
6. Adjust plan based on findings

## Appendix: File-by-File Breakdown

### init.lua Function Locations

| Function | Lines | Target Module |
|----------|-------|----------------|
| Metadata | 1-8 | init.lua (keep) |
| requireFromRoot | 13-18 | init.lua (keep) |
| init() | 40-91 | runtime.lua |
| loadPDMapping() | 93-138 | pd_mapping.lua |
| reloadPDMapping() | 140-173 | pd_mapping.lua |
| getClipboardContent() | 175-199 | clipboard.lua |
| processClipboard() | 201-254 | processing.lua |
| formatClipboardDirect() | 256-293 | processing.lua |
| formatClipboardSeed() | 295-337 | processing.lua |
| formatSelection() | 595-631 | processing.lua (via selection) |
| formatSelectionSeed() | 633-675 | processing.lua |
| editPDMapping() | 502-558 | pd_mapping.lua |
| showPDMap() | 560-588 | pd_mapping.lua |
| installHotkeyHelpers() | 590-627 | hotkeys.lua |
| FormatClip | 629-637 | hotkeys.lua |
| FormatClipSeed | 639-647 | hotkeys.lua |
| FormatCutSeed | 649-657 | hotkeys.lua |
| FormatSelected | 659-667 | hotkeys.lua |
| applyHooks() | 652-669 | hooks.lua |
| loadHooksFromFile() | 671-698 | hooks.lua |
| bindHotkeys() | 700-730 | hotkeys.lua |
| registerFormatter() | 732-745 | processing.lua |
| getMetadata() | 747-758 | init.lua (keep) |

## References

- Current init.lua: ~758 lines
- Test suite: 289 tests
- Dependencies: 15+ modules
- Public API methods: ~20 methods
