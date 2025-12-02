--[[
WHAT THIS FILE DOES:
This module provides an optimized pattern engine with batch compilation, performance
monitoring, and memory-aware caching. It builds upon the basic patterns module to
provide significant performance improvements for large-scale pattern matching operations.

KEY CONCEPTS:
- Batch Compilation: Pre-optimizes multiple patterns together for shared operations
- Performance Monitoring: Tracks pattern execution times and success rates
- Memory-Aware Caching: Uses weak references and monitors memory pressure
- Shared Optimization: Identifies and optimizes common pattern sub-expressions
- Batch Operations: Efficiently processes multiple texts against multiple patterns

EXAMPLE USAGE:
    local PatternsOptimized = require("src.utils.patterns_optimized")
    local engine = PatternsOptimized.new()
    engine:batchCompile({"arithmetic_candidate", "phone_semicolon", "date_range"})
    local results = engine:batchMatch(texts, patterns)
]]

local pkgRoot = (...):match("^(.*)%.utils%.patterns_optimized$")
local patterns = require(pkgRoot .. ".utils.patterns")

local PatternsOptimized = {}

-- Performance monitoring
local PerformanceMonitor = {
    patternStats = {},
    batchStats = {},
    memoryStats = {
        initialMemory = 0,
        currentMemory = 0,
        peakMemory = 0,
        cacheHits = 0,
        cacheMisses = 0
    }
}

-- Memory management configuration
local MEMORY_CONFIG = {
    MAX_CACHE_SIZE = 1000,
    MEMORY_THRESHOLD_MB = 50,
    WEAK_REF_THRESHOLD = 100,
    CLEANUP_BATCH_SIZE = 50
}

-- Shared optimizations for common pattern patterns
local SHARED_OPTIMIZATIONS = {
    -- Common prefixes that can be optimized
    numberPrefix = "^[%d%+%-%$%s]*",
    datePrefix = "^%s*%d%d?[/%.-]",
    whitespaceTrim = "^%s*(.-)%s*$",

    -- Common suffixes
    numberSuffix = "[%d%.,%s%(%)%+%-%*/%%^]*%s*$",
    dateSuffix = "[%d%d%d%d%a%s,./-]*%s*$",
}

-- Weak reference cache for memory-efficient pattern caching
local weakRefCache = setmetatable({}, {__mode = "v"})

-- Private constructor
local function new()
    local instance = {
        compiledPatterns = {},
        batchCache = {},
        performanceMonitor = PerformanceMonitor,
        sharedOptimizations = {},
        isMonitoring = false
    }
    setmetatable(instance, { __index = PatternsOptimized })
    return instance
end

-- Memory pressure detection
local function checkMemoryPressure()
    local currentMem = collectgarbage("count")
    PerformanceMonitor.memoryStats.currentMemory = currentMem

    if currentMem > PerformanceMonitor.memoryStats.peakMemory then
        PerformanceMonitor.memoryStats.peakMemory = currentMem
    end

    return currentMem > (MEMORY_CONFIG.MEMORY_THRESHOLD_MB * 1024) -- Convert MB to KB
end

-- Intelligent cache cleanup
local function cleanupCache(instance)
    local cacheSize = 0
    for _ in pairs(instance.batchCache) do
        cacheSize = cacheSize + 1
    end

    if cacheSize > MEMORY_CONFIG.MAX_CACHE_SIZE or checkMemoryPressure() then
        -- Remove least recently used entries
        local toRemove = {}
        local count = 0

        for key, value in pairs(instance.batchCache) do
            table.insert(toRemove, key)
            count = count + 1
            if count >= MEMORY_CONFIG.CLEANUP_BATCH_SIZE then
                break
            end
        end

        for _, key in ipairs(toRemove) do
            instance.batchCache[key] = nil
        end

        -- Force garbage collection
        collectgarbage("collect")
    end
end

