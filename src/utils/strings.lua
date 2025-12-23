--[[
WHAT THIS FILE DOES:
This module provides a collection of string manipulation utilities. These functions
are used throughout the application for parsing, cleaning, and comparing strings.
They handle common tasks like trimming whitespace, splitting strings, and
case-insensitive comparisons, providing a consistent and reusable toolkit.

KEY CONCEPTS:
- String Manipulation: Core functions for common string operations.
- Normalization: Functions to standardize strings, for example by normalizing
  different types of minus signs.
- Parsing: Utilities to help extract meaningful parts from strings.

EXAMPLE USAGE:
    local Strings = require("src.utils.strings")
    local trimmed = Strings.trim("  hello world  ")
    -- trimmed is now "hello world"
    local parts = Strings.split("a,b,c", ",")
    -- parts is now {"a", "b", "c"}
]]
local M = {}

-- PUBLIC METHOD: Trim leading and trailing whitespace from a string.
-- @param str string The input string.
-- @return string The trimmed string, or an empty string if input is nil.
-- Example: M.trim("  hello  ") → "hello"
function M.trim(str)
    -- GUARD: Handle nil input.
    if not str then return "" end
    -- ACTION: Use a pattern match to find and return the content between whitespace.
    return str:match("^%s*(.-)%s*$") or ""
end

-- PUBLIC METHOD: Split a string by a separator.
-- @param str string The input string.
-- @param sep string (optional) The separator pattern. Defaults to whitespace.
-- @return table A table of substrings.
-- Example: M.split("a,b,c", ",") → {"a", "b", "c"}
function M.split(str, sep)
    -- GUARD: Handle nil or empty string input.
    if not str or str == "" then return {} end
    -- SETUP: Default separator to whitespace if not provided.
    sep = sep or "%s"
    -- SETUP: Create a pattern to capture non-separator characters.
    local pattern = string.format("([^%s]+)", sep)
    local out = {}
    -- ACTION: Iterate through all matches and insert them into the output table.
    for part in str:gmatch(pattern) do
        table.insert(out, part)
    end
    return out
end

-- PUBLIC METHOD: Check if a string contains only characters from an allowed set.
-- @param str string The input string.
-- @param allowed string A string containing all allowed characters.
-- @return boolean true if the string contains only allowed characters, false otherwise.
-- Example: M.containsOnly("123", "0123456789") → true
function M.containsOnly(str, allowed)
    -- GUARD: Handle nil input.
    if not str then return false end
    -- ACTION: Match the string against a pattern that anchors to the start and
    -- end, and only allows characters from the `allowed` set.
    return str:match(string.format("^[%s]+$", allowed)) ~= nil
end

