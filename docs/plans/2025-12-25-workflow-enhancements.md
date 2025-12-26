# Workflow Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance ClipboardFormatter with time calculations, unit conversions, percentage arithmetic, and foundation refactoring to support inline text transformations without breaking user workflow.

**Architecture:** Modular detector system with strategy pattern for seed extraction, unified arithmetic evaluation, and new detectors for time math and unit conversions. All changes follow existing factory/registry patterns with dependency injection.

**Tech Stack:** Lua 5.4, Hammerspoon, busted testing framework, existing detector_factory and registry patterns.

---

## Overview

This plan implements the workflow enhancements in phases:
1. **Phase 1:** Foundation Refactoring - extractSeed strategy pattern, unified arithmetic
2. **Phase 2:** Percentage Arithmetic - extend arithmetic detector
3. **Phase 3:** Unit Conversions - new detector
4. **Phase 4:** Time Calculations - new detector with utility module

---

## Phase 1: Foundation Refactoring

### Task 1: Create Seed Strategies Module

**Files:**
- Create: `src/utils/seed_strategies.lua`
- Test: `test/utils/seed_strategies_spec.lua`

**Context:** The `extractSeed()` function in `src/utils/strings.lua` is ~130 lines with deeply nested logic. We'll extract each extraction path into a focused strategy function.

**Step 1: Write the failing test**

Create `test/utils/seed_strategies_spec.lua`:

```lua
describe("seed_strategies", function()
    local SeedStrategies

    setup(function()
        require("src.utils.seed_strategies")
        SeedStrategies = require("src.utils.seed_strategies")
    end)

    describe("date_range_strategy", function()
        local Date = require("src.formatters.date")
        local patterns = require("src.utils.patterns").all()

        it("extracts date range from string with prefix", function()
            local context = { patterns = patterns }
            local input = "Meeting: 01/15/2025 - 01/20/2025"
            local prefix, seed = SeedStrategies.date_range_strategy(input, context)
            assert.are_equal("Meeting: ", prefix)
            assert.are_equal("01/15/2025 - 01/20/2025", seed)
        end)

        it("returns nil for non-date strings", function()
            local context = { patterns = patterns }
            local input = "hello world"
            local result = SeedStrategies.date_range_strategy(input, context)
            assert.is_nil(result)
        end)
    end)

    describe("arithmetic_strategy", function()
        it("extracts pure arithmetic", function()
            local input = "10 + 5"
            local prefix, seed = SeedStrategies.arithmetic_strategy(input)
            assert.are_equal("", prefix)
            assert.are_equal("10 + 5", seed)
        end)

        it("extracts arithmetic after prefix", function()
            local input = "Total: 100 * 2"
            local prefix, seed = SeedStrategies.arithmetic_strategy(input)
            assert.are_equal("Total: ", prefix)
            assert.are_equal("100 * 2", seed)
        end)

        it("returns nil for non-arithmetic", function()
            local input = "hello world"
            local result = SeedStrategies.arithmetic_strategy(input)
            assert.is_nil(result)
        end)
    end)

    describe("separator_strategy", function()
        it("extracts after equals sign", function()
            local input = "result = 42"
            local prefix, seed = SeedStrategies.separator_strategy(input)
            assert.are_equal("result = ", prefix)
            assert.are_equal("42", seed)
        end)

        it("extracts after colon", function()
            local input = "Answer: 42"
            local prefix, seed = SeedStrategies.separator_strategy(input)
            assert.are_equal("Answer: ", prefix)
            assert.are_equal("42", seed)
        end)

        it("returns nil when no separator", function()
            local input = "hello world"
            local result = SeedStrategies.separator_strategy(input)
            assert.is_nil(result)
        end)
    end)

    describe("whitespace_strategy", function()
        it("splits at last whitespace", function()
            local input = "hello world"
            local prefix, seed = SeedStrategies.whitespace_strategy(input)
            assert.are_equal("hello ", prefix)
            assert.are_equal("world", seed)
        end)

        it("returns nil for single word", function()
            local input = "hello"
            local result = SeedStrategies.whitespace_strategy(input)
            assert.is_nil(result)
        end)
    end)

    describe("fallback_strategy", function()
        it("returns entire string as seed", function()
            local input = "hello"
            local prefix, seed = SeedStrategies.fallback_strategy(input)
            assert.are_equal("", prefix)
            assert.are_equal("hello", seed)
        end)
    end)

    describe("extractSeed", function()
        it("tries strategies in order and returns first match", function()
            local input = "Total: 10+5"
            local prefix, seed = SeedStrategies.extractSeed(input, {})
            assert.are_equal("Total: ", prefix)
            assert.are_equal("10+5", seed)
        end)

        it("falls back to whitespace strategy when others fail", function()
            local input = "hello world"
            local prefix, seed = SeedStrategies.extractSeed(input, {})
            assert.are_equal("hello ", prefix)
            assert.are_equal("world", seed)
        end)

        it("falls back to entire string for single word", function()
            local input = "hello"
            local prefix, seed = SeedStrategies.extractSeed(input, {})
            assert.are_equal("", prefix)
            assert.are_equal("hello", seed)
        end)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `LUA_PATH="src/?.lua;src/?/init.lua;test/?.lua;;" busted test/utils/seed_strategies_spec.lua`

Expected: FAIL with "module 'src.utils.seed_strategies' not found"

**Step 3: Write minimal implementation**

Create `src/utils/seed_strategies.lua`:

```lua
--[[
WHAT THIS FILE DOES:
Provides strategy pattern implementations for extracting "seeds" from text.
A seed is the portion of text most likely to be an evaluatable expression.

KEY CONCEPTS:
- Strategy Pattern: Each strategy attempts extraction, returns nil if not applicable
- Priority Order: Strategies are tried in sequence; first non-nil result wins
- Context Passing: Strategies receive context with dependencies (patterns, etc.)
]]

local pkgRoot = (...):match("^(.*)%.utils%.seed_strategies$")

-- Lazy-load date formatter for date range detection
local dateFormatter = nil
local function getDateFormatter()
    if not dateFormatter then
        local ok, result = pcall(function()
            return require(pkgRoot .. ".formatters.date")
        end)
        if ok then
            dateFormatter = result
        end
    end
    return dateFormatter
end

local M = {}

