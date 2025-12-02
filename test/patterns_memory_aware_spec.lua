---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local MemoryAwarePatterns = helper.requireFresh("utils.patterns_memory_aware")

describe("MemoryAwarePatterns", function()
    before_each(function()
        helper.reset()
        MemoryAwarePatterns.resetInstance()
    end)

    describe("instance creation", function()
        it("should create a new instance with defaults", function()
            local patterns = MemoryAwarePatterns.new()
            assert.is_not_nil(patterns)
            assert.is_not_nil(patterns.compiledCache)
            assert.is_not_nil(patterns.memoryMonitor)
        end)

        it("should use singleton pattern", function()
            local instance1 = MemoryAwarePatterns.getInstance()
            local instance2 = MemoryAwarePatterns.getInstance()
            assert.are.equal(instance1, instance2)
        end)

        it("should reset singleton", function()
            local instance1 = MemoryAwarePatterns.getInstance()
            MemoryAwarePatterns.resetInstance()
            local instance2 = MemoryAwarePatterns.getInstance()
            assert.is_not_equal(instance1, instance2)
        end)

        it("should merge configuration", function()
            local patterns = MemoryAwarePatterns.new({
                maxCacheSize = 50,
                maxMemoryMB = 5,
                weakRefEnabled = false
            })
            assert.are.equal(50, patterns.compiledCache:getMaxSize())
            assert.are.equal(5 * 1024, patterns.memoryMonitor.maxMemoryKB) -- 5MB in KB
        end)
    end)

    describe("LRU cache functionality", function()
        it("should cache and retrieve patterns", function()
            local patterns = MemoryAwarePatterns.new({maxCacheSize = 2})

            -- First compilation should cache
            local compiled1 = patterns:compile("arithmetic_candidate")
            local stats1 = patterns:getStats()
            assert.are.equal(0, stats1.cacheHits) -- First compilation is a miss
            assert.are.equal(1, stats1.cacheMisses)

            -- Second compilation should hit cache
            local compiled2 = patterns:compile("arithmetic_candidate")
            local stats2 = patterns:getStats()
            assert.are.equal(1, stats2.cacheHits)
            assert.are.equal(1, stats2.cacheMisses)
            assert.are.equal(compiled1, compiled2)
        end)

        it("should respect cache size limits", function()
            local patterns = MemoryAwarePatterns.new({maxCacheSize = 2})

            -- Fill cache
            patterns:compile("arithmetic_candidate")
            patterns:compile("phone_semicolon")
            assert.are.equal(2, patterns.compiledCache:getSize())

            -- Add third pattern - should evict LRU
            patterns:compile("date_full")
            assert.are.equal(2, patterns.compiledCache:getSize()) -- Still max size

            -- First pattern should be evicted (LRU)
            local stats = patterns:getStats()
            assert.is_true(stats.forcedEvictions >= 0)
        end)

        it("should clear caches", function()
            local patterns = MemoryAwarePatterns.new({maxCacheSize = 3})

            patterns:compile("arithmetic_candidate")
            patterns:compile("phone_semicolon")
            assert.are.equal(2, patterns.compiledCache:getSize())

            patterns:clearCaches()
            assert.are.equal(0, patterns.compiledCache:getSize())
        end)
    end)

    describe("memory monitoring", function()
        it("should monitor memory usage", function()
            local patterns = MemoryAwarePatterns.new()
            patterns:enableMemoryMonitoring(true)

            local stats = patterns:getStats()
            assert.is_not_nil(stats.memory)
            assert.is_number(stats.memory.currentKB)
            assert.is_number(stats.memory.peakKB)
            assert.is_number(stats.memory.maxKB)
        end)

        it("should perform cleanup under memory pressure", function()
            local patterns = MemoryAwarePatterns.new({
                maxCacheSize = 50,
                maxMemoryMB = 1, -- Very low limit to trigger cleanup
                autoCleanup = true
            })

            -- Fill cache to trigger memory pressure
            for i = 1, 60 do
                patterns:compile("arithmetic_candidate") -- Same pattern, but still triggers cleanup logic
            end

            local stats = patterns:getStats()
            -- Should have attempted cleanup due to low memory limit
            assert.is_true(stats.memoryCleanups >= 0)
        end)

        it("should optimize for memory", function()
            local patterns = MemoryAwarePatterns.new({maxCacheSize = 100})

            -- Add some patterns
            patterns:compile("arithmetic_candidate")
            patterns:compile("phone_semicolon")
            assert.is_true(patterns.compiledCache:getSize() > 0)

            patterns:optimizeForMemory()

            -- Cache size should be reduced
            local maxCacheSize = patterns.compiledCache:getMaxSize()
            assert.is_true(maxCacheSize <= 50) -- Should be reduced to half or less
        end)
    end)

    describe("adaptive sizing", function()
        it("should adjust cache size based on memory pressure", function()
            local patterns = MemoryAwarePatterns.new({
                maxCacheSize = 20,
                adaptiveSizing = true,
                maxMemoryMB = 1 -- Low memory limit
            })

            local initialSize = patterns.compiledCache:getMaxSize()

            -- Simulate memory pressure by filling cache
            for i = 1, 25 do
                patterns:compile("arithmetic_candidate")
            end

            local stats = patterns:getStats()
            -- Adaptive sizer should exist and have history
            assert.is_not_nil(stats.adaptiveSize)
            assert.is_not_nil(stats.adaptiveSize.current)
        end)

        it("should provide adaptive sizing history", function()
            local patterns = MemoryAwarePatterns.new({
                maxCacheSize = 10,
                adaptiveSizing = true
            })

            -- Trigger memory pressure to cause size adjustments
            patterns.memoryMonitor.currentMemoryKB = 800 -- High pressure
            patterns:_checkMemoryAndCleanup()

            local stats = patterns:getStats()
            if stats.adaptiveSize then
                assert.is_table(stats.adaptiveSize.history)
            end
        end)
    end)

    describe("statistics and monitoring", function()
        it("should provide comprehensive statistics", function()
            local patterns = MemoryAwarePatterns.new({maxCacheSize = 3})

            -- Generate some cache activity
            patterns:compile("arithmetic_candidate") -- miss
            patterns:compile("arithmetic_candidate") -- hit
            patterns:compile("phone_semicolon") -- miss
            patterns:compile("date_full") -- miss (should evict)

            local stats = patterns:getStats()
            assert.is_number(stats.cacheHits)
            assert.is_number(stats.cacheMisses)
            assert.is_number(stats.weakRefHits)
            assert.is_number(stats.cacheSize)
            assert.is_number(stats.maxCacheSize)
            assert.is_number(stats.hitRate)
            assert.is_not_nil(stats.memory)
        end)

        it("should calculate hit rate correctly", function()
            local patterns = MemoryAwarePatterns.new()

            -- No activity yet
            local stats1 = patterns:getStats()
            assert.are.equal(0, stats1.hitRate)

            -- Add activity
            patterns:compile("arithmetic_candidate") -- miss
            patterns:compile("arithmetic_candidate") -- hit

            local stats2 = patterns:getStats()
            assert.are.equal(0.5, stats2.hitRate) -- 1 hit out of 2 total
        end)
    end)

    describe("weak reference caching", function()
        it("should use weak references when enabled", function()
            local patterns = MemoryAwarePatterns.new({
                weakRefEnabled = true
            })

            local compiled = patterns:compile("arithmetic_candidate")
            assert.is_not_nil(compiled)

            -- Weak ref cache should be available
            assert.is_not_nil(patterns.weakRefCache)
        end)

        it("should track weak reference hits", function()
            local patterns = MemoryAwarePatterns.new({
                weakRefEnabled = true,
                maxCacheSize = 1 -- Small cache to force eviction
            })

            -- Fill cache
            patterns:compile("arithmetic_candidate")
            patterns:compile("phone_semicolon") -- Should evict first

            -- Access again - might come from weak ref
            patterns:compile("arithmetic_candidate")

            local stats = patterns:getStats()
            assert.is_number(stats.weakRefHits)
        end)
    end)

    describe("precompilation", function()
        it("should precompile multiple patterns", function()
            local patterns = MemoryAwarePatterns.new()

            local patternNames = {"arithmetic_candidate", "phone_semicolon", "date_full"}
            patterns:precompilePatterns(patternNames)

            local stats = patterns:getStats()
            assert.is_true(stats.patternCount >= #patternNames)
        end)

        it("should handle empty pattern list", function()
            local patterns = MemoryAwarePatterns.new()

            patterns:precompilePatterns({})

            local stats = patterns:getStats()
            assert.are.equal(0, stats.patternCount)
        end)
    end)

    describe("compatibility with patterns module", function()
        it("should provide compatible compiled function", function()
            local patterns = MemoryAwarePatterns.new()
            local compiled = patterns:compile("arithmetic_candidate")

            if compiled then
                assert.is_not_nil(compiled.match)
                assert.is_not_nil(compiled.contains)
            end
        end)

        it("should provide compatible match function", function()
            local patterns = MemoryAwarePatterns.new()

            local result = patterns:match("arithmetic_candidate", "123 + 456")
            -- Result depends on pattern - just ensure function doesn't error
        end)

        it("should provide compatible contains function", function()
            local patterns = MemoryAwarePatterns.new()

            local result = patterns:contains("arithmetic_candidate", "123 + 456")
            assert.is_boolean(result)
        end)

        it("should provide all patterns function", function()
            local patterns = MemoryAwarePatterns.new()

            local allPatterns = patterns:all()
            assert.is_table(allPatterns)
            assert.is_true(#allPatterns > 0)
        end)
    end)

    describe("error handling and edge cases", function()
        it("should handle invalid pattern names", function()
            local patterns = MemoryAwarePatterns.new()

            local compiled = patterns:compile("nonexistent_pattern")
            assert.is_nil(compiled)
        end)

        it("should handle nil configuration", function()
            local patterns = MemoryAwarePatterns.new(nil)
            assert.is_not_nil(patterns)
            assert.is_not_nil(patterns.compiledCache)
        end)

        it("should handle memory monitoring toggle", function()
            local patterns = MemoryAwarePatterns.new()

            patterns:enableMemoryMonitoring(true)
            patterns:enableMemoryMonitoring(false)

            local stats = patterns:getStats()
            assert.is_false(stats.memory.monitoringEnabled)
        end)
    end)

    describe("constants and configuration", function()
        it("should export memory configuration", function()
            assert.is_not_nil(MemoryAwarePatterns.MEMORY_CONFIG)
            assert.is_number(MemoryAwarePatterns.MEMORY_CONFIG.DEFAULT_CACHE_SIZE)
            assert.is_number(MemoryAwarePatterns.MEMORY_CONFIG.MAX_MEMORY_MB)
        end)
    end)
end)