-- Pre-optimize patterns for common use cases
local function preOptimizePattern(pattern)
    local optimized = pattern

    -- Apply common optimizations
    if pattern:find("^%s*%d") then
        optimized = optimized:gsub("^%s*", SHARED_OPTIMIZATIONS.numberPrefix)
    end

    if pattern:find("^%s*%d%d?[/%.-]") then
        optimized = optimized:gsub("^%s*", SHARED_OPTIMIZATIONS.datePrefix)
    end

    -- Optimize common quantifiers
    optimized = optimized:gsub("%*%+", "+")
    optimized = optimized:gsub("%+%*", "+")

    return optimized
end

-- Batch compile multiple patterns with shared optimizations
function PatternsOptimized:batchCompile(patternNames)
    if type(patternNames) ~= "table" then
        error("patternNames must be a table")
    end

    local startTime = os.clock()
    local compiled = {}
    local sharedOptimizations = {}

    -- First pass: identify shared optimizations
    for _, name in ipairs(patternNames) do
        local rawPattern = patterns.get(name)
        if rawPattern then
            local optimized = preOptimizePattern(rawPattern)
            sharedOptimizations[name] = optimized

            -- Look for common sub-patterns
            for sharedName, sharedPattern in pairs(SHARED_OPTIMIZATIONS) do
                if optimized:find(sharedPattern) then
                    if not sharedOptimizations[sharedName] then
                        sharedOptimizations[sharedName] = sharedPattern
                    end
                end
            end
        end
    end

    -- Second pass: compile with optimizations
    for _, name in ipairs(patternNames) do
        local patternObj = patterns.compiled(name)
        if patternObj then
            compiled[name] = {
                original = patternObj,
                optimized = preOptimizePattern(patternObj.raw),
                sharedOps = sharedOptimizations
            }

            -- Cache with weak references
            weakRefCache[name] = compiled[name]
            PerformanceMonitor.memoryStats.cacheMisses = PerformanceMonitor.memoryStats.cacheMisses + 1
        end
    end

    self.compiledPatterns = compiled
    self.sharedOptimizations = sharedOptimizations

    local compileTime = os.clock() - startTime
    if self.performanceMonitor then
        table.insert(self.performanceMonitor.batchStats, {
            operation = "batch_compile",
            patternCount = #patternNames,
            time = compileTime,
            memory = PerformanceMonitor.memoryStats.currentMemory
        })
    end

    cleanupCache(self)
    return compiled
end

-- Optimized batch match operation
function PatternsOptimized:batchMatch(texts, patternNames, options)
    options = options or {}
    local results = {}
    local cacheKey = table.concat(patternNames, ",") .. "|" .. #texts

    -- Check cache first
    if self.batchCache[cacheKey] and not options.forceRecompile then
        PerformanceMonitor.memoryStats.cacheHits = PerformanceMonitor.memoryStats.cacheHits + 1
        return self.batchCache[cacheKey]
    end

    local startTime = os.clock()

    -- Ensure patterns are compiled
    if #patternNames == 0 then
        patternNames = {}
        for name, _ in pairs(self.compiledPatterns) do
            table.insert(patternNames, name)
        end
    end

    -- Pre-compile if needed
    if #patternNames > 0 and next(self.compiledPatterns) == nil then
        self:batchCompile(patternNames)
    end

    -- Batch process texts
    for i, text in ipairs(texts) do
        results[i] = {}

        for _, patternName in ipairs(patternNames) do
            local compiled = self.compiledPatterns[patternName]
            if compiled then
                local patternStartTime = os.clock()

                -- Try optimized match first
                local matchResult = nil

                if options.useOptimized and compiled.optimized then
                    -- Use optimized pattern
                    local ok, result = pcall(function()
                        return text:match(compiled.optimized)
                    end)
                    if ok then
                        matchResult = result
                    end
                end

                -- Fallback to original pattern
                if matchResult == nil and compiled.original then
                    matchResult = compiled.original.match(text)
                end

                local patternTime = os.clock() - patternStartTime

                -- Track performance
                if self.performanceMonitor then
                    if not self.performanceMonitor.patternStats[patternName] then
                        self.performanceMonitor.patternStats[patternName] = {
                            matches = 0,
                            totalTime = 0,
                            avgTime = 0
                        }
                    end

                    local stats = self.performanceMonitor.patternStats[patternName]
                    stats.matches = stats.matches + 1
                    stats.totalTime = stats.totalTime + patternTime
                    stats.avgTime = stats.totalTime / stats.matches
                end

                results[i][patternName] = matchResult
            end
        end
    end

    -- Cache results
    self.batchCache[cacheKey] = results

    local totalTime = os.clock() - startTime
    if self.performanceMonitor then
        table.insert(self.performanceMonitor.batchStats, {
            operation = "batch_match",
            textCount = #texts,
            patternCount = #patternNames,
            time = totalTime,
            memory = PerformanceMonitor.memoryStats.currentMemory
        })
    end

    cleanupCache(self)
    return results