-- STRATEGY: Extract date ranges, preserving prefix text
function M.date_range_strategy(str, context)
    if not str or str == "" then
        return nil
    end

    -- Strip trailing whitespace before pattern matching
    str = str:match("^(.-)%s*$") or str

    local Date = getDateFormatter()
    if not Date or not Date.isRangeCandidate then
        return nil
    end

    -- Get patterns from context or load directly
    local patternsModule = context and context.patterns
    if not patternsModule then
        local ok2, pm = pcall(require, pkgRoot .. ".utils.patterns")
        if ok2 then
            patternsModule = pm
        end
    end

    if not Date.isRangeCandidate(str, { patterns = patternsModule }) then
        return nil
    end

    local allPatterns = patternsModule.all()
    local dateEntries = {
        allPatterns.date_token and allPatterns.date_token.raw,
        allPatterns.date_token_iso and allPatterns.date_token_iso.raw,
    }

    local firstDatePos = nil
    local lastDateEnd = 0

    for _, pattern in ipairs(dateEntries) do
        if pattern and pattern ~= "" then
            for pos, match in str:gmatch("()(" .. pattern .. ")") do
                if not firstDatePos or pos < firstDatePos then
                    firstDatePos = pos
                end
                local matchEnd = pos + #match - 1
                if matchEnd > lastDateEnd then
                    lastDateEnd = matchEnd
                end
            end
        end
    end

    if firstDatePos and firstDatePos > 1 then
        local prefix = str:sub(1, firstDatePos - 1)
        local seed = str:sub(firstDatePos)
        return prefix, seed
    elseif firstDatePos then
        return "", str
    end

    return nil
end

-- STRATEGY: Extract arithmetic expressions (pure or after prefix)
function M.arithmetic_strategy(str)
    if not str or str == "" then
        return nil
    end

    -- Try pure arithmetic first
    local arithmeticOnly = str:match("^([%d%.%s%(%)%+%-%*/%%^cC]+)$")
    if arithmeticOnly and arithmeticOnly:match("[%d%(]") then
        return "", arithmeticOnly
    end

    -- Try arithmetic after whitespace
    local beforeWs, ws, arith = str:match("^(.-)(%s+)([%d%.%s%(%)%+%-%*/%%^cC]+)$")
    if arith and arith:match("[%d%(]") then
        return beforeWs .. ws, arith
    end

    return nil
end

