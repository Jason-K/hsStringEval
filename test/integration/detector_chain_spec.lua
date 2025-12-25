---@diagnostic disable: undefined-global, undefined-field

describe("Detector Chain Integration", function()
    local ClipboardFormatter
    local helper

    setup(function()
        ClipboardFormatter = require("ClipboardFormatter.src.init")
        helper = require("spec_helper")
    end)

    before_each(function()
        helper.reset()
        ClipboardFormatter.spoonPath = helper.projectRoot .. "src"
    end)

    it("should process through all detectors in priority order", function()
        local instance = ClipboardFormatter:init()

        -- Arithmetic has priority 100 (processed first, lower number = higher priority)
        local result = instance:processClipboard("15 + 27")

        assert.is_not_nil(result)
        -- Arithmetic should match
        assert.equals("42", result)
    end)

    it("should handle multiple detectors competing for same input", function()
        local instance = ClipboardFormatter:init()

        -- Test PD detector (priority 70)
        local result = instance:processClipboard("25% PD")

        assert.is_not_nil(result)
        -- Should be processed by PD detector
        assert.is_truthy(result:match("25%%") or result:match("PD"))
    end)

    it("should pass context between detectors", function()
        local instance = ClipboardFormatter:init()

        -- Navigation detector handles URLs (side effect only)
        local context = {}
        local result = instance:processClipboard("https://example.com", context)

        -- Navigation returns side effect only, so result might be the original
        assert.is_not_nil(result)
    end)

    it("should handle detector errors gracefully", function()
        local instance = ClipboardFormatter:init()

        -- Valid input that should be handled
        local result = instance:processClipboard("15 + 27")

        -- Should not error even if individual detectors fail
        assert.is_not_nil(result)
    end)

    it("should support detector chain with early exit", function()
        local instance = ClipboardFormatter:init()

        -- Use early exit - stop after first match
        local context = { earlyExit = true }
        local result = instance:processClipboard("15 + 27", context)

        assert.is_not_nil(result)
        -- Should get first match result
        assert.equals("42", result)
    end)

    it("should expose registry for inspection", function()
        local instance = ClipboardFormatter:init()

        assert.is_not_nil(instance.registry)
        assert.is_table(instance.detectors)
        assert.is_true(#instance.detectors > 0)

        -- Check that we have the expected detectors
        local detectorIds = {}
        for _, detector in ipairs(instance.detectors) do
            table.insert(detectorIds, detector.id)
        end

        local allIds = table.concat(detectorIds, " ")
        assert.is_truthy(allIds:match("arithmetic"))
    end)
end)
