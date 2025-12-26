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
    local hasTime = text:match("%d+[ap]m") or text:match("%d+:%d+")
    local hasDuration = text:match("%d+[hms]")
    local hasOperator = text:match("[+-]")
    return hasTime and hasDuration and hasOperator
end

return function(deps)
    return DetectorFactory.createCustom({
        id = "time_calc",
        priority = 90,
        dependencies = {},
        deps = deps,
        customMatch = function(text, context)
            if not isTimeCalcCandidate(text) then
                return nil
            end

            local trimmed = text:match("^%s*(.-)%s*$")
            local lower = trimmed:lower()

            -- Handle "now +/- duration"
            if lower:match("^now%s*[+-]%s*[%d+hms]+$") then
                local op, duration = trimmed:match("^now%s*([+-])%s*([%d%ahms]+)$")
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

            -- Handle "HH:MM +/- duration" (24-hour format)
            local timeStr, op, durationStr = trimmed:match("^(%d+:%d+)%s*([+-])%s*([%d%ahms]+)$")
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

            -- Handle "Hham/pm +/- duration" (12-hour format)
            local hour, ampm, op2, durationStr2 = trimmed:match("^(%d+)%s*([ap]m)%s*([+-])%s*([%d%ahms]+)$")
            if hour and ampm and op2 and durationStr2 then
                local time12 = hour .. ampm
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

            return nil
        end
    })
end
