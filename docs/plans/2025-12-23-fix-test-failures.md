# Fix Test Failures Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 14 failing tests in the test suite by addressing bugs in logger stringification, extractSeed pattern matching, seed formatting logic, and metrics implementation.

**Architecture:**
- Fix logger's structured logging to properly stringify message arguments
- Update extractSeed to handle arithmetic expressions with internal whitespace
- Fix formatSeed to preserve leading whitespace correctly
- Fix metrics module timing and configuration issues
- Mock Hammerspoon dependencies for clipboard/selection tests

**Tech Stack:** Lua 5.4, busted test framework, Hammerspoon spoon architecture

---

## Task 1: Fix Logger Structured Logging Stringification

**Issue:** Logger is converting arguments to string representation (e.g., "table: 0x...") instead of properly stringifying multiple arguments.

**Files:**
- Modify: `src/utils/logger.lua`
- Test: `test/utils_spec.lua:20-32`, `test/init_spec.lua:103-123`

**Step 1: Read the logger implementation to understand current behavior**

Read: `src/utils/logger.lua` lines 1-100

**Step 2: Write failing test that demonstrates the issue**

Add to `test/utils_spec.lua` after line 28:
```lua
it("properly stringifies multiple args in structured mode", function()
    local loggerModule = helper.requireFresh("utils.logger")
    local logger = loggerModule.new("test", "info", {
        structured = true,
        includeTimestamp = false,
    })
    logger:w("hello", "world")
    local entry = logger.messages[#logger.messages]
    assert.equal('{"level":"warning","message":"hello world"}', entry.args[1])
end)
```

**Step 3: Run test to verify it fails**

Run: `./scripts/test.sh test/utils_spec.lua`
Expected: FAIL with message containing "table: 0x..."

**Step 4: Fix the logger to concatenate multiple arguments**

In `src/utils/logger.lua`, locate the structured logging code (around line 80-100).
Find where `args[1]` is set for structured logging.

Change from:
```lua
args[1] = cjson.encode({level = level, message = tostring(message)})
```

To:
```lua
-- Concatenate multiple arguments into a single message
local messageStr
if type(message) == "table" then
    local parts = {}
    for i, v in ipairs(message) do
        parts[i] = tostring(v)
    end
    messageStr = table.concat(parts, " ")
else
    messageStr = tostring(message)
end
args[1] = cjson.encode({level = level, message = messageStr})
```

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils_spec.lua test/init_spec.lua`
Expected: PASS for logger tests

**Step 6: Commit**

```bash
git add src/utils/logger.lua test/utils_spec.lua test/init_spec.lua
git commit -m "fix(logger): properly stringify multiple args in structured logging"
```

---

## Task 2: Fix extractSeed Pattern Matching for Arithmetic with Whitespace

**Issue:** The arithmetic pattern `[%d%.%(%)%+%-%*/%%^cC]+` doesn't include `\s`, so expressions like "5 + 3" only match "3" instead of the full expression.

**Files:**
- Modify: `src/utils/strings.lua`
- Test: `test/utils_spec.lua:34-66`

**Step 1: Examine the current extractSeed patterns**

Read: `src/utils/strings.lua` lines 127-137 (the two arithmetic pattern matching attempts)

**Step 2: Write failing test for arithmetic with internal whitespace**

Add to `test/utils_spec.lua`:
```lua
it("extracts arithmetic expressions with internal whitespace", function()
    local strings = helper.requireFresh("utils.strings")
    local prefix, seed = strings.extractSeed("let x = 5 + 3")
    assert.equal("let x = ", prefix)
    assert.equal("5 + 3", seed)
end)
```

**Step 3: Run test to verify it fails**

Run: `./scripts/test.sh test/utils_spec.lua`
Expected: FAIL with seed="3" instead of "5 + 3"

**Step 4: Update arithmetic patterns to include internal whitespace**

In `src/utils/strings.lua`, line 127, change the pattern from:
```lua
local beforeWs, ws, arith = str:match("^(.-)(%s+)([%d%.%(%)%+%-%*/%%^cC]+)$")
```

To:
```lua
local beforeWs, ws, arith = str:match("^(.-)(%s+)([%d%.%s%(%)%+%-%*/%%^cC]+)$")
```

Line 134, change from:
```lua
local arithmeticOnly = str:match("^([%d%.%(%)%+%-%*/%%^cC]+)$")
```

To:
```lua
local arithmeticOnly = str:match("^([%d%.%s%(%)%+%-%*/%%^cC]+)$")
```

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils_spec.lua`
Expected: PASS for extractSeed tests

