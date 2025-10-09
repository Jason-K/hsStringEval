local M = {}

local function hasHS()
    return type(hs) == "table"
end

local function hasField(field)
    return hasHS() and hs[field] ~= nil
end

local function hasTimer()
    return hasField("timer")
end

local function hasWaitUntil()
    return hasTimer() and type(hs.timer.waitUntil) == "function"
end

local function sleep(ms)
    if not ms or ms <= 0 then
        return
    end
    if hasTimer() and type(hs.timer.usleep) == "function" then
        hs.timer.usleep(ms * 1000)
    end
end

function M.hasPasteboard()
    return hasField("pasteboard")
end

function M.getPasteboard(which)
    if not M.hasPasteboard() then return nil end
    return hs.pasteboard.getContents(which)
end

function M.setPasteboard(value)
    if not M.hasPasteboard() then return end
    hs.pasteboard.setContents(value or "")
end

function M.clearPasteboard()
    if not M.hasPasteboard() then return end
    hs.pasteboard.clearContents()
end

function M.runAppleScript(script, logger)
    if not hasField("osascript") then
        return false, nil
    end
    local ok, result = hs.osascript.applescript(script)
    if not ok and logger and logger.w then
        logger.w("AppleScript error: " .. tostring(result))
    end
    return ok == true, result
end

function M.copyViaAppleScript(logger)
    local script = [[
        tell application "System Events"
            keystroke "c" using {command down}
        end tell
    ]]
    local ok = select(1, M.runAppleScript(script, logger))
    return ok == true
end

function M.pasteViaAppleScript(logger)
    local script = [[
        tell application "System Events"
            keystroke "v" using {command down}
        end tell
    ]]
    local ok = select(1, M.runAppleScript(script, logger))
    return ok == true
end

function M.copyViaEventtap(logger)
    if not hasField("eventtap") then
        return false
    end
    local ok, err = pcall(function()
        hs.eventtap.keyStroke({ "cmd" }, "c")
    end)
    if not ok and logger and logger.w then
        logger.w("eventtap copy failed: " .. tostring(err))
    end
    return ok == true
end

function M.waitForModifiers(interval)
    if not (hasField("timer") and hasField("eventtap")) then
        return true
    end
    local _ = interval
    return hs.timer.waitUntil(function()
        local mods = hs.eventtap.checkKeyboardModifiers()
        return not (mods and (mods.cmd or mods.alt or mods.ctrl or mods.shift))
    end)
end

function M.waitForClipboardChange(original, opts)
    if not M.hasPasteboard() then
        return nil
    end
    opts = opts or {}
    sleep(opts.initialDelayMs)
    local pollInterval = opts.pollIntervalMs or 50
    local maxPolls = tonumber(opts.maxPolls)
    if maxPolls == nil then
        maxPolls = 8
    elseif maxPolls < 0 then
        maxPolls = 0
    end

    local function readChanged()
        local current = M.getPasteboard()
        if type(current) == "string" and current ~= "" and current ~= original then
            return current
        end
        return nil
    end

    local immediate = readChanged()
    if immediate then
        return immediate
    end

    if hasWaitUntil() then
        local captured
        local found = false
        local attempts = 0
        local intervalSeconds = pollInterval / 1000
        hs.timer.waitUntil(function()
            attempts = attempts + 1
            local value = readChanged()
            if value then
                captured = value
                found = true
                return true
            end
            if maxPolls > 0 and attempts >= maxPolls then
                return true
            end
            return false
        end, nil, intervalSeconds)
        if found then
            return captured
        end
    end

    for _ = 1, maxPolls do
        sleep(pollInterval)
        local value = readChanged()
        if value then
            return value
        end
    end
    return nil
end

function M.focusFrontmostWindow(logger)
    if not hasField("application") then
        return
    end
    local app = hs.application.frontmostApplication()
    if not app then
        return
    end
    local win = app:focusedWindow()
    if win ~= nil then
        win:focus()
    elseif logger and logger.d then
        logger.d("No focused window before copy")
    end
end

function M.readClipboardFallback(logger)
    local script = [[
        set theContent to ""
        try
            tell application "System Events"
                set theContent to the clipboard as text
            end tell
        end try
        return theContent
    ]]
    local ok, result = M.runAppleScript(script, logger)
    if ok and type(result) == "string" then
        return result
    end
    return nil
end

function M.nowMillis()
    if hasTimer() and type(hs.timer.secondsSinceEpoch) == "function" then
        local seconds = hs.timer.secondsSinceEpoch()
        if type(seconds) == "number" then
            return seconds * 1000
        end
    end
    return os.clock() * 1000
end

function M.sleep(ms)
    sleep(ms)
end

return M
