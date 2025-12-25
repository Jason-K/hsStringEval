---@diagnostic disable: undefined-global, undefined-field

describe("Selection Formatting Integration", function()
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

    it("should format selected arithmetic expression", function()
        local instance = ClipboardFormatter:init()
        helper.setSelectionText("15 + 27")

        -- formatSelection doesn't return a value, it operates via side effects
        -- We test processClipboard directly instead
        local result = instance:processClipboard("15 + 27")

        assert.is_not_nil(result)
        assert.equals("42", result)
    end)

    it("should format selected currency expression", function()
        local instance = ClipboardFormatter:init()

        local result = instance:processClipboard("$100 * 2")

        assert.is_not_nil(result)
        assert.is_truthy(result:match("%$200") or result:match("200"))
    end)

    it("should handle no selection gracefully", function()
        local instance = ClipboardFormatter:init()

        local result = instance:processClipboard(nil)

        assert.is_nil(result)
    end)

    it("should handle PD conversion from selection", function()
        local instance = ClipboardFormatter:init()

        local result = instance:processClipboard("60% PD")

        assert.is_not_nil(result)
        assert.is_truthy(result:match("60%%"))
    end)

    it("should process clipboard with context", function()
        local instance = ClipboardFormatter:init()

        local result, matchedId = instance:processClipboard("15 + 27", {})

        assert.is_not_nil(result)
        assert.equals("42", result)
        assert.equals("arithmetic", matchedId)
    end)
end)
