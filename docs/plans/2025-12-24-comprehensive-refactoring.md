# ClipboardFormatter Comprehensive Refactoring Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Systematically refactor the ClipboardFormatter codebase to eliminate code duplication, standardize patterns, improve performance, and enhance maintainability through consistent dependency injection, unified abstractions, centralized configuration, and comprehensive testing.

**Architecture:** This refactoring follows the existing modular architecture but enforces consistency across all modules. We'll (1) standardize dependency injection declarations across all detectors, (2) extract duplicated code into shared utilities, (3) centralize all configuration and constants, (4) optimize performance bottlenecks, and (5) improve test coverage. Each change is isolated, tested, and committed independently following TDD principles.

**Tech Stack:** Lua 5.4, LuaRocks, busted (testing), Hammerspoon (runtime environment)

---

## Progress Summary

**Last Updated:** 2025-12-24

### Overall Progress: 19/19 tasks completed (100%) ✅

| Area | Tasks | Completed | Status |
|------|-------|-----------|--------|
| Area 1: Dependency Injection Consistency | 4 | 4 | ✅ COMPLETE |
| Area 2: Code Deduplication & Abstractions | 5 | 5 | ✅ COMPLETE |
| Area 3: Configuration & Constants | 3 | 3 | ✅ COMPLETE |
| Area 4: Performance Optimizations | 3 | 3 | ✅ COMPLETE |
| Area 5: Testing Improvements | 3 | 3 | ✅ COMPLETE |
| Area 6: Code Organization | 1 | 1 | ✅ COMPLETE |

### Completed Tasks

**Area 1: Dependency Injection Consistency**
- ✅ 1.1: Audit and Document All Current Dependencies
- ✅ 1.2: Standardize Detector Dependency Declarations
- ✅ 1.3: Create Dependency Validation in Detector Factory
- ✅ 1.4: Standardize Context vs Dependencies Access

**Area 2: Code Deduplication & Abstractions**
- ✅ 2.1: Create Shared Error Handling Utility
- ✅ 2.2: Create Logging Wrapper Utility
- ✅ 2.3: Create String Processing Utilities
- ✅ 2.4: Create Unified Configuration Accessor
- ✅ 2.5: Create Validation Framework

**Area 3: Configuration & Constants**
- ✅ 3.1: Centralize All Constants
- ✅ 3.2: Centralize PD Mapping Paths Configuration
- ✅ 3.3: Add Configuration Schema Validation

**Area 4: Performance Optimizations**
- ✅ 4.1: Optimize Pattern Caching with LRU
- ✅ 4.2: Add Early Exit to Registry Processing
- ✅ 4.3: Optimize Arithmetic Evaluation Path

**Area 5: Testing Improvements**
- ✅ 5.1: Create Integration Test Suite
- ✅ 5.2: Standardize Mocking with Test Helpers
- ✅ 5.3: Add Property-Based Testing for Edge Cases

**Area 6: Code Organization**
- ✅ 6.1: Split Monolithic init.lua into 5 focused spoon modules

### Test Count Progression

- Baseline: 169 tests
- After Area 1: 182 tests (+13)
- After Area 2: 254 tests (+72)
- After Area 3: 266 tests (+12)
- After Area 4: 271 tests (+5)
- After Area 5.1: 289 tests (+18)
- After Area 5.2-5.3: 349 tests (+60)
- **Final: 349 tests (+180 total, 106% increase)**

### New Modules Created

**Area 2: Code Deduplication & Abstractions**
| Module | File | Purpose |
|--------|------|---------|
| error_handler | `src/utils/error_handler.lua` | Safe error wrapping and logging |
| logging_wrapper | `src/utils/logging_wrapper.lua` | Null-safe logger wrappers |
| string_processing | `src/utils/string_processing.lua` | Number localization, URL encoding, expression extraction |
| config_accessor | `src/utils/config_accessor.lua` | Safe nested config access with merging |
| validation | `src/utils/validation.lua` | Reusable validation utilities |

**Area 3: Configuration & Constants**
| Module | File | Purpose |
|--------|------|---------|
| constants | `src/config/constants.lua` | Centralized constants for priorities, time, cache, paths |
| schema | `src/config/schema.lua` | Type definitions for all configuration sections |
| validator | `src/config/validator.lua` | Schema-based type validation |

**Area 6: Code Organization (Spoon Modules)**
| Module | File | Purpose |
|--------|------|---------|
| hooks | `src/spoon/hooks.lua` | Hook system management (applyHooks, loadHooksFromFile) |
| hotkeys | `src/spoon/hotkeys.lua` | Hotkey binding and helper installation |
| pd_mapping | `src/spoon/pd_mapping.lua` | PD mapping file loading and caching |
| clipboard | `src/spoon/clipboard.lua` | Clipboard I/O operations |
| processing | `src/spoon/processing.lua` | Core clipboard processing pipeline |

**Area 5: Testing Improvements**
| Module | File | Purpose |
|--------|------|---------|
| mock_helper | `test/mock_helper.lua` | Spy, stub, mock utilities for tests |
| property_helper | `test/property_helper.lua` | Property-based testing with random generators |

### Documentation Added

- `docs/dependency-map.md` - Complete dependency audit and mapping
- `docs/dependency-access-pattern.md` - Standardized access pattern documentation

---

## Overview of Refactoring Areas

This plan is organized into six major areas:

1. **Dependency Injection Consistency** - Standardize how detectors declare and use dependencies
2. **Code Deduplication & Abstractions** - Extract common patterns into shared utilities
3. **Configuration & Constants** - Centralize all hardcoded values
4. **Performance Optimizations** - Improve pattern caching, registry processing, and evaluation strategies
5. **Testing Improvements** - Add integration tests, standardize mocking, improve coverage
6. **Code Organization** - Split monolithic files, improve separation of concerns

---

## Area 1: Dependency Injection Consistency

### Task 1.1: Audit and Document All Current Dependencies

**Files:**

- Create: `docs/dependency-map.md`
- Reference: `src/detectors/*.lua` (all detector files)
- Reference: `src/formatters/*.lua` (all formatter files)

**Step 1: Create dependency mapping script**

Write: `scripts/audit_dependencies.lua`

```lua
#!/usr/bin/env lua5.4
-- Audit dependencies across all detectors and formatters
local lfs = require("lfs")
local inspect = require("inspect")

local function scanFile(filePath)
    local file = io.open(filePath, "r")
    if not file then return nil end

    local content = file:read("*a")
    file:close()

    -- Extract declared dependencies
    local declared = content:match('dependencies%s*=%s*{([^}]+)}')
    local declaredList = {}
    if declared then
        for dep in declared:gmatch('"([^"]+)"') do
            table.insert(declaredList, dep)
        end
    end

    -- Extract actual usage patterns (context.XXX, deps.XXX)
    local actualUsage = {}
    for usage in content:gmatch('(%w+%.%w+)') do
        local prefix, key = usage:match('^(%w+)%.(%w+)$')
        if prefix == "context" or prefix == "deps" then
            actualUsage[key] = (actualUsage[key] or 0) + 1
        end
    end

    return {
        declared = declaredList,
        actual = actualUsage
    }
end

local function scanDirectory(dir)
    local results = {}
    for file in lfs.dir(dir) do
        if file:match("%.lua$") and file ~= "init.lua" then
            local path = dir .. "/" .. file
            local data = scanFile(path)
            if data then
                results[file] = data
            end
        end
    end
    return results
end

print("=== Dependency Audit ===\n")

print("## Detectors")
local detectors = scanDirectory("src/detectors")
for name, data in pairs(detectors) do
    print(string.format("\n### %s", name:gsub("%.lua$", "")))
    print("Declared: " .. inspect(data.declared))
    print("Used: " .. inspect(data.actual))
end

print("\n## Formatters")
local formatters = scanDirectory("src/formatters")
for name, data in pairs(formatters) do
    print(string.format("\n### %s", name:gsub("%.lua$", "")))
    print("Declared: " .. inspect(data.declared))
    print("Used: " .. inspect(data.actual))
end
```

**Step 2: Run the audit script**

Run: `lua5.4 scripts/audit_dependencies.lua`

Expected: List of all detectors and formatters with declared vs actual dependencies

**Step 3: Document findings**

Create: `docs/dependency-map.md` with the audit output and analysis of discrepancies

**Step 4: Commit**

```bash
git add scripts/audit_dependencies.lua docs/dependency-map.md
git commit -m "feat(di): add dependency audit script and documentation"
```

---

### Task 1.2: Standardize Detector Dependency Declarations

**Files:**

- Modify: `src/detectors/pd.lua`
- Modify: `src/detectors/combinations.lua`
- Modify: `src/detectors/navigation.lua`
- Modify: `src/detectors/arithmetic.lua`
- Modify: `src/detectors/date.lua`
- Test: `test/detectors_spec.lua`

**Step 1: Update pd.lua to declare dependencies**

Read: `src/detectors/pd.lua`

Current file has implicit dependencies. Add explicit declaration:

```lua
-- At the top, after detector_factory import
local detector_factory = require("ClipboardFormatter.src.utils.detector_factory")

return detector_factory.create({
    name = "pd_conversion",

    dependencies = {"pdMapping", "formatters"},  -- ADD THIS

    priority = 100,
    -- rest of file unchanged
```

**Step 2: Update combinations.lua**

Read: `src/detectors/combinations.lua`

Add explicit dependencies (even if empty, document it):

```lua
return detector_factory.create({
    name = "combinations",

    dependencies = {},  -- ADD: explicitly state no dependencies

    priority = 70,
    -- rest of file unchanged
```

**Step 3: Update navigation.lua**

Read: `src/detectors/navigation.lua`

Fix incomplete dependency declaration:

```lua
return detector_factory.create({
    name = "navigation",

    dependencies = {"logger", "config"},  -- ADD "config" - was missing

    priority = 60,
    -- rest of file unchanged
```

**Step 4: Verify arithmetic.lua and date.lua are correct**

Read: `src/detectors/arithmetic.lua` - should already have `dependencies = {"patterns"}`

Read: `src/detectors/date.lua` - should already have `dependencies = {"patterns"}`

**Step 5: Run tests to ensure no breakage**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 6: Commit**

```bash
git add src/detectors/*.lua
git commit -m "refactor(di): standardize dependency declarations across all detectors"
```

---

### Task 1.3: Create Dependency Validation in Detector Factory

**Files:**

- Modify: `src/utils/detector_factory.lua`
- Test: `test/utils_spec.lua` (create if not exists)

