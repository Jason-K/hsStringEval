local pkgRoot = (...):match("^(.*)%.detectors%.combinations$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")

local function isCombinationCandidate(text)
    if not text or text == "" then return false end
    if not text:find("[cC]") then return false end
    local stripped = text:gsub("[%d%s_cC%%]", "")
    return stripped == "" or #stripped <= 2
end

local function buildCombinationString(values)
    table.sort(values, function(a, b) return a > b end)
    local running = values[1] / 100
    local parts = { string.format("%d%%", values[1]) }
    for i = 2, #values do
        local pct = values[i] / 100
        running = running + pct * (1 - running)
        local runningPct = math.floor(running * 100 + 0.5)
        table.insert(parts, string.format(" c %d%% = %d%%", values[i], runningPct))
    end
    return table.concat(parts)
end

return function(deps)
    return DetectorFactory.createCustom({
        id = "combinations",
        priority = 60,
        deps = deps,
        customMatch = function(text, context)
            if not isCombinationCandidate(text) then
                return nil
            end
            local numbers = {}
            for num in text:gmatch("%d+") do
                table.insert(numbers, tonumber(num))
            end
            if #numbers < 2 then
                return nil
            end
            local ok, output = pcall(buildCombinationString, numbers)
            if not ok then
                error("Combination detector failed: " .. tostring(output))
            end
            return output
        end,
    })
end
