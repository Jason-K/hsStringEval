local moduleRoot = (...):match("^(.*)%.selection$")
local clipboardIO = require(moduleRoot .. ".io")
local restore = require(moduleRoot .. ".restore")
local utilsRoot = moduleRoot:match("^(.*)%.clipboard$")
local strings = require(utilsRoot .. ".utils.strings")
local hsUtils = require(utilsRoot .. ".utils.hammerspoon")

local Selection = {}

function Selection.apply(formatter, opts)
    opts = opts or {}
    local logger = opts.logger
    local selectionCfg = opts.config or {}
    hsUtils.focusFrontmostWindow(logger)

    local originalClipboard = clipboardIO.getPrimaryPasteboard()
    clipboardIO.clearPrimaryPasteboard()

    if selectionCfg.waitAfterClearMs then
        hsUtils.sleep(selectionCfg.waitAfterClearMs)
    end

    hsUtils.waitForModifiers(selectionCfg.modifierCheckInterval)

    local copied = hsUtils.copyViaAppleScript(logger)
    if not copied and selectionCfg.retryWithEventtap ~= false then
        hsUtils.copyViaEventtap(logger)
    end

    local selectedText = hsUtils.waitForClipboardChange(originalClipboard, {
        initialDelayMs = selectionCfg.copyDelayMs or 300,
        pollIntervalMs = selectionCfg.pollIntervalMs,
        maxPolls = selectionCfg.maxPolls,
    })

    if (not selectedText or selectedText == "") and selectionCfg.retryWithEventtap then
        hsUtils.copyViaEventtap(logger)
        selectedText = hsUtils.waitForClipboardChange(originalClipboard, {
            initialDelayMs = selectionCfg.copyDelayMs or 300,
            pollIntervalMs = selectionCfg.pollIntervalMs,
            maxPolls = selectionCfg.maxPolls,
        })
    end

    local hasSelection = type(selectedText) == "string" and selectedText ~= ""
    if not hasSelection then -- luacheck: ignore
        if opts.restoreOriginal ~= false then
            restore.to(originalClipboard)
        end
        return {
            success = false,
            reason = "no_selection",
            original = originalClipboard,
        }
    end

    local trimmed = strings.trim(selectedText or "")
    local formatted = formatter(trimmed)
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

    clipboardIO.setPrimaryPasteboard(formatted)
    hsUtils.sleep(selectionCfg.pasteDelayMs or 60)
    hsUtils.pasteViaAppleScript(logger)

    if opts.restoreOriginal ~= false then
        hsUtils.sleep(selectionCfg.pasteDelayMs or 60)
        restore.to(originalClipboard)
    end

    return {
        success = true,
        formatted = formatted,
        original = originalClipboard,
    }
end

return Selection