-- PUBLIC METHOD: Check if a string starts with a given prefix.
-- @param str string The input string.
-- @param prefix string The prefix to check for.
-- @return boolean true if the string starts with the prefix, false otherwise.
-- Example: M.startsWith("hello world", "hello") → true
function M.startsWith(str, prefix)
    -- GUARD: Handle nil inputs.
    if not str or not prefix then return false end
    -- ACTION: Compare the substring of `str` with the same length as `prefix`
    -- to the `prefix`.
    return str:sub(1, #prefix) == prefix
end

-- PUBLIC METHOD: Perform a case-insensitive comparison of two strings.
-- @param a string The first string.
-- @param b string The second string.
-- @return boolean true if the strings are equal when case is ignored.
-- Example: M.equalFold("Hello", "hello") → true
function M.equalFold(a, b)
    -- GUARD: Handle nil inputs.
    if a == nil or b == nil then return false end
    -- ACTION: Convert both strings to lower case and compare.
    return a:lower() == b:lower()
end

-- PUBLIC METHOD: Normalize different types of minus signs to a standard hyphen.
-- This is useful for parsing arithmetic expressions where users might input
-- different characters for subtraction.
-- @param str string The input string.
-- @return string The string with minus signs normalized.
function M.normalizeMinus(str)
    -- GUARD: Handle nil input.
    if not str then return str end
    -- ACTION: Replace en dash, em dash, and minus sign with a hyphen-minus.
    str = str:gsub("–", "-") -- En dash
    str = str:gsub("—", "-") -- Em dash
    str = str:gsub("−", "-") -- Minus sign
    return str
end

-- PUBLIC METHOD: Extract a potential "seed" for an expression from a string.
-- The seed is the part of the string that is most likely to be an evaluatable
-- expression. This is determined by looking for common separators like '=', ':',
-- or brackets, or falling back to the last word.
-- @param str string The input string.
-- @return string The prefix before the seed.
-- @return string The extracted seed.
-- Example: M.extractSeed("Total: 10+5") → "Total: ", "10+5"
function M.extractSeed(str)
    -- GUARD: Handle nil or empty string input.
    if not str or str == "" then
        return "", ""
    end

    -- Strip trailing whitespace (including newlines) before pattern matching.
    -- This ensures patterns that use $ (end-of-string anchor) work correctly.
    -- Trailing whitespace is typically a copy-paste artifact and not meaningful
    -- for seed extraction purposes.
    local originalStr = str
    str = str:match("^(.-)%s*$") or str

    -- STRATEGY: Look for the last whitespace-separated token that could be an expression.
    -- This is more reliable than looking for separators like '[' which can appear in labels.

    -- First, try to find a simple arithmetic-like pattern at the end
    -- Look for the last whitespace before an arithmetic expression
    -- Include 'c' and 'C' for combination operations like "12c11"
    -- Include %s for internal whitespace in expressions like "5 + 3"
    local beforeWs, ws, arith = str:match("^(.-)(%s+)([%d%.%s%(%)%+%-%*/%%^cC]+)$")
    if arith and arith:match("[%d%(]") then
        -- Found arithmetic at the end with leading whitespace - keep the space in prefix
        return beforeWs .. ws, arith
    end

    -- Try without requiring leading whitespace (for strings that are just arithmetic)
    -- Include %s for internal whitespace in expressions like "5 + 3"
    local arithmeticOnly = str:match("^([%d%.%s%(%)%+%-%*/%%^cC]+)$")
    if arithmeticOnly and arithmeticOnly:match("[%d%(]") then
        return "", arithmeticOnly
    end

    -- Fallback: Look for common separators that precede an expression
    -- We look for these followed by whitespace to avoid matching parts of words.
    local separators = { "=%s", ":%s", "%(", "%[", "{" }
    local lastSepPos = 0

    -- STEP: Find the last occurrence of any separator.
    for _, sep in ipairs(separators) do
        local searchPos = 1
        while true do
            -- ACTION: Find the next occurrence of the separator.
            local pos = str:find(sep, searchPos)
            if not pos then
                break
            end
            -- ACTION: Find the start of the content after the separator.
            local afterSep = str:find("[^%s]", pos + 1)
            if afterSep and afterSep - 1 > lastSepPos then
                -- REGISTER: Update the position of the last separator found.
                lastSepPos = afterSep - 1
            end
            -- STEP: Continue searching from the next position.
            searchPos = pos + 1
        end
    end

    -- CASE: A separator was found.
    if lastSepPos > 0 then
        -- PROCESS: Split the string at the separator position.
        local prefix = str:sub(1, lastSepPos)
        local seed = str:sub(lastSepPos + 1)
        return prefix, seed
    end

    -- CASE: No separator found, look for the last whitespace.
    local lastWhitespace = 0
    for i = 1, #str do
        if str:sub(i, i):match("%s") then
            lastWhitespace = i
        end
    end

    -- CASE: Whitespace was found.
    if lastWhitespace > 0 then
        -- PROCESS: Split the string at the last whitespace position.
        local prefix = str:sub(1, lastWhitespace)
        local seed = str:sub(lastWhitespace + 1)
        return prefix, seed
    end

    -- CASE: No whitespace found, the entire string is the seed.
    return "", str
end

return M
