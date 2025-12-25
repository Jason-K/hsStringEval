---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")

describe("clipboard utilities", function()
    before_each(function()
        helper.reset()
    end)

    it("manages primary pasteboard", function()
        local ioModule = helper.requireFresh("clipboard.io")
        helper.setClipboard("hello")
        assert.equal("hello", ioModule.getPrimaryPasteboard())
        ioModule.setPrimaryPasteboard("world")
        assert.equal("world", helper.getClipboard())
        ioModule.clearPrimaryPasteboard()
        assert.equal("", helper.getClipboard())
    end)

    it("falls back to osascript clipboard", function()
        local ioModule = helper.requireFresh("clipboard.io")
        helper.setClipboard("")
        helper.setFindClipboard("")
        helper.setSelectionText("from applescript")
        helper.setOsascriptHandler(function(script)
            if script:find("clipboard as text") then
                return true, "from applescript"
            end
            return true, ""
        end)
        assert.equal("from applescript", ioModule.getPrimaryPasteboard())
    end)

    it("restores clipboard state", function()
        local restore = helper.requireFresh("clipboard.restore")
        helper.setClipboard("before")
        restore.to(nil)
        assert.equal("", helper.getClipboard())
        restore.to("again")
        assert.equal("again", helper.getClipboard())
    end)

    it("formats selection when formatter returns content", function()
        local selection = helper.requireFresh("clipboard.selection")
        helper.setClipboard("original")
        helper.setSelectionText(" 1 + 1 ")

        local result = selection.apply(function(text)
            return text .. "=" .. "2"
        end, {
            logger = hs.logger.new("test", "debug"),
            config = { retryWithEventtap = false },
            restoreOriginal = false,
        })

        assert.is_true(result.success)
        -- Note: leading whitespace is preserved as per design
        assert.equal(" 1 + 1 =2", helper.getClipboard())
        assert.truthy(helper.pasteInvoked)
    end)

    it("restores original clipboard when no change", function()
        local selection = helper.requireFresh("clipboard.selection")
        helper.setClipboard("keep")
        helper.setSelectionText("same")

        local result = selection.apply(function()
            return nil
        end, {
            logger = hs.logger.new("test", "debug"),
            config = { retryWithEventtap = false },
        })

        assert.is_false(result.success)
        assert.equal("keep", helper.getClipboard())
        assert.equal("no_change", result.reason)
    end)

    it("returns failure when copy yields nothing", function()
        local selection = helper.requireFresh("clipboard.selection")
        helper.setClipboard("keep")
        helper.setSelectionText(nil)
        helper.setOsascriptHandler(function(script)
            if script:find('keystroke "c"') then
                return true, helper.getClipboard()
            end
            return true, ""
        end)

        local result = selection.apply(function()
            return "unused"
        end, {
            logger = hs.logger.new("test", "debug"),
            config = { retryWithEventtap = false },
        })

        assert.is_false(result.success)
        assert.equal("no_selection", result.reason)
        assert.equal("keep", helper.getClipboard())
    end)
end)
