--[[
WHAT THIS FILE DOES:
This module provides a modular, maintainable alternative to the monolithic selection logic.
It breaks down the complex Selection.apply function into smaller, focused functions
with clear responsibilities, making the code easier to test, debug, and maintain.

KEY CONCEPTS:
- Modular Design: Separates concerns into discrete, testable functions
- Strategy Pattern: Different selection methods as interchangeable strategies
- Clear Separation: Input, processing, and output phases are clearly separated
- Error Isolation: Each module handles its own errors appropriately
- Single Responsibility: Each function has one clear purpose

EXAMPLE USAGE:
    local Selection = require("src.clipboard.selection_modular")
    local result = Selection.apply(formatter, options)
]]

local pkgRoot = (...):match("^(.*)%.clipboard%.selection_modular$")
local clipboardIO = require(pkgRoot .. ".clipboard.io")
local restore = require(pkgRoot .. ".clipboard.restore")
local ClipboardOperations = require(pkgRoot .. ".utils.clipboard_operations")

local Selection = {}

-- Debug helper module
local Debug = {}

function Debug.create(enabled, logger)
    local dprint = enabled and function(...)
        print(...)
        if logger and logger.d then
            logger.d(table.concat({...}, " "))
        end
    end or function() end

    return {
        print = dprint,
        log = function(level, ...)
            if logger and logger[level] then
                logger[level](table.concat({...}, " "))
            end
        end
    }
end

-- Configuration helper module
local Config = {}

function Config.normalize(opts)
    opts = opts or {}
    local selectionCfg = opts.config or {}

    -- Helper to check if a boolean option is enabled
    -- Checks both opts.config[key] and opts[key] for flexibility
    local function isEnabled(configKey, optsKey)
        local configVal = selectionCfg[configKey]
        local optsVal = opts[optsKey]
        -- If either explicitly false, disable
        if configVal == false or optsVal == false then
            return false
        end
        -- Otherwise, default to true
        return true
    end

    return {
        -- Debug options
        debug = selectionCfg.debug or opts.debug or false,

        -- Selection method preferences
        tryAccessibilityAPI = isEnabled("tryAccessibilityAPI", "tryAccessibilityAPI"),
        copySelection = isEnabled("copySelection", "copySelection"),
        fallbackKeystroke = isEnabled("fallbackKeystroke", "fallbackKeystroke"),

        -- Timing configurations
        copyWaitTimeoutMs = selectionCfg.copyWaitTimeoutMs or 600,
        copyDelayMs = selectionCfg.copyDelayMs or 300,
        fallbackDelayMs = selectionCfg.fallbackDelayMs or 20000,
        pasteDelayMs = selectionCfg.pasteDelayMs or 60,

        -- Restore behavior
        restoreOriginal = opts.restoreOriginal ~= false,

        -- Enhanced retry configuration
        retry = selectionCfg.retry or {
            maxRetries = 3,
            baseDelayMs = 100,
            maxDelayMs = 1000,
            exponentialBackoff = true
        }
    }
end

-- Selection strategy interfaces
local SelectionStrategies = {}

-- Accessibility API strategy
function SelectionStrategies.tryAccessibilityAPI(config, debug)
    if not config.tryAccessibilityAPI then
        return nil, "accessibility_disabled"
    end

    debug.print("DEBUG: Trying accessibility API")

    local ok, uielement = pcall(require, "hs.uielement")
    if not ok then
        debug.log("w", "hs.uielement not available")
        return nil, "no_uielement"
    end

    local ok2, elem = pcall(uielement.focusedElement)
    if not ok2 or not elem then
        debug.log("w", "No focused element available")
        return nil, "no_focused_element"
    end

    local ok3, text = pcall(elem.selectedText, elem)
    if ok3 and text and text ~= "" then
        debug.print("DEBUG: Got text via accessibility API")
        return text, "success"
    end

    return nil, "no_selection"
end

