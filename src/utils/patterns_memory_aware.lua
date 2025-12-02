--[[
WHAT THIS FILE DOES:
This module provides memory-aware caching for pattern operations with automatic
garbage collection, memory pressure monitoring, and intelligent cache eviction.
It builds upon the patterns module to provide efficient memory management for
long-running sessions with significant resource optimization.

KEY CONCEPTS:
- Weak References: Uses weak tables for automatic garbage collection
- Memory Pressure Monitoring: Tracks memory usage and triggers cleanup
- Intelligent Eviction: LRU-based cache eviction with size limits
- Adaptive Sizing: Dynamically adjusts cache size based on available memory
- Resource Monitoring: Tracks cache hit rates and memory efficiency

EXAMPLE USAGE:
    local MemoryAwarePatterns = require("src.utils.patterns_memory_aware")
    local patterns = MemoryAwarePatterns.new()
    patterns:enableMemoryMonitoring(true)
    local compiled = patterns:compile("arithmetic_candidate")
]]

local pkgRoot = (...):match("^(.*)%.utils%.patterns_memory_aware$")
local patterns = require(pkgRoot .. ".utils.patterns")
local hsUtils = require(pkgRoot .. ".utils.hammerspoon")

local MemoryAwarePatterns = {}

-- Memory management configuration
local MEMORY_CONFIG = {
    DEFAULT_CACHE_SIZE = 100,
    MAX_MEMORY_MB = 10, -- Maximum cache memory usage in MB
    CLEANUP_THRESHOLD = 0.7, -- Trigger cleanup at 70% memory usage
    EVICTION_BATCH_SIZE = 20, -- Number of items to evict at once
    MONITORING_INTERVAL_MS = 5000, -- Check memory every 5 seconds
    WEAK_REF_ENABLED = true, -- Use weak references for automatic GC
    ADAPTIVE_SIZING = true, -- Dynamically adjust cache size
}

-- LRU cache implementation
local LRUCache = {}

function LRUCache.new(maxSize)
    local instance = {
        maxSize = maxSize or MEMORY_CONFIG.DEFAULT_CACHE_SIZE,
        data = {},
        accessOrder = {},
        size = 0
    }
    setmetatable(instance, { __index = LRUCache })
    return instance
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

function LRUCache:remove(key)
    if self.data[key] then
        self.data[key] = nil
        self:_removeFromOrder(key)
        self.size = self.size - 1
    end
end

function LRUCache:clear()
    self.data = {}
    self.accessOrder = {}
    self.size = 0
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

function LRUCache:getSize()
    return self.size
end

function LRUCache:getMaxSize()
    return self.maxSize
end

function LRUCache:setMaxSize(newSize)
    self.maxSize = newSize
    -- Evict excess entries if necessary
    while self.size > self.maxSize do
        self:_evictLRU()
    end
end

-- Memory pressure detector
local MemoryMonitor = {}

function MemoryMonitor.new(config)
    local instance = {
        config = config or {},
        currentMemoryKB = 0,
        peakMemoryKB = 0,
        lastCheckTime = 0,
        checkIntervalMs = MEMORY_CONFIG.MONITORING_INTERVAL_MS,
        alertThreshold = MEMORY_CONFIG.CLEANUP_THRESHOLD,
        maxMemoryKB = (config.maxMemoryMB or MEMORY_CONFIG.MAX_MEMORY_MB) * 1024,
        monitoringEnabled = false,
        lastCleanupTime = 0,
        cleanupCount = 0
    }
    setmetatable(instance, { __index = MemoryMonitor })
    return instance
end

function MemoryMonitor:checkMemory()
    local currentMemory = collectgarbage("count")
    self.currentMemoryKB = currentMemory

    if currentMemory > self.peakMemoryKB then
        self.peakMemoryKB = currentMemory
    end

    local memoryPressure = currentMemory / self.maxMemoryKB
    return {
        currentKB = currentMemory,
        peakKB = self.peakMemoryKB,
        maxKB = self.maxMemoryKB,
        pressureRatio = memoryPressure,
        needsCleanup = memoryPressure > self.alertThreshold
    }
end

function MemoryMonitor:enableMonitoring(enabled)
    self.monitoringEnabled = enabled
end

function MemoryMonitor:recordCleanup()
    self.lastCleanupTime = os.time()
    self.cleanupCount = self.cleanupCount + 1
end

function MemoryMonitor:getStats()
    return {
        currentKB = self.currentMemoryKB,
        peakKB = self.peakMemoryKB,
        maxKB = self.maxMemoryKB,
        pressureRatio = self.currentMemoryKB / self.maxMemoryKB,
        monitoringEnabled = self.monitoringEnabled,
        cleanupCount = self.cleanupCount,
        lastCleanupTime = self.lastCleanupTime
    }
