describe("seed_strategies", function()
    local SeedStrategies

    setup(function()
        require("src.utils.seed_strategies")
        SeedStrategies = require("src.utils.seed_strategies")
    end)

    describe("date_range_strategy", function()
        local Date = require("src.formatters.date")
        local patterns = require("src.utils.patterns").all()

        it("extracts date range from string with prefix", function()
            local context = { patterns = patterns }
            local input = "Meeting: 01/15/2025 - 01/20/2025"
            local prefix, seed = SeedStrategies.date_range_strategy(input, context)
            assert.are_equal("Meeting: ", prefix)
            assert.are_equal("01/15/2025 - 01/20/2025", seed)
        end)

        it("returns nil for non-date strings", function()
            local context = { patterns = patterns }
            local input = "hello world"
            local result = SeedStrategies.date_range_strategy(input, context)
            assert.is_nil(result)
        end)
    end)

    describe("arithmetic_strategy", function()
        it("extracts pure arithmetic", function()
            local input = "10 + 5"
            local prefix, seed = SeedStrategies.arithmetic_strategy(input)
            assert.are_equal("", prefix)
            assert.are_equal("10 + 5", seed)
        end)

        it("extracts arithmetic after prefix", function()
            local input = "Total: 100 * 2"
            local prefix, seed = SeedStrategies.arithmetic_strategy(input)
            assert.are_equal("Total: ", prefix)
            assert.are_equal("100 * 2", seed)
        end)

        it("returns nil for non-arithmetic", function()
            local input = "hello world"
            local result = SeedStrategies.arithmetic_strategy(input)
            assert.is_nil(result)
        end)
    end)

    describe("separator_strategy", function()
        it("extracts after equals sign", function()
            local input = "result = 42"
            local prefix, seed = SeedStrategies.separator_strategy(input)
            assert.are_equal("result = ", prefix)
            assert.are_equal("42", seed)
        end)

        it("extracts after colon", function()
            local input = "Answer: 42"
            local prefix, seed = SeedStrategies.separator_strategy(input)
            assert.are_equal("Answer: ", prefix)
            assert.are_equal("42", seed)
        end)

        it("returns nil when no separator", function()
            local input = "hello world"
            local result = SeedStrategies.separator_strategy(input)
            assert.is_nil(result)
        end)
    end)

    describe("whitespace_strategy", function()
        it("splits at last whitespace", function()
            local input = "hello world"
            local prefix, seed = SeedStrategies.whitespace_strategy(input)
            assert.are_equal("hello ", prefix)
            assert.are_equal("world", seed)
        end)

        it("returns nil for single word", function()
            local input = "hello"
            local result = SeedStrategies.whitespace_strategy(input)
            assert.is_nil(result)
        end)
    end)

    describe("fallback_strategy", function()
        it("returns entire string as seed", function()
            local input = "hello"
            local prefix, seed = SeedStrategies.fallback_strategy(input)
            assert.are_equal("", prefix)
            assert.are_equal("hello", seed)
        end)
    end)

    describe("extractSeed", function()
        it("tries strategies in order and returns first match", function()
            local input = "Total: 10+5"
            local prefix, seed = SeedStrategies.extractSeed(input, {})
            assert.are_equal("Total: ", prefix)
            assert.are_equal("10+5", seed)
        end)

        it("falls back to whitespace strategy when others fail", function()
            local input = "hello world"
            local prefix, seed = SeedStrategies.extractSeed(input, {})
            assert.are_equal("hello ", prefix)
            assert.are_equal("world", seed)
        end)

        it("falls back to entire string for single word", function()
            local input = "hello"
            local prefix, seed = SeedStrategies.extractSeed(input, {})
            assert.are_equal("", prefix)
            assert.are_equal("hello", seed)
        end)
    end)
end)