**Step 6: Commit**

```bash
git add src/utils/strings.lua test/utils_spec.lua
git commit -m "fix(strings): include whitespace in extractSeed arithmetic patterns"
```

---

## Task 3: Fix formatSeed Leading Whitespace Preservation

**Issue:** When `formatSelectionSeed` extracts a seed with only whitespace prefix, it preserves the leading whitespace. But when seed extraction returns the entire body (no prefix), the leading whitespace is lost.

**Files:**
- Modify: `src/init.lua`
- Test: `test/init_spec.lua:244-261`

**Step 1: Examine the formatSelectionSeed logic**

Read: `src/init.lua` lines 651-690

**Step 2: Read the failing test**

Read: `test/init_spec.lua` lines 244-261

**Step 3: Add debug logging to understand the failure**

Add to `test/init_spec.lua` before line 248:
```lua
print("DEBUG: formatted:", formatted)
print("DEBUG: seed:", seed)
print("DEBUG: prefix:", prefix)
print("DEBUG: prefix match:", prefix:match("^%s*$"))
```

**Step 4: Run test with debug output**

Run: `./scripts/test.sh test/init_spec.lua`
Expected: See what values are being compared

**Step 5: Fix the leading whitespace preservation logic**

In `src/init.lua` around line 670, the condition `if prefix:match("^%s*$")` checks if prefix is only whitespace.

The issue is that when `extractSeed` returns `prefix=""` and `seed=body` (no separators found), we're losing the leading whitespace that was trimmed.

Change line 670 from:
```lua
if prefix:match("^%s*$") then
    return leading_ws .. formatted .. trailing_ws
```

To:
```lua
if prefix:match("^%s*$") or prefix == "" then
    return leading_ws .. formatted .. trailing_ws
```

**Step 6: Run tests to verify they pass**

Run: `./scripts/test.sh test/init_spec.lua`
Expected: PASS for formatSeed test

**Step 7: Commit**

```bash
git add src/init.lua test/init_spec.lua
git commit -m "fix(formatSeed): preserve leading whitespace when prefix is empty"
```

---

## Task 4: Mock Hammerspoon Dependencies for Clipboard Tests

**Issue:** Clipboard and selection tests fail because they require Hammerspoon's `hs.uielement`, `hs.eventtap`, `hs.application` modules which don't exist in test environment.

**Files:**
- Modify: `test/clipboard_spec.lua`, `test/selection_modular_spec.lua`
- Create: `test/mocks/hs.lua`

**Step 1: Check existing Hammerspoon mocks**

Read: `test/spec_helper.lua` lines 71-80

**Step 2: Create comprehensive Hammerspoon mock module**

Create: `test/mocks/hs.lua`
```lua
return {
    uielement = {
        focusedElement = function()
            return nil
        end
    },
    eventtap = {
        keyStroke = function(modifiers, key, delay)
            return true
        end
    },
    application = {
        frontmostApplication = function()
            return nil
        end,
        menuBar = function()
            return nil
        end
    },
    timer = {
        usleep = function microseconds
            -- Mock: just return immediately
        end,
        doAfter = function(seconds, callback)
            callback()
        end
    },
    alert = function(message)
        print("[ALERT] " .. tostring(message))
    end
}
```

**Step 3: Update spec_helper to load Hammerspoon mocks**

In `test/spec_helper.lua` after line 73, add:
```lua
package.preload["hs.uielement"] = function()
    return require("mocks.hs").uielement
end
package.preload["hs.eventtap"] = function()
    return require("mocks.hs").eventtap
end
package.preload["hs.application"] = function()
    return require("mocks.hs").application
end
package.preload["hs.timer"] = function()
    return require("mocks.hs").timer
end
package.preload["hs.alert"] = function()
    return require("mocks.hs").alert
end
```

**Step 4: Run clipboard tests to verify they pass**

Run: `./scripts/test.sh test/clipboard_spec.lua`
Expected: Tests should no longer error on missing modules

**Step 5: Commit**

```bash
git add test/spec_helper.lua test/mocks/hs.lua
git commit -m "test: add Hammerspoon module mocks for clipboard/selection tests"
```

---

## Task 5: Fix Selection Empty Text Handling