-- STRATEGY: Extract after common separators (=, :, (, [, {)
function M.separator_strategy(str)
    if not str or str == "" then
        return nil
    end

    local separators = { "=%s", ":%s", "%(", "%[", "{" }
    local lastSepPos = 0

    for _, sep in ipairs(separators) do
        local searchPos = 1
        while true do
            local pos = str:find(sep, searchPos)
            if not pos then
                break
            end
            local afterSep = str:find("[^%s]", pos + 1)
            if afterSep and afterSep - 1 > lastSepPos then
                lastSepPos = afterSep - 1
            end
            searchPos = pos + 1
        end
    end

    if lastSepPos > 0 then
        local prefix = str:sub(1, lastSepPos)
        local seed = str:sub(lastSepPos + 1)
        return prefix, seed
    end

    return nil
end

-- STRATEGY: Split at last whitespace
function M.whitespace_strategy(str)
    if not str or str == "" then
        return nil
    end

    local lastWhitespace = 0
    for i = 1, #str do
        if str:sub(i, i):match("%s") then
            lastWhitespace = i
        end
    end

    if lastWhitespace > 0 then
        local prefix = str:sub(1, lastWhitespace)
        local seed = str:sub(lastWhitespace + 1)
        return prefix, seed
    end

    return nil
end

-- STRATEGY: Fallback - entire string is seed
function M.fallback_strategy(str)
    if not str or str == "" then
        return nil
    end
    return "", str
end

-- PUBLIC: Try each strategy in order, return first non-nil result
function M.extractSeed(str, context)
    local strategies = {
        M.date_range_strategy,
        M.arithmetic_strategy,
        M.separator_strategy,
        M.whitespace_strategy,
        M.fallback_strategy,
    }

    for _, strategy in ipairs(strategies) do
        local prefix, seed = strategy(str, context)
        if prefix ~= nil then
            return prefix, seed
        end
    end

    return "", str
end

return M
```

**Step 4: Run test to verify it passes**

Run: `LUA_PATH="src/?.lua;src/?/init.lua;test/?.lua;;" busted test/utils/seed_strategies_spec.lua`

Expected: PASS

**Step 5: Commit**

```bash
git add src/utils/seed_strategies.lua test/utils/seed_strategies_spec.lua
git commit -m "feat: extract seed strategies from extractSeed()

Create modular strategy pattern for seed extraction:
- date_range_strategy: date range position finding
- arithmetic_strategy: pure and prefix arithmetic
- separator_strategy: =, :, (, [, { separators
- whitespace_strategy: last whitespace split
- fallback_strategy: entire string as seed

This reduces complexity and makes testing easier.
"
```

---

### Task 2: Refactor strings.lua to Use Seed Strategies

**Files:**
- Modify: `src/utils/strings.lua:126-262`

**Context:** Replace the ~130 line `extractSeed()` function with a call to the new strategies module.

**Step 1: Update strings.lua to use seed_strategies**

Replace the `extractSeed()` function (lines 134-262) with:

```lua
-- PUBLIC METHOD: Extract a potential "seed" for an expression from a string.
-- Delegates to seed_strategies module for modular extraction logic.
-- @param str string The input string.
-- @return string The prefix before the seed.
-- @return string The extracted seed.
-- Example: M.extractSeed("Total: 10+5") → "Total: ", "10+5"
function M.extractSeed(str, context)
    local seedStrategies
    local ok, result = pcall(function()
        return require(pkgRoot .. ".utils.seed_strategies")
    end)

    if not ok then
        -- Fallback to simple logic if module unavailable
        if not str or str == "" then
            return "", ""
        end
        return "", str
    end

    return seedStrategies.extractSeed(str, context)
end
```

Also remove the now-unnecessary `getDateFormatter()` function (lines 28-40).

**Step 2: Run existing tests to verify behavior unchanged**

Run: `./scripts/test.sh`

Expected: All tests pass (behavior is preserved)

**Step 3: Commit**

```bash
git add src/utils/strings.lua
git commit -m "refactor: use seed_strategies module in strings.extractSeed

Simplify extractSeed() by delegating to seed_strategies module.
Removes ~130 lines of nested logic, preserving all behavior.
"
```

---

### Task 3: Extend Arithmetic Tokenizer for Parentheses

**Files:**
- Modify: `src/formatters/arithmetic.lua:75-112`

**Context:** The tokenizer needs to handle parentheses to enable a single evaluation path.

**Step 1: Write failing test for parentheses**

Add to `test/formatters_spec.lua`:

```lua
describe("arithmetic tokenizer with parentheses", function()
    local Arithmetic = require("src.formatters.arithmetic")

    it("evaluates (2+3)*4 correctly", function()
        local result = Arithmetic.process("(2+3)*4", {})
        assert.are_equal(20, tonumber(result))
    end)

    it("evaluates 2*(3+4) correctly", function()
        local result = Arithmetic.process("2*(3+4)", {})
        assert.are_equal(14, tonumber(result))
    end)

    it("evaluates (2+3)*(4+5) correctly", function()
        local result = Arithmetic.process("(2+3)*(4+5)", {})
        assert.are_equal(45, tonumber(result))
    end)

    it("evaluates nested parentheses (2*(3+4))", function()
        local result = Arithmetic.process("(2*(3+4))", {})
        assert.are_equal(14, tonumber(result))
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/formatters_spec.lua`

Expected: FAIL - parentheses cause tokenization to fail

**Step 3: Update tokenizer to handle parentheses**

In `src/formatters/arithmetic.lua`, update `tokenizeExpression()` function:

```lua
local function tokenizeExpression(equation)
    local tokens = {}
    local currentNum = ""
    local isNegative = false
    local lastWasOperator = true

    for i = 1, #equation do
        local char = equation:sub(i, i)
        if char:match("[%d%.]") then
            currentNum = currentNum .. char
            lastWasOperator = false
        elseif char == "(" then
            -- Flush pending number before opening paren
            if currentNum ~= "" then
                local numeric = tonumber(currentNum)
                if numeric then
                    table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
                end
                currentNum = ""
                isNegative = false
            end
            table.insert(tokens, "*")  -- Implicit multiplication
            table.insert(tokens, char)
            lastWasOperator = true
        elseif char == ")" then
            -- Flush pending number before closing paren
            if currentNum ~= "" then
                local numeric = tonumber(currentNum)
                if numeric then
                    table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
                end
                currentNum = ""
                isNegative = false
            end
            table.insert(tokens, char)
            lastWasOperator = false
        elseif char == "+" or char == "-" or char == "*" or char == "/" or char == "%" or char == "^" then
            if char == "-" and lastWasOperator then
                isNegative = not isNegative
            else
                if currentNum ~= "" then
                    local numeric = tonumber(currentNum)
                    if numeric then
                        table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
                    end
                    currentNum = ""
                    isNegative = false
                end
                table.insert(tokens, char)
                lastWasOperator = true
            end
        end
    end

    if currentNum ~= "" then
        local numeric = tonumber(currentNum)
        if numeric then
            table.insert(tokens, tostring(numeric * (isNegative and -1 or 1)))
        end
    end

    return tokens
end
```

Also update `evaluateTokens()` to handle parentheses:

```lua
local function evaluateTokens(tokens)
    local cleanTokens = {}
    for _, token in ipairs(tokens) do
        if token ~= " " then
            table.insert(cleanTokens, token)
        end
    end

    local function isOperator(token)
        return token == "+" or token == "-" or token == "*" or token == "/" or token == "%" or token == "^"
    end

    local precedence = {
        ["^"] = 4,
        ["*"] = 3,
        ["/"] = 3,
        ["%"] = 3,
        ["+"] = 2,
        ["-"] = 2,
    }

    local rightAssociative = {
        ["^"] = true,
    }

    local output = {}
    local stack = {}

    for _, token in ipairs(cleanTokens) do
        local number = tonumber(token)
        if number ~= nil then
            table.insert(output, number)
        elseif token == "(" then
            table.insert(stack, token)
        elseif token == ")" then
            while #stack > 0 and stack[#stack] ~= "(" do
                table.insert(output, table.remove(stack))
            end
            if #stack > 0 and stack[#stack] == "(" then
                table.remove(stack)
            end
        elseif isOperator(token) then
            while true do
                local top = stack[#stack]
                if not top or not isOperator(top) then
                    break
                end
                local currentPrecedence = precedence[token] or 0
                local topPrecedence = precedence[top] or 0
                local isRightAssociative = rightAssociative[token] == true
                local shouldPop = currentPrecedence < topPrecedence
                    or (not isRightAssociative and currentPrecedence == topPrecedence)
                if shouldPop then
                    table.insert(output, table.remove(stack))
                else
                    break
                end
            end
            table.insert(stack, token)
        end
    end

    while #stack > 0 do
        table.insert(output, table.remove(stack))
    end

    local eval = {}
    for _, token in ipairs(output) do
        if type(token) == "number" then
            table.insert(eval, token)
        elseif isOperator(token) then
            local b = table.remove(eval)
            local a = table.remove(eval)
            if a == nil or b == nil then
                return nil
            end
            local result
            if token == "+" then
                result = a + b
            elseif token == "-" then
                result = a - b
            elseif token == "*" then
                result = a * b
            elseif token == "/" then
                if b == 0 then return nil end
                result = a / b
            elseif token == "%" then
                if b == 0 then return nil end
                result = a % b
            elseif token == "^" then
                result = a ^ b
            end
            table.insert(eval, result)
        else
            return nil
        end
    end

    if #eval ~= 1 then
        return nil
    end

    return eval[1]
end
```

**Step 4: Run test to verify it passes**

Run: `./scripts/test.sh test/formatters_spec.lua`

Expected: PASS

**Step 5: Commit**

```bash
git add src/formatters/arithmetic.lua test/formatters_spec.lua
git commit -m "feat(arithmetic): add parentheses support to tokenizer

Extend tokenizer to handle ( and ) tokens.
Update shunting-yard algorithm to manage parentheses correctly.
Enables single-path evaluation for all arithmetic operations.
"
```

---

### Task 4: Unify Arithmetic Evaluation Path

**Files:**
- Modify: `src/formatters/arithmetic.lua:254-285`

**Context:** Now that tokenizer supports parentheses, remove the `load()` path and use tokenizer as the single evaluation method.

**Step 1: Simplify process() to use only tokenizer**

Update the `process()` function, replacing lines 254-285 with:

```lua
function Arithmetic.process(content, opts)
    if not Arithmetic.isCandidate(content, opts) then
        return nil
    end

    local hasCurrency = content:find("%$") ~= nil
    local normalized = strings.normalizeMinus(content)
    local displayInput = strings.trim(normalized)
    local cleaned = normalizeExpressionNumbers(removeCurrencyAndWhitespace(normalized), opts)

    -- Use tokenizer for all expressions (now supports parentheses)
    local tokens = tokenizeExpression(cleaned)
    local result = evaluateTokens(tokens)

    if not result then
        return nil
    end

    local numericResult = result
    local formattedResult
    if hasCurrency then
        formattedResult = currency.format(numericResult)
        if not formattedResult then
            return nil
        end
    else
        if type(numericResult) == "number" then
            local integral = math.floor(numericResult)
            if math.abs(numericResult - integral) < 1e-9 then
                formattedResult = tostring(integral)
            else
                formattedResult = tostring(numericResult)
            end
        else
            formattedResult = tostring(numericResult)
        end
    end

    local template
    if opts and opts.config and opts.config.templates then
        template = opts.config.templates.arithmetic
    end
    if template and template ~= "" then
        local replacements = {
            input = displayInput,
            result = formattedResult,
            numeric = tostring(numericResult),
        }
        local rendered = template:gsub("%${(.-)}", function(key)
            return replacements[key] or ""
        end)
        return rendered
    end

    return formattedResult
end
```

**Step 2: Remove unused evaluateEquation() function**

Delete the `evaluateEquation()` function (lines 211-224) and `needsTokenization()` function (lines 227-231).

**Step 3: Run tests to verify behavior unchanged**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 4: Commit**

```bash
git add src/formatters/arithmetic.lua
git commit -m "refactor(arithmetic): unify to single tokenizer evaluation

Remove load() evaluation path. Tokenizer now handles all cases
including parentheses, %, and ^ operators. Simpler, more
predictable behavior with no sandbox escape concerns.
"
```

---

### Task 5: Add Pattern Dependency Declarations

**Files:**
- Modify: `src/utils/detector_factory.lua`
- Modify: All detectors in `src/detectors/*.lua`

**Context:** Detectors should explicitly declare which patterns they use for better documentation and validation.

**Step 1: Write test for pattern dependency validation**

Create `test/detectors/pattern_dependencies_spec.lua`:

```lua
describe("detector pattern dependencies", function()
    local DetectorFactory = require("src.utils.detector_factory")
    local patterns = require("src.utils.patterns").all()

    it("validates patterns exist when declared", function()
        local detector = DetectorFactory.create({
            id = "test_detector",
            patternDependencies = { "arithmetic_candidate", "date_full" },
            deps = {},
        })
        -- Should not throw; patterns exist
        assert.is_not_nil(detector)
    end)

    it("throws error for missing pattern", function()
        local ok, err = pcall(function()
            DetectorFactory.create({
                id = "test_detector",
                patternDependencies = { "nonexistent_pattern" },
                deps = {},
            })
        end)
        assert.is_false(ok)
        assert.is_true(tostring(err):find("nonexistent_pattern") ~= nil)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/detectors/pattern_dependencies_spec.lua`

Expected: FAIL - detector_factory doesn't validate patternDependencies yet

**Step 3: Update detector_factory to validate patternDependencies**

In `src/utils/detector_factory.lua`, modify the `create()` function to add pattern validation:

Add after dependency validation (find where dependencies are validated and add pattern validation similarly):

```lua
-- Validate pattern dependencies if declared
if spec.patternDependencies then
    if type(spec.patternDependencies) ~= "table" then
        error("patternDependencies must be a table")
    end

    local patterns = deps.patterns
    if not patterns or type(patterns.all) ~= "function" then
        error("patterns must be provided in deps when patternDependencies are declared")
    end

    local allPatterns = patterns.all()
    for _, patternName in ipairs(spec.patternDependencies) do
        if not allPatterns[patternName] then
            error(string.format("Pattern '%s' not found in patterns registry", patternName))
        end
    end

    -- Store pattern dependencies for later use
    result._patternDependencies = spec.patternDependencies
end
```

**Step 4: Update arithmetic detector to declare pattern dependencies**

In `src/detectors/arithmetic.lua`:

```lua
return function(deps)
    return DetectorFactory.create({
        id = "arithmetic",
        priority = 100,
        dependencies = {"patterns"},
        patternDependencies = { "arithmetic_candidate", "date_full", "localized_number" },
        formatterKey = "arithmetic",
        defaultFormatter = defaultFormatter,
        deps = deps,
    })
end
```

**Step 5: Run test to verify it passes**

Run: `./scripts/test.sh test/detectors/pattern_dependencies_spec.lua`

Expected: PASS

**Step 6: Update remaining detectors to declare pattern dependencies**

Update each detector in `src/detectors/`:

**date.lua:**
```lua
patternDependencies = { "date_full", "date_token", "date_token_iso", "date_range", ... }
```

**phone.lua:**
```lua
patternDependencies = { "phone_us", "phone_intl", ... }
```

**pd.lua, combinations.lua, navigation.lua** - add appropriate pattern declarations

**Step 7: Commit**

```bash
git add src/utils/detector_factory.lua src/detectors/*.lua test/detectors/pattern_dependencies_spec.lua
git commit -m "feat(detectors): add pattern dependency declarations

Detectors now explicitly declare which patterns they use.
Factory validates patterns exist at initialization time.
Improves documentation and catches configuration errors early.
"
```

---

## Phase 2: Percentage Arithmetic

### Task 6: Add Percentage Patterns

**Files:**
- Modify: `src/utils/patterns.lua`

**Context:** Add regex patterns for percentage expressions.

**Step 1: Write failing test for percentage patterns**

Add to `test/utils_spec.lua` or create new pattern test:

```lua
describe("percentage patterns", function()
    local patterns = require("src.utils.patterns").all()

    it("matches '15% of 24000'", function()
        local p = patterns.percentage_of
        assert.is_not_nil(p)
        local match = p.match("15% of 24000")
        assert.is_not_nil(match)
    end)

    it("matches '24000 + 15%'", function()
        local p = patterns.percentage_add
        local match = p.match("24000 + 15%")
        assert.is_not_nil(match)
    end)

    it("matches '24000 - 25%'", function()
        local p = patterns.percentage_sub
        local match = p.match("24000 - 25%")
        assert.is_not_nil(match)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/utils_spec.lua`

Expected: FAIL - patterns don't exist

**Step 3: Add percentage patterns to patterns.lua**

Add to the patterns table in `src/utils/patterns.lua`:

```lua
-- Percentage patterns for arithmetic
percentage_of = {
    raw = "(%d+%%)%s+of%s+([%d%.,]+)",
    match = function(input)
        return input:match("^(%d+%%)%s+of%s+([%d%.,]+)$")
    end
},
percentage_add = {
    raw = "([%d%.,]+)%s*%+%s*(%d+%%)",
    match = function(input)
        return input:match("^([%d%.,]+)%s*%+%s*(%d+%%)$")
    end
},
percentage_sub = {
    raw = "([%d%.,]+)%s*%-%s*(%d+%%)",
    match = function(input)
        return input:match("^([%d%.,]+)%s*%-%s*(%d+%%)$")
    end
},
```

**Step 4: Run test to verify it passes**

Run: `./scripts/test.sh test/utils_spec.lua`

Expected: PASS

**Step 5: Commit**

```bash
git add src/utils/patterns.lua test/utils_spec.lua
git commit -m "feat(patterns): add percentage operation patterns

Add patterns for:
- X% of Y (percentage of value)
- Y + X% (add percentage)
- Y - X% (subtract percentage)
"
```

---

### Task 7: Implement Percentage Pre-processor

**Files:**
- Modify: `src/formatters/arithmetic.lua`

**Context:** Transform percentage syntax to standard arithmetic before evaluation.

**Step 1: Write failing test for percentage arithmetic**

Add to `test/formatters_spec.lua`:

```lua
describe("percentage arithmetic", function()
    local Arithmetic = require("src.formatters.arithmetic")

    it("calculates 15% of 24000", function()
        local result = Arithmetic.process("15% of 24000", {})
        assert.are_equal(3600, tonumber(result))
    end)

    it("calculates 24000 + 15%", function()
        local result = Arithmetic.process("24000 + 15%", {})
        assert.are_equal(27600, tonumber(result))
    end)

    it("calculates 24000 - 25%", function()
        local result = Arithmetic.process("24000 - 25%", {})
        assert.are_equal(18000, tonumber(result))
    end)

    it("handles currency with percentage", function()
        local result = Arithmetic.process("$24000 - 15%", {})
        assert.are_equal("$20,400", result)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/formatters_spec.lua`

Expected: FAIL - percentages not handled

**Step 3: Add percentage transformation function**

In `src/formatters/arithmetic.lua`, add before the `process()` function:

```lua
local function transformPercentageExpressions(expr)
    -- Transform "X% of Y" → "X / 100 * Y"
    local percentOf, value = expr:match("^(%d+)%%%s+of%s+([%d%.,]+)$")
    if percentOf and value then
        return string.format("%s / 100 * %s", percentOf, value)
    end

    -- Transform "Y + X%" → "Y * (1 + X/100)"
    local base, addPercent = expr:match("^([%d%.,]+)%s*%+%s*(%d+)%%$")
    if base and addPercent then
        return string.format("%s * (1 + %s / 100)", base, addPercent)
    end

    -- Transform "Y - X%" → "Y * (1 - X/100)"
    local subBase, subPercent = expr:match("^([%d%.,]+)%s*%-%s*(%d+)%%$")
    if subBase and subPercent then
        return string.format("%s * (1 - %s / 100)", subBase, subPercent)
    end

    return expr
end
```

**Step 4: Update process() to use transformation**

In `process()`, after normalizing the input but before tokenizing, add the transformation:

```lua
-- After:
local cleaned = normalizeExpressionNumbers(removeCurrencyAndWhitespace(normalized), opts)

-- Add:
cleaned = transformPercentageExpressions(cleaned)

-- Then continue with tokenization...
local tokens = tokenizeExpression(cleaned)
```

**Step 5: Run test to verify it passes**

Run: `./scripts/test.sh test/formatters_spec.lua`

Expected: PASS

**Step 6: Update arithmetic detector pattern dependencies**

In `src/detectors/arithmetic.lua`:

```lua
patternDependencies = {
    "arithmetic_candidate",
    "date_full",
    "localized_number",
    "percentage_of",
    "percentage_add",
    "percentage_sub",
},
```

**Step 7: Commit**

```bash
git add src/formatters/arithmetic.lua src/detectors/arithmetic.lua test/formatters_spec.lua
git commit -m "feat(arithmetic): add percentage calculation support

Support expressions like:
- 15% of 24000 → 3600
- 24000 + 15% → 27600
- 24000 - 25% → 18000
- $24000 - 15% → $20,400

Transforms percentage syntax to arithmetic before evaluation.
"
```

---

## Phase 3: Unit Conversions

### Task 8: Create Units Detector

**Files:**
- Create: `src/detectors/units.lua`
- Create: `src/formatters/unit.lua`
- Test: `test/detectors/units_spec.lua`

**Context:** New detector for unit conversions (length, weight, temperature, data, speed).

**Step 1: Write failing test**

Create `test/detectors/units_spec.lua`:

```lua
describe("units detector", function()
    local UnitsDetector
    local patterns

    setup(function()
        UnitsDetector = require("src.detectors.units")
        patterns = require("src.utils.patterns").all()
    end)

    local function createContext()
        return {
            logger = { d = function() end, i = function() end, w = function() end, e = function() end },
            config = {},
            patterns = patterns,
            pdMapping = {},
            formatters = {},
        }
    end

    it("converts km to mi", function()
        local detector = UnitsDetector(createContext())
        local result = detector.match("100km to mi", createContext())
        assert.is_not_nil(result)
        assert.is_true(result.formatted:match("62") ~= nil)
    end)

    it("converts lb to kg", function()
        local detector = UnitsDetector(createContext())
        local result = detector.match("150lb to kg", createContext())
        assert.is_not_nil(result)
        assert.is_true(result.formatted:match("68") ~= nil)
    end)

    it("converts F to C", function()
        local detector = UnitsDetector(createContext())
        local result = detector.match("72F to C", createContext())
        assert.is_not_nil(result)
        assert.is_true(result.formatted:match("22") ~= nil)
    end)

    it("returns nil for non-conversion input", function()
        local detector = UnitsDetector(createContext())
        local result = detector.match("hello world", createContext())
        assert.is_nil(result)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/detectors/units_spec.lua`

Expected: FAIL - module doesn't exist

**Step 3: Create unit formatter**

Create `src/formatters/unit.lua`:

```lua
local pkgRoot = (...):match("^(.*)%.formatters%.unit$")

local M = {}

-- Conversion factors to base unit
local conversions = {
    -- Length (base: meter)
    length = {
        m = { toBase = 1, fromBase = 1 },
        km = { toBase = 1000, fromBase = 0.001 },
        mi = { toBase = 1609.344, fromBase = 0.000621371 },
        ft = { toBase = 0.3048, fromBase = 3.28084 },
        in = { toBase = 0.0254, fromBase = 39.3701 },
        cm = { toBase = 0.01, fromBase = 100 },
        mm = { toBase = 0.001, fromBase = 1000 },
    },
    -- Weight (base: kilogram)
    weight = {
        kg = { toBase = 1, fromBase = 1 },
        g = { toBase = 0.001, fromBase = 1000 },
        lb = { toBase = 0.453592, fromBase = 2.20462 },
        oz = { toBase = 0.0283495, fromBase = 35.274 },
    },
    -- Temperature (special formulas)
    temperature = {
        C = { toF = function(c) return c * 9/5 + 32 end, fromF = function(f) return (f - 32) * 5/9 end },
        F = { toF = function(f) return f end, fromF = function(f) return f end },
        K = { toF = function(k) return k * 9/5 - 459.67 end, fromF = function(f) return (f + 459.67) * 5/9 end },
    },
    -- Data (base: byte)
    data = {
        MB = { toBase = 1000000, fromBase = 0.000001 },
        GB = { toBase = 1000000000, fromBase = 0.000000001 },
        TB = { toBase = 1000000000000, fromBase = 0.000000000001 },
    },
    -- Speed (base: m/s)
    speed = {
        mph = { toBase = 0.44704, fromBase = 2.23694 },
        kph = { toBase = 0.277778, fromBase = 3.6 },
        ["m/s"] = { toBase = 1, fromBase = 1 },
    },
}

-- Unit to category mapping
local unitCategories = {
    m = "length", km = "length", mi = "length", ft = "length",
    in = "length", cm = "length", mm = "length",
    kg = "weight", g = "weight", lb = "weight", oz = "weight",
    C = "temperature", F = "temperature", K = "temperature",
    MB = "data", GB = "data", TB = "data",
    mph = "speed", kph = "speed", ["m/s"] = "speed",
}

function M.convert(value, fromUnit, toUnit)
    local fromCat = unitCategories[fromUnit]
    local toCat = unitCategories[toUnit]

    if not fromCat or not toCat or fromCat ~= toCat then
        return nil, "incompatible units"
    end

    local numericValue = tonumber(value)
    if not numericValue then
        return nil, "invalid value"
    end

    local category = conversions[fromCat]

    -- Temperature special handling
    if fromCat == "temperature" then
        local f = category[fromUnit].toF(numericValue)
        local result = category[toUnit].fromF(f)
        return result
    end

    -- Standard conversion through base unit
    local fromFactor = category[fromUnit].toBase
    local toFactor = category[toUnit].fromBase
    local baseValue = numericValue * fromFactor
    local result = baseValue * toFactor

    return result
end

function M.formatConversion(value, fromUnit, toUnit)
    local result, err = M.convert(value, fromUnit, toUnit)
    if err then
        return nil, err
    end

    -- Format with appropriate precision
    local formatted
    if math.abs(result) < 0.01 then
        formatted = string.format("%.6g", result)
    elseif math.abs(result) >= 1000 then
        formatted = string.format("%.2f", result)
    else
        formatted = string.format("%.2f", result)
        -- Remove trailing zeros
        formatted = formatted:gsub("%.?0+$", "")
    end

    return formatted .. " " .. toUnit
end

return M
```

**Step 4: Create units detector**

Create `src/detectors/units.lua`:

```lua
local pkgRoot = (...):match("^(.*)%.detectors%.units$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local unitFormatter = require(pkgRoot .. ".formatters.unit")

local function isConversionCandidate(text)
    if not text or text == "" then return false end
    -- Pattern: number + unit + (to|in) + unit
    return text:match("^[%d%.,]+%s*[a-zA-Z]+%s+(to|in)%s+[a-zA-Z]+$") ~= nil
end

return function(deps)
    return DetectorFactory.createCustom({
        id = "units",
        priority = 80,
        dependencies = {},
        deps = deps,
        customMatch = function(text, context)
            if not isConversionCandidate(text) then
                return nil
            end

            -- Parse: "100km to mi" or "100km in mi"
            local valueStr, fromUnit, toUnit = text:match("^([%d%.,]+)%s*([a-zA-Z]+)%s+(to|in)%s+([a-zA-Z]+)$")
            if not valueStr or not fromUnit or not toUnit then
                return nil
            end

            local result = unitFormatter.formatConversion(valueStr, fromUnit, toUnit)
            if not result then
                return nil
            end

            return result
        end
    })
end
```

**Step 5: Register units detector in init.lua**

In `src/init.lua`, add to detectorConstructors:

```lua
local detectorConstructors = {
    requireFromRoot("detectors.arithmetic"),
    requireFromRoot("detectors.date"),
    requireFromRoot("detectors.pd"),
    requireFromRoot("detectors.combinations"),
    requireFromRoot("detectors.phone"),
    requireFromRoot("detectors.navigation"),
    requireFromRoot("detectors.units"),  -- Add this line
}
```

**Step 6: Run test to verify it passes**

Run: `./scripts/test.sh test/detectors/units_spec.lua`

Expected: PASS

**Step 7: Commit**

```bash
git add src/detectors/units.lua src/formatters/unit.lua src/init.lua test/detectors/units_spec.lua
git commit -m "feat(detectors): add unit conversion detector

Support conversions for:
- Length: m, km, mi, ft, in, cm, mm
- Weight: kg, g, lb, oz
- Temperature: C, F, K
- Data: MB, GB, TB
- Speed: mph, kph, m/s

Usage: 100km to mi, 150lb in kg, 72F to C
"
```

---

## Phase 4: Time Calculations

### Task 9: Create Time Math Utilities

**Files:**
- Create: `src/utils/time_math.lua`
- Test: `test/utils/time_math_spec.lua`

**Context:** Utility module for parsing and calculating with times and durations.

**Step 1: Write failing test**

Create `test/utils/time_math_spec.lua`:

```lua
describe("time_math", function()
    local TimeMath = require("src.utils.time_math")

    describe("parseTime", function()
        it("parses 9am as 9:00", function()
            local hour, min, ampm = TimeMath.parseTime("9am")
            assert.are_equal(9, hour)
            assert.are_equal(0, min)
            assert.are_equal("am", ampm)
        end)

        it("parses 5:30pm as 17:30", function()
            local hour, min, ampm = TimeMath.parseTime("5:30pm")
            assert.are_equal(5, hour)
            assert.are_equal(30, min)
            assert.are_equal("pm", ampm)
        end)

        it("parses 14:30 as 14:30 (24h)", function()
            local hour, min, ampm = TimeMath.parseTime("14:30")
            assert.are_equal(14, hour)
            assert.are_equal(30, min)
            assert.is_nil(ampm)
        end)
    end)

    describe("parseDuration", function()
        it("parses 30m as 30 minutes", function()
            local secs = TimeMath.parseDuration("30m")
            assert.are_equal(1800, secs)
        end)

        it("parses 2h as 2 hours", function()
            local secs = TimeMath.parseDuration("2h")
            assert.are_equal(7200, secs)
        end)

        it("parses 1h30m as 90 minutes", function()
            local secs = TimeMath.parseDuration("1h30m")
            assert.are_equal(5400, secs)
        end)
    end)

    describe("addDuration", function()
        it("adds 2 hours to 9am", function()
            local result = TimeMath.addDuration("9am", "2h")
            assert.is_true(result:match("11:") ~= nil)
            assert.is_true(result:match("AM") ~= nil)
        end)

        it("wraps day: 11pm + 2h = 1am", function()
            local result = TimeMath.addDuration("11pm", "2h")
            assert.is_true(result:match("1:") ~= nil)
            assert.is_true(result:match("AM") ~= nil)
        end)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/utils/time_math_spec.lua`

Expected: FAIL - module doesn't exist

**Step 3: Implement time_math module**

Create `src/utils/time_math.lua`:

```lua
--[[
WHAT THIS FILE DOES:
Provides time parsing, duration parsing, and time calculation utilities.
Supports 12h (am/pm) and 24h time formats.

KEY CONCEPTS:
- Time Parsing: Extract hour, minute, am/pm from various formats
- Duration Parsing: Convert duration strings to seconds
- Time Math: Add/subtract durations from times with day wrap handling
]]

local M = {}

-- Parse time string, returning hour, minute, ampm (ampm is nil for 24h)
function M.parseTime(timeStr)
    if not timeStr or timeStr == "" then
        return nil
    end

    local hour, min, ampm

    -- Try 12h format: "9am", "9:30am", "9:30 am", "9:30 a.m."
    local h12, m12, ap = timeStr:match("^(%d+):(%d+)%s*(am|pm|a%.m%.|p%.m%.)$")
    if h12 then
        hour = tonumber(h12)
        min = tonumber(m12)
        ampm = ap:lower():gsub("%.", "")
        return hour, min, ampm
    end

    -- Try 12h without minutes: "9am", "9 pm"
    local h12only, ap2 = timeStr:match("^(%d+)%s*(am|pm|a%.m%.|p%.m%.)$")
    if h12only then
        hour = tonumber(h12only)
        min = 0
        ampm = ap2:lower():gsub("%.", "")
        return hour, min, ampm
    end

    -- Try 24h format: "14:30", "9:00"
    local h24, m24 = timeStr:match("^(%d+):(%d+)$")
    if h24 then
        hour = tonumber(h24)
        min = tonumber(m24)
        return hour, min, nil
    end

    return nil
end

-- Parse duration string to seconds
function M.parseDuration(durationStr)
    if not durationStr or durationStr == "" then
        return nil
    end

    local totalSeconds = 0

    -- Match patterns like "2h30m", "45m", "1h"
    for hours, mins in durationStr:gmatch("(%d+)h") do
        totalSeconds = totalSeconds + (tonumber(hours) * 3600)
    end
    for mins in durationStr:gmatch("(%d+)m") do
        totalSeconds = totalSeconds + (tonumber(mins) * 60)
    end
    for secs in durationStr:gmatch("(%d+)s") do
        totalSeconds = totalSeconds + tonumber(secs)
    end

    if totalSeconds == 0 then
        return nil
    end

    return totalSeconds
end

-- Convert parsed time to seconds since midnight
local function timeToSeconds(hour, min, ampm)
    local h = hour
    if ampm == "pm" and h ~= 12 then
        h = h + 12
    elseif ampm == "am" and h == 12 then
        h = 0
    end
    return h * 3600 + min * 60
end

-- Convert seconds since midnight to formatted time string
local function secondsToTime(seconds, useAmPm)
    local secsPerDay = 86400
    local days = math.floor(seconds / secsPerDay)
    local secsInDay = seconds % secsPerDay

    local h = math.floor(secsInDay / 3600)
    local m = math.floor((secsInDay % 3600) / 60)

    if useAmPm then
        local ampm = h >= 12 and "PM" or "AM"
        local displayH = h
        if h == 0 then
            displayH = 12
        elseif h > 12 then
            displayH = h - 12
        end
        return string.format("%d:%02d %s", displayH, m, ampm)
    else
        return string.format("%d:%02d", h, m)
    end
end

-- Add duration to time, return formatted result
function M.addDuration(timeStr, durationStr)
    local hour, min, ampm = M.parseTime(timeStr)
    if not hour then
        return nil
    end

    local durationSecs = M.parseDuration(durationStr)
    if not durationSecs then
        return nil
    end

    local timeSecs = timeToSeconds(hour, min, ampm)
    local resultSecs = timeSecs + durationSecs

    local useAmPm = (ampm ~= nil)
    return secondsToTime(resultSecs, useAmPm)
end

-- Subtract duration from time
function M.subtractDuration(timeStr, durationStr)
    local hour, min, ampm = M.parseTime(timeStr)
    if not hour then
        return nil
    end

    local durationSecs = M.parseDuration(durationStr)
    if not durationSecs then
        return nil
    end

    local timeSecs = timeToSeconds(hour, min, ampm)
    local resultSecs = timeSecs - durationSecs

    -- Handle negative (wrap to previous day)
    if resultSecs < 0 then
        resultSecs = resultSecs + 86400
    end

    local useAmPm = (ampm ~= nil)
    return secondsToTime(resultSecs, useAmPm)
end

return M
```

**Step 4: Run test to verify it passes**

Run: `./scripts/test.sh test/utils/time_math_spec.lua`

Expected: PASS

**Step 5: Commit**

```bash
git add src/utils/time_math.lua test/utils/time_math_spec.lua
git commit -m "feat(utils): add time_math utility module

Parse times (12h/24h), parse durations, and perform time calculations.
Handles day wrap for times crossing midnight.
"
```

---

### Task 10: Create Time Calculations Detector

**Files:**
- Create: `src/detectors/time_calc.lua`
- Test: `test/detectors/time_calc_spec.lua`

**Context:** New detector for time arithmetic like "9am + 2h".

**Step 1: Write failing test**

Create `test/detectors/time_calc_spec.lua`:

```lua
describe("time_calc detector", function()
    local TimeCalcDetector
    local patterns

    setup(function()
        TimeCalcDetector = require("src.detectors.time_calc")
        patterns = require("src.utils.patterns").all()
    end)

    local function createContext()
        return {
            logger = { d = function() end, i = function() end, w = function() end, e = function() end },
            config = {},
            patterns = patterns,
            pdMapping = {},
            formatters = {},
        }
    end

    it("calculates 9am + 2h", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match("9am + 2h", createContext())
        assert.is_not_nil(result)
        assert.is_true(result.formatted:match("11:") ~= nil)
    end)

    it("calculates 14:30 - 45m", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match("14:30 - 45m", createContext())
        assert.is_not_nil(result)
        assert.is_true(result.formatted:match("13:45") ~= nil)
    end)

    it("calculates now + 30m", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match("now + 30m", createContext())
        assert.is_not_nil(result)
    end)

    it("returns nil for non-time input", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match("hello world", createContext())
        assert.is_nil(result)
    end)
end)
```

**Step 2: Run test to verify it fails**

Run: `./scripts/test.sh test/detectors/time_calc_spec.lua`

Expected: FAIL - module doesn't exist

**Step 3: Create time_calc detector**

Create `src/detectors/time_calc.lua`:

```lua
local pkgRoot = (...):match("^(.*)%.detectors%.time_calc$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local TimeMath = require(pkgRoot .. ".utils.time_math")

local function isTimeCalcCandidate(text)
    if not text or text == "" then return false end
    -- Check for "now" or time patterns
    if text:lower():find("^now%s*[+-]") then
        return true
    end
    -- Check for time + duration pattern
    local hasTime = text:match("%d+[ap]m") or text:match("%d+:%d+")
    local hasDuration = text:match("%d+[hms]")
    local hasOperator = text:match("[+-]")
    return hasTime and hasDuration and hasOperator
end

return function(deps)
    return DetectorFactory.createCustom({
        id = "time_calc",
        priority = 90,
        dependencies = {},
        deps = deps,
        customMatch = function(text, context)
            if not isTimeCalcCandidate(text) then
                return nil
            end

            local trimmed = text:match("^%s*(.-)%s*$")
            local lower = trimmed:lower()

            -- Handle "now +/- duration"
            if lower:match("^now%s*[+-]%s*[%d+hms]+$") then
                local op, duration = trimmed:match("^now%s*([+-])%s*([%d%ahms]+)$")
                if not op or not duration then
                    return nil
                end

                local nowStr = os.date("%H:%M")
                local result
                if op == "+" then
                    result = TimeMath.addDuration(nowStr, duration)
                else
                    result = TimeMath.subtractDuration(nowStr, duration)
                end

                if result then
                    return result
                end
            end

            -- Handle "time +/- duration"
            local timeStr, op, durationStr = trimmed:match("^(%d+:?%d*[ap]?)%s*([+-])%s*([%d%ahms]+)$")
            if timeStr and op and durationStr then
                local result
                if op == "+" then
                    result = TimeMath.addDuration(timeStr, durationStr)
                else
                    result = TimeMath.subtractDuration(timeStr, durationStr)
                end

                if result then
                    return result
                end
            end

            return nil
        end
    })
end
```

**Step 4: Register time_calc detector in init.lua**

In `src/init.lua`, add to detectorConstructors:

```lua
local detectorConstructors = {
    requireFromRoot("detectors.arithmetic"),
    requireFromRoot("detectors.date"),
    requireFromRoot("detectors.pd"),
    requireFromRoot("detectors.combinations"),
    requireFromRoot("detectors.phone"),
    requireFromRoot("detectors.navigation"),
    requireFromRoot("detectors.units"),
    requireFromRoot("detectors.time_calc"),  -- Add this line
}
```

**Step 5: Run test to verify it passes**

Run: `./scripts/test.sh test/detectors/time_calc_spec.lua`

Expected: PASS

**Step 6: Commit**

```bash
git add src/detectors/time_calc.lua src/init.lua test/detectors/time_calc_spec.lua
git commit -m "feat(detectors): add time calculation detector

Support expressions like:
- 9am + 2h → 11:00 AM
- 14:30 - 45m → 13:45
- now + 30m → [current time + 30 min]

Handles day wrap and 12h/24h formats.
"
```

---

## Phase 5: Integration & Polish

### Task 11: Update Documentation

**Files:**
- Modify: `README.md` (if exists) or create
- Modify: `CLAUDE.md`

**Step 1: Update CLAUDE.md with new capabilities**

Add to the "Detectors" section in `CLAUDE.md`:

```markdown
**Detectors (`src/detectors/`)**
- Modular pattern detection system via registry pattern
- Each detector created via `detector_factory.create()` with dependency injection
- Detectors can optionally declare `dependencies` and `patternDependencies` arrays
- Built-in detectors: arithmetic, date ranges, PD conversions, combinations, phone numbers, navigation, unit conversions, time calculations
- Detectors return `{ formatted, matchedId, rawResult, sideEffect, errors }`
```

Add to "Key Architectural Patterns" section:

```markdown
**Seed Processing**: The `formatSeed` methods use the `seed_strategies` module to extract expressions after `=`, `:`, or whitespace boundaries. Strategies are tried in order: date_range → arithmetic → separator → whitespace → fallback.
```

**Step 2: Update README.md or create quick reference**

Create or update README with usage examples:

```markdown
## Usage Examples

### Arithmetic
- `10 + 5` → `15`
- `$100 - $25` → `$75`
- `15% of 24000` → `3600`
- `24000 + 15%` → `27600`

### Time Calculations
- `9am + 2h` → `11:00 AM`
- `now + 30m` → [current time + 30 min]
- `14:30 - 45m` → `13:45`

### Unit Conversions
- `100km to mi` → `62.14 mi`
- `150lb to kg` → `68.03 kg`
- `72F to C` → `22.22°C`
```

**Step 3: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: update documentation for new features

Document time calculations, unit conversions, percentage arithmetic,
and refactored seed extraction architecture.
"
```

---

### Task 12: Full Integration Test

**Step 1: Run full test suite**

Run: `./scripts/test.sh`

Expected: All tests pass

**Step 2: Test with real workflow**

Manual testing checklist:
- [ ] Arithmetic: `10+5` hotkey produces `15`
- [ ] Currency: `$100-$25` hotkey produces `$75`
- [ ] Percentage: `15% of 24000` hotkey produces `3600`
- [ ] Time: `9am + 2h` hotkey produces `11:00 AM`
- [ ] Units: `100km to mi` hotkey produces `62.14 mi`
- [ ] Date range: `01/15/2025 - 01/20/2025` hotkey produces formatted range

**Step 3: Commit final integration**

```bash
git commit --allow-empty -m "feat: complete workflow enhancements implementation

All phases complete:
- Foundation refactoring (seed strategies, unified arithmetic)
- Percentage arithmetic
- Unit conversions
- Time calculations

Ready for production use.
"
```

---

## Summary

This plan implements the workflow enhancements in 12 tasks across 5 phases:

| Phase | Tasks | New Files | Modified Files |
|-------|-------|-----------|----------------|
| 1: Foundation | 5 | 2 | 5 |
| 2: Percentage | 2 | 0 | 3 |
| 3: Units | 1 | 3 | 1 |
| 4: Time | 2 | 3 | 1 |
| 5: Polish | 2 | 0 | 2 |
| **Total** | **12** | **8** | **12** |

Estimated: 60-90 minutes of focused implementation with TDD approach.
