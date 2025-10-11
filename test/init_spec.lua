---@diagnostic disable: undefined-global, undefined-field, need-check-nil

local helper = require("spec_helper")

describe("ClipboardFormatter", function()
    local Formatter

    before_each(function()
        helper.reset()
        Formatter = helper.requireFresh("init")
        Formatter.spoonPath = helper.projectRoot .. "src"
    end)

    it("initializes with defaults and detectors", function()
        local instance = Formatter:init()
        assert.is_table(instance.registry)
        assert.is_not_nil(next(instance.detectors))
        assert.is_table(instance.pdMapping)
    end)

    it("loads PD mapping from custom path", function()
        local instance = Formatter:init()
        helper.withTempFile("25: 5\n", function(path)
            local map = instance:loadPDMapping(path)
            assert.equal(5, map[25])
        end)
    end)

    it("reloads PD mapping when requested", function()
        local instance = Formatter:init()
        helper.withTempFile("30: 6\n", function(path)
            instance:loadPDMapping(path)
            helper.withTempFile("30: 8\n", function(updatedPath)
                local reloaded = instance:reloadPDMapping(updatedPath)
                assert.equal(8, reloaded[30])
                assert.equal(8, instance.pdMapping[30])
            end)
        end)
    end)

    it("reads clipboard content", function()
        local instance = Formatter:init()
        helper.setClipboard("value")
        assert.equal("value", instance:getClipboardContent())
    end)

    it("processes clipboard content via detectors", function()
        local instance = Formatter:init()
        local result = instance:processClipboard("$2*2")
        assert.equal("$4.00", result)
    end)

    it("throttles repeated clipboard processing", function()
        local instance = Formatter:init({
            config = {
                processing = {
                    throttleMs = 500,
                },
            },
        })
        local calls = 0
        local originalProcess = instance.registry.process
        ---@diagnostic disable-next-line: duplicate-set-field
        instance.registry.process = function(registry, text, context)
            calls = calls + 1
            return originalProcess(registry, text, context)
        end
        local first = instance:processClipboard("2+2")
        local second = instance:processClipboard("2+2")
        assert.equal(first, second)
        assert.equal(1, calls)
        instance.registry.process = originalProcess
    end)

    it("registers custom detectors", function()
        local instance = Formatter:init()
        local detector = {
            id = "custom",
            priority = 999,
            match = function(_, text)
                if text == "special" then
                    return "handled"
                end
            end,
        }
        local registered = instance:registerDetector(detector)
        assert.equal(detector, registered)
        assert.equal("handled", instance:processClipboard("special"))
    end)

    it("registers custom formatters", function()
        local instance = Formatter:init()
        local custom = {
            process = function(_, text)
                return "wrapped:" .. text
            end,
        }
        instance:registerFormatter("wrapped", custom)
        assert.equal(custom, instance:getFormatter("wrapped"))
        assert.equal("wrapped:test", custom.process(custom, "test"))
    end)

    it("honors logging configuration overrides", function()
        local instance = Formatter:init({
            config = {
                logging = {
                    level = "debug",
                    structured = true,
                    includeTimestamp = false,
                },
            },
        })
        local logs = instance.logger.messages or {}
        local before = #logs
        instance.logger:w("structured message")
        local entry = instance.logger.messages and instance.logger.messages[before + 1]
        assert.is_not_nil(entry)
        assert.same("w", entry.method)
        assert.equal('{"level":"warning","message":"structured message"}', entry.args[1])
        assert.equal("debug", instance.logger.level)
        instance:setLogLevel("error")
        assert.equal("error", instance.logger.level)
    end)

    it("applies hook tables and functions", function()
        local instance = Formatter:init()
        local called = {}
        instance:applyHooks(function()
            table.insert(called, "func")
        end)
        instance:applyHooks({
            detectors = function()
                table.insert(called, "table")
            end
        })
        assert.same({ "func", "table" }, called)
    end)

    it("applies formatter hooks before detector hooks", function()
        local FormatterModule = helper.requireFresh("init")
        FormatterModule.spoonPath = helper.projectRoot .. "src"
        local instance = FormatterModule:init({
            hooks = {
                formatters = function(obj)
                    obj:registerFormatter("shout", {
                        process = function(_, text)
                            return string.upper(text)
                        end,
                    })
                end,
                detectors = function(obj)
                    obj:registerDetector({
                        id = "shout",
                        priority = 10,
                        match = function(_, text, context)
                            local fmt = context.formatters and context.formatters.shout
                            if fmt and fmt.process then
                                return fmt.process(fmt, text)
                            end
                        end,
                    })
                end,
            },
        })
        assert.equal("HOOK ME", instance:processClipboard("hook me"))
    end)

    it("allows hooks to override built-in formatters", function()
        local FormatterModule = helper.requireFresh("init")
        FormatterModule.spoonPath = helper.projectRoot .. "src"
        local instance = FormatterModule:init({
            hooks = {
                formatters = function(obj)
                    local original = obj:getFormatter("arithmetic")
                    obj:registerFormatter("arithmetic", {
                        isCandidate = function(content, opts)
                            return original.isCandidate(content, opts)
                        end,
                        process = function(content, opts)
                            local base = original.process(content, opts)
                            if base then
                                return "hooked:" .. base
                            end
                        end,
                    })
                end,
            },
        })
        assert.equal("hooked:$4.00", instance:processClipboard("$2*2"))
    end)

    it("loads hooks from file when available", function()
        local instance = Formatter:init()
        local hookSource = [[
return {
    detectors = function(formatter)
        formatter:registerDetector({
            id = 'from_file',
            priority = 1,
            match = function()
                return 'hooked'
            end,
        })
    end,
}
]]
        helper.withTempFile(hookSource, function(path)
            instance:loadHooksFromFile(path)
            assert.equal("hooked", instance:processClipboard("anything"))
        end)
    end)

    it("formats clipboard directly and alerts on success", function()
        local instance = Formatter:init()
        helper.setClipboard("1+1")
        local ok = instance:formatClipboardDirect()
        assert.is_true(ok)
        assert.equal("2", helper.getClipboard())
        assert.equal("Formatted clipboard", helper.alerts[#helper.alerts])
    end)

    it("returns side effects for navigation matches", function()
        local instance = Formatter:init()
        local _, _, _, sideEffect = instance:processClipboard("https://example.com")
        assert.is_table(sideEffect)
        assert.equal("browser", sideEffect.type)
        assert.equal("https://example.com", helper.openedUrls[#helper.openedUrls])
    end)

    it("executes navigation side effects via formatClipboardDirect", function()
        local instance = Formatter:init()
        helper.setClipboard("obsidian://open?vault=Main")
        helper.clearAlerts()
        local ok = instance:formatClipboardDirect()
        assert.is_true(ok)
        assert.equal("obsidian://open?vault=Main", helper.getClipboard())
        assert.equal("Opened application URL", helper.alerts[#helper.alerts])
        assert.equal(1, #helper.taskInvocations)
        local invocation = helper.taskInvocations[1]
        assert.equal("/usr/bin/open", invocation.command)
        assert.same({ "-u", "obsidian://open?vault=Main" }, invocation.args)
    end)

    it("formats selection via helper module", function()
        local instance = Formatter:init()
        local selectionModule = require("clipboard.selection")
        local originalApply = selectionModule.apply
        ---@diagnostic disable-next-line: duplicate-set-field
        selectionModule.apply = function(formatter, opts)
            assert.is_function(formatter)
            assert.is_table(opts)
            return {
                success = true,
                formatted = "result",
            }
        end
        local ok = instance:formatSelection()
        assert.is_true(ok)
        assert.equal("Formatted selection", helper.alerts[#helper.alerts])
        selectionModule.apply = originalApply
    end)

    it("alerts when selection is unavailable", function()
        local instance = Formatter:init()
        local selectionModule = require("clipboard.selection")
        local originalApply = selectionModule.apply
        ---@diagnostic disable-next-line: duplicate-set-field
        selectionModule.apply = function()
            return {
                success = false,
                reason = "no_selection",
            }
        end
        local ok = instance:formatSelection()
        assert.is_false(ok)
        assert.equal("Could not get selected text", helper.alerts[#helper.alerts])
        selectionModule.apply = originalApply
    end)

    it("binds hotkeys through hs.spoons", function()
        local instance = Formatter:init()
        instance:bindHotkeys({ format = { "ctrl" } })
        assert.is_table(helper.lastHotkeySpec)
        assert.is_function(helper.lastHotkeySpec.spec.format)
    end)

    it("installs hotkey helpers when requested", function()
        assert.is_nil(_G.FormatClip)
        local instance = Formatter:init({
            config = {
                hotkeys = {
                    installHelpers = true,
                },
            },
        })
        assert.is_function(_G.FormatClip)
        helper.setClipboard("2+3")
        assert.is_true(_G.FormatClip())
        assert.equal("5", helper.getClipboard())
        instance:removeHotkeyHelpers()
        assert.is_nil(_G.FormatClip)
    end)

    it("allows hotkey helpers to be installed and removed manually", function()
        local instance = Formatter:init()
        instance:installHotkeyHelpers()
        assert.is_function(_G.FormatClip)
        instance:removeHotkeyHelpers()
        assert.is_nil(_G.FormatClip)
    end)
end)
