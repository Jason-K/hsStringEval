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

-- Get package root for module loading (works in both test and Hammerspoon environments)
local pkgRoot = (...):match("^(.*)%.utils%.strings$")

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
-- Delegates to seed_strategies module for modular extraction logic.
-- @param str string The input string.
-- @param table context (optional) Context object with dependencies (patterns, etc.)
-- @return string The prefix before the seed.
-- @return string The extracted seed.
-- Example: M.extractSeed("Total: 10+5") → "Total: ", "10+5"
function M.extractSeed(str, context)
    local ok, seedStrategies = pcall(function()
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

return M
