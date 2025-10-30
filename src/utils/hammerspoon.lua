--[[
WHAT THIS FILE DOES:
Provides a collection of utility functions that interact with the Hammerspoon API.
This module abstracts away the direct calls to `hs`, making it easier to manage
dependencies on Hammerspoon and to mock for testing purposes. It includes
functions for clipboard management, running AppleScript, simulating key presses,
and other system-level interactions.

KEY CONCEPTS:
- Abstraction: Wraps Hammerspoon functions to provide a consistent interface and
  handle cases where Hammerspoon is not available.
- System Interaction: Exposes functions for interacting with the clipboard,
  running scripts, and managing windows.
- Timing: Includes utilities for sleeping and waiting for system events.

EXAMPLE USAGE:
    local Hammerspoon = require("src.utils.hammerspoon")
    if Hammerspoon.hasPasteboard() then
        local content = Hammerspoon.getPasteboard()
        print(content)
        Hammerspoon.setPasteboard("new content")
    end
]]
local M = {}

-- HELPER: Check if the global `hs` object is available.
local function hasHS()
    -- ACTION: Check for `hs` table.
    return type(hs) == "table"
end

-- HELPER: Check if a specific field exists in the `hs` object.
-- @param field string The name of the field to check.
-- @return boolean true if the field exists, false otherwise.
local function hasField(field)
    -- ACTION: Check for `hs` and the field.
    return hasHS() and hs[field] ~= nil
end

-- HELPER: Check if `hs.timer` is available.
local function hasTimer()
    -- ACTION: Check for the `timer` field.
    return hasField("timer")
end

-- HELPER: Pause execution for a specified duration in milliseconds.
-- @param ms number The number of milliseconds to sleep.
local function sleep(ms)
    -- GUARD: Ensure ms is a positive number.
    if not ms or ms <= 0 then
        return
    end
    -- ACTION: Use `hs.timer.usleep` for microsecond-level sleeping.
    if hasTimer() and type(hs.timer.usleep) == "function" then
        hs.timer.usleep(ms * 1000)
    end
end

-- PUBLIC METHOD: Check if the Hammerspoon pasteboard API is available.
-- @return boolean true if `hs.pasteboard` exists, false otherwise.
function M.hasPasteboard()
    -- ACTION: Check for the `pasteboard` field.
    return hasField("pasteboard")
end

-- PUBLIC METHOD: Get the contents of the pasteboard.
-- @param which string (optional) The name of the pasteboard to get contents from.
-- @return string|nil The contents of the pasteboard, or nil if unavailable.
function M.getPasteboard(which)
    -- GUARD: Check for pasteboard availability.
    if not M.hasPasteboard() then return nil end
    -- ACTION: Retrieve pasteboard contents.
    return hs.pasteboard.getContents(which)
end

-- PUBLIC METHOD: Set the contents of the pasteboard.
-- @param value string The new content for the pasteboard.
function M.setPasteboard(value)
    -- GUARD: Check for pasteboard availability.
    if not M.hasPasteboard() then return end
    -- ACTION: Set pasteboard contents, defaulting to an empty string.
    hs.pasteboard.setContents(value or "")
end

-- PUBLIC METHOD: Clear the contents of the pasteboard.
function M.clearPasteboard()
    -- GUARD: Check for pasteboard availability.
    if not M.hasPasteboard() then return end
    -- ACTION: Clear pasteboard contents.
    hs.pasteboard.clearContents()
end

-- PUBLIC METHOD: Execute an AppleScript script.
-- @param script string The AppleScript to execute.
-- @param logger table (optional) A logger object to log errors.
-- @return boolean true if the script ran successfully, false otherwise.
-- @return any The result of the script execution.
function M.runAppleScript(script, logger)
    -- GUARD: Check for osascript availability.
    if not hasField("osascript") then
        return false, nil
    end
    -- ACTION: Run the AppleScript.
    local ok, result = hs.osascript.applescript(script)
    -- FAIL: Log error if execution fails.
    if not ok and logger and logger.w then
        logger.w("AppleScript error: " .. tostring(result))
    end
    -- PROCESS: Return success status and result.
    return ok == true, result
end

-- PUBLIC METHOD: Simulate a "copy" command (Cmd+C) using AppleScript.
-- @param logger table (optional) A logger object to log errors.
-- @return boolean true if the keystroke was sent successfully.
function M.copyViaAppleScript(logger)
    -- SETUP: Define the AppleScript for Cmd+C.
    local script = [[
        tell application "System Events"
            keystroke "c" using {command down}
        end tell
    ]]
    -- ACTION: Run the script and return success status.
    local ok = select(1, M.runAppleScript(script, logger))
    return ok == true
end

-- PUBLIC METHOD: Simulate a "paste" command (Cmd+V) using AppleScript.
-- @param logger table (optional) A logger object to log errors.
-- @return boolean true if the keystroke was sent successfully.
function M.pasteViaAppleScript(logger)
    -- SETUP: Define the AppleScript for Cmd+V.
    local script = [[
        tell application "System Events"
            keystroke "v" using {command down}
        end tell
    ]]
    -- ACTION: Run the script and return success status.
    local ok = select(1, M.runAppleScript(script, logger))
    return ok == true
end

