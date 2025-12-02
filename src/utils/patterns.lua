--[[
WHAT THIS FILE DOES:
This module provides a centralized registry for managing and accessing Lua string
patterns (regular expressions). It allows patterns to be defined in one place
and then accessed by name throughout the application. It also provides a caching
mechanism, where patterns are "compiled" into a table of utility functions
(`contains`, `match`, `gmatch`) the first time they are accessed. This improves
performance by avoiding repeated setup and makes using the patterns more convenient.

KEY CONCEPCandidacyTS:
- Pattern Registry: A single source of truth for all string patterns.
- Compilation: Patterns are lazily compiled into a more useful format with
  helper functions.
- Caching: Compiled patterns are cached to avoid redundant work.
- Abstraction: Provides a simple API to access and use complex patterns without
  needing to know their implementation details.

EXAMPLE USAGE:
    local Patterns = require("src.utils.patterns")
    Patterns.register("my_pattern", "%d+")
    local compiled = Patterns.compiled("my_pattern")
    if compiled.contains("hello 123 world") then
        print("Found a number!")
    end
]]

-- SETUP: A table to store the raw string patterns, mapped by name.
local rawPatterns = {
    -- Matches strings that look like they could be arithmetic expressions.
    -- Allows dollar signs interspersed with numbers (e.g., "$120-$50" or "120-$50")
    arithmetic_candidate = "^%s*[%$%d%.,%s%(%)%+%-%*/%%^]+$",
    -- Matches phone numbers that use a semicolon separator.
    phone_semicolon = "%d+;.+",
    -- A general token for a date, like "MM/DD/YYYY".
    date_token = "%d+[/%.-]%d+[/%.-]%d+",
    -- Matches a full date string from start to end.
    date_full = "^%d%d?[/%.-]%d%d?[/%.-]%d%d%d?%d?$",
    -- Matches an ISO-formatted date token, like "YYYY-MM-DD".
    date_token_iso = "%d%d%d%d[/%.-]%d%d[/%.-]%d%d",
    -- Matches a date that includes text, like "Jan 1, 2023".
    date_token_text = "[%a%.]+%s+%d%d?[, ]*%d?%d?%d?%d?",
    -- Matches a date range separated by a dash.
    date_range_dash = "^(%d+[/%.-]%d+[/%.-]%d+)%-(%d+[/%.-]%d+[/%.-]%d+)$",
    -- Matches a number that may be localized with commas or periods.
    localized_number = "^%s*[+-]?[%d%.%,]+%s*$",
}

-- SETUP: A cache for the compiled pattern objects.
local compiled = {}

-- HELPER: Compiles a raw pattern string into a table of useful functions.
-- The compiled object is cached for future use.
-- @param name string The name of the pattern to compile.
-- @return table|nil The compiled pattern object, or nil if not found.
local function compile(name)
    -- GUARD: Check if the raw pattern exists.
    local pattern = rawPatterns[name]
    if not pattern then
        return nil
    end
    -- PROCESS: If not already compiled, create the compiled object.
    if not compiled[name] then
        -- REGISTER: Store the compiled object in the cache.
        compiled[name] = {
            raw = pattern,
            -- HELPER: Function to check if a string contains the pattern.
            contains = function(text)
                return type(text) == "string" and text:find(pattern) ~= nil
            end,
            -- HELPER: Function to match the pattern against a string.
            match = function(text)
                if type(text) ~= "string" then return nil end
                return text:match(pattern)
            end,
            -- HELPER: Function to iterate over all matches of the pattern in a string.
            gmatch = function(text)
                if type(text) ~= "string" then
                    -- Return a dummy iterator for invalid input.
                    return function() end
                end
                return text:gmatch(pattern)
            end,
        }
    end
    return compiled[name]
end

-- HELPER: Creates a snapshot of all compiled patterns.
-- @return table A table of all compiled pattern objects.
local function snapshot()
    local result = {}
    -- ACTION: Iterate through all raw patterns and compile them.
    for name in pairs(rawPatterns) do
        result[name] = compile(name)
    end
    return result
end

local M = {}

-- PUBLIC METHOD: Register a new pattern.
-- @param name string The name of the pattern.
-- @param pattern string The raw pattern string.
function M.register(name, pattern)
    -- ACTION: Add the new pattern to the raw patterns table.
    rawPatterns[name] = pattern
    -- CLEANUP: Invalidate any previously compiled version.
    compiled[name] = nil
end

-- PUBLIC METHOD: Ensure a pattern is registered, and if not, register it.
-- @param name string The name of the pattern.
-- @param pattern string The pattern to register if it doesn't exist.
-- @return table The compiled pattern object.
function M.ensure(name, pattern)
    -- GUARD: Check if the pattern is already registered.
    if rawPatterns[name] == nil then
        -- ACTION: Register the new pattern if it's not.
        M.register(name, pattern)
    end
    -- PROCESS: Return the compiled pattern.
    return compile(name)
end

-- PUBLIC METHOD: Get the raw string of a pattern.
-- @param name string The name of the pattern.
-- @return string|nil The raw pattern string, or nil if not found.
function M.get(name)
    local entry = compile(name)
    return entry and entry.raw or nil
end

-- PUBLIC METHOD: Get the compiled object for a pattern.
-- @param name string The name of the pattern.
-- @return table|nil The compiled pattern object, or nil if not found.
function M.compiled(name)
    return compile(name)
end

-- PUBLIC METHOD: A convenience function to match a pattern against a string.
-- @param name string The name of the pattern.
-- @param text string The string to match against.
-- @return any The result of the match, or nil if the pattern doesn't exist.
function M.match(name, text)
    local entry = compile(name)
    if not entry then return nil end
    return entry.match(text)
end

-- PUBLIC METHOD: A convenience function to check if a string contains a pattern.
-- @param name string The name of the pattern.
-- @param text string The string to check.
-- @return boolean true if the string contains the pattern, false otherwise.
function M.contains(name, text)
    local entry = compile(name)
    if not entry then return false end
    return entry.contains(text)
end

-- PUBLIC METHOD: Get all compiled patterns.
-- @return table A table containing all compiled pattern objects.
function M.all()
    return snapshot()
end

return M
