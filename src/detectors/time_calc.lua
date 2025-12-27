local pkgRoot = (...):match("^(.*)%.detectors%.time_calc$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local TimeMath = require(pkgRoot .. ".utils.time_math")

local function isTimeCalcCandidate(text)
    if not text or text == "" then return false end
    -- Check for "now" or time patterns
    if text:lower():find("^now%s*[+-]") then
        return true
    end
    -- Check for time + duration pattern
    -- Support: "12am", "12 am", "12 AM", "12a", "12:30", "12:30am", "12:30 am"
    local hasTime = text:match("%d+%s*[apAP][mM]?") or text:match("%d+:%d+%s*[apAP][mM]?") or text:match("%d+:%d+")
    local lower = text:lower()
    -- Check for both abbreviations (h, m, s, with optional spaces) and full words (hours, minutes, seconds)
    -- Also match when there's no space after the unit (e.g., "13hours" at end of string)
    local hasDuration = lower:match("%d+%s*[hms][%s$]*") or lower:match("%d+%s*hours?[%s$]*") or
                        lower:match("%d+%s*minutes?[%s$]*") or lower:match("%d+%s*seconds?[%s$]*")
    local hasOperator = text:match("[+-]")
    return hasTime and hasDuration and hasOperator
end

local function isDateCalcCandidate(text)
    if not text or text == "" then return false end
    local lower = text:lower()

    -- Check for "today" (case-insensitive) with operator
    if lower:find("^today%s*[+-]") then
        return true
    end

    -- Check for date pattern (MM/DD/YY, YYYY-MM-DD, etc.) with operator
    -- Note: In Lua character class, - must be at the end or escaped to avoid range interpretation
    local hasDate = text:match("%d%d?%s*[/%-.]%s*%d%d?") or text:match("%d%d%d%d%s*[/%-.]%s*%d%d?")
    local hasDateOperator = text:match("[+-]")
    -- Check for date duration (days, weeks, months, years, d, w, mo, y)
    -- Note: Match with optional trailing space or end of string
    local hasDateDuration = lower:match("%d+%s*days?") or lower:match("%d+%s*weeks?") or
                           lower:match("%d+%s*months?") or lower:match("%d+%s*years?") or
                           lower:match("%d+%s*d[%s$]*") or lower:match("%d+%s*w[%s$]*") or
                           lower:match("%d+%s*mo[%s$]*") or lower:match("%d+%s*y[%s$]*")

    return hasDate and hasDateOperator and hasDateDuration
end

return function(deps)
    return DetectorFactory.createCustom({
        id = "time_calc",
        priority = 90,
        dependencies = {},
        deps = deps,
        customMatch = function(text, context)
            local trimmed = text:match("^%s*(.-)%s*$")
            local lower = trimmed:lower()

            -- Check if this is a date calculation first
            if isDateCalcCandidate(text) then
                -- Handle "today +/- duration" (case-insensitive)
                if lower:match("^today%s*[+-]%s*[%w%s]+$") then
                    local op, duration = lower:match("^today%s*([+-])%s*([%w%s]+)$")
                    if op and duration then
                        local result
                        if op == "+" then
                            result = TimeMath.addDateDuration("today", duration)
                        else
                            result = TimeMath.subtractDateDuration("today", duration)
                        end
                        if result then
                            return result
                        end
                    end
                end

                -- Handle "MM/DD/YYYY +/- duration" (4-digit year at the end)
                local dateStr4, op4, durationStr4 = trimmed:match("^(%d%d?%s*[/%-.]%s*%d%d?%s*[/%-.]%s*%d%d%d%d)%s*([+-])%s*([%w%s]+)$")
                if dateStr4 and op4 and durationStr4 then
                    -- Normalize date by removing spaces around separators
                    dateStr4 = dateStr4:gsub("%s*([/%-.])%s*", "%1")
                    local result
                    if op4 == "+" then
                        result = TimeMath.addDateDuration(dateStr4, durationStr4)
                    else
                        result = TimeMath.subtractDateDuration(dateStr4, durationStr4)
                    end
                    if result then
                        return result
                    end
                end

                -- Handle "MM/DD/YY +/- duration" or "YYYY-MM-DD +/- duration"
                -- First try: YYYY-MM-DD format (4-digit year first)
                local dateStr, op, durationStr = trimmed:match("^(%d%d%d%d%s*[/%-.]%s*%d%d?%s*[/%-.]%s*%d%d?)%s*([+-])%s*([%w%s]+)$")
                if dateStr and op and durationStr then
                    -- Normalize date by removing spaces around separators
                    dateStr = dateStr:gsub("%s*([/%-.])%s*", "%1")
                    local result
                    if op == "+" then
                        result = TimeMath.addDateDuration(dateStr, durationStr)
                    else
                        result = TimeMath.subtractDateDuration(dateStr, durationStr)
                    end
                    if result then
                        return result
                    end
                end

                -- Second try: MM/DD/YY format (2-digit year at the end)
                dateStr, op, durationStr = trimmed:match("^(%d%d?%s*[/%-.]%s*%d%d?%s*[/%-.]%s*%d%d)%s*([+-])%s*([%w%s]+)$")
                if dateStr and op and durationStr then
                    -- Normalize date by removing spaces around separators
                    dateStr = dateStr:gsub("%s*([/%-.])%s*", "%1")
                    local result
                    if op == "+" then
                        result = TimeMath.addDateDuration(dateStr, durationStr)
                    else
                        result = TimeMath.subtractDateDuration(dateStr, durationStr)
                    end
                    if result then
                        return result
                    end
                end

                -- Handle "MM/DD +/- duration" (no year)
                local dateStr2, op2, durationStr2 = trimmed:match("^(%d%d?%s*[/%-.]%s*%d%d?)%s*([+-])%s*([%w%s]+)$")
                if dateStr2 and op2 and durationStr2 then
                    -- Check if this is actually a 2-part date (not 3-part that was already handled)
                    -- A 3-part date would have another separator
                    if not dateStr2:match("[/%-.].*[/%-.]") then
                        dateStr2 = dateStr2:gsub("%s*([/%-.])%s*", "%1")
                        local result
                        if op2 == "+" then
                            result = TimeMath.addDateDuration(dateStr2, durationStr2)
                        else
                            result = TimeMath.subtractDateDuration(dateStr2, durationStr2)
                        end
                        if result then
                            return result
                        end
                    end
                end
            end

            -- Check if this is a time calculation
            if not isTimeCalcCandidate(text) then
                return nil
            end

            -- Handle "now +/- duration" (supports both "12m" and "12 minutes")
            if lower:match("^now%s*[+-]%s*[%w%s]+$") then
                local op, duration = trimmed:match("^now%s*([+-])%s*([%w%s]+)$")
                if not op or not duration then
                    return nil
                end

                local nowStr = os.date("%H:%M")
                local result
                if op == "+" then
                    result = TimeMath.addDuration(nowStr, duration)
                else
                    result = TimeMath.subtractDuration(nowStr, duration)
                end

                if result then
                    return result
                end
            end

            -- Handle "HH:MM +/- duration" (24-hour format, supports both abbreviations and full words)
            local timeStr, op, durationStr = trimmed:match("^(%d+:%d+)%s*([+-])%s*([%w%s]+)$")
            if timeStr and op and durationStr then
                local result
                if op == "+" then
                    result = TimeMath.addDuration(timeStr, durationStr)
                else
                    result = TimeMath.subtractDuration(timeStr, durationStr)
                end

                if result then
                    return result
                end
            end

            -- Handle "HH:MM am/pm +/- duration" (12-hour with minutes, supports both abbreviations and full words)
            local timeHM, ampm, op1a, durationStr1a = trimmed:match("^(%d+:%d+)%s*([apAP][mM])%s*([+-])%s*([%w%s]+)$")
            if timeHM and ampm and op1a and durationStr1a then
                local time12 = timeHM .. ampm
                local result
                if op1a == "+" then
                    result = TimeMath.addDuration(time12, durationStr1a)
                else
                    result = TimeMath.subtractDuration(time12, durationStr1a)
                end

                if result then
                    return result
                end
            end

            -- Handle "HH:MM am/pm+duration" (12-hour with minutes, no space before operator)
            local timeHM2, ampm2b, op1b, durationStr1b = trimmed:match("^(%d+:%d+)%s*([apAP][mM])([+-])%s*([%w%s]+)$")
            if timeHM2 and ampm2b and op1b and durationStr1b then
                local time12b = timeHM2 .. ampm2b
                local result
                if op1b == "+" then
                    result = TimeMath.addDuration(time12b, durationStr1b)
                else
                    result = TimeMath.subtractDuration(time12b, durationStr1b)
                end

                if result then
                    return result
                end
            end

            -- Handle "Ham/pm +/- duration" (12-hour format without minutes, supports both abbreviations and full words)
            local hour, ampm2, op2, durationStr2 = trimmed:match("^(%d+)%s*([apAP][mM])%s*([+-])%s*([%w%s]+)$")
            if hour and ampm2 and op2 and durationStr2 then
                local time12 = hour .. ampm2
                local result
                if op2 == "+" then
                    result = TimeMath.addDuration(time12, durationStr2)
                else
                    result = TimeMath.subtractDuration(time12, durationStr2)
                end

                if result then
                    return result
                end
            end

            -- Handle "Ham/pm+duration" (12-hour format without minutes, no space before operator)
            local hour2b, ampm2c, op2b, durationStr2b = trimmed:match("^(%d+)%s*([apAP][mM])([+-])%s*([%w%s]+)$")
            if hour2b and ampm2c and op2b and durationStr2b then
                local time12b = hour2b .. ampm2c
                local result
                if op2b == "+" then
                    result = TimeMath.addDuration(time12b, durationStr2b)
                else
                    result = TimeMath.subtractDuration(time12b, durationStr2b)
                end

                if result then
                    return result
                end
            end

            -- Handle "Ha/p +/- duration" (12-hour format with single-letter am/pm abbreviation, e.g., "12a + 13 hours")
            local hour3, ampm3, op3, durationStr3 = trimmed:match("^(%d+)%s*([apAP])%s*([+-])%s*([%w%s]+)$")
            if hour3 and ampm3 and op3 and durationStr3 then
                local time12abbr = hour3 .. ampm3 .. "m"  -- Normalize to "12am" format
                local result
                if op3 == "+" then
                    result = TimeMath.addDuration(time12abbr, durationStr3)
                else
                    result = TimeMath.subtractDuration(time12abbr, durationStr3)
                end

                if result then
                    return result
                end
            end

            -- Handle "Ha/p+duration" (12-hour format with single-letter am/pm, no space before operator)
            local hour3b, ampm3b, op3b, durationStr3b = trimmed:match("^(%d+)%s*([apAP])([+-])%s*([%w%s]+)$")
            if hour3b and ampm3b and op3b and durationStr3b then
                local time12abbrb = hour3b .. ampm3b .. "m"  -- Normalize to "12am" format
                local result
                if op3b == "+" then
                    result = TimeMath.addDuration(time12abbrb, durationStr3b)
                else
                    result = TimeMath.subtractDuration(time12abbrb, durationStr3b)
                end

                if result then
                    return result
                end
            end

            return nil
        end
    })
end