end

-- Adaptive cache sizing
local AdaptiveSizer = {}

function AdaptiveSizer.new(baseSize, maxSize, minSize)
    baseSize = baseSize or MEMORY_CONFIG.DEFAULT_CACHE_SIZE
    local instance = {
        baseSize = baseSize,
        maxSize = maxSize or baseSize * 2,
        minSize = minSize or math.floor(baseSize / 2),
        currentSize = baseSize,
        adjustmentHistory = {},
        lastAdjustmentTime = 0
    }
    setmetatable(instance, { __index = AdaptiveSizer })
    return instance
end

function AdaptiveSizer:adjustSize(memoryStats, cacheStats)
    local now = os.time()

    -- Don't adjust too frequently (at least 30 seconds apart)
    if now - self.lastAdjustmentTime < 30 then
        return self.currentSize
    end

    local pressure = memoryStats.pressureRatio
    local hitRate = cacheStats.hitRate or 0
    local newSize = self.currentSize

    -- If memory pressure is high, reduce cache size
    if pressure > 0.8 then
        newSize = math.max(self.minSize, math.floor(self.currentSize * 0.7))
    -- If memory pressure is low and hit rate is poor, increase cache size
    elseif pressure < 0.5 and hitRate < 0.8 then
        newSize = math.min(self.maxSize, math.floor(self.currentSize * 1.2))
    -- If hit rate is excellent and memory pressure is moderate, increase slightly
    elseif pressure < 0.6 and hitRate > 0.9 then
        newSize = math.min(self.maxSize, math.floor(self.currentSize * 1.1))
    end

    if newSize ~= self.currentSize then
        table.insert(self.adjustmentHistory, {
            from = self.currentSize,
            to = newSize,
            timestamp = now,
            pressure = pressure,
            hitRate = hitRate
        })

        self.currentSize = newSize
        self.lastAdjustmentTime = now
    end

    return self.currentSize
end

function AdaptiveSizer:getHistory()
    return self.adjustmentHistory
end

-- Main MemoryAwarePatterns class
local function new(config)
    config = config or {}

    local instance = {
        -- Caching systems
        compiledCache = LRUCache.new(config.maxCacheSize),
        weakRefCache = setmetatable({}, {__mode = "v"}),

        -- Memory management
        memoryMonitor = MemoryMonitor.new(config),
        adaptiveSizer = nil,

        -- Configuration
        config = {
            maxCacheSize = config.maxCacheSize or MEMORY_CONFIG.DEFAULT_CACHE_SIZE,
            maxMemoryMB = config.maxMemoryMB or MEMORY_CONFIG.MAX_MEMORY_MB,
            weakRefEnabled = config.weakRefEnabled ~= false,
            adaptiveSizing = config.adaptiveSizing ~= false,
            autoCleanup = config.autoCleanup ~= false
        },

        -- Statistics
        stats = {
            cacheHits = 0,
            cacheMisses = 0,
            weakRefHits = 0,
            forcedEvictions = 0,
            memoryCleanups = 0,
            patternCount = 0,
            totalMemorySavedKB = 0
        }
    }

    -- Initialize adaptive sizer if enabled
    if instance.config.adaptiveSizing then
        instance.adaptiveSizer = AdaptiveSizer.new(
            config.maxCacheSize,
            (config.maxCacheSize or MEMORY_CONFIG.DEFAULT_CACHE_SIZE) * 2,
            math.floor((config.maxCacheSize or MEMORY_CONFIG.DEFAULT_CACHE_SIZE) / 2)
        )
    end

    setmetatable(instance, { __index = MemoryAwarePatterns })
    return instance
end

-- Enhanced pattern compilation with memory awareness
function MemoryAwarePatterns:compile(patternName)
    -- Check LRU cache first
    local compiled = self.compiledCache:get(patternName)
    if compiled then
        self.stats.cacheHits = self.stats.cacheHits + 1
        return compiled
    end

    -- Check weak reference cache
    if self.config.weakRefEnabled then
        compiled = self.weakRefCache[patternName]
        if compiled then
            self.stats.weakRefHits = self.stats.weakRefHits + 1
            -- Promote to LRU cache
            self.compiledCache:set(patternName, compiled)
            return compiled
        end
    end

    -- Compile new pattern
    compiled = patterns.compiled(patternName)
    if compiled then
        self.stats.cacheMisses = self.stats.cacheMisses + 1
        self.stats.patternCount = self.stats.patternCount + 1

        -- Store in both caches
        self.compiledCache:set(patternName, compiled)
        if self.config.weakRefEnabled then
            self.weakRefCache[patternName] = compiled
        end

        -- Check memory pressure and cleanup if needed
        if self.config.autoCleanup then
            self:_checkMemoryAndCleanup()
        end
    end

    return compiled
