local pkgRoot = (...):match("^(.*)%.detectors%.units$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local unitFormatter = require(pkgRoot .. ".formatters.unit")

local function isConversionCandidate(text)
    if not text or text == "" then return false end
    -- Pattern: number + unit + (to|in) + unit
    local connector = text:match("^[%d%.,]+%s*[a-zA-Z]+%s+([a-zA-Z]+)%s+[a-zA-Z]+$")
    return connector == "to" or connector == "in"
end

return function(deps)
    return DetectorFactory.createCustom({
        id = "units",
        priority = 80,
        dependencies = {},
        deps = deps,
        customMatch = function(text, context)
            if not isConversionCandidate(text) then
                return nil
            end

            -- Parse: "100km to mi" or "100km in mi"
            local valueStr, fromUnit, connector, toUnit = text:match("^([%d%.,]+)%s*([a-zA-Z]+)%s+([a-zA-Z]+)%s+([a-zA-Z]+)$")
            if not valueStr or not fromUnit or not toUnit then
                return nil
            end

            -- Verify connector is "to" or "in"
            if connector ~= "to" and connector ~= "in" then
                return nil
            end

            local result = unitFormatter.formatConversion(valueStr, fromUnit, toUnit)
            if not result then
                return nil
            end

            return result
        end
    })
end
