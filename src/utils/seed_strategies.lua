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

    if not Date.isRangeCandidate(str, {}) then
        return nil
    end

    -- Get patterns from context or load directly
    local allPatterns = context and context.patterns
    if not allPatterns or not allPatterns.date_token then
        local ok2, pm = pcall(require, pkgRoot .. ".utils.patterns")
        if ok2 then
            allPatterns = pm.all()
        end
    end

    if not allPatterns then
        return nil
    end
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
-- Extended to support time/date calculations (e.g., "12:00 AM + 13 hours", "12/16/25 + 1 day")
function M.arithmetic_strategy(str)
    if not str or str == "" then
        return nil
    end

    -- Extended character set for arithmetic + time/date expressions:
    -- - Digits, decimal: 0-9 .
    -- - Whitespace: %s
    -- - Operators: () + - * / % ^ c C
    -- - Time: : (colon)
    -- - Date: / (slash)
    -- - All letters (for "hours", "minutes", "day", "AM/PM", "now", "today", etc.): %a
    local exprChars = "[%d%.%s%(%)%+%-%*/%%^cC:/%a]"

    -- Pattern 1: "Word: expr" - prefix ending with : followed by arithmetic
    -- This handles "Total: 100 * 2" but not "12:00 AM + 13 hours" (starts with digit)
    local prefix, seed = str:match("^(%a[^:]-:%s+)(" .. exprChars .. "+)$")
    if seed and seed:match("[%d%(]") then
        return prefix, seed
    end

    -- Pattern 1b: "Word expr" - any word prefix followed by time/date expression
    -- This handles "testing 12AM + 13 hours" where "testing " is the prefix
    local prefixB, seedB = str:match("^(%a+%s+)(" .. exprChars .. "+)$")
    if prefixB and seedB and seedB:match("^[%d%:]") then
        -- Check if the seed starts with a time/date pattern (digit or colon)
        -- Also verify it contains an operator to avoid matching simple numbers
        if seedB:match("[+-]") and (seedB:match("^%d") or seedB:match("^%d+:%d+")) then
            return prefixB, seedB
        end
    end

    -- Pattern 2: "anything today/Today/TODAY expr" - need to differentiate:
    --   - "today + 1 day" (date calc) → keep "today" in seed
    --   - "today 12AM + 13 hours" (time calc) → "today" is prefix
    -- Use case-insensitive matching
    local lowerStr = str:lower()
    local prefixT, seedT = str:match("^(.-)([Tt][Oo][Dd][Aa][Yy]%s*" .. exprChars .. "+)$")
    if prefixT and seedT then
        local afterToday = seedT:match("^[Tt][Oo][Dd][Aa][Yy]%s*(.*)$")
        -- If "today" is followed immediately by operator (with optional whitespace), it's a date calc
        if afterToday and afterToday:match("^%s*[+-]") then
            -- Date calculation: keep "today" in seed
            return prefixT, seedT
        -- If "today" is followed by a time expression (starts with digit), it's a time calc
        elseif afterToday and (afterToday:match("^%s*%d") or afterToday:match("^%s*%d+:%d+") or afterToday:match("^%s*%d+[apAP]")) then
            -- Time calculation: "today" is prefix, rest is seed
            return prefixT .. seedT:match("^[Tt][Oo][Dd][Aa][Yy]%s+"), afterToday:match("^%s*(.*)$")
        end
    end

    -- Pattern 3: "anything now/Now/NOW expr" - similar logic as "today"
    local prefixN, seedN = str:match("^(.-)([Nn][Oo][Ww]%s*" .. exprChars .. "+)$")
    if prefixN and seedN then
        local afterNow = seedN:match("^[Nn][Oo][Ww]%s*(.*)$")
        -- If "now" is followed immediately by operator, it's a date calc
        if afterNow and afterNow:match("^%s*[+-]") then
            -- Date calculation: keep "now" in seed
            return prefixN, seedN
        -- If "now" is followed by a time expression, it's a time calc
        elseif afterNow and (afterNow:match("^%s*%d") or afterNow:match("^%s*%d+:%d+") or afterNow:match("^%s*%d+[apAP]")) then
            -- Time calculation: "now" is prefix, rest is seed
            return prefixN .. seedN:match("^[Nn][Oo][Ww]%s+"), afterNow:match("^%s*(.*)$")
        end
    end

    -- Pattern 4: Pure arithmetic/time/date (entire string matches)
    -- Must start with specific patterns: digit, operator, (, ), time keywords, etc.
    -- This prevents matching arbitrary text like "line1\n15/3"
    local function isValidStart(s)
        local sLower = s:lower()
        return s:match("^[%d%(%)%+%-*/%%^cC:.]")  -- starts with digit, operator, (, ), ., :, :
            or sLower:match("^now%s*[+-]")
            or sLower:match("^today%s*[+-]")
            or s:match("^%d+[:/]")  -- starts with time like "12:" or date like "12/"
    end

    local arithmeticOnly = str:match("^" .. exprChars .. "+$")
    if arithmeticOnly and arithmeticOnly:match("[%d%(]") and isValidStart(str) then
        return "", arithmeticOnly
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
