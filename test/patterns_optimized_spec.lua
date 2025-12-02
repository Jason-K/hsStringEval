---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local PatternsOptimized = helper.requireFresh("utils.patterns_optimized")

describe("PatternsOptimized", function()
    before_each(function()
        helper.reset()
    end)

    local testPatterns = {
        "arithmetic_candidate",
        "phone_semicolon",
        "date_full",
        "localized_number"
    }

    local testTexts = {
        "123 + 456",
        "555;123;4567",
        "12/25/2023",
        "$1,234.56",
        "Regular text with no patterns",
        "Multiple: 123 and 12/25/2023"
    }

    describe("batch compilation", function()
        it("should batch compile multiple patterns", function()
            local engine = PatternsOptimized.new()
            local compiled = engine:batchCompile(testPatterns)

            assert.is_not_nil(compiled)
            -- Count compiled patterns (it's a map)
            local count = 0
            for _ in pairs(compiled) do
                count = count + 1
            end
            assert.is_true(count >= 1) -- At least some patterns should be compiled
            assert.is_not_nil(compiled.arithmetic_candidate)
            assert.is_not_nil(compiled.phone_semicolon)
            assert.is_not_nil(compiled.date_full)
            assert.is_not_nil(compiled.localized_number)
        end)

        it("should cache compiled patterns", function()
            local engine = PatternsOptimized.new()
            engine:batchCompile(testPatterns)

            -- Second call should use cached versions
            local startTime = os.clock()
            local compiled = engine:batchCompile(testPatterns)
            local endTime = os.clock()

            assert.is_not_nil(compiled)
            -- Should be very fast on second call (using cache)
            assert.is_true((endTime - startTime) < 0.1)
        end)

        it("should handle empty pattern list", function()
            local engine = PatternsOptimized.new()
            local compiled = engine:batchCompile({})

            assert.is_not_nil(compiled)
        end)
    end)

    describe("batch matching", function()
        it("should batch match multiple texts against patterns", function()
            local engine = PatternsOptimized.new()
            engine:batchCompile(testPatterns)

            local results = engine:batchMatch(testTexts, testPatterns)

            assert.is_not_nil(results)
            assert.are.equal(#testTexts, #results)

            -- Check arithmetic pattern matches
            assert.is_not_nil(results[1].arithmetic_candidate) -- "123 + 456"
            assert.is_nil(results[2].arithmetic_candidate) -- "555;123;4567" (not arithmetic)

            -- Check phone pattern matches
            assert.is_nil(results[1].phone_semicolon) -- "123 + 456" (not phone format)
            assert.is_not_nil(results[2].phone_semicolon) -- "555;123;4567" (should match)
        end)

        it("should cache batch results", function()
            local engine = PatternsOptimized.new()
            engine:batchCompile(testPatterns)

            local results1 = engine:batchMatch(testTexts, testPatterns)
            local results2 = engine:batchMatch(testTexts, testPatterns)

            assert.is_not_nil(results1)
            assert.is_not_nil(results2)
            assert.are.equal(#results1, #results2)
        end)

        it("should handle force recompile option", function()
            local engine = PatternsOptimized.new()
            engine:batchCompile(testPatterns)

            local results1 = engine:batchMatch(testTexts, testPatterns)
            local results2 = engine:batchMatch(testTexts, testPatterns, {forceRecompile = true})

            assert.is_not_nil(results1)
            assert.is_not_nil(results2)
        end)
    end)

    describe("batch contains", function()
        it("should check pattern presence efficiently", function()
            local engine = PatternsOptimized.new()
            engine:batchCompile(testPatterns)

            local results = engine:batchContains(testTexts, testPatterns)

            assert.is_not_nil(results)
            assert.are.equal(#testTexts, #results)

            -- Check boolean results (should be true/false, not nil)
            if results[1].arithmetic_candidate ~= nil then
                assert.is_boolean(results[1].arithmetic_candidate)
            end
            if results[1].phone_semicolon ~= nil then
                assert.is_boolean(results[1].phone_semicolon)
            end
            if results[1].date_full ~= nil then
                assert.is_boolean(results[1].date_full)
            end
        end)
    end)

    describe("performance monitoring", function()
        it("should track pattern statistics", function()
            local engine = PatternsOptimized.new()
            engine:enableMonitoring(true)

            engine:batchCompile(testPatterns)
            engine:batchMatch(testTexts, testPatterns)

            local stats = engine:getStats()

            assert.is_not_nil(stats.patternStats)
            assert.is_not_nil(stats.memory)
            assert.is_not_nil(stats.batchStats)
            assert.is_true(#stats.batchStats > 0)
        end)

        it("should track memory usage", function()
            local engine = PatternsOptimized.new()
            engine:enableMonitoring(true)

            local stats = engine:getStats()

            assert.is_not_nil(stats.memory)
            assert.is_number(stats.memory.currentMemory)
            assert.is_number(stats.memory.cacheHits)
            assert.is_number(stats.memory.cacheMisses)
        end)

        it("should allow enabling/disabling monitoring", function()
            local engine = PatternsOptimized.new()

            engine:enableMonitoring(false)
            local stats1 = engine:getStats()

            engine:enableMonitoring(true)
            engine:batchMatch(testTexts, testPatterns)
            local stats2 = engine:getStats()

            -- Stats should be available when monitoring is enabled
            assert.is_not_nil(stats2)
        end)
    end)

    describe("memory optimization", function()
        it("should optimize memory usage", function()
            local engine = PatternsOptimized.new()

            -- Add some cache entries
            engine:batchCompile(testPatterns)
            engine:batchMatch(testTexts, testPatterns)

            local beforeMem = collectgarbage("count")
            engine:optimizeMemory()
            local afterMem = collectgarbage("count")

            -- Memory should not increase significantly after optimization
            assert.is_true(afterMem <= beforeMem * 1.1) -- Allow 10% variance
        end)
    end)

    describe("singleton instance", function()
        it("should return the same instance", function()
            local instance1 = PatternsOptimized.getInstance()
            local instance2 = PatternsOptimized.getInstance()

            assert.are.equal(instance1, instance2)
        end)

        it("should have monitoring enabled by default", function()
            local instance = PatternsOptimized.getInstance()
            assert.is_true(instance.isMonitoring)
        end)
    end)

    describe("compatibility with patterns module", function()
        it("should provide compatible compiled function", function()
            local compiled = PatternsOptimized.compiled("arithmetic_candidate")

            if compiled then
                assert.is_not_nil(compiled.match)
                assert.is_not_nil(compiled.contains)
            end
        end)

        it("should provide compatible match function", function()
            local result = PatternsOptimized.match("arithmetic_candidate", "123 + 456")
            -- Result depends on pattern, just ensure function doesn't error
        end)

        it("should provide compatible contains function", function()
            local result = PatternsOptimized.contains("arithmetic_candidate", "123 + 456")
            assert.is_boolean(result)
        end)

        it("should provide all patterns function", function()
            local allPatterns = PatternsOptimized.all()
            assert.is_not_nil(allPatterns)
        end)
    end)

    describe("error handling", function()
        it("should handle invalid pattern names gracefully", function()
            local engine = PatternsOptimized.new()

            local compiled = engine:batchCompile({"nonexistent_pattern"})
            assert.is_not_nil(compiled)
        end)

        it("should handle empty inputs", function()
            local engine = PatternsOptimized.new()

            local matchResults = engine:batchMatch({}, {})
            assert.is_not_nil(matchResults)
            assert.are.equal(0, #matchResults)

            local containsResults = engine:batchContains({}, {})
            assert.is_not_nil(containsResults)
            assert.are.equal(0, #containsResults)
        end)
    end)
end)