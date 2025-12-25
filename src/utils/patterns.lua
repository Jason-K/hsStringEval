--[[
WHAT THIS FILE DOES:
This module provides a centralized registry for managing and accessing Lua string
patterns (regular expressions) with memory-efficient caching. It combines the
simple, clean API of the original patterns module with LRU caching and memory
pressure monitoring from the memory-aware implementation.

KEY CONCEPTS:
- Pattern Registry: A single source of truth for all string patterns
- LRU Caching: Least-Recently-Used cache for compiled patterns
- Memory Awareness: Automatic cleanup when memory pressure is high
- Weak References: Secondary weak table for automatic garbage collection
- Backward Compatible: Maintains the original simple API

EXAMPLE USAGE:
    local patterns = require("src.utils.patterns")

    -- Basic usage (backward compatible)
    local compiled = patterns.compiled("arithmetic_candidate")
    if compiled.contains("hello 123 world") then
        print("Found a number!")
    end

    -- Optional configuration for memory management
    patterns.configure({
        maxCacheSize = 100,        -- LRU cache size
        memoryThresholdMB = 10,    -- Trigger cleanup at 10MB
        autoCleanup = true,        -- Auto memory management
    })
]]

-- ============================================================================
-- INTERNAL: LRU Cache Implementation
-- ============================================================================

local LRUCache = {}
LRUCache.__index = LRUCache

function LRUCache.new(maxSize)
    local instance = {
        maxSize = maxSize or 100,
        data = {},
        accessOrder = {},
        size = 0
    }
    return setmetatable(instance, LRUCache)
end

function LRUCache:get(key)
    local value = self.data[key]
    if value then
        -- Move to end (most recently used)
        self:_removeFromOrder(key)
        self:_addToOrder(key)
        return value
    end
    return nil
end

function LRUCache:set(key, value)
    if self.data[key] then
        -- Update existing
        self.data[key] = value
        self:_removeFromOrder(key)
        self:_addToOrder(key)
    else
        -- Add new
        if self.size >= self.maxSize then
            self:_evictLRU()
        end
        self.data[key] = value
        self:_addToOrder(key)
        self.size = self.size + 1
    end
end

function LRUCache:_addToOrder(key)
    table.insert(self.accessOrder, key)
end

function LRUCache:_removeFromOrder(key)
    for i, k in ipairs(self.accessOrder) do
        if k == key then
            table.remove(self.accessOrder, i)
            break
        end
    end
end

function LRUCache:_evictLRU()
    if #self.accessOrder > 0 then
        local lruKey = table.remove(self.accessOrder, 1)
        self.data[lruKey] = nil
        self.size = self.size - 1
    end
end

function LRUCache:clear()
    self.data = {}
    self.accessOrder = {}
    self.size = 0
end

-- ============================================================================
-- INTERNAL: Pattern Registry and Compilation
-- ============================================================================

-- Raw pattern strings
local rawPatterns = {
    -- Matches strings that look like they could be arithmetic expressions
    arithmetic_candidate = "^%s*[%$%d%.,%s%(%)%+%-%*/%%^]+$",
    -- Matches phone numbers that use a semicolon separator
    phone_semicolon = "%d+;.+",
    -- A general token for a date, like "MM/DD/YYYY"
    date_token = "%d+[/%.-]%d+[/%.-]%d+",
    -- Matches a full date string from start to end
    date_full = "^%d%d?[/%.-]%d%d?[/%.-]%d%d%d?%d?$",
    -- Matches an ISO-formatted date token, like "YYYY-MM-DD"
    date_token_iso = "%d%d%d%d[/%.-]%d%d[/%.-]%d%d",
    -- Matches a date that includes text, like "Jan 1, 2023"
    date_token_text = "[%a%.]+%s+%d%d?[, ]*%d?%d?%d?%d?",
    -- Matches a date range separated by a dash
    date_range_dash = "^(%d+[/%.-]%d+[/%.-]%d+)%-(%d+[/%.-]%d+[/%.-]%d+)$",
    -- Matches a number that may be localized with commas or periods
    localized_number = "^%s*[+-]?[%d%.%,]+%s*$",
}

