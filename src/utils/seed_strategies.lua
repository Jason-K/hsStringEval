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