**Step 1: Write failing test for dependency validation**

Create: `test/utils_spec.lua`

```lua
describe("Detector Factory - Dependency Validation", function()
    local detector_factory

    setup(function()
        detector_factory = require("ClipboardFormatter.src.utils.detector_factory")
    end)

    it("should validate that declared dependencies are available", function()
        local badDetector = detector_factory.create({
            name = "bad_detector",
            dependencies = {"nonexistent_dependency"},
            priority = 50,
            pattern = function() return "test" end,
            formatter = function() return "result" end
        })

        local deps = {}  -- Empty dependencies - missing "nonexistent_dependency"
        local result, err = pcall(function()
            return badDetector(deps)
        end)

        assert.is_false(result)
        assert.is_truthy(err:match("missing.*dependency"))
    end)

    it("should allow detectors with no dependencies", function()
        local goodDetector = detector_factory.create({
            name = "good_detector",
            dependencies = {},
            priority = 50,
            pattern = function() return "test" end,
            formatter = function() return "result" end
        })

        local deps = {}
        local detector = goodDetector(deps)
        assert.is_not_nil(detector)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/utils_spec.lua`

Expected: FAIL with "dependency validation not implemented"

**Step 3: Implement dependency validation**

Read: `src/utils/detector_factory.lua`

Add validation after line 14 (after meta.name assignment):

```lua
-- After: meta.name = spec.name
-- Add:

-- Validate declared dependencies
if meta.dependencies then
    for _, depName in ipairs(meta.dependencies) do
        if not dependencies[depName] then
            error(string.format(
                "Detector '%s' declares dependency '%s' but it was not provided. " ..
                "Available: %s",
                meta.name,
                depName,
                table.concat(dependencies, ", ")
            ))
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `./scripts/test.sh test/utils_spec.lua`

Expected: PASS

**Step 5: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 6: Commit**

```bash
git add src/utils/detector_factory.lua test/utils_spec.lua
git commit -m "feat(di): add dependency validation in detector factory"
```

---

### Task 1.4: Standardize Context vs Dependencies Access

**Files:**

- Modify: `src/detectors/arithmetic.lua`
- Modify: `src/detectors/date.lua`
- Modify: `src/detectors/navigation.lua`
- Modify: `src/detectors/pd.lua`
- Modify: `src/detectors/registry.lua`
- Test: `test/detectors_spec.lua`

**Step 1: Document the access pattern convention**

Create: `docs/dependency-access-pattern.md`

````markdown
# Dependency Access Pattern

## Rule: Injected Dependencies vs Context

**Injected Dependencies (`deps`):** Default values and core utilities

- `logger` - Always use `deps.logger` or `context.logger`
- `patterns` - Pattern registry
- `formatters` - Formatter utilities
- `config` - Default configuration

**Context (`context`):** Runtime overrides and call-specific data

- `config` - Merged with defaults, use for config access
- `__lastSideEffect` - Side effect tracking

## Access Pattern

```lua
-- CORRECT: Use context for merged config
local benefitPerWeek = (context.config or deps.config).pd.benefitPerWeek

-- CORRECT: Use deps for direct utilities
local pattern = deps.patterns.get("arithmetic")

-- CORRECT: Use context for runtime data
context.__lastSideEffect = meta
```
````

````

**Step 2: Update arithmetic.lua for consistent context access**

Read: `src/detectors/arithmetic.lua`

Find all `context.config` and `deps.patterns` usage - verify they follow the documented pattern

**Step 3: Update pd.lua for consistent context access**

Read: `src/detectors/pd.lua`

Line ~53: Change `local benefitPerWeek = deps.config.pd.benefitPerWeek` to:
```lua
local benefitPerWeek = (context.config or deps.config).pd.benefitPerWeek
````

**Step 4: Update navigation.lua for consistent context access**

Read: `src/detectors/navigation.lua`

Verify logger access pattern uses `deps.logger` consistently

**Step 5: Run tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 6: Commit**

```bash
git add src/detectors/*.lua docs/dependency-access-pattern.md
git commit -m "refactor(di): standardize context vs dependencies access pattern"
```

---

## Area 2: Code Deduplication & Abstractions

### Task 2.1: Create Shared Error Handling Utility

**Files:**

- Create: `src/utils/error_handler.lua`
- Modify: `src/utils/detector_factory.lua`
- Modify: `src/detectors/navigation.lua`
- Test: `test/utils/error_handler_spec.lua`

**Step 1: Write the error handler module**

Create: `src/utils/error_handler.lua`

```lua
--[[
Error handling utilities for ClipboardFormatter

Provides consistent error handling patterns across all modules.
]]

local M = {}

-- Error types
local ErrorTypes = {
    VALIDATION = "validation",
    RUNTIME = "runtime",
    DEPENDENCY = "dependency",
    CONFIGURATION = "configuration"
}

--[[
Wrap a function call with consistent error handling

@param fn function to execute
@param context string describing where the error occurred
@param errorHandler optional custom error handler
@return boolean success, any result or error message
]]
function M.safeCall(fn, context, errorHandler)
    local success, result = pcall(fn)

    if not success then
        if errorHandler then
            return false, errorHandler(result)
        end

        -- Default error formatting
        local errorMsg = string.format("[%s] %s", context or "unknown", tostring(result))
        return false, errorMsg
    end

    return true, result
end

--[[
Create a typed error

@param errorType string from ErrorTypes
@param message string error description
@param details optional table with additional context
@return table error object
]]
function M.makeError(errorType, message, details)
    return {
        type = errorType or "runtime",
        message = message,
        details = details or {},
        timestamp = os.time()
    }
end

--[[
Log error with context

@param logger logger instance
@param context string describing the operation
@param error any error value
]]
function M.logError(logger, context, error)
    if not logger or not logger.e then return end

    local errorStr = error
    if type(error) == "table" then
        errorStr = string.format("%s: %s", error.type, error.message)
    end

    logger.e(string.format("[%s] %s", context, errorStr))
end

M.ErrorTypes = ErrorTypes

return M
```

**Step 2: Write failing tests**

Create: `test/utils/error_handler_spec.lua`

```lua
describe("Error Handler", function()
    local error_handler

    setup(function()
        error_handler = require("ClipboardFormatter.src.utils.error_handler")
    end)

    it("should wrap successful calls", function()
        local fn = function() return "success" end
        local success, result = error_handler.safeCall(fn, "test_operation")

        assert.is_true(success)
        assert.equals("success", result)
    end)

    it("should wrap failed calls with context", function()
        local fn = function() error("test error") end
        local success, result = error_handler.safeCall(fn, "test_operation")

        assert.is_false(success)
        assert.is_truthy(result:match("test_operation"))
        assert.is_truthy(result:match("test error"))
    end)

    it("should use custom error handler", function()
        local fn = function() error("test error") end
        local customHandler = function(err) return "CUSTOM: " .. err end
        local success, result = error_handler.safeCall(fn, "test_operation", customHandler)

        assert.is_false(success)
        assert.is_truthy(result:match("CUSTOM:"))
    end)

    it("should create typed errors", function()
        local err = error_handler.makeError("validation", "Invalid input", {field = "value"})

        assert.equals("validation", err.type)
        assert.equals("Invalid input", err.message)
        assert.equals("value", err.details.field)
        assert.is_not_nil(err.timestamp)
    end)
end)
```

**Step 3: Run tests to verify they fail**

Run: `./scripts/test.sh test/utils/error_handler_spec.lua`

Expected: FAIL - module doesn't exist yet

**Step 4: Create the module**

(The code from Step 1 is the implementation)

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils/error_handler_spec.lua`

Expected: PASS

**Step 6: Update detector_factory.lua to use error_handler**

Read: `src/utils/detector_factory.lua`

Replace lines 4-9 (defaultErrorHandler) with:

```lua
local error_handler = require("ClipboardFormatter.src.utils.error_handler")

-- At the call site (around line 31 in detect function):
local success, result = error_handler.safeCall(function()
    return meta.pattern(input, deps.patterns)
end, meta.name .. ".pattern")

if not success or not result then return nil end
```

**Step 7: Update navigation.lua to use error_handler**

Read: `src/detectors/navigation.lua`

Add import at top:

```lua
local error_handler = require("ClipboardFormatter.src.utils.error_handler")
```

Replace runTask error handling (around lines 60-74) with:

```lua
local success, result = error_handler.safeCall(task.fn, task.desc, function(err)
    error_handler.logError(deps.logger, "navigation", err)
    return err  -- Return original error
end)

if not success then return nil end
```

**Step 8: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 9: Commit**

```bash
git add src/utils/error_handler.lua src/utils/detector_factory.lua src/detectors/navigation.lua test/utils/error_handler_spec.lua
git commit -m "refactor(dedup): extract shared error handling utility"
```

---

### Task 2.2: Create Logging Wrapper Utility

**Files:**

- Create: `src/utils/logging_wrapper.lua`
- Modify: `src/detectors/navigation.lua`
- Modify: `src/detectors/registry.lua`
- Test: `test/utils/logging_wrapper_spec.lua`

**Step 1: Write the logging wrapper module**

Create: `src/utils/logging_wrapper.lua`

```lua
--[[
Logging wrapper with built-in safety checks

Provides null-safe logging that gracefully handles missing or nil loggers.
]]

local M = {}

--[[
Create a safe logger wrapper

@param logger optional logger instance
@return table with safe logging methods
]]
function M.wrap(logger)
    local noop = function() end

    return {
        d = logger and logger.d or noop,  -- debug
        i = logger and logger.i or noop,  -- info
        w = logger and logger.w or noop,  -- warn
        e = logger and logger.e or noop,  -- error
        -- Original logger for direct access if needed
        _logger = logger
    }
end

--[[
Check if logger is available and has a specific level

@param logger logger instance
@param level string log level (d, i, w, e)
@return boolean true if logging is available
]]
function M.canLog(logger, level)
    return logger ~= nil and logger[level] ~= nil
end

