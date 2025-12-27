--[[
WHAT THIS FILE DOES:
Provides time parsing, duration parsing, time calculation, and date arithmetic utilities.
Supports 12h (am/pm) and 24h time formats, plus date calculations.

KEY CONCEPTS:
- Time Parsing: Extract hour, minute, am/pm from various formats
- Duration Parsing: Convert duration strings to seconds
- Time Math: Add/subtract durations from times with day wrap handling
- Date Parsing: Parse dates in various formats (MM/DD/YY, M/D/YYYY, etc.)
- Date Math: Add/subtract day/week/month/year durations from dates
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

    -- Try 12h with single letter am/pm: "9a", "9p" (abbreviated format)
    local h12abbr, apabbr = lowerStr:match("^(%d+)%s*([ap])%.?$")
    if h12abbr then
        hour = tonumber(h12abbr)
        min = 0
        ampm = apabbr .. "m"  -- Normalize to "am" or "pm"
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
-- Supports both abbreviations ("2h30m", "45m", "2 h 30 m") and full words ("2 hours 30 minutes", "45 minutes", "2hours")
function M.parseDuration(durationStr)
    if not durationStr or durationStr == "" then
        return nil
    end

    local totalSeconds = 0
    local lower = durationStr:lower()

    -- Match full word units (with optional spaces)
    -- Use find with letter-check to avoid double-counting (e.g., "2h" in "2hours")
    local function matchWordUnit(pattern, multiplier)
        local pos = 1
        while true do
            local matchStart, matchEnd, num = lower:find(pattern, pos)
            if not matchStart then
                break
            end
            -- Check if followed by non-letter (or end of string)
            local nextChar = lower:sub(matchEnd + 1, matchEnd + 1)
            if nextChar == "" or not nextChar:match("[a-z]") then
                totalSeconds = totalSeconds + (tonumber(num) * multiplier)
            end
            pos = matchEnd + 1
        end
    end

    -- Hours: "hour", "hours"
    matchWordUnit("(%d+)%s*hours?", 3600)
    -- Minutes: "minute", "minutes"
    matchWordUnit("(%d+)%s*minutes?", 60)
    -- Seconds: "second", "seconds"
    matchWordUnit("(%d+)%s*seconds?", 1)

    -- Match abbreviations with optional spaces (h, m, s)
    -- Use find to ensure the unit is not followed by a letter (to avoid "12m" in "12minutes")
    local function matchUnit(pattern, multiplier)
        local pos = 1
        while true do
            local matchStart, matchEnd, num = lower:find(pattern, pos)
            if not matchStart then
                break
            end
            -- Check if followed by non-letter (or end of string)
            local nextChar = lower:sub(matchEnd + 1, matchEnd + 1)
            if nextChar == "" or not nextChar:match("[a-z]") then
                totalSeconds = totalSeconds + (tonumber(num) * multiplier)
            end
            pos = matchEnd + 1
        end
    end

    matchUnit("(%d+)%s*h", 3600)
    matchUnit("(%d+)%s*m", 60)
    matchUnit("(%d+)%s*s", 1)

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

-- ============================================================================
-- DATE ARITHMETIC
-- ============================================================================

-- Parse date string, returning year, month, day
-- Supports: MM/DD/YY, M/D/YYYY, YYYY-MM-DD, "today"
function M.parseDate(dateStr)
    if not dateStr or dateStr == "" then
        return nil
    end

    local lower = dateStr:lower()
    local trimmed = dateStr:match("^%s*(.-)%s*$")

    -- Handle "today"
    if lower == "today" then
        local today = os.date("*t")
        return today.year, today.month, today.day
    end

    -- Try ISO format: YYYY-MM-DD or YYYY/MM/DD
    local y, m, d = trimmed:match("^(%d%d%d%d)[-/](%d%d)[-/](%d%d)$")
    if y then
        return tonumber(y), tonumber(m), tonumber(d)
    end

    -- Try MM/DD/YY or M/D/YY (with 2-digit year)
    local m1, d1, y1 = trimmed:match("^(%d+)[-/](%d+)[-/](%d%d)$")
    if m1 and d1 and y1 then
        local year = tonumber(y1)
        local currentYear = tonumber(os.date("%Y")) or 2000
        local currentCentury = math.floor(currentYear / 100) * 100
        if year + currentCentury > currentYear + 30 then
            currentCentury = currentCentury - 100
        end
        return year + currentCentury, tonumber(m1), tonumber(d1)
    end

    -- Try MM/DD/YYYY or M/D/YYYY (with 4-digit year)
    local m2, d2, y2 = trimmed:match("^(%d+)[-/](%d+)[-/](%d%d%d%d)$")
    if m2 and d2 and y2 then
        return tonumber(y2), tonumber(m2), tonumber(d2)
    end

    -- Try MM/DD or M/D (no year, assume current year)
    local m3, d3 = trimmed:match("^(%d+)[-/](%d+)$")
    if m3 and d3 then
        local currentYear = tonumber(os.date("%Y")) or 2000
        return currentYear, tonumber(m3), tonumber(d3)
    end

    return nil
end

-- Parse date duration to days/weeks/months/years
-- Supports: "1 day", "2 days", "1 week", "3 weeks", "1 month", "6 months", "1 year", "2 years"
-- Also abbreviations: "1d", "2w", "1mo", "1y"
function M.parseDateDuration(durationStr)
    if not durationStr or durationStr == "" then
        return nil
    end

    local lower = durationStr:lower()
    local result = { days = 0, weeks = 0, months = 0, years = 0 }

    -- Match full word units (with optional spaces)
    local function matchWordUnit(pattern, unit, multiplier)
        local pos = 1
        while true do
            local matchStart, matchEnd, num = lower:find(pattern, pos)
            if not matchStart then
                break
            end
            -- Check if followed by non-letter (or end of string)
            local nextChar = lower:sub(matchEnd + 1, matchEnd + 1)
            if nextChar == "" or not nextChar:match("[a-z]") then
                result[unit] = result[unit] + (tonumber(num) * multiplier)
            end
            pos = matchEnd + 1
        end
    end

    -- Match full word units
    matchWordUnit("(%d+)%s*days?", "days", 1)
    matchWordUnit("(%d+)%s*weeks?", "weeks", 1)
    matchWordUnit("(%d+)%s*months?", "months", 1)
    matchWordUnit("(%d+)%s*years?", "years", 1)

    -- Match abbreviations (d, w, mo, m - careful with months vs minutes)
    local function matchAbbr(pattern, unit)
        local pos = 1
        while true do
            local matchStart, matchEnd, num = lower:find(pattern, pos)
            if not matchStart then
                break
            end
            local nextChar = lower:sub(matchEnd + 1, matchEnd + 1)
            if nextChar == "" or not nextChar:match("[a-z]") then
                result[unit] = result[unit] + tonumber(num)
            end
            pos = matchEnd + 1
        end
    end

    matchAbbr("(%d+)%s*d", "days")
    matchAbbr("(%d+)%s*w", "weeks")
    -- Use "mo" for months abbreviation to avoid conflict with "m" for minutes
    matchAbbr("(%d+)%s*mo", "months")
    matchAbbr("(%d+)%s*y", "years")

    -- Check if we found any date-related duration
    if result.days + result.weeks + result.months + result.years == 0 then
        return nil
    end

    return result
end

-- Format date as MM/DD/YYYY
function M.formatDate(year, month, day)
    return string.format("%02d/%02d/%04d", month, day, year)
end

-- Add date duration to a date
function M.addDateDuration(dateStr, durationStr)
    local year, month, day = M.parseDate(dateStr)
    if not year then
        return nil
    end

    local duration = M.parseDateDuration(durationStr)
    if not duration then
        return nil
    end

    -- Add years and months
    year = year + duration.years
    month = month + duration.months

    -- Handle month overflow
    while month > 12 do
        month = month - 12
        year = year + 1
    end
    while month < 1 do
        month = month + 12
        year = year - 1
    end

    -- Add weeks and days
    local totalDays = duration.weeks * 7 + duration.days

    -- Use os.time for proper date arithmetic
    local timestamp = os.time({
        year = year,
        month = month,
        day = day,
        hour = 12,
        min = 0,
        sec = 0,
        isdst = false,
    })

    if not timestamp then
        return nil
    end

    -- Add days (86400 seconds per day)
    timestamp = timestamp + (totalDays * 86400)

    local resultDate = os.date("*t", timestamp)
    return M.formatDate(resultDate.year, resultDate.month, resultDate.day)
end

-- Subtract date duration from a date
function M.subtractDateDuration(dateStr, durationStr)
    local year, month, day = M.parseDate(dateStr)
    if not year then
        return nil
    end

    local duration = M.parseDateDuration(durationStr)
    if not duration then
        return nil
    end

    -- Subtract years and months
    year = year - duration.years
    month = month - duration.months

    -- Handle month underflow
    while month < 1 do
        month = month + 12
        year = year - 1
    end
    while month > 12 do
        month = month - 12
        year = year + 1
    end

    -- Subtract weeks and days
    local totalDays = duration.weeks * 7 + duration.days

    -- Use os.time for proper date arithmetic
    local timestamp = os.time({
        year = year,
        month = month,
        day = day,
        hour = 12,
        min = 0,
        sec = 0,
        isdst = false,
    })

    if not timestamp then
        return nil
    end

    -- Subtract days (86400 seconds per day)
    timestamp = timestamp - (totalDays * 86400)

    local resultDate = os.date("*t", timestamp)
    return M.formatDate(resultDate.year, resultDate.month, resultDate.day)
end

return M
