-- Core Processing for ClipboardFormatter
-- Handles all clipboard processing and formatting operations

local M = {}

--- Process clipboard content through detector registry with throttling
-- @param instance The ClipboardFormatter spoon instance
-- @param content The content to process
-- @return formatted result, matched detector ID, raw result, side effect
function M.process(instance, content)
    local strings = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.strings")
    local hsUtils = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.hammerspoon")
    local trimmed = strings.trim(content)
    if trimmed == "" then
        return nil
    end
    local processingCfg = instance.config.processing or {}
    local throttleMs = tonumber(processingCfg.throttleMs) or 0
    local now = hsUtils.nowMillis()
    local last = instance._lastProcessing
    if throttleMs > 0 then
        if type(last) == "table" then
            local sameFingerprint = last.fingerprint == trimmed
            local withinWindow = (now - last.timestamp) <= throttleMs
            if sameFingerprint and withinWindow then
                if instance.logger and instance.logger.d then
                    instance.logger.d("Skipping processing within throttle window")
                end
                return last.result, last.matchedId, last.rawResult, last.sideEffect
            end
        end
    end
    local context = {
        logger = instance.logger,
        config = instance.config,
        patterns = instance.patterns,
        pdMapping = instance.pdMapping or {},
        formatters = instance.formatters,
    }
    local result, matchedId, rawResult = instance.registry:process(trimmed, context)
    local sideEffect = context.__lastSideEffect
    instance._lastProcessing = {
        fingerprint = trimmed,
        timestamp = now,
        result = result,
        matchedId = matchedId,
        rawResult = rawResult,
        sideEffect = sideEffect,
    }
    return result, matchedId, rawResult, sideEffect
end

--- Format clipboard content directly
-- @param instance The ClipboardFormatter spoon instance
-- @return true if formatting was applied, false otherwise
function M.formatClipboardDirect(instance)
    local clipboardIO = require((instance._packageRoot or "ClipboardFormatter.src") .. ".clipboard.io")
    local hs = _G.hs

    local clipboard = instance:getClipboardContent()
    if not clipboard or clipboard == "" then
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Clipboard empty")
        end
        return false
    end

    local formatted, _, _, sideEffect = M.process(instance, clipboard)
    if sideEffect then
        if type(hs) == "table" and hs.alert then
            local message = sideEffect.message or "Action executed"
            hs.alert.show(message)
        end
        return true
    end

    if type(formatted) == "string" and formatted ~= clipboard then
        clipboardIO.setPrimaryPasteboard(formatted)
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Formatted clipboard")
        end
        return true
    end

    if type(hs) == "table" and hs.alert then
        hs.alert.show("No formattable content in clipboard")
    end
    return false
end

--- Format only the seed portion of clipboard content
-- @param instance The ClipboardFormatter spoon instance
-- @param opts Optional options table (e.g., autoPaste boolean)
-- @return true if formatting was applied, false otherwise
function M.formatClipboardSeed(instance, opts)
    local strings = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.strings")
    local clipboardIO = require((instance._packageRoot or "ClipboardFormatter.src") .. ".clipboard.io")
    local hs = _G.hs

    opts = opts or {}
    local clipboard = instance:getClipboardContent()
    if not clipboard or clipboard == "" then
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Clipboard empty")
        end
        return false
    end

    local prefix, seed = strings.extractSeed(clipboard)
    if seed == "" then
        if type(hs) == "table" and hs.alert then
            hs.alert.show("No seed found in clipboard")
        end
        return false
    end

    if instance.logger and instance.logger.d then
        instance.logger.d("formatClipboardSeed - prefix: [" .. prefix .. "] seed: [" .. seed .. "]")
    end

    local formatted, _, _, sideEffect = M.process(instance, seed)

    if instance.logger and instance.logger.d then
        instance.logger.d("formatClipboardSeed - formatted: [" ..
            tostring(formatted) .. "] sideEffect: " .. tostring(sideEffect ~= nil))
    end

    if sideEffect then
        clipboardIO.setPrimaryPasteboard(clipboard)
        if type(hs) == "table" and hs.alert then
            local message = sideEffect.message or "Action executed"
            hs.alert.show(message)
        end
        return true
    end

    if type(formatted) == "string" and formatted ~= seed then
        local result = prefix .. formatted
        if instance.logger and instance.logger.d then
            instance.logger.d("formatClipboardSeed - setting clipboard to: [" .. result .. "]")
        end
        clipboardIO.setPrimaryPasteboard(result)
        if opts.autoPaste and type(hs) == "table" and hs.eventtap and hs.eventtap.keyStroke then
            hs.timer.doAfter(0.05, function()
                hs.eventtap.keyStroke({ "cmd" }, "v")
            end)
        end
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Formatted clipboard")
        end
        return true
    end

    if type(hs) == "table" and hs.alert then
        hs.alert.show("No formattable content in clipboard")
    end
    return false