--[[
Conditional debug logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.debug(logger, format_string, ...)
    if M.canLog(logger, "d") then
        logger:d(string.format(format_string, ...))
    end
end

--[[
Conditional info logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.info(logger, format_string, ...)
    if M.canLog(logger, "i") then
        logger:i(string.format(format_string, ...))
    end
end

--[[
Conditional warning logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.warn(logger, format_string, ...)
    if M.canLog(logger, "w") then
        logger:w(string.format(format_string, ...))
    end
end

--[[
Conditional error logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.error(logger, format_string, ...)
    if M.canLog(logger, "e") then
        logger:e(string.format(format_string, ...))
    end
end

return M
```

**Step 2: Write failing tests**

Create: `test/utils/logging_wrapper_spec.lua`

```lua
describe("Logging Wrapper", function()
    local logging_wrapper

    setup(function()
        logging_wrapper = require("ClipboardFormatter.src.utils.logging_wrapper")
    end)

    it("should wrap a valid logger", function()
        local mockLogger = {
            d = spy.new(function() end),
            i = spy.new(function() end),
            w = spy.new(function() end),
            e = spy.new(function() end)
        }

        local wrapped = logging_wrapper.wrap(mockLogger)

        wrapped.d("debug message")
        wrapped.i("info message")
        wrapped.w("warning message")
        wrapped.e("error message")

        assert.spy(mockLogger.d).was_called(1)
        assert.spy(mockLogger.i).was_called(1)
        assert.spy(mockLogger.w).was_called(1)
        assert.spy(mockLogger.e).was_called(1)
    end)

    it("should wrap nil logger without errors", function()
        local wrapped = logging_wrapper.wrap(nil)

        -- Should not throw
        wrapped.d("debug message")
        wrapped.i("info message")
        wrapped.w("warning message")
        wrapped.e("error message")

        assert.is_true(true)  -- If we get here, success
    end)

    it("should check logging availability", function()
        local validLogger = { d = function() end }
        assert.is_true(logging_wrapper.canLog(validLogger, "d"))
        assert.is_false(logging_wrapper.canLog(validLogger, "i"))
        assert.is_false(logging_wrapper.canLog(nil, "d"))
    end)

    it("should provide convenience functions", function()
        local mockLogger = { d = spy.new(function() end) }

        logging_wrapper.debug(mockLogger, "value: %s", "test")

        assert.spy(mockLogger.d).was_called_with(match._, "value: test")
    end)
end)
```

**Step 3: Run tests to verify they fail**

Run: `./scripts/test.sh test/utils/logging_wrapper_spec.lua`

Expected: FAIL - module doesn't exist yet

**Step 4: Create the module**

(The code from Step 1 is the implementation)

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils/logging_wrapper_spec.lua`

Expected: PASS

**Step 6: Update navigation.lua to use logging_wrapper**

Read: `src/detectors/navigation.lua`

Add import:

```lua
local log = require("ClipboardFormatter.src.utils.logging_wrapper")
```

Replace logger usage pattern. Find all:

```lua
if deps.logger and deps.logger.d then deps.logger:d(...) end
```

Replace with:

```lua
log.debug(deps.logger, "...")
```

**Step 7: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 8: Commit**

```bash
git add src/utils/logging_wrapper.lua src/detectors/navigation.lua test/utils/logging_wrapper_spec.lua
git commit -m "refactor(dedup): extract safe logging wrapper utility"
```

---

### Task 2.3: Create String Processing Utilities

**Files:**

- Create: `src/utils/string_processing.lua`
- Modify: `src/detectors/arithmetic.lua`
- Modify: `src/detectors/navigation.lua`
- Test: `test/utils/string_processing_spec.lua`

**Step 1: Write the string processing module**

Create: `src/utils/string_processing.lua`

```lua
--[[
String processing utilities

Common string manipulation functions used across detectors and formatters.
]]

local M = {}

--[[
Normalize localized numbers to standard format

Handles various decimal separators and thousand separators.
@param input string number with potential locale formatting
@return string normalized number string
]]
function M.normalizeLocalizedNumber(input)
    if type(input) ~= "string" then return input end

    -- Remove thousand separators (comma or dot followed by 3 digits)
    local normalized = input:gsub(",(%d%d%d)", "%1")
    normalized = normalized:gsub("%.(%d%d%d)", "%1")

    -- Handle decimal comma (European style)
    if normalized:match(",") and not normalized:match("%.") then
        normalized = normalized:gsub(",", ".")
    end

    return normalized
end

--[[
URL encode a string

Simple URL encoding for navigation links.
@param str string to encode
@return string URL-encoded string
]]
function M.urlEncode(str)
    if type(str) ~= "string" then return str end

    return str:gsub("[^%w _~%.%-]",
        function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        :gsub(" ", "+")
end

--[[
Extract last expression from clipboard content

Looks for expressions after =, :, or whitespace boundaries.
Used for seed formatting.
@param content string clipboard content
@return string|nil extracted expression or nil
]]
function M.extractExpression(content)
    if type(content) ~= "string" then return nil end

    -- Try = first (e.g., "= 1 + 2")
    local expr = content:match("=%s*(.+)$")
    if expr then return expr end

    -- Try : (e.g., ":foo bar")
    expr = content:match(":%s*(.+)$")
    if expr then return expr end

    -- Try whitespace boundary
    local lastSpace = content:match("%S+$")
    if lastSpace then return lastSpace end

    return content
end

--[[
Trim whitespace from both ends of string

@param str string to trim
@return string trimmed string
]]
function M.trim(str)
    if type(str) ~= "string" then return str end

    return str:match("^%s*(.-)%s*$")
end

return M
```

**Step 2: Write failing tests**

Create: `test/utils/string_processing_spec.lua`

```lua
describe("String Processing", function()
    local string_proc

    setup(function()
        string_proc = require("ClipboardFormatter.src.utils.string_processing")
    end)

    describe("normalizeLocalizedNumber", function()
        it("should handle comma decimal separator", function()
            assert.equals("123.45", string_proc.normalizeLocalizedNumber("123,45"))
        end)

        it("should handle dot decimal separator", function()
            assert.equals("123.45", string_proc.normalizeLocalizedNumber("123.45"))
        end)

        it("should remove thousand separators", function()
            assert.equals("1234567.89", string_proc.normalizeLocalizedNumber("1,234,567.89"))
        end)

        it("should handle European thousand separators", function()
            assert.equals("1234567.89", string_proc.normalizeLocalizedNumber("1.234.567,89"))
        end)
    end)

    describe("urlEncode", function()
        it("should encode special characters", function()
            local encoded = string_proc.urlEncode("hello world")
            assert.equals("hello+world", encoded)
        end)

        it("should encode spaces as plus", function()
            assert.equals("foo+bar", string_proc.urlEncode("foo bar"))
        end)

        it("should preserve safe characters", function()
            local input = "abc123_-~."
            assert.equals(input, string_proc.urlEncode(input))
        end)
    end)

    describe("extractExpression", function()
        it("should extract after equals sign", function()
            assert.equals("1 + 2", string_proc.extractExpression("Result: 3 = 1 + 2"))
        end)

        it("should extract after colon", function()
            assert.equals("search term", string_proc.extractExpression("Search: :search term"))
        end)

        it("should extract last word", function()
            assert.equals("bar", string_proc.extractExpression("foo baz bar"))
        end)

        it("should return content if no marker", function()
            assert.equals("hello", string_proc.extractExpression("hello"))
        end)
    end)
end)
```

**Step 3: Run tests to verify they fail**

Run: `./scripts/test.sh test/utils/string_processing_spec.lua`

Expected: FAIL - module doesn't exist yet

**Step 4: Create the module**

(The code from Step 1 is the implementation)

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils/string_processing_spec.lua`

Expected: PASS

**Step 6: Update arithmetic.lua to use string_processing**

Read: `src/detectors/arithmetic.lua`

The `normalizeNumber` function (lines 18-59) can be simplified to:

```lua
local string_proc = require("ClipboardFormatter.src.utils.string_processing")

-- In detect function, replace normalizeNumber with:
local normalized = string_proc.normalizeLocalizedNumber(input)
```

**Step 7: Update navigation.lua to use string_processing**

Read: `src/detectors/navigation.lua`

Replace urlEncode function (lines 127-131) with:

```lua
local string_proc = require("ClipboardFormatter.src.utils.string_processing")

-- Replace urlEncode usage:
local encoded = string_proc.urlEncode(query)
```

**Step 8: Update strings.lua to use string_processing**

Read: `src/utils/strings.lua`

The `extractSeed` function can delegate to the new utility:

```lua
local string_proc = require("ClipboardFormatter.src.utils.string_processing")

function M.extractSeed(content)
    return string_proc.extractExpression(content)
end
```

**Step 9: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 10: Commit**

```bash
git add src/utils/string_processing.lua src/detectors/arithmetic.lua src/detectors/navigation.lua src/utils/strings.lua test/utils/string_processing_spec.lua
git commit -m "refactor(dedup): extract shared string processing utilities"
```

---

### Task 2.4: Create Unified Configuration Accessor

**Files:**

- Create: `src/utils/config_accessor.lua`
- Modify: `src/detectors/pd.lua`
- Modify: `src/detectors/navigation.lua`
- Modify: `src/clipboard/selection_modular.lua`
- Test: `test/utils/config_accessor_spec.lua`

**Step 1: Write the config accessor module**

Create: `src/utils/config_accessor.lua`

```lua
--[[
Unified configuration accessor with safe nested access

Provides consistent access to configuration with fallbacks and validation.
]]

local M = {}

--[[
Get a nested config value safely

@param config table configuration object
@param path string dot-notation path (e.g., "pd.benefitPerWeek")
@param default any default value if path not found
@return any config value or default
]]
function M.get(config, path, default)
    if type(config) ~= "table" then return default end

    local current = config
    local keys = {}

    -- Split path by dots
    for key in path:gmatch("[^%.]+") do
        table.insert(keys, key)
    end

    -- Traverse nested structure
    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end

    return current
end

--[[
Merge user config with defaults

User config takes precedence over defaults.
@param defaults table default configuration
@param user table user configuration (can be nil)
@return table merged configuration
]]
function M.merge(defaults, user)
    local result = {}

    -- Copy defaults
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            result[k] = M.merge(v, {})
        else
            result[k] = v
        end
    end

    -- Overlay user config
    if user then
        for k, v in pairs(user) do
            if type(v) == "table" and type(result[k]) == "table" then
                result[k] = M.merge(result[k], v)
            else
                result[k] = v
            end
        end
    end

    return result
end

--[[
Create a context-aware config accessor

@param deps table injected dependencies
@param context table runtime context (optional)
@return table accessor with get() method
]]
function M.accessor(deps, context)
    local merged = M.merge(deps.config or {}, (context or {}).config or {})

    return {
        get = function(path, default)
            return M.get(merged, path, default)
        end,

        raw = merged  -- For raw access if needed
    }
end

return M
```

**Step 2: Write failing tests**

Create: `test/utils/config_accessor_spec.lua`

```lua
describe("Config Accessor", function()
    local config_accessor

    setup(function()
        config_accessor = require("ClipboardFormatter.src.utils.config_accessor")
    end)

    describe("get", function()
        it("should get nested values", function()
            local config = {
                pd = { benefitPerWeek = 290 },
                selection = { copyDelayMs = 50 }
            }

            assert.equals(290, config_accessor.get(config, "pd.benefitPerWeek"))
            assert.equals(50, config_accessor.get(config, "selection.copyDelayMs"))
        end)

        it("should return default for missing path", function()
            local config = { pd = {} }

            assert.equals(100, config_accessor.get(config, "pd.missing", 100))
            assert.equals(nil, config_accessor.get(config, "totally.missing"))
        end)

        it("should handle nil config", function()
            assert.equals("default", config_accessor.get(nil, "any.path", "default"))
        end)
    end)

    describe("merge", function()
        it("should merge user config over defaults", function()
            local defaults = {
                a = 1,
                b = { x = 10, y = 20 }
            }
            local user = {
                b = { y = 99 },
                c = 30
            }

            local result = config_accessor.merge(defaults, user)

            assert.equals(1, result.a)
            assert.equals(10, result.b.x)  -- Default preserved
            assert.equals(99, result.b.y)  -- User override
            assert.equals(30, result.c)    -- New value
        end)
    end)

    describe("accessor", function()
        it("should create context-aware accessor", function()
            local deps = { config = { pd = { benefitPerWeek = 290 } } }
            local context = { config = { pd = { benefitPerWeek = 500 } } }

            local accessor = config_accessor.accessor(deps, context)

            assert.equals(500, accessor:get("pd.benefitPerWeek"))
        end)

        it("should use defaults when context has no override", function()
            local deps = { config = { pd = { benefitPerWeek = 290 } } }
            local context = {}

            local accessor = config_accessor.accessor(deps, context)

            assert.equals(290, accessor:get("pd.benefitPerWeek"))
        end)
    end)
end)
```

**Step 3: Run tests to verify they fail**

Run: `./scripts/test.sh test/utils/config_accessor_spec.lua`

Expected: FAIL - module doesn't exist yet

**Step 4: Create the module**

(The code from Step 1 is the implementation)

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils/config_accessor_spec.lua`

Expected: PASS

**Step 6: Update pd.lua to use config_accessor**

Read: `src/detectors/pd.lua`

Replace line ~53:

```lua
local config_accessor = require("ClipboardFormatter.src.utils.config_accessor")

local cfg = config_accessor.accessor(deps, context)
local benefitPerWeek = cfg:get("pd.benefitPerWeek", 290)
```

**Step 7: Update navigation.lua to use config_accessor**

Read: `src/detectors/navigation.lua`

Replace config access patterns:

```lua
local config_accessor = require("ClipboardFormatter.src.utils.config_accessor")

local cfg = config_accessor.accessor(deps, context)
local copyDelayMs = cfg:get("selection.copyDelayMs", 50)
```

**Step 8: Update selection_modular.lua to use config_accessor**

Read: `src/clipboard/selection_modular.lua`

Replace opts.config usage:

```lua
local config_accessor = require("ClipboardFormatter.src.utils.config_accessor")

local cfg = config_accessor.accessor({config = defaultConfig}, {config = opts.config})
local delay = cfg:get("selection.copyDelayMs", 50)
```

**Step 9: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 10: Commit**

```bash
git add src/utils/config_accessor.lua src/detectors/pd.lua src/detectors/navigation.lua src/clipboard/selection_modular.lua test/utils/config_accessor_spec.lua
git commit -m "refactor(dedup): extract unified config accessor utility"
```

---

### Task 2.5: Create Validation Framework

**Files:**

- Create: `src/utils/validation.lua`
- Modify: `src/utils/detector_factory.lua`
- Test: `test/utils/validation_spec.lua`

**Step 1: Write the validation module**

Create: `src/utils/validation.lua`

```lua
--[[
Validation framework for detectors and formatters

Provides reusable validators for common validation patterns.
]]

local M = {}

-- Error types for validation
local ValidationErrorTypes = {
    MISSING_METHOD = "missing_method",
    INVALID_TYPE = "invalid_type",
    INVALID_VALUE = "invalid_value",
    MISSING_FIELD = "missing_field"
}

--[[
Validate that a table has required methods

@param obj table to validate
@param methods table list of required method names
@return boolean true if valid
@return string|nil error message
]]
function M.hasMethods(obj, methods)
    if type(obj) ~= "table" then
        return false, string.format("Expected table, got %s", type(obj))
    end

    for _, method in ipairs(methods) do
        if type(obj[method]) ~= "function" then
            return false, string.format("Missing required method: %s", method)
        end
    end

    return true
end

--[[
Validate a function result

@param result any value to validate
@param expectedType string expected type (optional)
@return boolean true if valid
@return string|nil error message
]]
function M.validateResult(result, expectedType)
    if result == nil then
        return false, "Result is nil"
    end

    if expectedType then
        if type(result) ~= expectedType then
            return false, string.format("Expected %s, got %s", expectedType, type(result))
        end
    end

    return true
end

--[[
Validate detector spec

@param spec table detector specification
@return boolean true if valid
@return table|nil list of errors
]]
function M.validateDetectorSpec(spec)
    local errors = {}

    if type(spec) ~= "table" then
        return false, {"Expected spec to be a table"}
    end

    -- Required fields
    if not spec.name then
        table.insert(errors, "Missing required field: name")
    end

    if not spec.priority then
        table.insert(errors, "Missing required field: priority")
    end

    -- Validate methods
    if spec.pattern and type(spec.pattern) ~= "function" then
        table.insert(errors, "pattern must be a function")
    end

    if spec.formatter and type(spec.formatter) ~= "function" then
        table.insert(errors, "formatter must be a function")
    end

    return #errors == 0, #errors > 0 and errors or nil
end

--[[
Create a type validator

@param expectedType string expected Lua type
@return function validator function
]]
function M.type(expectedType)
    return function(value)
        return type(value) == expectedType,
               type(value) ~= expectedType and string.format("Expected %s, got %s", expectedType, type(value)) or nil
    end
end

--[[
Create a range validator for numbers

@param min number minimum value (inclusive)
@param max number maximum value (inclusive)
@return function validator function
]]
function M.range(min, max)
    return function(value)
        if type(value) ~= "number" then
            return false, string.format("Expected number, got %s", type(value))
        end

        return value >= min and value <= max,
               value < min and string.format("Value %s below minimum %s", value, min) or
               value > max and string.format("Value %s above maximum %s", value, max) or nil
    end
end

M.ValidationErrorTypes = ValidationErrorTypes

return M
```

**Step 2: Write failing tests**

Create: `test/utils/validation_spec.lua`

```lua
describe("Validation Framework", function()
    local validation

    setup(function()
        validation = require("ClipboardFormatter.src.utils.validation")
    end)

    describe("hasMethods", function()
        it("should validate existing methods", function()
            local obj = { foo = function() end, bar = function() end }
            local valid, err = validation.hasMethods(obj, {"foo", "bar"})

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail on missing method", function()
            local obj = { foo = function() end }
            local valid, err = validation.hasMethods(obj, {"foo", "bar"})

            assert.is_false(valid)
            assert.is_truthy(err:match("bar"))
        end)

        it("should fail on non-table", function()
            local valid, err = validation.hasMethods("string", {"foo"})

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected table"))
        end)
    end)

    describe("validateResult", function()
        it("should pass valid result", function()
            local valid, err = validation.validateResult("hello", "string")

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail on nil result", function()
            local valid, err = validation.validateResult(nil)

            assert.is_false(valid)
            assert.is_truthy(err:match("nil"))
        end)

        it("should fail on type mismatch", function()
            local valid, err = validation.validateResult(123, "string")

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected string"))
        end)
    end)

    describe("validateDetectorSpec", function()
        it("should pass valid spec", function()
            local spec = {
                name = "test",
                priority = 50,
                pattern = function() end,
                formatter = function() end
            }

            local valid, errors = validation.validateDetectorSpec(spec)

            assert.is_true(valid)
            assert.is_nil(errors)
        end)

        it("should fail on missing fields", function()
            local spec = {}

            local valid, errors = validation.validateDetectorSpec(spec)

            assert.is_false(valid)
            assert.truthy(errors.name)
            assert.truthy(errors.priority)
        end)

        it("should fail on wrong types", function()
            local spec = {
                name = "test",
                priority = 50,
                pattern = "not a function",
                formatter = function() end
            }

            local valid, errors = validation.validateDetectorSpec(spec)

            assert.is_false(valid)
            assert.truthy(errors.pattern)
        end)
    end)

    describe("type validator", function()
        it("should validate correct type", function()
            local validator = validation.type("string")
            local valid, err = validator("hello")

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail wrong type", function()
            local validator = validation.type("string")
            local valid, err = validator(123)

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected string"))
        end)
    end)

    describe("range validator", function()
        it("should validate within range", function()
            local validator = validation.range(1, 10)
            local valid, err = validator(5)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail below minimum", function()
            local validator = validation.range(1, 10)
            local valid, err = validator(0)

            assert.is_false(valid)
            assert.is_truthy(err:match("below minimum"))
        end)

        it("should fail above maximum", function()
            local validator = validation.range(1, 10)
            local valid, err = validator(11)

            assert.is_false(valid)
            assert.is_truthy(err:match("above maximum"))
        end)
    end)
end)
```

**Step 3: Run tests to verify they fail**

Run: `./scripts/test.sh test/utils/validation_spec.lua`

Expected: FAIL - module doesn't exist yet

**Step 4: Create the module**

(The code from Step 1 is the implementation)

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils/validation_spec.lua`

Expected: PASS

**Step 6: Update detector_factory.lua to use validation**

Read: `src/utils/detector_factory.lua`

Replace the manual validation (lines ~24-36) with:

```lua
local validation = require("ClipboardFormatter.src.utils.validation")

-- After line 13 (meta assignment), add:
local valid, errors = validation.validateDetectorSpec(spec)
if not valid then
    error(string.format("Invalid detector spec: %s", table.concat(errors, ", ")))
end
```

**Step 7: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 8: Commit**

```bash
git add src/utils/validation.lua src/utils/detector_factory.lua test/utils/validation_spec.lua
git commit -m "refactor(dedup): create unified validation framework"
```

---

## Area 3: Configuration & Constants

### Task 3.1: Centralize All Constants

**Files:**

- Create: `src/config/constants.lua`
- Modify: `src/utils/patterns.lua`
- Modify: `src/clipboard/selection_modular.lua`
- Modify: `src/init.lua`
- Modify: `src/config/defaults.lua`
- Test: `test/config/constants_spec.lua`

**Step 1: Write the constants module**

Create: `src/config/constants.lua`

```lua
--[[
Centralized constants for ClipboardFormatter

All magic numbers and configuration values are defined here
for easy maintenance and consistency.
]]

local M = {}

-- Detector Priorities
-- Higher priority detectors are evaluated first
M.PRIORITY = {
    PD_CONVERSION = 100,
    ARITHMETIC = 80,
    DATE_RANGE = 10000,  -- Deliberately low priority
    COMBINATIONS = 70,
    NAVIGATION = 60,
    PHONE = 90
}

-- Time Constants (milliseconds)
M.TIME = {
    SELECTION_COPY_DELAY = 50,
    SELECTION_EVENT_DELAY = 300,
    SELECTION_TIMEOUT = 500,
    THROTTLE_DEFAULT = 500
}

-- Cache Constants
M.CACHE = {
    PATTERN_MAX_SIZE = 100,
    PATTERN_MEMORY_THRESHOLD_MB = 10,
    LRU_INITIAL_CAPACITY = 50
}

-- Pattern Names
M.PATTERNS = {
    ARITHMETIC = "arithmetic",
    DATE_RANGE = "date_range",
    COMBINATION = "combination",
    PHONE = "phone"
}

-- Error Messages
M.ERRORS = {
    MISSING_DEPENDENCY = "missing required dependency",
    INVALID_DETECTOR_SPEC = "invalid detector specification",
    PATTERN_NOT_FOUND = "pattern not found in registry",
    FORMATTER_MISSING = "formatter method not found"
}

-- PD (Permanent Disability) Defaults
M.PD = {
    BENEFIT_PER_WEEK = 290
}

-- File Paths (can be overridden by environment)
M.PATHS = {
    -- PD mapping files
    PD_BUNDLED = "hsStringEval/config/pd_mappings.lua",
    PD_USER = hs and hs.configdir .. "/hsStringEval/pd_mappings.lua" or nil,
    PD_FALLBACK = hs and hs.configdir .. "/pd_mappings.lua" or nil
}

-- Validation Constants
M.VALIDATION = {
    MAX_CLIPBOARD_LENGTH = 100000,
    MAX_SELECTION_RETRIES = 3
}

return M
```

**Step 2: Write failing tests**

Create: `test/config/constants_spec.lua`

```lua
describe("Constants", function()
    local constants

    setup(function()
        constants = require("ClipboardFormatter.src.config.constants")
    end)

    it("should define all priority constants", function()
        assert.equals(100, constants.PRIORITY.PD_CONVERSION)
        assert.equals(80, constants.PRIORITY.ARITHMETIC)
        assert.equals(70, constants.PRIORITY.COMBINATIONS)
        assert.equals(60, constants.PRIORITY.NAVIGATION)
    end)

    it("should define all time constants", function()
        assert.equals(50, constants.TIME.SELECTION_COPY_DELAY)
        assert.equals(300, constants.TIME.SELECTION_EVENT_DELAY)
    end)

    it("should define cache constants", function()
        assert.equals(100, constants.CACHE.PATTERN_MAX_SIZE)
        assert.equals(10, constants.CACHE.PATTERN_MEMORY_THRESHOLD_MB)
    end)

    it("should define PD defaults", function()
        assert.equals(290, constants.PD.BENEFIT_PER_WEEK)
    end)

    it("should define pattern names", function()
        assert.equals("arithmetic", constants.PATTERNS.ARITHMETIC)
        assert.equals("date_range", constants.PATTERNS.DATE_RANGE)
    end)
end)
```

**Step 3: Run tests to verify they fail**

Run: `./scripts/test.sh test/config/constants_spec.lua`

Expected: FAIL - module doesn't exist yet

**Step 4: Create the module**

(The code from Step 1 is the implementation)

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/config/constants_spec.lua`

Expected: PASS

**Step 6: Update all files to use constants**

Read: `src/detectors/pd.lua`
Change priority from `100` to `constants.PRIORITY.PD_CONVERSION`

Read: `src/detectors/arithmetic.lua`
Change priority from `80` to `constants.PRIORITY.ARITHMETIC`

Read: `src/detectors/combinations.lua`
Change priority from `70` to `constants.PRIORITY.COMBINATIONS`

Read: `src/detectors/navigation.lua`
Change priority from `60` to `constants.PRIORITY.NAVIGATION`

Read: `src/utils/patterns.lua`
Replace `100` with `constants.CACHE.PATTERN_MAX_SIZE`
Replace `10` with `constants.CACHE.PATTERN_MEMORY_THRESHOLD_MB`

Read: `src/clipboard/selection_modular.lua`
Replace `50` with `constants.TIME.SELECTION_COPY_DELAY`
Replace `300` with `constants.TIME.SELECTION_EVENT_DELAY`

Read: `src/detectors/pd.lua`
Replace `290` with `constants.PD.BENEFIT_PER_WEEK`

**Step 7: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 8: Commit**

```bash
git add src/config/constants.lua src/detectors/*.lua src/utils/patterns.lua src/clipboard/selection_modular.lua test/config/constants_spec.lua
git commit -m "refactor(config): centralize all magic numbers into constants module"
```

---

### Task 3.2: Centralize PD Mapping Paths Configuration

**Files:**

- Modify: `src/config/defaults.lua`
- Modify: `src/utils/pd_cache.lua`
- Test: `test/config/pd_paths_spec.lua`

**Step 1: Update defaults.lua with centralized path configuration**

Read: `src/config/defaults.lua`

Replace the hardcoded paths (lines 28-31) with:

```lua
local constants = require("ClipboardFormatter.src.config.constants")

-- In the config return:
pd = {
    benefitPerWeek = constants.PD.BENEFIT_PER_WEEK,
    mappingPaths = {
        constants.PATHS.PD_BUNDLED,
        constants.PATHS.PD_USER,
        constants.PATHS.PD_FALLBACK
    }
}
```

**Step 2: Update pd_cache.lua to use config paths**

Read: `src/utils/pd_cache.lua`

Replace hardcoded paths with config access:

```lua
local function getMappingPaths(config)
    return config.pd.mappingPaths or {
        "hsStringEval/config/pd_mappings.lua",
        hs.configdir .. "/hsStringEval/pd_mappings.lua",
        hs.configdir .. "/pd_mappings.lua"
    }
end
```

**Step 3: Run tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 4: Commit**

```bash
git add src/config/defaults.lua src/utils/pd_cache.lua
git commit -m "refactor(config): centralize PD mapping paths configuration"
```

---

### Task 3.3: Add Configuration Schema Validation

**Files:**

- Create: `src/config/schema.lua`
- Create: `src/config/validator.lua`
- Modify: `src/init.lua`
- Test: `test/config/schema_spec.lua`

**Step 1: Write the configuration schema**

Create: `src/config/schema.lua`

```lua
--[[
Configuration schema definition

Defines the expected structure and types for all configuration values.
]]

local constants = require("ClipboardFormatter.src.config.constants")

local M = {}

return {
    pd = {
        benefitPerWeek = "number",
        mappingPaths = "table"
    },

    processing = {
        throttleMs = "number",
        priority = "table"
    },

    selection = {
        copyDelayMs = "number",
        eventDelayMs = "number",
        timeoutMs = "number",
        maxRetries = "number"
    },

    patterns = {
        maxCacheSize = "number",
        memoryThresholdMB = "number",
        autoCleanup = "boolean"
    },

    logging = {
        level = "string",
        sinks = "table"
    },

    templates = {
        arithmetic = "string"
    }
}
```

**Step 2: Write the configuration validator**

Create: `src/config/validator.lua`

```lua
--[[
Configuration validator

Validates user configuration against the schema.
]]

local schema = require("ClipboardFormatter.src.config.schema")
local validation = require("ClipboardFormatter.src.utils.validation")

local M = {}

--[[
Validate configuration against schema

@param config table user configuration
@param defaults table default configuration
@return boolean true if valid
@return table|nil validation errors
]]
function M.validate(config, defaults)
    local errors = {}
    local merged = validation.merge(defaults, config or {})

    for section, fields in pairs(schema) do
        if merged[section] then
            for field, expectedType in pairs(fields) do
                local value = merged[section][field]
                if value ~= nil and type(value) ~= expectedType then
                    table.insert(errors, string.format(
                        "%s.%s: expected %s, got %s",
                        section, field, expectedType, type(value)
                    ))
                end
            end
        end
    end

    return #errors == 0, #errors > 0 and errors or nil
end

return M
```

**Step 3: Write failing tests**

Create: `test/config/schema_spec.lua`

```lua
describe("Configuration Schema Validator", function()
    local config_validator
    local defaults

    setup(function()
        config_validator = require("ClipboardFormatter.src.config.validator")
        defaults = require("ClipboardFormatter.src.config.defaults")
    end)

    it("should pass valid config", function()
        local config = {
            pd = { benefitPerWeek = 300 }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_true(valid)
        assert.is_nil(errors)
    end)

    it("should fail on type mismatch", function()
        local config = {
            pd = { benefitPerWeek = "not a number" }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_false(valid)
        assert.truthy(errors[1]:match("expected number"))
    end)

    it("should validate nested config", function()
        local config = {
            selection = { copyDelayMs = "invalid" }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_false(valid)
        assert.truthy(errors[1]:match("selection.copyDelayMs"))
    end)
end)
```

**Step 4: Run tests to verify they fail**

Run: `./scripts/test.sh test/config/schema_spec.lua`

Expected: FAIL - modules don't exist yet

**Step 5: Create the modules**

(The code from Steps 1 and 2 are the implementations)

**Step 6: Run tests to verify they pass**

Run: `./scripts/test.sh test/config/schema_spec.lua`

Expected: PASS

**Step 7: Integrate validation into spoon initialization**

Read: `src/init.lua`

After loading user config, add validation:

```lua
local config_validator = require("ClipboardFormatter.src.config.validator")

-- After merging user config with defaults:
local valid, errors = config_validator.validate(userConfig, defaults)
if not valid then
    hs.luaalertLog("ClipboardFormatter", "Invalid configuration:\n" .. table.concat(errors, "\n"))
    -- Continue with defaults, but log the issue
end
```

**Step 8: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 9: Commit**

```bash
git add src/config/schema.lua src/config/validator.lua src/init.lua test/config/schema_spec.lua
git commit -m "feat(config): add configuration schema validation"
```

---

## Area 4: Performance Optimizations

### Task 4.1: Optimize Pattern Caching Strategy

**Files:**

- Modify: `src/utils/patterns.lua`
- Test: `test/utils/patterns_spec.lua`

**Step 1: Write failing test for precompilation**

Add to: `test/utils/patterns_spec.lua`

```lua
it("should precompile critical patterns at startup", function()
    local patterns = require("ClipboardFormatter.src.utils.patterns")

    -- Configure precompilation
    patterns.configure({
        precompile = {"arithmetic", "date_range", "phone"}
    })

    -- Access should be fast (cached)
    local start = os.clock()
    local pattern1 = patterns.get("arithmetic")
    local pattern2 = patterns.get("arithmetic")
    local elapsed = os.clock() - start

    assert.is_not_nil(pattern1)
    assert.equals(pattern1, pattern2)
    assert.is_true(elapsed < 0.01)  -- Should be very fast
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/utils/patterns_spec.lua`

Expected: FAIL - precompile option not implemented

**Step 3: Implement precompilation in patterns.lua**

Read: `src/utils/patterns.lua`

Add precompilation support:

```lua
-- Add to configuration options
local config = {
    maxCacheSize = 100,
    memoryThresholdMB = 10,
    autoCleanup = true,
    precompile = nil  -- new option
}

-- Add precompilation function
local function precompilePatterns(patternList)
    if not patternList then return end

    for _, name in ipairs(patternList) do
        if patternRegistry[name] then
            -- Force compilation and caching
            getCompiledPattern(name)
        end
    end
end

-- Update configure function
function M.configure(opts)
    if opts then
        for k, v in pairs(opts) do
            config[k] = v
        end
    end

    -- Precompile critical patterns if specified
    if opts.precompile then
        precompilePatterns(opts.precompile)
    end
end
```

**Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils/patterns_spec.lua`

Expected: PASS

**Step 5: Update defaults.lua to include precompilation**

Read: `src/config/defaults.lua`

Add to patterns config:

```lua
patterns = {
    maxCacheSize = 100,
    memoryThresholdMB = 10,
    autoCleanup = true,
    precompile = {"arithmetic", "date_range", "phone", "combination"}
}
```

**Step 6: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 7: Commit**

```bash
git add src/utils/patterns.lua src/config/defaults.lua test/utils/patterns_spec.lua
git commit -m "perf(patterns): add pattern precompilation for faster startup"
```

---

### Task 4.2: Add Early Exit to Registry Processing

**Files:**

- Modify: `src/detectors/registry.lua`
- Test: `test/detectors/registry_spec.lua`

**Step 1: Write test for early exit behavior**

Add to: `test/detectors/registry_spec.lua`

```lua
it("should stop processing after first match when configured", function()
    local mockDetector = spy.new(function(input)
        return { formatted = "result", matchedId = "test" }
    end)

    local mockDetector2 = spy.new(function(input)
        error("This should not be called")
    end)

    local registry = require("ClipboardFormatter.src.detectors.registry")

    -- Clear and register detectors
    registry.clear()
    registry.register("test", mockDetector, 100)
    registry.register("test2", mockDetector2, 50)

    -- Process with early exit
    local result = registry.process("test input", {earlyExit = true})

    assert.is_not_nil(result)
    assert.spy(mockDetector).was_called(1)
    assert.spy(mockDetector2).was_called(0)  -- Should not be called
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/detectors/registry_spec.lua`

Expected: FAIL - earlyExit option not implemented

**Step 3: Implement early exit in registry.lua**

Read: `src/detectors/registry.lua`

Modify process function:

```lua
function M.process(input, context)
    -- Validate input
    if not input or input == "" then return nil end

    -- Process detectors in priority order
    for _, detectorInfo in ipairs(detectorList) do
        local success, result = pcall(function()
            return detectorInfo.detect(input, context)
        end)

        if success and result then
            -- Early exit if configured
            if context and context.earlyExit then
                return result
            end

            -- Existing collection logic
            table.insert(matches, result)
        end
    end

    -- Return based on context
    if context and context.earlyExit then
        return matches[1] or nil
    end

    return #matches > 0 and matches or nil
end
```

**Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh test/detectors/registry_spec.lua`

Expected: PASS

**Step 5: Update defaults to enable early exit by default**

Read: `src/config/defaults.lua`

Add to processing config:

```lua
processing = {
    throttleMs = 500,
    earlyExit = true  -- Stop after first match
}
```

**Step 6: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 7: Commit**

```bash
git add src/detectors/registry.lua src/config/defaults.lua test/detectors/registry_spec.lua
git commit -m "perf(registry): add early exit optimization for faster processing"
```

---

### Task 4.3: Optimize Arithmetic Evaluation Path Selection

**Files:**

- Modify: `src/detectors/arithmetic.lua`
- Test: `test/detectors/arithmetic_spec.lua`

**Step 1: Write test for smart evaluation path selection**

Add to: `test/detectors/arithmetic_spec.lua`

```lua
it("should use fast evaluation for simple expressions", function()
    local detector = createDetector()

    -- Simple expression should use load() path
    local result = detector("= 2 + 2", {})

    assert.is_not_nil(result)
    assert.equals("4", result.formatted)
end)

it("should use safe evaluation for complex expressions", function()
    local detector = createDetector()

    -- Complex expression with operators requiring tokenization
    local result = detector("= 5 % 2 ^ 3", {})

    assert.is_not_nil(result)
    assert.equals("5", result.formatted)  -- 5 % (2^3) = 5 % 8 = 5
end)
```

**Step 2: Check current behavior**

Run: `./scripts/test.sh test/detectors/arithmetic_spec.lua`

Expected: Tests should pass with current implementation

**Step 3: Optimize evaluation path selection**

Read: `src/detectors/arithmetic.lua`

Add smart path selection:

```lua
-- After pattern matching, add complexity check:
local function needsTokenization(expr)
    -- Check for operators requiring tokenization
    return expr:match("%%") or expr:match("%^") or
           expr:match("[%[%](){}]")
end

-- In detect function, modify evaluation:
if needsTokenization(expr) then
    -- Use tokenization for complex expressions
    local tokens = tokenize(expr)
    if tokens then
        result = evaluateTokens(tokens)
    end
else
    -- Use fast load() for simple expressions
    result = evaluateEquation(expr)
end
```

**Step 4: Run tests**

Run: `./scripts/test.sh test/detectors/arithmetic_spec.lua`

Expected: All tests pass

**Step 5: Add benchmark test**

Add to test file:

```lua
it("should be faster for simple expressions", function()
    local detector = createDetector()
    local iterations = 100

    local start = os.clock()
    for i = 1, iterations do
        detector("= 1 + 1", {})
    end
    local simpleTime = os.clock() - start

    start = os.clock()
    for i = 1, iterations do
        detector("= 5 % 2 ^ 3", {})
    end
    local complexTime = os.clock() - start

    -- Simple should be faster (or at least not much slower)
    assert.is_true(simpleTime <= complexTime * 2)
end)
```

**Step 6: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 7: Commit**

```bash
git add src/detectors/arithmetic.lua test/detectors/arithmetic_spec.lua
git commit -m "perf(arithmetic): optimize evaluation path selection"
```

---

## Area 5: Testing Improvements

### Task 5.1: Create Integration Test Suite

**Files:**

- Create: `test/integration/clipboard_formatting_spec.lua`
- Create: `test/integration/selection_formatting_spec.lua`
- Create: `test/integration/detector_chain_spec.lua`

**Step 1: Write clipboard formatting integration test**

Create: `test/integration/clipboard_formatting_spec.lua`

```lua
describe("Clipboard Formatting Integration", function()
    local ClipboardFormatter

    setup(function()
        ClipboardFormatter = require("ClipboardFormatter.src.init")
    end)

    it("should format arithmetic from clipboard", function()
        local input = "The result is 15 + 27 = 42"
        local result = ClipboardFormatter.format(input)

        assert.is_not_nil(result)
        assert.is_truthy(result:match("42") or result:match("15 %+ 27"))
    end)

    it("should format date ranges from clipboard", function()
        local input = "Meeting from 2024-01-15 to 2024-01-20"
        local result = ClipboardFormatter.format(input)

        assert.is_not_nil(result)
    end)

    it("should handle multiple detectors on same input", function()
        local input = "PD 60% = 120, math: 15 + 27 = 42"
        local result = ClipboardFormatter.format(input)

        assert.is_not_nil(result)
    end)

    it("should return original if no patterns match", function()
        local input = "No patterns here"
        local result = ClipboardFormatter.format(input)

        assert.equals(input, result)
    end)
end)
```

**Step 2: Write selection formatting integration test**

Create: `test/integration/selection_formatting_spec.lua`

```lua
describe("Selection Formatting Integration", function()
    local ClipboardFormatter

    setup(function()
        ClipboardFormatter = require("ClipboardFormatter.src.init")
    end)

    it("should format selected arithmetic expression", function()
        local input = "15 + 27"
        local result = ClipboardFormatter.formatSelection(input)

        assert.is_not_nil(result)
        assert.equals("42", result)
    end)

    it("should format selected phone number", function()
        local input = "Call me at 415-555-1234"
        local result = ClipboardFormatter.formatSelection(input)

        assert.is_not_nil(result)
    end)

    it("should handle empty selection", function()
        local result = ClipboardFormatter.formatSelection("")

        assert.equals("", result)
    end)
end)
```

**Step 3: Write detector chain integration test**

Create: `test/integration/detector_chain_spec.lua`

```lua
describe("Detector Chain Integration", function()
    local registry

    setup(function()
        registry = require("ClipboardFormatter.src.detectors.registry")
    end)

    it("should process detectors in priority order", function()
        -- Clear and register test detectors
        registry.clear()

        local callOrder = {}
        registry.register("high", function(input)
            table.insert(callOrder, "high")
            return nil  -- No match
        end, 100)

        registry.register("medium", function(input)
            table.insert(callOrder, "medium")
            return {formatted = "medium result"}
        end, 50)

        registry.register("low", function(input)
            table.insert(callOrder, "low")
            return {formatted = "low result"}
        end, 10)

        registry.process("test", {})

        -- Should call high, medium, then stop (low not called)
        assert.equals("high", callOrder[1])
        assert.equals("medium", callOrder[2])
        assert.is_nil(callOrder[3])
    end)

    it("should handle all detectors with no early exit", function()
        registry.clear()

        local callOrder = {}
        registry.register("first", function(input)
            table.insert(callOrder, "first")
            return {formatted = "first"}
        end, 100)

        registry.register("second", function(input)
            table.insert(callOrder, "second")
            return {formatted = "second"}
        end, 50)

        registry.process("test", {earlyExit = false})

        -- Should call both
        assert.equals(2, #callOrder)
    end)
end)
```

**Step 4: Run integration tests**

Run: `./scripts/test.sh test/integration/`

Expected: Tests pass

**Step 5: Commit**

```bash
git add test/integration/
git commit -m "test(integration): add integration test suite for end-to-end scenarios"
```

---

### Task 5.2: Standardize Mocking with Test Helpers

**Files:**

- Create: `test/helpers/mocks.lua`
- Modify: `test/spec_helper.lua`
- Modify: `test/detectors_spec.lua` (to use new mocks)

**Step 1: Create standardized mock helpers**

Create: `test/helpers/mocks.lua`

```lua
--[[
Standardized mock objects for testing

Provides consistent mock implementations across all tests.
]]

local M = {}

--[[
Create a mock logger

@param config table optional configuration
@return table mock logger
]]
function M.mockLogger(config)
    config = config or {}

    local logs = {
        debug = {},
        info = {},
        warn = {},
        error = {}
    }

    return {
        d = function(msg)
            table.insert(logs.debug, msg)
            if config.verbose then print("[DEBUG] " .. msg) end
        end,
        i = function(msg)
            table.insert(logs.info, msg)
            if config.verbose then print("[INFO] " .. msg) end
        end,
        w = function(msg)
            table.insert(logs.warn, msg)
            if config.verbose then print("[WARN] " .. msg) end
        end,
        e = function(msg)
            table.insert(logs.error, msg)
            if config.verbose then print("[ERROR] " .. msg) end
        end,

        -- Test helpers
        _logs = logs,
        _clear = function()
            logs.debug = {}
            logs.info = {}
            logs.warn = {}
            logs.error = {}
        end,
        _hadLog = function(level, pattern)
            for _, msg in ipairs(logs[level] or {}) do
                if msg:match(pattern) then return true end
            end
            return false
        end
    }
end

--[[
Create a mock pattern registry

@param patterns table optional pattern definitions
@return table mock pattern registry
]]
function M.mockPatterns(patterns)
    patterns = patterns or {}

    return {
        get = function(name)
            return patterns[name]
        end,
        register = function(name, pattern)
            patterns[name] = pattern
        end
    }
end

--[[
Create a mock formatter

@return table mock formatter
]]
function M.mockFormatter()
    return {
        arithmetic = spy.new(function(result) return result end),
        currency = spy.new(function(amount) return "$" .. amount end),
        date = spy.new(function(dateStr) return dateStr end),
        phone = spy.new(function(phone) return phone end),

        -- Test helpers
        _reset = function()
            for k, v in pairs(mockFormatter()) do
                if type(v) == "function" then
                    mockFormatter()[k] = v
                end
            end
        end
    }
end

--[[
Create a mock PD mapping

@return table mock PD mapping
]]
function M.mockPDMapping()
    return {
        getPD = function(percentage)
            return {
                percentage = percentage,
                benefitPerWeek = 290,
                weeklyBenefit = math.floor(290 * percentage / 100)
            }
        end
    }
end

--[[
Create a mock Hammerspoon environment

@return table mock hs table
]]
function M.mockHammerspoon()
    return {
        eventtap = {
            keyStroke = spy.new(function() end)
        },
        clipboard = {
            getContents = spy.new(function() return "" end),
            setContents = spy.new(function() end)
        },
        timer = {
            doAfter = spy.new(function(delay, fn) fn() end)
        },
        alert = spy.new(function() end),
        luaalertLog = spy.new(function() end)
    }
end

--[[
Create complete mock dependencies for detector testing

@param overrides table optional dependency overrides
@return table complete mock dependencies
]]
function M.mockDependencies(overrides)
    local deps = {
        logger = M.mockLogger(),
        patterns = M.mockPatterns(),
        formatters = M.mockFormatter(),
        config = require("ClipboardFormatter.src.config.defaults"),
        pdMapping = M.mockPDMapping(),
        hs = M.mockHammerspoon()
    }

    -- Apply overrides
    if overrides then
        for k, v in pairs(overrides) do
            deps[k] = v
        end
    end

    return deps
end

return M
```

**Step 2: Update spec_helper to expose mocks**

Read: `test/spec_helper.lua`

Add:

```lua
-- Add to exports
local mocks = require("test.helpers.mocks")
_M.mocks = mocks
```

**Step 3: Update a test to use new mocks**

Read: `test/detectors/arithmetic_spec.lua`

Replace mock setup with:

```lua
local mocks = require("test.helpers.mocks")

describe("Arithmetic Detector", function()
    local detector
    local mockDeps

    setup(function()
        mockDeps = mocks.mockDependencies({
            patterns = {
                arithmetic = "%f[%w%$%€]?%s*(%d+[.,]?%d*)%s*([+%-*/%%%^])%s*(%d+[.,]?%d*)%s*=?"
            }
        })

        local Arithmetic = require("ClipboardFormatter.src.detectors.arithmetic")
        detector = Arithmetic(mockDeps)
    end)
end)
```

**Step 4: Run tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 5: Commit**

```bash
git add test/helpers/mocks.lua test/spec_helper.lua test/detectors/arithmetic_spec.lua
git commit -m "test(helpers): create standardized mock objects for consistent testing"
```

---

### Task 5.3: Add Property-Based Testing for Edge Cases

**Files:**

- Create: `test/property/string_processing_spec.lua`
- Create: `test/property/arithmetic_spec.lua`

**Step 1: Install property-based testing library**

Run: `luarocks install --only-deps --tree ./lua_modules lunatest`

Or create simple property testing helpers:

**Step 2: Create property testing helper**

Create: `test/helpers/property.lua`

```lua
--[[
Simple property-based testing helper
]]

local M = {}

--[[
Generate random test cases

@param generator function to generate random values
@param count number of test cases
@return table list of generated values
]]
function M.generate(generator, count)
    local results = {}
    for i = 1, count do
        table.insert(results, generator(i))
    end
    return results
end

--[[
Test a property holds for all generated cases

@param name string property name
@param generator function to generate test cases
@param property function to test (should return true if property holds)
@param count number of test cases (default 100)
]]
function M.forAll(name, generator, property, count)
    count = count or 100

    for i = 1, count do
        local value = generator(i)
        local result, err = property(value)

        if not result then
            error(string.format(
                "Property '%s' failed for value: %s\n%s",
                name,
                inspect(value),
                err or ""
            ))
        end
    end
end

return M
```

**Step 3: Write property-based tests for string processing**

Create: `test/property/string_processing_spec.lua`

```lua
describe("String Processing - Property Tests", function()
    local string_proc
    local property

    setup(function()
        string_proc = require("ClipboardFormatter.src.utils.string_processing")
        property = require("test.helpers.property")
    end)

    it("should normalize to valid number format", function()
        property.forAll(
            "normalization produces valid format",
            function(i)
                -- Generate numbers with various formats
                local formats = {
                    string.format("%d.%d", i, i % 100),      -- 123.45
                    string.format("%d,%d", i, i % 100),      -- 123,45
                    string.format("%d,%d%d%d", i, i % 10),   -- 1,234
                }
                return formats[(i % #formats) + 1]
            end,
            function(input)
                local result = string_proc.normalizeLocalizedNumber(input)
                -- Should be parseable as number
                return tonumber(result) ~= nil, result
            end,
            50
        )
    end)

    it("should preserve numeric value through normalization", function()
        property.forAll(
            "normalization preserves value",
            function(i)
                return string.format("%d.%d", i, i % 100)
            end,
            function(input)
                local original = tonumber(input:gsub(",", "."))
                local normalized = string_proc.normalizeLocalizedNumber(input)
                local result = tonumber(normalized)

                return math.abs(original - result) < 0.01,
                       string.format("Original: %s, Normalized: %s", original, result)
            end,
            50
        )
    end)
end)
```

**Step 4: Write property-based tests for arithmetic**

Create: `test/property/arithmetic_spec.lua`

```lua
describe("Arithmetic - Property Tests", function()
    local property
    local mockDeps
    local detector

    setup(function()
        property = require("test.helpers.property")
        local mocks = require("test.helpers.mocks")
        mockDeps = mocks.mockDependencies()
        local Arithmetic = require("ClipboardFormatter.src.detectors.arithmetic")
        detector = Arithmetic(mockDeps)
    end)

    it("should round-trip simple addition", function()
        property.forAll(
            "addition commutes",
            function(i)
                return string.format("= %d + %d", i, (i + 1) % 100)
            end,
            function(input)
                local result = detector(input, {})
                return result ~= nil, input
            end,
            30
        )
    end)

    it("should handle all basic operators", function()
        local operators = {"+", "-", "*", "/"}
        property.forAll(
            "all operators work",
            function(i)
                local op = operators[(i % #operators) + 1]
                local a = i + 1
                local b = (i % 10) + 1  -- Avoid division by zero
                return string.format("= %d %s %d", a, op, b)
            end,
            function(input)
                local result = detector(input, {})
                return result ~= nil, input
            end,
            40
        )
    end)
end)
```

**Step 5: Run property tests**

Run: `./scripts/test.sh test/property/`

Expected: All property tests pass

**Step 6: Commit**

```bash
git add test/helpers/property.lua test/property/
git commit -m "test(property): add property-based tests for edge cases"
```

---

## Area 6: Code Organization

### Task 6.1: Split Monolithic init.lua

**Files:**

- Create: `src/spoon/runtime.lua` (spoon initialization)
- Create: `src/spoon/hotkeys.lua` (hotkey helpers)
- Create: `src/spoon/hooks.lua` (hook system)
- Modify: `src/init.lua` (becomes thin entry point)

**Step 1: Extract spoon runtime to separate module**

Read: `src/init.lua` to identify spoon initialization code

Create: `src/spoon/runtime.lua`

```lua
--[[
Spoon runtime module

Handles Hammerspoon spoon initialization and lifecycle.
]]

local M = {}

--[[
Initialize the spoon

@param spoon table spoon instance
]]
function M.init(spoon)
    -- Spoon initialization logic from init.lua
    -- Copy relevant sections here

    return spoon
end

--[[
Get spoon metadata

@return table metadata
]]
function M.metadata()
    return {
        version = "1.0",
        author = "Original author",
        homepage = "https://github.com/...",
        license = "MIT",
        description = "Clipboard formatting spoon"
    }
end

return M
```

**Step 2: Extract hotkey helpers**

Create: `src/spoon/hotkeys.lua`

```lua
--[[
Hotkey helpers for ClipboardFormatter

Provides convenient hotkey setup functions.
]]

local M = {}

--[[
Bind hotkey for clipboard formatting

@param spoon table spoon instance
@param mods table modifier keys
@param key string key character
]]
function M.bindFormatClip(spoon, mods, key)
    spoon.hs.hotkey.bind(mods, key, function()
        spoon:formatClip()
    end)
end

--[[
Bind hotkey for seed formatting

@param spoon table spoon instance
@param mods table modifier keys
@param key string key character
]]
function M.bindFormatSeed(spoon, mods, key)
    spoon.hs.hotkey.bind(mods, key, function()
        spoon:formatClipSeed()
    end)
end

return M
```

**Step 3: Extract hook system**

Create: `src/spoon/hooks.lua`

```lua
--[[
Hook system for runtime extension

Allows users to extend spoon behavior at specific lifecycle points.
]]

local M = {}

local hooks = {}

--[[
Register a hook

@param name string hook name
@param fn function hook callback
]]
function M.register(name, fn)
    if not hooks[name] then
        hooks[name] = {}
    end
    table.insert(hooks[name], fn)
end

--[[
Execute hooks

@param name string hook name
@param ... any arguments to pass to hooks
]]
function M.execute(name, ...)
    if hooks[name] then
        for _, fn in ipairs(hooks[name]) do
            fn(...)
        end
    end
end

--[[
Get all registered hooks

@return table hooks registry
]]
function M.getAll()
    return hooks
end

return M
```

**Step 4: Simplify init.lua to entry point**

Read: `src/init.lua` and refactor to:

```lua
--[[
ClipboardFormatter Spoon

Main entry point for the clipboard formatting spoon.
]]

local M = {}

-- Import submodules
local runtime = require("ClipboardFormatter.src.spoon.runtime")
local hotkeys = require("ClipboardFormatter.src.spoon.hotkeys")
local hooks = require("ClipboardFormatter.src.spoon.hooks")
local registry = require("ClipboardFormatter.src.detectors.registry")

-- Forward declarations
function M.format(content)
    return registry.process(content, M.context)
end

-- ... other public API methods ...

-- Hook system forwarders
M.registerHook = hooks.register
M.executeHooks = hooks.execute

-- Hotkey helpers
M.bindFormatClip = hotkeys.bindFormatClip
M.bindFormatSeed = hotkeys.bindFormatSeed

-- Spoon initialization
function M:init()
    runtime.init(self)
    return self
end

return M
```

**Step 5: Write tests for new modules**

Create: `test/spoon/runtime_spec.lua`
Create: `test/spoon/hotkeys_spec.lua`
Create: `test/spoon/hooks_spec.lua`

**Step 6: Run all tests**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 7: Commit**

```bash
git add src/spoon/ src/init.lua test/spoon/
git commit -m "refactor(org): split monolithic init.lua into focused modules"
```

---

### Task 6.2: Add Metrics Collection Enhancement

**Files:**

- Modify: `src/utils/metrics.lua`
- Test: `test/utils/metrics_spec.lua`

**Step 1: Enhance metrics module**

Read: `src/utils/metrics.lua`

Add comprehensive metrics:

```lua
-- Add to metrics module

local M = {
    -- Existing metrics
    counters = {},
    timers = {},

    -- New: gauges for current values
    gauges = {},

    -- New: histograms for value distributions
    histograms = {}
}

function M.gauge(name, value)
    M.gauges[name] = value
end

function M.histogram(name, value, buckets)
    M.histograms[name] = M.histograms[name] or {values = {}, buckets = buckets}
    table.insert(M.histograms[name].values, value)
end

function M.getPercentile(name, percentile)
    local hist = M.histograms[name]
    if not hist or #hist.values == 0 then return 0 end

    table.sort(hist.values)
    local index = math.ceil(percentile * #hist.values)
    return hist.values[index]
end

return M
```

**Step 2: Write tests**

Add to: `test/utils/metrics_spec.lua`

```lua
it("should track gauge values", function()
    metrics.gauge("memory_mb", 100)
    assert.equals(100, metrics.gauges.memory_mb)

    metrics.gauge("memory_mb", 150)
    assert.equals(150, metrics.gauges.memory_mb)
end)

it("should track histograms and calculate percentiles", function()
    for i = 1, 100 do
        metrics.histogram("response_time", i, {10, 50, 90})
    end

    assert.equals(50, metrics.getPercentile("response_time", 0.5))
    assert.equals(90, metrics.getPercentile("response_time", 0.9))
end)
```

**Step 3: Run tests**

Run: `./scripts/test.sh test/utils/metrics_spec.lua`

Expected: All tests pass

**Step 4: Commit**

```bash
git add src/utils/metrics.lua test/utils/metrics_spec.lua
git commit -m "feat(metrics): add gauges and histograms for comprehensive metrics"
```

---

### Task 6.3: Create API Documentation

**Files:**

- Create: `docs/api.md`
- Create: `scripts/generate_docs.lua`

**Step 1: Create documentation structure**

Create: `docs/api.md`

````markdown
# ClipboardFormatter API Documentation

## Spoon API

### `ClipboardFormatter:format(content)`

Formats clipboard content using registered detectors.

**Parameters:**

- `content` (string): The clipboard content to format

**Returns:**

- (string|nil): Formatted content, or nil if no patterns matched

**Example:**

```lua
local result = ClipboardFormatter:format("15 + 27 = ")
-- Returns: "42"
```
````

### `ClipboardFormatter:formatSeed(content)`

Formats the last expression (seed) from content.

**Parameters:**

- `content` (string): Content with seed expression

**Returns:**

- (string|nil): Formatted result

### `ClipboardFormatter:formatSelection(content)`

Formats selected text directly.

## Detector API

### Creating a Detector

```lua
local detector_factory = require("ClipboardFormatter.src.utils.detector_factory")

return detector_factory.create({
    name = "my_detector",
    dependencies = {"patterns", "logger"},
    priority = 50,
    pattern = function(input, patterns)
        return patterns.get("my_pattern"):match(input)
    end,
    formatter = function(match, context)
        return formatResult(match)
    end
})
```

### Detector Specification

| Field          | Type     | Required | Description                     |
| -------------- | -------- | -------- | ------------------------------- |
| `name`         | string   | Yes      | Unique detector name            |
| `dependencies` | table    | No       | Array of dependency names       |
| `priority`     | number   | Yes      | Evaluation order (higher first) |
| `pattern`      | function | Yes      | Pattern matching function       |
| `formatter`    | function | Yes      | Result formatting function      |

## Utility Modules

### `src/utils/string_processing`

String manipulation utilities.

#### `normalizeLocalizedNumber(input)`

Normalizes numbers with locale-specific formatting.

### `src/utils/error_handler`

Consistent error handling patterns.

#### `safeCall(fn, context, errorHandler)`

Wraps function execution with error handling.

### `src/utils/logging_wrapper`

Null-safe logging utilities.

#### `wrap(logger)`

Creates a safe logger wrapper.

## Configuration

### Default Configuration

See `src/config/defaults.lua` for all configuration options.

### Priority Constants

```lua
local constants = require("ClipboardFormatter.src.config.constants")
constants.PRIORITY.ARITHMETIC  -- 80
constants.PRIORITY.PD_CONVERSION  -- 100
```

## Extending

### Registering Custom Detectors

```lua
local registry = require("ClipboardFormatter.src.detectors.registry")

registry.register("my_detector", detectFn, 75)
```

### Using Hooks

```lua
ClipboardFormatter:registerHook("beforeFormat", function(content)
    -- Pre-process content
end)
```

````

**Step 2: Create doc generation script**

Create: `scripts/generate_docs.lua`

```lua
#!/usr/bin/env lua5.4
-- Generate API documentation from source code comments

local lfs = require("lfs")

local function scanFile(filePath)
    local file = io.open(filePath, "r")
    if not file then return nil end

    local inBlockComment = false
    local docs = {}

    for line in file:lines() do
        -- Detect block comments
        local startComment, endComment = line:match("^%-%-%[%["), line:match("%]%]")

        if startComment then
            inBlockComment = true
        end

        if inBlockComment then
            table.insert(docs, line:gsub("^%-%-%[?", ""):gsub("%]?$", ""))
        end

        if endComment then
            inBlockComment = false
        end
    end

    file:close()
    return table.concat(docs, "\n")
end

local function generateModuleDocs(modulePath)
    local sourcePath = "src/" .. modulePath:gsub("%.", "/") .. ".lua"
    return scanFile(sourcePath)
end

-- Main
print("--[[")
print("Auto-generated API documentation")
print("Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
print("]]--")
print()

local modules = {
    "ClipboardFormatter.src.utils.string_processing",
    "ClipboardFormatter.src.utils.error_handler",
    "ClipboardFormatter.src.utils.logging_wrapper",
    "ClipboardFormatter.src.detectors.registry",
}

for _, module in ipairs(modules) do
    print("## " .. module)
    print()
    local docs = generateModuleDocs(module)
    if docs then
        print(docs)
    else
        print("No documentation available")
    end
    print()
end
````

**Step 3: Make script executable**

Run: `chmod +x scripts/generate_docs.lua`

**Step 4: Commit**

```bash
git add docs/api.md scripts/generate_docs.lua
git commit -m "docs(api): add comprehensive API documentation"
```

---

## Summary

This refactoring plan addresses all major areas identified in the codebase review:

1. **Dependency Injection Consistency** - Standardized declarations, added validation, unified access patterns
2. **Code Deduplication** - Extracted error handling, logging, string processing, config access, and validation into shared utilities
3. **Configuration** - Centralized constants, added schema validation, made paths configurable
4. **Performance** - Added pattern precompilation, early exit optimization, smart evaluation paths
5. **Testing** - Added integration tests, standardized mocks, property-based tests
6. **Organization** - Split monolithic files, enhanced metrics, added API documentation

Each task follows TDD principles with:

- Write failing test first
- Run to verify failure
- Implement minimal code
- Run to verify passing
- Commit

The plan is comprehensive but modular - each area can be implemented independently, allowing for incremental refactoring without disrupting functionality.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2025-12-24-comprehensive-refactoring.md`.
