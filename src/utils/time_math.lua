--[[
WHAT THIS FILE DOES:
Provides time parsing, duration parsing, and time calculation utilities.
Supports 12h (am/pm) and 24h time formats.

KEY CONCEPTS:
- Time Parsing: Extract hour, minute, am/pm from various formats
- Duration Parsing: Convert duration strings to seconds
- Time Math: Add/subtract durations from times with day wrap handling
]]

local M = {}

-- Parse time string, returning hour, minute, ampm (ampm is nil for 24h)
function M.parseTime(timeStr)
    if not timeStr or timeStr == "" then
        return nil
    end

    local hour, min, ampm
    local lowerStr = timeStr:lower()

    -- Try 12h format with minutes: "9:30am", "9:30 am", "9:30 a.m."
    local h12, m12, ap = lowerStr:match("^(%d+):(%d+)%s*([ap]m)%.?$")
    if h12 then
        hour = tonumber(h12)
        min = tonumber(m12)
        ampm = ap
        return hour, min, ampm
    end

    -- Try 12h with dots: "9:30 a.m."
    local h12d, m12d = lowerStr:match("^(%d+):(%d+)%s*a%.m%.?$")
    if h12d then
        return tonumber(h12d), tonumber(m12d), "am"
    end

    local h12d2, m12d2 = lowerStr:match("^(%d+):(%d+)%s*p%.m%.?$")
    if h12d2 then
        return tonumber(h12d2), tonumber(m12d2), "pm"
    end

    -- Try 12h without minutes: "9am", "9 pm"
    local h12only, ap2 = lowerStr:match("^(%d+)%s*([ap]m)%.?$")
    if h12only then
        hour = tonumber(h12only)
        min = 0
        ampm = ap2
        return hour, min, ampm
    end

    -- Try 12h without minutes with dots: "9 a.m."
    local h12d3 = lowerStr:match("^(%d+)%s*a%.m%.?$")
    if h12d3 then
        return tonumber(h12d3), 0, "am"
    end

    local h12d4 = lowerStr:match("^(%d+)%s*p%.m%.?$")
    if h12d4 then
        return tonumber(h12d4), 0, "pm"
    end

    -- Try 24h format: "14:30", "9:00"
    local h24, m24 = timeStr:match("^(%d+):(%d+)$")
    if h24 then
        hour = tonumber(h24)
        min = tonumber(m24)
        return hour, min, nil
    end

    return nil
end

-- Parse duration string to seconds
function M.parseDuration(durationStr)
    if not durationStr or durationStr == "" then
        return nil
    end

    local totalSeconds = 0

    -- Match patterns like "2h30m", "45m", "1h"
    for hours in durationStr:gmatch("(%d+)h") do
        totalSeconds = totalSeconds + (tonumber(hours) * 3600)
    end
    for mins in durationStr:gmatch("(%d+)m") do
        totalSeconds = totalSeconds + (tonumber(mins) * 60)
    end
    for secs in durationStr:gmatch("(%d+)s") do
        totalSeconds = totalSeconds + tonumber(secs)
    end

    if totalSeconds == 0 then
        return nil
    end

    return totalSeconds
end

-- Convert parsed time to seconds since midnight
local function timeToSeconds(hour, min, ampm)
    local h = hour
    if ampm == "pm" and h ~= 12 then
        h = h + 12
    elseif ampm == "am" and h == 12 then
        h = 0
    end
    return h * 3600 + min * 60
end

-- Convert seconds since midnight to formatted time string
local function secondsToTime(seconds, useAmPm)
    local secsPerDay = 86400
    local days = math.floor(seconds / secsPerDay)
    local secsInDay = seconds % secsPerDay

    local h = math.floor(secsInDay / 3600)
    local m = math.floor((secsInDay % 3600) / 60)

    if useAmPm then
        local ampm = h >= 12 and "PM" or "AM"
        local displayH = h
        if h == 0 then
            displayH = 12
        elseif h > 12 then
            displayH = h - 12
        end
        return string.format("%d:%02d %s", displayH, m, ampm)
    else
        return string.format("%d:%02d", h, m)
    end
end

-- Add duration to time, return formatted result
function M.addDuration(timeStr, durationStr)
    local hour, min, ampm = M.parseTime(timeStr)
    if not hour then
        return nil
    end

    local durationSecs = M.parseDuration(durationStr)
    if not durationSecs then
        return nil
    end

    local timeSecs = timeToSeconds(hour, min, ampm)
    local resultSecs = timeSecs + durationSecs

    local useAmPm = (ampm ~= nil)
    return secondsToTime(resultSecs, useAmPm)
end

-- Subtract duration from time
function M.subtractDuration(timeStr, durationStr)
    local hour, min, ampm = M.parseTime(timeStr)
    if not hour then
        return nil
    end

    local durationSecs = M.parseDuration(durationStr)
    if not durationSecs then
        return nil
    end

    local timeSecs = timeToSeconds(hour, min, ampm)
    local resultSecs = timeSecs - durationSecs

    -- Handle negative (wrap to previous day)
    if resultSecs < 0 then
        resultSecs = resultSecs + 86400
    end

    local useAmPm = (ampm ~= nil)
    return secondsToTime(resultSecs, useAmPm)
end

return M