end

--- Cut the current line and format the seed at the end
-- Performs the entire flow inside Hammerspoon:
-- 1) Select to beginning of the line (Cmd+Shift+Left)
-- 2) Cut (Cmd+X) and wait for clipboard to change
-- 3) Evaluate only the seed at the end of the selection
-- 4) Paste back result (or original text for side effects) and optionally restore clipboard
-- @param instance The ClipboardFormatter spoon instance
-- @param opts Optional options table
-- @return true if formatting was applied, false otherwise
function M.cutLineAndFormatSeed(instance, opts)
    local strings = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.strings")
    local clipboardIO = require((instance._packageRoot or "ClipboardFormatter.src") .. ".clipboard.io")
    local hsUtils = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.hammerspoon")
    local hs = _G.hs

    if type(hs) ~= "table" or not hs.eventtap then
        if instance.logger and instance.logger.w then
            instance.logger.w("cutLineAndFormatSeed requires hs.eventtap")
        end
        return false
    end

    local pasteCfg = instance.config and instance.config.selection or {}
    local pasteDelayMs = tonumber(pasteCfg.pasteDelayMs) or 60
    local pollIntervalMs = tonumber(pasteCfg.pollIntervalMs) or 50
    local maxPolls = tonumber(pasteCfg.maxPolls) or 8
    local copyDelayMs = tonumber(pasteCfg.copyDelayMs) or 300
    local copyWaitTimeoutMs = tonumber(pasteCfg.copyWaitTimeoutMs) or 0

    -- Ensure the frontmost window is focused to receive keystrokes
    if hsUtils and hsUtils.focusFrontmostWindow then
        hsUtils.focusFrontmostWindow(instance.logger)
    end

    local originalClipboard = clipboardIO.getPrimaryPasteboard() or ""

    -- Select to beginning of line and cut
    hs.eventtap.keyStroke({ "cmd", "shift" }, "left", 0)
    hs.eventtap.keyStroke({ "cmd" }, "x", 0)

    -- Wait for clipboard to change to the cut text.
    -- We adaptively extend the wait window if the app is slow to update.
    local cutText
    local totalWaitMs = math.max(copyWaitTimeoutMs, pollIntervalMs * maxPolls)
    totalWaitMs = math.max(totalWaitMs, copyDelayMs)
    -- Ensure at least 600ms total window for slow apps
    if totalWaitMs < 600 then totalWaitMs = 600 end

    local remainingMs = totalWaitMs
    if hsUtils and hsUtils.waitForClipboardChange then
        -- First attempt using the helper with an expanded number of polls
        local expandedPolls = math.max(maxPolls, math.floor(totalWaitMs / pollIntervalMs + 0.5))
        cutText = hsUtils.waitForClipboardChange(originalClipboard, {
            pollIntervalMs = pollIntervalMs,
            maxPolls = expandedPolls,
        })
        remainingMs = totalWaitMs - (expandedPolls * pollIntervalMs)
    end

    -- If still unchanged, do a short sleep and check directly in a loop
    if type(cutText) ~= "string" or cutText == "" then
        if hsUtils and hsUtils.sleep then
            hsUtils.sleep(math.min(copyDelayMs, 200))
            remainingMs = remainingMs - math.min(copyDelayMs, 200)
        end
        local deadline = os.clock() * 1000 + math.max(remainingMs, 0)
        local notExpired = (os.clock() * 1000) < deadline
        while (type(cutText) ~= "string" or cutText == "" or cutText == originalClipboard) and notExpired do
            local current = clipboardIO.getPrimaryPasteboard()
            if type(current) == "string" and current ~= "" and current ~= originalClipboard then
                cutText = current
                break
            end
            if hsUtils and hsUtils.sleep then hsUtils.sleep(math.min(pollIntervalMs, 50)) end
        end
    end
    if type(cutText) ~= "string" or cutText == "" then
        -- Fallback: read whatever is currently there
        cutText = clipboardIO.getPrimaryPasteboard()
    end

    if type(cutText) ~= "string" or cutText == "" then
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Clipboard not updated after cut")
        end
        -- Nothing cut; bail
        return false
    end

    -- Extract seed from the cut text
    local prefix, seed = strings.extractSeed(cutText)
    if instance.logger and instance.logger.d then
        instance.logger.d("cutLineAndFormatSeed - prefix: [" .. prefix .. "] seed: [" .. seed .. "]")
    end
    if seed == "" then
        -- Paste back original cut text to avoid data loss
        clipboardIO.setPrimaryPasteboard(cutText)
        hs.timer.doAfter(pasteDelayMs / 1000, function()
            hs.eventtap.keyStroke({ "cmd" }, "v")
            if instance.config and instance.config.restoreClipboard then
                hs.timer.doAfter(pasteDelayMs / 1000, function()
                    clipboardIO.setPrimaryPasteboard(originalClipboard)
                end)
            end
        end)
        if type(hs) == "table" and hs.alert then
            hs.alert.show("No seed found in clipboard")
        end
        return false
    end

    -- Process just the seed
    local formatted, _, _, sideEffect = M.process(instance, seed)
    if instance.logger and instance.logger.d then
        instance.logger.d("cutLineAndFormatSeed - formatted: [" ..
            tostring(formatted) .. "] sideEffect: " .. tostring(sideEffect ~= nil))
    end

    if sideEffect then
        -- Paste back the original cut text, then restore clipboard
        clipboardIO.setPrimaryPasteboard(cutText)
        hs.timer.doAfter(pasteDelayMs / 1000, function()
            hs.eventtap.keyStroke({ "cmd" }, "v")
            if instance.config and instance.config.restoreClipboard then
                hs.timer.doAfter(pasteDelayMs / 1000, function()
                    clipboardIO.setPrimaryPasteboard(originalClipboard)
                end)
            end
        end)
        if type(hs) == "table" and hs.alert then
            local message = sideEffect.message or "Action executed"
            hs.alert.show(message)
        end
        return true
    end

    if type(formatted) == "string" and formatted ~= seed then
        local result = prefix .. formatted
        if instance.logger and instance.logger.d then
            instance.logger.d("cutLineAndFormatSeed - paste: [" .. result .. "]")
        end
        clipboardIO.setPrimaryPasteboard(result)
        hs.timer.doAfter(pasteDelayMs / 1000, function()
            hs.eventtap.keyStroke({ "cmd" }, "v")
            if instance.config and instance.config.restoreClipboard then
                hs.timer.doAfter(pasteDelayMs / 1000, function()
                    clipboardIO.setPrimaryPasteboard(originalClipboard)
                end)
            end
        end)
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Formatted selection")
        end
        return true
    end

    -- No change: paste back original cut text
    clipboardIO.setPrimaryPasteboard(cutText)
    hs.timer.doAfter(pasteDelayMs / 1000, function()
        hs.eventtap.keyStroke({ "cmd" }, "v")
        if instance.config and instance.config.restoreClipboard then
            hs.timer.doAfter(pasteDelayMs / 1000, function()
                clipboardIO.setPrimaryPasteboard(originalClipboard)
            end)
        end
    end)
    if type(hs) == "table" and hs.alert then
        hs.alert.show("No formatting needed")
    end
    return false
