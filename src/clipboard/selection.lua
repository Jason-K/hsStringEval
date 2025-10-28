local moduleRoot = (...):match("^(.*)%.selection$")
local clipboardIO = require(moduleRoot .. ".io")
local restore = require(moduleRoot .. ".restore")
local utilsRoot = moduleRoot:match("^(.*)%.clipboard$")
local strings = require(utilsRoot .. ".utils.strings")

local Selection = {}

-- Try to get selected text via accessibility API
local function tryAccessibilityAPI(dprint)
    local uielement = require("hs.uielement")
    local elem = uielement.focusedElement()
    if elem and elem.selectedText then
        local text = elem:selectedText()
        if text and text ~= "" then
            dprint("DEBUG: Got text via accessibility API")
            return text
        end
    end
    return nil
end
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

    -- Get current clipboard
    local originalClipboard = clipboardIO.getPrimaryPasteboard()
    dprint("DEBUG: Clipboard at start:", originalClipboard)

    local selectedText = nil
    local hasSelection = false

    -- Method 1: Try accessibility API first (fastest, no clipboard interference)
    if selectionCfg.tryAccessibilityAPI ~= false then
        selectedText = tryAccessibilityAPI(dprint)
        if selectedText and selectedText ~= "" then
            hasSelection = true
            dprint("DEBUG: Selection captured via accessibility API")
        end
    end

    -- Method 2: Menu-based copy with polling (if accessibility failed)
    if not hasSelection and selectionCfg.copySelection ~= false then
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
                selectedText = now
                break
            end
            timer.usleep(stepMs * 1000)
        end

        if not changed then
            local delayMs = selectionCfg.copyDelayMs or 300
            dprint("DEBUG: Clipboard unchanged after poll; waiting", delayMs, "ms")
            timer.usleep(delayMs * 1000)
            selectedText = clipboardIO.getPrimaryPasteboard()
            changed = selectedText ~= originalClipboard and selectedText ~= nil
        end
        -- Method 3: Final keystroke fallback with longer delay (for slow apps)
        if not changed and selectionCfg.fallbackKeystroke ~= false then
            local fallbackDelayMs = selectionCfg.fallbackDelayMs or 20000 -- microseconds (20ms)
            dprint("DEBUG: Trying fallback keystroke with longer delay")
            eventtap.keyStroke({ "cmd" }, "c", 0)
            timer.usleep(fallbackDelayMs)
            selectedText = clipboardIO.getPrimaryPasteboard()
            changed = selectedText ~= originalClipboard and selectedText ~= nil
        end

        hasSelection = changed
    end

    -- Get the selection
    dprint("DEBUG: Clipboard after copy:", selectedText)
    hasSelection = (hasSelection and selectedText and selectedText ~= originalClipboard and selectedText ~= "") == true
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