-- Compiles a raw pattern string into a table of useful functions
local function compilePattern(pattern)
    return {
        raw = pattern,
        contains = function(text)
            return type(text) == "string" and text:find(pattern) ~= nil
        end,
        match = function(text)
            if type(text) ~= "string" then return nil end
            return text:match(pattern)
        end,
        gmatch = function(text)
            if type(text) ~= "string" then
                return function() end
            end
            return text:gmatch(pattern)
        end,
    }
end

-- ============================================================================
-- MODULE CONFIGURATION
-- ============================================================================

local config = {
    maxCacheSize = 100,
    memoryThresholdMB = 10,
    autoCleanup = true,
}

-- Caching systems
local lruCache = LRUCache.new(config.maxCacheSize)
local weakRefCache = setmetatable({}, { __mode = "v" })

-- ============================================================================
-- PUBLIC API
-- ============================================================================

local M = {}

-- Configure the patterns module
-- @param opts table Configuration options
function M.configure(opts)
    opts = opts or {}
    if opts.maxCacheSize then
        config.maxCacheSize = opts.maxCacheSize
        lruCache = LRUCache.new(config.maxCacheSize)
        weakRefCache = setmetatable({}, { __mode = "v" })
    end
    if opts.memoryThresholdMB then
        config.memoryThresholdMB = opts.memoryThresholdMB
    end
    if opts.autoCleanup ~= nil then
        config.autoCleanup = opts.autoCleanup
    end
end

-- Register a new pattern
-- @param name string The name of the pattern
-- @param pattern string The raw pattern string
function M.register(name, pattern)
    rawPatterns[name] = pattern
    -- Invalidate caches
    lruCache.data[name] = nil
    weakRefCache[name] = nil
end

-- Ensure a pattern is registered, and if not, register it
-- @param name string The name of the pattern
-- @param pattern string The pattern to register if it doesn't exist
-- @return table The compiled pattern object
function M.ensure(name, pattern)
    if rawPatterns[name] == nil then
        M.register(name, pattern)
    end
    return M.compiled(name)
end

-- Get the raw string of a pattern
-- @param name string The name of the pattern
-- @return string|nil The raw pattern string, or nil if not found
function M.get(name)
    return rawPatterns[name]
end

-- Get the compiled object for a pattern (with caching)
-- @param name string The name of the pattern
-- @return table|nil The compiled pattern object, or nil if not found
function M.compiled(name)
    local rawPattern = rawPatterns[name]
    if not rawPattern then
        return nil
    end

    -- Check LRU cache first
    local compiled = lruCache:get(name)
    if compiled then
        return compiled
    end

    -- Check weak reference cache
    compiled = weakRefCache[name]
    if compiled then
        -- Promote to LRU cache
        lruCache:set(name, compiled)
        return compiled
    end

    -- Compile new pattern
    compiled = compilePattern(rawPattern)

    -- Store in both caches
    lruCache:set(name, compiled)
    weakRefCache[name] = compiled

    -- Optional memory cleanup
    if config.autoCleanup then
        local currentMemoryKB = collectgarbage("count")
        local thresholdKB = config.memoryThresholdMB * 1024
        if currentMemoryKB > thresholdKB then
            collectgarbage("collect")
        end
    end

    return compiled
end

-- A convenience function to match a pattern against a string
-- @param name string The name of the pattern
-- @param text string The string to match against
-- @return any The result of the match, or nil if the pattern doesn't exist
function M.match(name, text)
    local entry = M.compiled(name)
    if not entry then return nil end
    return entry.match(text)
end

-- A convenience function to check if a string contains a pattern
-- @param name string The name of the pattern
-- @param text string The string to check
-- @return boolean true if the string contains the pattern, false otherwise
function M.contains(name, text)
    local entry = M.compiled(name)
    if not entry then return false end
    return entry.contains(text)
end

-- Get all compiled patterns
-- @return table A table containing all compiled pattern objects
function M.all()
    local result = {}
    for name in pairs(rawPatterns) do
        result[name] = M.compiled(name)
    end
    return result
end

-- Clear all caches (useful for testing or memory management)
function M.clearCaches()
    lruCache:clear()
    -- Weak reference cache is automatically cleaned by GC
end

-- Get memory/cache statistics (for debugging)
-- @return table Statistics about cache performance
function M.getStats()
    return {
        cacheSize = lruCache.size,
        maxCacheSize = lruCache.maxSize,
        memoryThresholdMB = config.memoryThresholdMB,
        autoCleanup = config.autoCleanup,
    }
end

return M