-- Menu-based copy strategy
function SelectionStrategies.tryMenuCopy(config, debug, originalClipboard)
    if not config.copySelection then
        return nil, "copy_disabled"
    end

    debug.print("DEBUG: Trying menu-based copy")

    local app = require("hs.application").frontmostApplication()
    local eventtap = require("hs.eventtap")
    local timer = require("hs.timer")

    -- Try menu copy first
    if app and app:selectMenuItem({ "Edit", "Copy" }) then
        debug.print("DEBUG: Invoked Edit > Copy via menu")
    else
        debug.print("DEBUG: Copy menu unavailable; sending Cmd+C keystroke")
        eventtap.keyStroke({ "cmd" }, "c", 0)
    end

    -- Poll for clipboard change with enhanced retry logic
    local maxWaitMs = config.copyWaitTimeoutMs
    local stepMs = 20

    for attempt = 1, math.floor(maxWaitMs / stepMs) do
        local now = clipboardIO.getPrimaryPasteboard()
        if now and now ~= originalClipboard and now ~= "" then
            debug.print("DEBUG: Clipboard changed after", (attempt * stepMs), "ms")
            return now, "success"
        end
        timer.usleep(stepMs * 1000)
    end

    -- Fallback to fixed delay
    debug.print("DEBUG: Clipboard unchanged after poll; waiting", config.copyDelayMs, "ms")
    timer.usleep(config.copyDelayMs * 1000)

    local selectedText = clipboardIO.getPrimaryPasteboard()
    if selectedText ~= originalClipboard and selectedText then
        return selectedText, "success"
    end

    return nil, "no_change"
end

-- Fallback keystroke strategy
function SelectionStrategies.tryFallbackKeystroke(config, debug)
    if not config.fallbackKeystroke then
        return nil, "fallback_disabled"
    end

    debug.print("DEBUG: Trying fallback keystroke")

    local eventtap = require("hs.eventtap")
    local timer = require("hs.timer")

    eventtap.keyStroke({ "cmd" }, "c", 0)
    timer.usleep(config.fallbackDelayMs)

    local selectedText = clipboardIO.getPrimaryPasteboard()
    if selectedText and selectedText ~= "" then
        return selectedText, "success"
    end

    return nil, "no_selection"
end

-- Text processing module
local TextProcessor = {}

function TextProcessor.processSelection(formatter, rawText, debug, logger)
    debug.print("DEBUG: Processing selection:", rawText)

    local ok, formatted, sideEffect = pcall(formatter, rawText)
    if not ok then
        debug.print("DEBUG: Formatter error:", formatted)
        if logger and logger.e then
            logger.e("Formatter error: " .. tostring(formatted))
        end
        return nil, "formatter_error", formatted
    end

    debug.print("DEBUG: Formatted result:", formatted)
    debug.print("DEBUG: Side effect:", sideEffect)

    if not formatted or (formatted == rawText and not sideEffect) then
        return nil, "no_change", nil
    end

    return formatted, "success", sideEffect
end

-- Paste operations module
local PasteOperations = {}

function PasteOperations.pasteFormattedText(formattedText, config, debug)
    debug.print("DEBUG: Pasting formatted text")

    -- Handle empty text case
    if not formattedText or formattedText == "" then
        return false, "empty_text"
    end

    local clipboardResult = ClipboardOperations.setTextWithRetry(formattedText, config, nil)
    if not clipboardResult then
        return nil, "clipboard_write_failed"
    end

    local eventtap = require("hs.eventtap")
    local timer = require("hs.timer")
    local app = require("hs.application").frontmostApplication()

    timer.usleep(config.pasteDelayMs * 1000)

    if app and app:selectMenuItem({ "Edit", "Paste" }) then
        debug.print("DEBUG: Invoked Edit > Paste via menu")
    else
        debug.print("DEBUG: Paste menu unavailable; sending Cmd+V keystroke")
        eventtap.keyStroke({ "cmd" }, "v", 0)
    end

    return true, "success"