end

--- Format the currently selected text
-- @param instance The ClipboardFormatter spoon instance
-- @return true if formatting was applied, false otherwise
function M.formatSelection(instance)
    local selection = require((instance._packageRoot or "ClipboardFormatter.src") .. ".clipboard.selection_modular")
    local hs = _G.hs

    if instance.logger and instance.logger.d then
        instance.logger.d("formatSelection method called")
    end
    local outcome = selection.apply(function(text)
                                        local formatted, _, _, sideEffect = M.process(instance, text)
                                        return formatted, sideEffect
                                    end, {
                                        logger = instance.logger,
                                        config = {
                                            debug = (instance.config.selection and instance.config.selection.debug) or false,
                                            waitAfterClearMs = instance.config.selection.waitAfterClearMs,
                                            modifierCheckInterval = instance.config.selection.modifierCheckInterval,
                                            copyDelayMs = instance.config.selection.copyDelayMs,
                                            pasteDelayMs = instance.config.selection.pasteDelayMs,
                                            pollIntervalMs = instance.config.selection.pollIntervalMs,
                                            maxPolls = instance.config.selection.maxPolls,
                                            retryWithEventtap = instance.config.selection.retryWithEventtap,
                                        },
                                        restoreOriginal = instance.config.restoreClipboard,
                                    })

    if outcome.success then
        if type(hs) == "table" and hs.alert then
            local message = outcome.sideEffectMessage or "Formatted selection"
            hs.alert.show(message)
        end
        return true
    end

    if type(hs) == "table" and hs.alert then
        local reason = outcome.reason == "no_selection" and "Could not get selected text" or "No formatting needed"
        hs.alert.show(reason)
    end

    return false
