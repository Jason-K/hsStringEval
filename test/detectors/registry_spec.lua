---@diagnostic disable: undefined-global, undefined-field

describe("Detector Registry", function()
    local registry
    local helper

    setup(function()
        registry = require("ClipboardFormatter.src.detectors.registry")
        helper = require("spec_helper")
    end)

    before_each(function()
        helper.reset()
        -- Create a fresh registry for each test
        registry = registry.new()
    end)

    it("should process all detectors by default", function()
        local callCount = { first = 0, second = 0 }

        local detector1 = {
            id = "first",
            priority = 100,
            match = function(text, context)
                callCount.first = callCount.first + 1
                return nil  -- No match
            end
        }

        local detector2 = {
            id = "second",
            priority = 50,
            match = function(text, context)
                callCount.second = callCount.second + 1
                return "matched"
            end
        }

        registry:register(detector1)
        registry:register(detector2)

        local result = registry:process("test", {})

        assert.equals("matched", result)
        assert.equals(1, callCount.first)
        assert.equals(1, callCount.second)
    end)

    it("should stop processing after first match when earlyExit is true", function()
        local callCount = { first = 0, second = 0 }

        local detector1 = {
            id = "first",
            priority = 50,  -- Higher priority (lower number = higher priority)
            match = function(text, context)
                callCount.first = callCount.first + 1
                return "first_match"
            end
        }

        local detector2 = {
            id = "second",
            priority = 100,  -- Lower priority
            match = function(text, context)
                callCount.second = callCount.second + 1
                return "second_match"
            end
        }

        registry:register(detector1)
        registry:register(detector2)

        local result = registry:process("test", { earlyExit = true })

        assert.equals("first_match", result)
        assert.equals(1, callCount.first)
        assert.equals(0, callCount.second)  -- Should not be called
    end)

    it("should continue processing if first detector doesn't match even with earlyExit", function()
        local callCount = { first = 0, second = 0 }

        local detector1 = {
            id = "first",
            priority = 50,  -- Higher priority (lower number = higher priority)
            match = function(text, context)
                callCount.first = callCount.first + 1
                return nil  -- No match
            end
        }

        local detector2 = {
            id = "second",
            priority = 100,  -- Lower priority
            match = function(text, context)
                callCount.second = callCount.second + 1
                return "matched"
            end
        }

        registry:register(detector1)
        registry:register(detector2)

        local result = registry:process("test", { earlyExit = true })

        assert.equals("matched", result)
        assert.equals(1, callCount.first)
        assert.equals(1, callCount.second)
    end)

    it("should register detectors and sort by priority", function()
        local detector1 = { id = "low", priority = 100 }
        local detector2 = { id = "high", priority = 50 }
        local detector3 = { id = "medium", priority = 75 }

        registry:register(detector1)
        registry:register(detector2)
        registry:register(detector3)

        -- Should be sorted by priority (lower number = higher priority)
        assert.equals("high", registry.detectors[1].id)
        assert.equals("medium", registry.detectors[2].id)
        assert.equals("low", registry.detectors[3].id)
    end)

    it("should handle detector errors gracefully", function()
        local errorDetector = {
            id = "error",
            priority = 100,
            match = function(text, context)
                error("Intentional error")
            end
        }

        local okDetector = {
            id = "ok",
            priority = 50,
            match = function(text, context)
                return "ok_result"
            end
        }

        registry:register(errorDetector)
        registry:register(okDetector)

        local result = registry:process("test", {})

        -- Should continue despite error and return ok detector result
        assert.equals("ok_result", result)
    end)
end)