end

-- Results module
local Results = {}

function Results.createSuccess(formatted, original, sideEffectMessage)
    return {
        success = true,
        formatted = formatted,
        original = original,
        sideEffectMessage = sideEffectMessage,
    }
end

function Results.createFailure(reason, original, error)
    local result = {
        success = false,
        reason = reason,
        original = original,
    }
    if error then
        result.error = error
    end
    return result
end

function Results.shouldRestore(opts, success)
    return opts.restoreOriginal ~= false
end

-- Main orchestrator
local Orchestrator = {}

function Orchestrator.executeSelection(formatter, opts)
    opts = opts or {}
    local config = Config.normalize(opts)
    local debug = Debug.create(config.debug, opts.logger)

    debug.print("DEBUG: Selection.apply called")

    -- Phase 1: Setup and backup
    local originalClipboard = ClipboardOperations.getTextWithRetry(config, opts.logger)
    debug.print("DEBUG: Original clipboard:", originalClipboard)

    -- Phase 2: Selection acquisition
    local selectedText, selectionMethod = Orchestrator.acquireSelection(config, debug, originalClipboard)

    if not selectedText or selectedText == "" or selectedText == originalClipboard then
        debug.print("DEBUG: No valid selection obtained")
        if Results.shouldRestore(opts, false) then
            restore.to(originalClipboard)
        end
        return Results.createFailure("no_selection", originalClipboard)
    end

    debug.print("DEBUG: Selection obtained via:", selectionMethod)
    debug.print("DEBUG: Selected text:", selectedText)

    -- Phase 3: Text processing
    local formatted, processStatus, processResult = TextProcessor.processSelection(
        formatter, selectedText, debug, opts.logger)

    if processStatus ~= "success" then
        if Results.shouldRestore(opts, false) then
            restore.to(originalClipboard)
        end
        return Results.createFailure(processStatus, originalClipboard, processResult)
    end

    -- Phase 4: Paste formatted text
    local pasteSuccess, pasteStatus = PasteOperations.pasteFormattedText(formatted, config, debug)

    if not pasteSuccess then
        if Results.shouldRestore(opts, false) then
            restore.to(originalClipboard)
        end
        return Results.createFailure(pasteStatus, originalClipboard)
    end

    -- Phase 5: Cleanup and restore
    if Results.shouldRestore(opts, true) then
        local timer = require("hs.timer")
        timer.usleep(config.pasteDelayMs * 1000)
        restore.to(originalClipboard)
    end

    local sideEffectMessage = processResult and processResult.message
    return Results.createSuccess(formatted, originalClipboard, sideEffectMessage)
end

function Orchestrator.acquireSelection(config, debug, originalClipboard)
    -- Strategy 1: Accessibility API (fastest, no clipboard interference)
    local text, method = SelectionStrategies.tryAccessibilityAPI(config, debug)
    if text and text ~= "" then
        return text, method
    end

    -- Strategy 2: Menu-based copy with polling
    text, method = SelectionStrategies.tryMenuCopy(config, debug, originalClipboard)
    if text and text ~= "" and text ~= originalClipboard then
        return text, method
    end

    -- Strategy 3: Fallback keystroke
    text, method = SelectionStrategies.tryFallbackKeystroke(config, debug)
    if text and text ~= "" and text ~= originalClipboard then
        return text, method
    end

    return nil, "no_selection"
end

-- Public API - maintains compatibility with original Selection.apply
function Selection.apply(formatter, opts)
    return Orchestrator.executeSelection(formatter, opts)
end

-- Export modules for testing and advanced usage
Selection.Debug = Debug
Selection.Config = Config
Selection.SelectionStrategies = SelectionStrategies
Selection.TextProcessor = TextProcessor
Selection.PasteOperations = PasteOperations
Selection.Results = Results
Selection.Orchestrator = Orchestrator

return Selection