end

-- Memory pressure check and cleanup
function MemoryAwarePatterns:_checkMemoryAndCleanup()
    local memoryStats = self.memoryMonitor:checkMemory()

    if memoryStats.needsCleanup then
        self:_performCleanup(memoryStats)
    end

    -- Adaptive sizing if enabled
    if self.adaptiveSizer then
        local cacheStats = {
            hitRate = self:_getHitRate()
        }
        local newSize = self.adaptiveSizer:adjustSize(memoryStats, cacheStats)
        if newSize and self.compiledCache then
            self.compiledCache:setMaxSize(newSize)
        end
    end
end

function MemoryAwarePatterns:_performCleanup(memoryStats)
    -- Force garbage collection
    collectgarbage("collect")

    -- Evict old cache entries if needed
    if memoryStats.pressureRatio > 0.9 then
        -- Emergency cleanup - evict 50% of cache
        local targetSize = math.floor(self.compiledCache:getMaxSize() * 0.5)
        while self.compiledCache:getSize() > targetSize do
            self.compiledCache:_evictLRU()
            self.stats.forcedEvictions = self.stats.forcedEvictions + 1
        end
    end

    self.memoryMonitor:recordCleanup()
    self.stats.memoryCleanups = self.stats.memoryCleanups + 1
end

function MemoryAwarePatterns:_getHitRate()
    local total = self.stats.cacheHits + self.stats.cacheMisses + self.stats.weakRefHits
    if total == 0 then return 0 end
    return (self.stats.cacheHits + self.stats.weakRefHits) / total
end

-- Public API methods
function MemoryAwarePatterns:enableMemoryMonitoring(enabled)
    self.memoryMonitor:enableMonitoring(enabled)
end

function MemoryAwarePatterns:enableAutoCleanup(enabled)
    self.config.autoCleanup = enabled
end

function MemoryAwarePatterns:clearCaches()
    self.compiledCache:clear()
    -- Weak reference cache is automatically cleaned by GC
end

function MemoryAwarePatterns:precompilePatterns(patternNames)
    for _, name in ipairs(patternNames) do
        self:compile(name)
    end
end

function MemoryAwarePatterns:getStats()
    local memoryStats = self.memoryMonitor:getStats()
    return {
        cacheHits = self.stats.cacheHits,
        cacheMisses = self.stats.cacheMisses,
        weakRefHits = self.stats.weakRefHits,
        forcedEvictions = self.stats.forcedEvictions,
        memoryCleanups = self.stats.memoryCleanups,
        patternCount = self.stats.patternCount,
        cacheSize = self.compiledCache:getSize(),
        maxCacheSize = self.compiledCache:getMaxSize(),
        hitRate = self:_getHitRate(),
        memory = memoryStats,
        adaptiveSize = self.adaptiveSizer and {
            current = self.adaptiveSizer.currentSize,
            history = self.adaptiveSizer:getHistory()
        } or nil
    }
end

function MemoryAwarePatterns:optimizeForMemory()
    -- Aggressive memory optimization
    self:clearCaches()
    collectgarbage("collect")

    if self.compiledCache:getMaxSize() > MEMORY_CONFIG.DEFAULT_CACHE_SIZE / 2 then
        self.compiledCache:setMaxSize(math.floor(MEMORY_CONFIG.DEFAULT_CACHE_SIZE / 2))
    end
end

-- Compatibility with original patterns module
function MemoryAwarePatterns:match(name, text)
    local compiled = self:compile(name)
    return compiled and compiled.match(text)
end

function MemoryAwarePatterns:contains(name, text)
    local compiled = self:compile(name)
    return compiled and compiled.contains(text)
end

function MemoryAwarePatterns:all()
    -- Get all available pattern names
    local allPatterns = patterns.all()
    local patternNames = {}
    for name, _ in pairs(allPatterns) do
        table.insert(patternNames, name)
    end
    return patternNames
end

-- Factory methods
local globalInstance = nil

function MemoryAwarePatterns.getInstance(config)
    if not globalInstance then
        globalInstance = new(config)
    end
    return globalInstance
end

function MemoryAwarePatterns.resetInstance()
    if globalInstance then
        globalInstance:clearCaches()
    end
    globalInstance = nil
end

return {
    new = new,
    getInstance = MemoryAwarePatterns.getInstance,
    resetInstance = MemoryAwarePatterns.resetInstance,
    MEMORY_CONFIG = MEMORY_CONFIG
}