**Issue:** Selection test expects empty text to not be equal to nil, but current implementation returns nil for both.

**Files:**
- Modify: `src/clipboard/selection_modular.lua` or `src/clipboard/selection.lua`
- Test: `test/selection_modular_spec.lua:142-156`

**Step 1: Examine the failing test**

Read: `test/selection_modular_spec.lua` lines 142-156

**Step 2: Understand what the test expects**

The test uses `assert.is_not_nil(result)` and `assert.is_not.same(false, result)`.

**Step 3: Find the paste function in selection module**

Grep for "function.*paste" in `src/clipboard/selection_modular.lua`

**Step 4: Fix the paste function to handle empty text**

Ensure paste returns `{success = false, reason = "empty_text"}` instead of `nil`.

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/selection_modular_spec.lua`
Expected: PASS for empty text test

**Step 6: Commit**

```bash
git add src/clipboard/selection_modular.lua
git commit -m "fix(selection): return structured result for empty text paste"
```

---

## Task 6: Fix Metrics Timer Operations

**Issue:** Multiple metrics tests fail because timers aren't recording elapsed time correctly.

**Files:**
- Modify: `src/utils/metrics.lua` (if it exists)
- Test: `test/metrics_spec.lua`

**Step 1: Check if metrics module exists**

Run: `ls -la src/utils/metrics.lua`

**Step 2: If module doesn't exist, create a basic implementation**

Create: `src/utils/metrics.lua` with basic timer tracking:
```lua
local M = {}

function M.new()
    return {
        timers = {},
        errors = {},
        config = {
            samplingRate = 1.0,
        }
    }
end

function M.startTimer(self, name)
    self.timers[name] = {start = os.time(), end = nil}
end

function M.recordTimer(self, name)
    if self.timers[name] then
        self.timers[name].ended = os.time()
    end
end

function M.getTimer(self, name)
    return self.timers[name]
end

-- Add other methods as needed by tests

return M
```

**Step 3: If module exists, fix the timing issues**

Look for timer start/end logic and ensure `os.time()` or similar is being used correctly.

**Step 4: Run tests to verify they pass**

Run: `./scripts/test.sh test/metrics_spec.lua`
Expected: PASS for timer tests

**Step 5: Commit**

```bash
git add src/utils/metrics.lua
git commit -m "fix(metrics): implement proper timer tracking"
```

---

## Task 7: Fix Adaptive Clipboard Waits

**Issue:** Test for adaptive clipboard waits expects `true` but gets `false`.

**Files:**
- Modify: `src/utils/hammerspoon.lua` or relevant clipboard utility
- Test: `test/utils_spec.lua:75-88`

**Step 1: Examine the test**

Read: `test/utils_spec.lua` lines 75-88

**Step 2: Find the adaptive clipboard wait implementation**

Grep for "adaptive" or "clipboard.*wait" in `src/utils/`

**Step 3: Understand what the test is checking**

The test likely checks if adaptive waiting is enabled/configured correctly.

**Step 4: Fix the implementation**

Ensure the adaptive wait function returns `true` when enabled or properly implements the logic.

**Step 5: Run tests to verify they pass**

Run: `./scripts/test.sh test/utils_spec.lua`
Expected: PASS for adaptive wait test

**Step 6: Commit**

```bash
git add src/utils/hammerspoon.lua test/utils_spec.lua
git commit -m "fix(hammerspoon): implement adaptive clipboard wait logic"
```

---

## Task 8: Verify All Tests Pass

**Step 1: Run full test suite**

Run: `./scripts/test.sh`

**Step 2: Review any remaining failures**

If tests still fail, analyze each failure and create follow-up tasks.

**Step 3: Create summary of fixes**

Document what was fixed in `docs/test-fixes-summary.md`.

**Step 4: Final commit**

```bash
git add docs/test-fixes-summary.md
git commit -m "docs: summarize test failure fixes"
```

---

## Notes

- **TDD Approach:** Each task follows red-green-refactor: write failing test, fix it, verify
- **Frequent Commits:** Commit after each independent fix to enable easy rollback
- **DRY Principle:** Reuse existing mocks and helper functions
- **YAGNI Principle:** Only fix what's needed to make tests pass, don't add features
- **Test Isolation:** Each test should run independently; use `helper.reset()` and `helper.requireFresh()`

## Dependencies

- Lua 5.4
- busted test framework
- cjson library (for structured logging)
- Existing test helpers in `test/spec_helper.lua`
