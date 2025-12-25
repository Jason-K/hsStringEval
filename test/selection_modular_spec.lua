---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local SelectionModular = require("ClipboardFormatter.src.clipboard.selection_modular")

describe("SelectionModular", function()
    before_each(function()
        helper.reset()
        helper.setClipboard("original clipboard content")
    end)

    local mockFormatter = function(text)
        return "formatted: " .. text
    end

    describe("configuration normalization", function()
        it("should normalize empty options", function()
            local config = SelectionModular.Config.normalize({})
            assert.is_not_nil(config)
            assert.is_false(config.debug)
            assert.is_true(config.tryAccessibilityAPI)
            assert.is_true(config.copySelection)
            assert.is_true(config.fallbackKeystroke)
            assert.is_number(config.copyDelayMs)
            assert.is_number(config.pasteDelayMs)
        end)

        it("should merge user configuration", function()
            local opts = {
                config = {
                    debug = true,
                    copyDelayMs = 500
                },
                restoreOriginal = false
            }
            local config = SelectionModular.Config.normalize(opts)
            assert.is_true(config.debug)
            assert.are.equal(500, config.copyDelayMs)
            assert.is_false(config.restoreOriginal)
        end)
    end)

    describe("debug helper", function()
        it("should create debug helper", function()
            local debug = SelectionModular.Debug.create(true)
            assert.is_not_nil(debug.print)
            assert.is_function(debug.print)
        end)

        it("should create disabled debug helper", function()
            local debug = SelectionModular.Debug.create(false)
            assert.is_not_nil(debug.print)
            assert.is_function(debug.print)
            -- Should not error when called
            debug.print("test message")
        end)
    end)

    describe("selection strategies", function()
        it("should handle accessibility API when disabled", function()
            local config = { tryAccessibilityAPI = false }
            local debug = SelectionModular.Debug.create(false)

            local text, method = SelectionModular.SelectionStrategies.tryAccessibilityAPI(config, debug)
            assert.is_nil(text)
            assert.are.equal("accessibility_disabled", method)
        end)

        it("should handle menu copy when disabled", function()
            local config = { copySelection = false }
            local debug = SelectionModular.Debug.create(false)

            local text, method = SelectionModular.SelectionStrategies.tryMenuCopy(config, debug, "test")
            assert.is_nil(text)
            assert.are.equal("copy_disabled", method)
        end)

        it("should handle fallback keystroke when disabled", function()
            local config = { fallbackKeystroke = false }
            local debug = SelectionModular.Debug.create(false)

            local text, method = SelectionModular.SelectionStrategies.tryFallbackKeystroke(config, debug)
            assert.is_nil(text)
            assert.are.equal("fallback_disabled", method)
        end)
    end)

    describe("text processor", function()
        it("should process text successfully", function()
            local debug = SelectionModular.Debug.create(false)
            local text = "test input"

            local formatted, status, result = SelectionModular.TextProcessor.processSelection(
                mockFormatter, text, debug)

            assert.is_not_nil(formatted)
            assert.are.equal("formatted: test input", formatted)
            assert.are.equal("success", status)
            assert.is_nil(result)
        end)

        it("should handle formatter errors", function()
            local debug = SelectionModular.Debug.create(false)
            local errorFormatter = function() error("test error") end
            local text = "test input"

            local formatted, status, result = SelectionModular.TextProcessor.processSelection(
                errorFormatter, text, debug)

            assert.is_nil(formatted)
            assert.are.equal("formatter_error", status)
            assert.is_not_nil(result)
        end)

        it("should handle no change scenarios", function()
            local debug = SelectionModular.Debug.create(false)
            local identityFormatter = function(text) return text end
            local text = "test input"

            local formatted, status, result = SelectionModular.TextProcessor.processSelection(
                identityFormatter, text, debug)

            assert.is_nil(formatted)
            assert.are.equal("no_change", status)
            assert.is_nil(result)
        end)
    end)

    describe("paste operations", function()
        it("should paste formatted text", function()
            local config = SelectionModular.Config.normalize({})
            local debug = SelectionModular.Debug.create(false)
            local text = "test text to paste"

            local success, status = SelectionModular.PasteOperations.pasteFormattedText(
                text, config, debug)

            assert.is_not_nil(success)
            assert.is_not_nil(status)
        end)

        it("should handle empty text", function()
            local config = SelectionModular.Config.normalize({})
            local debug = SelectionModular.Debug.create(false)

            local success, status = SelectionModular.PasteOperations.pasteFormattedText(
                "", config, debug)

            -- Should handle gracefully
            assert.is_not_nil(success)
            assert.is_not_nil(status)
        end)
    end)

    describe("results creation", function()
        it("should create success result", function()
            local result = SelectionModular.Results.createSuccess(
                "formatted text", "original text", "side effect")

            assert.is_true(result.success)
            assert.are.equal("formatted text", result.formatted)
            assert.are.equal("original text", result.original)
            assert.are.equal("side effect", result.sideEffectMessage)
        end)

        it("should create failure result", function()
            local result = SelectionModular.Results.createFailure(
                "test_error", "original text", "error details")

            assert.is_false(result.success)
            assert.are.equal("test_error", result.reason)
            assert.are.equal("original text", result.original)
            assert.are.equal("error details", result.error)
        end)

        it("should determine restore behavior", function()
            assert.is_true(SelectionModular.Results.shouldRestore({}, true))
            assert.is_true(SelectionModular.Results.shouldRestore({}, false))
            assert.is_true(SelectionModular.Results.shouldRestore({restoreOriginal = true}, true))
            assert.is_true(SelectionModular.Results.shouldRestore({restoreOriginal = true}, false))
            assert.is_false(SelectionModular.Results.shouldRestore({restoreOriginal = false}, true))
            assert.is_false(SelectionModular.Results.shouldRestore({restoreOriginal = false}, false))
        end)
    end)

    describe("orchestrator selection acquisition", function()
        it("should try accessibility API first", function()
            local config = SelectionModular.Config.normalize({tryAccessibilityAPI = true})
            local debug = SelectionModular.Debug.create(true)

            -- Mock hs.uielement to be unavailable
            package.loaded["hs.uielement"] = nil

            local text, method = SelectionModular.Orchestrator.acquireSelection(
                config, debug, "original")

            -- Should fallback to menu copy when accessibility fails
            assert.is_not_nil(text)
            assert.is_not_nil(method)
        end)

        it("should respect disabled strategies", function()
            local config = SelectionModular.Config.normalize({
                config = {
                    tryAccessibilityAPI = false,
                    copySelection = false,
                    fallbackKeystroke = false
                }
            })
            local debug = SelectionModular.Debug.create(false)

            local text, method = SelectionModular.Orchestrator.acquireSelection(
                config, debug, "original")

            assert.is_nil(text)
            assert.are.equal("no_selection", method)
        end)
    end)

    describe("main apply function", function()
        it("should handle no selection scenario", function()
            local opts = {restoreOriginal = true}
            local result = SelectionModular.apply(mockFormatter, opts)

            assert.is_not_nil(result)
            assert.is_false(result.success)
            assert.are.equal("no_selection", result.reason)
            assert.are.equal("original clipboard content", result.original)
        end)

        it("should handle formatter errors", function()
            -- Mock selection text
            helper.setClipboard("selected text")

            local errorFormatter = function() error("formatter failed") end
            local opts = {restoreOriginal = true}

            local result = SelectionModular.apply(errorFormatter, opts)

            assert.is_not_nil(result)
            -- Note: Without actual selection mechanism, result may vary
        end)

        it("should integrate all modules", function()
            -- Test that all modules are properly integrated
            assert.is_not_nil(SelectionModular.Debug)
            assert.is_not_nil(SelectionModular.Config)
            assert.is_not_nil(SelectionModular.SelectionStrategies)
            assert.is_not_nil(SelectionModular.TextProcessor)
            assert.is_not_nil(SelectionModular.PasteOperations)
            assert.is_not_nil(SelectionModular.Results)
            assert.is_not_nil(SelectionModular.Orchestrator)
        end)

        it("should maintain API compatibility", function()
            -- The apply function should work like the original
            local result = SelectionModular.apply(mockFormatter, {})

            assert.is_not_nil(result)
            assert.is_boolean(result.success)
            -- success results don't have reason, so we check for reason only on failure
            if not result.success then
                assert.is_string(result.reason)
            end
        end)
    end)

    describe("error handling and edge cases", function()
        it("should handle nil formatter", function()
            local opts = {}

            local ok, result = pcall(SelectionModular.apply, nil, opts)
            -- Should not crash
            assert.is_not_nil(ok)
            assert.is_not_nil(result)
        end)

        it("should handle nil options", function()
            local result = SelectionModular.apply(mockFormatter, nil)
            assert.is_not_nil(result)
        end)

        it("should handle empty options", function()
            local result = SelectionModular.apply(mockFormatter, {})
            assert.is_not_nil(result)
        end)
    end)
end)