end

--- Format only the seed at the end of the selected text
-- Formats only the seed at the end of the selected text and pastes back
-- prefix + formattedResult. Side effects preserve the original selection.
-- @param instance The ClipboardFormatter spoon instance
-- @return true if formatting was applied, false otherwise
function M.formatSelectionSeed(instance)
    local strings = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.strings")
    local selection = require((instance._packageRoot or "ClipboardFormatter.src") .. ".clipboard.selection_modular")
    local hs = _G.hs

    if instance.logger and instance.logger.d then
        instance.logger.d("formatSelectionSeed method called")
    end
    local outcome = selection.apply(function(text)
                                        -- Preserve leading and trailing whitespace (tabs/newlines)
                                        local leading_ws = text:match("^(%s*)") or ""
                                        local trailing_ws = text:match("(%s*)$") or ""
                                        local body = text:sub(1, #text - #trailing_ws)
                                        local prefix, seed = strings.extractSeed(body)
                                        local formatted, _, _, sideEffect = M.process(instance, seed)
                                        if sideEffect then
                                            -- Preserve original selection; signal side effect
                                            return text, sideEffect
                                        end
                                        if type(formatted) == "string" and formatted ~= seed then
                                            -- If prefix is only whitespace or empty, preserve leading whitespace
                                            if prefix:match("^%s*$") or prefix == "" then
                                                return leading_ws .. formatted .. trailing_ws
                                            else
                                                return prefix .. formatted .. trailing_ws
                                            end
                                        end
                                        return text
                                    end, {
                                        logger = instance.logger,
                                        config = {
                                            debug = (instance.config.selection and instance.config.selection.debug) or false,
                                            waitAfterClearMs = instance.config.selection.waitAfterClearMs,
                                            modifierCheckInterval = instance.config.selection.modifierCheckInterval,
                                            copyDelayMs = instance.config.selection.copyDelayMs,
                                            pasteDelayMs = instance.config.selection.pasteDelayMs,
                                            pollIntervalMs = instance.config.selection.pollIntervalMs,
                                            maxPolls = instance.config.selection.maxPolls,
                                            retryWithEventtap = instance.config.selection.retryWithEventtap,
                                        },
                                        restoreOriginal = instance.config.restoreClipboard,
                                    })

    if outcome.success then
        if type(hs) == "table" and hs.alert then
            local message = outcome.sideEffectMessage or "Formatted selection"
            hs.alert.show(message)
        end
        return true
    end

    if type(hs) == "table" and hs.alert then
        local reason = outcome.reason == "no_selection" and "Could not get selected text" or "No formatting needed"
        hs.alert.show(reason)
    end

    return false
end

return M
