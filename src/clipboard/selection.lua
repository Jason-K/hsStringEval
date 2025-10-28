local moduleRoot = (...):match("^(.*)%.selection$")
local clipboardIO = require(moduleRoot .. ".io")
local restore = require(moduleRoot .. ".restore")
local utilsRoot = moduleRoot:match("^(.*)%.clipboard$")
local strings = require(utilsRoot .. ".utils.strings")

local Selection = {}

function Selection.apply(formatter, opts)
    -- Debug helper
    local noop = function() end
    opts = opts or {}
    local selectionCfg = (opts and opts.config) or {}
    local debugEnabled = (selectionCfg and selectionCfg.debug) or opts.debug or false
    local function dprint(...)
        if debugEnabled then
            print(...)
        end
    end
    dprint("DEBUG: Selection.apply called")
    local logger = opts.logger

    -- Get current clipboard - it should already have the selection
    local originalClipboard = clipboardIO.getPrimaryPasteboard()
    dprint("DEBUG: Clipboard at start:", originalClipboard)

    -- If selection mode is enabled, copy the selection.
    -- Use menu-based copy to avoid interference from held modifiers (e.g., vmod).
    if selectionCfg.copySelection ~= false then
        local app = require("hs.application").frontmostApplication()
        local eventtap = require("hs.eventtap")
        local timer = require("hs.timer")

        local copiedViaMenu = false
        if app and app:selectMenuItem({ "Edit", "Copy" }) then
            copiedViaMenu = true
            dprint("DEBUG: Invoked Edit > Copy via menu")
        else
            -- Fallback to keystroke if menu path unavailable
            dprint("DEBUG: Copy menu unavailable; sending Cmd+C keystroke")
            eventtap.keyStroke({ "cmd" }, "c", 0)
        end

        -- Prefer a short poll for clipboard change; fallback to fixed delay
        local maxWaitMs = selectionCfg.copyWaitTimeoutMs or 600
        local stepMs = 20
        local changed = false
        for _ = 1, math.floor(maxWaitMs / stepMs) do
            local now = clipboardIO.getPrimaryPasteboard()
            if now and now ~= originalClipboard and now ~= "" then
                changed = true
                break
            end
            timer.usleep(stepMs * 1000)
        end
        if not changed then
            local delayMs = selectionCfg.copyDelayMs or 300
            dprint("DEBUG: Clipboard unchanged after poll; waiting", delayMs, "ms")
            timer.usleep(delayMs * 1000)
        end
    end

    -- Get the selection
    local selectedText = clipboardIO.getPrimaryPasteboard()
    dprint("DEBUG: Clipboard after copy:", selectedText)
    local hasSelection = selectedText and selectedText ~= originalClipboard and selectedText ~= ""
    dprint("DEBUG: Has selection:", hasSelection)

    if not hasSelection then
        if opts.restoreOriginal ~= false then
            restore.to(originalClipboard)
        end
        return {
            success = false,
            reason = "no_selection",
            original = originalClipboard,
        }
    end

    local trimmed = strings.trim(selectedText)
    dprint("DEBUG: Selected text:", trimmed)
    local ok, formatted = pcall(formatter, trimmed)
    if not ok then
        dprint("DEBUG: Formatter error:", formatted)
        if opts.restoreOriginal ~= false then
            restore.to(originalClipboard)
        end
        return {
            success = false,
            reason = "formatter_error",
            error = formatted,
            original = originalClipboard,
        }
    end
    dprint("DEBUG: Formatted result:", formatted)
    dprint("DEBUG: Same as original?", formatted == trimmed)
    if not formatted or formatted == trimmed then
        if opts.restoreOriginal ~= false then
            restore.to(originalClipboard)
        end
        return {
            success = false,
            reason = "no_change",
            original = originalClipboard,
        }
    end

    -- Paste the formatted text; prefer menu path to avoid held modifiers
    local eventtap = require("hs.eventtap")
    local timer = require("hs.timer")
    local app = require("hs.application").frontmostApplication()
    clipboardIO.setPrimaryPasteboard(formatted)
    local pasteDelayMs = selectionCfg.pasteDelayMs or 60
    timer.usleep(pasteDelayMs * 1000)
    local pastedViaMenu = false
    if app and app:selectMenuItem({ "Edit", "Paste" }) then
        pastedViaMenu = true
        dprint("DEBUG: Invoked Edit > Paste via menu")
    else
        dprint("DEBUG: Paste menu unavailable; sending Cmd+V keystroke")
        eventtap.keyStroke({ "cmd" }, "v", 0)
    end

    -- Restore original clipboard
    if opts.restoreOriginal ~= false then
        timer.usleep(pasteDelayMs * 1000)
        restore.to(originalClipboard)
    end

    return {
        success = true,
        formatted = formatted,
        original = originalClipboard,
    }
end

return Selection