-- PUBLIC METHOD: Simulate a "copy" command (Cmd+C) using Hammerspoon's eventtap.
-- @param logger table (optional) A logger object to log errors.
-- @return boolean true if the keystroke was sent successfully.
function M.copyViaEventtap(logger)
    -- GUARD: Check for eventtap availability.
    if not hasField("eventtap") then
        return false
    end
    -- TRY: Attempt to send the keystroke.
    local ok, err = pcall(function()
        hs.eventtap.keyStroke({ "cmd" }, "c")
    end)
    -- FAIL: Log error if it fails.
    if not ok and logger and logger.w then
        logger.w("eventtap copy failed: " .. tostring(err))
    end
    -- PROCESS: Return success status.
    return ok == true
end

-- PUBLIC METHOD: Wait for modifier keys (Cmd, Alt, Ctrl, Shift) to be released.
-- We do this to avoid race conditions where the user is still holding down
-- modifier keys when we are trying to simulate keystrokes.
-- @param interval number (optional) The polling interval in milliseconds. Defaults to 50.
-- @return boolean true if modifiers were released within the timeout, false otherwise.
function M.waitForModifiers(interval)
    -- GUARD: Check for necessary Hammerspoon modules.
    if not (hasField("timer") and hasField("eventtap")) then
        return true
    end
    -- SETUP: Initialize polling parameters.
    local waitInterval = interval or 50
    local attempts = 0
    local maxAttempts = math.floor((5000 / waitInterval) + 0.5)
    if maxAttempts < 1 then
        maxAttempts = 1
    end
    -- ACTION: Poll for modifier key state.
    while attempts < maxAttempts do
        -- STEP: Get current modifier state.
        local mods = hs.eventtap.checkKeyboardModifiers()
        -- SUCCESS: Return if no modifiers are pressed.
        if not (mods and (mods.cmd or mods.alt or mods.ctrl or mods.shift)) then
            return true
        end
        -- STEP: Wait before next poll.
        sleep(waitInterval)
        attempts = attempts + 1
    end
    -- FAIL: Return false if timeout is reached.
    return false
end

-- PUBLIC METHOD: Wait for the clipboard content to change from an original value.
-- @param original string The original clipboard content to compare against.
-- @param opts table (optional) Options: `initialDelayMs`, `pollIntervalMs`, `maxPolls`.
-- @return string|nil The new clipboard content, or nil if it didn't change.
function M.waitForClipboardChange(original, opts)
    -- GUARD: Check for pasteboard availability.
    if not M.hasPasteboard() then
        return nil
    end
    -- SETUP: Initialize options.
    opts = opts or {}
    sleep(opts.initialDelayMs)
    local pollInterval = opts.pollIntervalMs or 50
    local maxPolls = tonumber(opts.maxPolls)
    if maxPolls == nil then
        maxPolls = 8
    elseif maxPolls < 0 then
        maxPolls = 0
    end

    -- HELPER: Read clipboard and check if it has changed.
    local function readChanged()
        local current = M.getPasteboard()
        if type(current) == "string" and current ~= "" and current ~= original then
            return current
        end
        return nil
    end

    -- STEP: Check for immediate change.
    local immediate = readChanged()
    if immediate then
        return immediate
    end

    -- ACTION: Poll for changes up to `maxPolls` times.
    for _ = 1, maxPolls do
        sleep(pollInterval)
        local value = readChanged()
        if value then
            return value
        end
    end
    -- FAIL: Return nil if no change occurred within the polling period.
    return nil
end

-- PUBLIC METHOD: Focus the frontmost application window.
-- This can be useful to ensure that simulated keystrokes are sent to the
-- correct application.
-- @param logger table (optional) A logger object for debugging.
function M.focusFrontmostWindow(logger)
    -- GUARD: Check for application module availability.
    if not hasField("application") then
        return
    end
    -- ACTION: Get the frontmost application.
    local app = hs.application.frontmostApplication()
    if not app then
        return
    end
    -- ACTION: Get and focus the focused window of the application.
    local win = app:focusedWindow()
    if win ~= nil then
        win:focus()
    -- DEBUG: Log if no focused window was found.
    elseif logger and logger.d then
        logger.d("No focused window before copy")
    end
end

-- PUBLIC METHOD: A fallback method to read the clipboard using AppleScript.
-- This is useful when the standard Hammerspoon pasteboard functions fail.
-- @param logger table (optional) A logger object.
-- @return string|nil The clipboard content, or nil on failure.
function M.readClipboardFallback(logger)
    -- SETUP: AppleScript to get clipboard content as text.
    local script = [[
        set theContent to ""
        try
            tell application "System Events"
                set theContent to the clipboard as text
            end tell
        end try
        return theContent
    ]]
    -- ACTION: Run the script.
    local ok, result = M.runAppleScript(script, logger)
    -- SUCCESS: Return the result if it's a string.
    if ok and type(result) == "string" then
        return result
    end
    -- FAIL: Return nil on failure.
    return nil
end

-- PUBLIC METHOD: Get the current time in milliseconds since the epoch.
-- Provides a higher-resolution timestamp if `hs.timer` is available.
-- @return number The current time in milliseconds.
function M.nowMillis()
    -- CASE: Use `hs.timer.secondsSinceEpoch` for better precision if available.
    if hasTimer() and type(hs.timer.secondsSinceEpoch) == "function" then
        local seconds = hs.timer.secondsSinceEpoch()
        if type(seconds) == "number" then
            return seconds * 1000
        end
    end
    -- CASE: Fallback to `os.clock()`.
    return os.clock() * 1000
end

-- PUBLIC METHOD: Pause execution for a specified duration.
-- @param ms number The number of milliseconds to sleep.
function M.sleep(ms)
    -- ACTION: Call the internal sleep function.
    sleep(ms)
end

return M
