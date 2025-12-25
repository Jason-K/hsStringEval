---@diagnostic disable: undefined-global, undefined-field

describe("Clipboard Formatting Integration", function()
    local ClipboardFormatter
    local helper

    setup(function()
        ClipboardFormatter = require("ClipboardFormatter.src.init")
        helper = require("spec_helper")
    end)

    before_each(function()
        helper.reset()
        -- Initialize spoon
        ClipboardFormatter.spoonPath = helper.projectRoot .. "src"
    end)

    it("should format arithmetic from clipboard", function()
        local instance = ClipboardFormatter:init()
        helper.setClipboard("15 + 27")

        instance:formatClipboardDirect()
        local result = helper.getClipboard()

        assert.is_not_nil(result)
        assert.is_truthy(result:match("42"))
    end)

    it("should format date ranges from clipboard", function()
        local instance = ClipboardFormatter:init()
        helper.setClipboard("2024-01-15 to 2024-01-20")

        instance:formatClipboardDirect()
        local result = helper.getClipboard()

        assert.is_not_nil(result)
        -- Date range should be formatted
        assert.is_truthy(result:match("01/15/2024") or result:match("2024%-01%-15"))
    end)

    it("should format PD conversion from clipboard", function()
        local instance = ClipboardFormatter:init()
        helper.setClipboard("60% PD")

        instance:formatClipboardDirect()
        local result = helper.getClipboard()

        assert.is_not_nil(result)
        assert.is_truthy(result:match("60%%"))
    end)

    it("should handle currency arithmetic from clipboard", function()
        local instance = ClipboardFormatter:init()
        helper.setClipboard("$100 * 2")

        instance:formatClipboardDirect()
        local result = helper.getClipboard()

        assert.is_not_nil(result)
        assert.is_truthy(result:match("%$200") or result:match("200"))
    end)

    it("should return original if no patterns match", function()
        local instance = ClipboardFormatter:init()
        local input = "No patterns here"
        helper.setClipboard(input)

        instance:formatClipboardDirect()
        local result = helper.getClipboard()

        assert.equals(input, result)
    end)

    it("should handle empty clipboard", function()
        local instance = ClipboardFormatter:init()
        helper.setClipboard("")

        instance:formatClipboardDirect()
        local result = helper.getClipboard()

        assert.is_not_nil(result)
    end)

    it("should process clipboard content directly", function()
        local instance = ClipboardFormatter:init()

        local result = instance:processClipboard("15 + 27")

        assert.is_not_nil(result)
        assert.equals("42", result)
    end)
end)