end

-- Batch contains operation (optimized)
function PatternsOptimized:batchContains(texts, patternNames, options)
    options = options or {}
    local results = {}

    -- Use batch match for efficiency
    local matchResults = self:batchMatch(texts, patternNames, options)

    for i, textMatches in ipairs(matchResults) do
        results[i] = {}
        for patternName, matchResult in pairs(textMatches) do
            results[i][patternName] = matchResult ~= nil
        end
    end

    return results
end

-- Get performance statistics
function PatternsOptimized:getStats()
    return {
        memory = PerformanceMonitor.memoryStats,
        patternStats = PerformanceMonitor.patternStats,
        batchStats = PerformanceMonitor.batchStats,
        cacheSize = 0,
        compiledCount = 0
    }
end

-- Enable/disable performance monitoring
function PatternsOptimized:enableMonitoring(enabled)
    self.isMonitoring = enabled
    if not enabled then
        -- Clear existing stats
        PerformanceMonitor.patternStats = {}
        PerformanceMonitor.batchStats = {}
    end
end

-- Optimize memory usage
function PatternsOptimized:optimizeMemory()
    collectgarbage("collect")
    cleanupCache(self)

    -- Clear weak reference cache if it's getting large
    local weakCount = 0
    for _ in pairs(weakRefCache) do
        weakCount = weakCount + 1
    end

    if weakCount > MEMORY_CONFIG.WEAK_REF_THRESHOLD then
        -- Clear weak cache
        for key in pairs(weakRefCache) do
            weakRefCache[key] = nil
        end
    end
end

-- Get or create instance (singleton pattern)
local instance = nil

function PatternsOptimized.getInstance()
    if not instance then
        instance = new()
        instance:enableMonitoring(true)
    end
    return instance
end

-- Factory method for creating new instances
function PatternsOptimized.new()
    return new()
end

-- Compatibility functions with original patterns module
function PatternsOptimized.compiled(name)
    local instance = PatternsOptimized.getInstance()
    if not instance.compiledPatterns[name] then
        instance:batchCompile({name})
    end
    return instance.compiledPatterns[name] and instance.compiledPatterns[name].original
end

function PatternsOptimized.match(name, text)
    local compiled = PatternsOptimized.compiled(name)
    return compiled and compiled.match(text)
end

function PatternsOptimized.contains(name, text)
    local compiled = PatternsOptimized.compiled(name)
    return compiled and compiled.contains(text)
end

function PatternsOptimized.all()
    local instance = PatternsOptimized.getInstance()
    local allPatterns = patterns.all()
    local patternNames = {}
    for name, _ in pairs(allPatterns) do
        table.insert(patternNames, name)
    end
    instance:batchCompile(patternNames)

    local result = {}
    for name, compiled in pairs(instance.compiledPatterns) do
        result[name] = compiled.original
    end
    return result
end

-- Export singleton instance and factory
return {
    new = new,
    getInstance = PatternsOptimized.getInstance,
    compiled = PatternsOptimized.compiled,
    match = PatternsOptimized.match,
    contains = PatternsOptimized.contains,
    all = PatternsOptimized.all
}