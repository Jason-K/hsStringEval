local pkgRoot = (...):match("^(.*)%.formatters%.unit$")

local M = {}

-- Conversion factors to base unit
local conversions = {
    -- Length (base: meter)
    length = {
        m = { toBase = 1, fromBase = 1 },
        km = { toBase = 1000, fromBase = 0.001 },
        mi = { toBase = 1609.344, fromBase = 0.000621371 },
        ft = { toBase = 0.3048, fromBase = 3.28084 },
        ["in"] = { toBase = 0.0254, fromBase = 39.3701 },
        cm = { toBase = 0.01, fromBase = 100 },
        mm = { toBase = 0.001, fromBase = 1000 },
    },
    -- Weight (base: kilogram)
    weight = {
        kg = { toBase = 1, fromBase = 1 },
        g = { toBase = 0.001, fromBase = 1000 },
        lb = { toBase = 0.453592, fromBase = 2.20462 },
        oz = { toBase = 0.0283495, fromBase = 35.274 },
    },
    -- Temperature (special formulas)
    temperature = {
        C = { toF = function(c) return c * 9/5 + 32 end, fromF = function(f) return (f - 32) * 5/9 end },
        F = { toF = function(f) return f end, fromF = function(f) return f end },
        K = { toF = function(k) return k * 9/5 - 459.67 end, fromF = function(f) return (f + 459.67) * 5/9 end },
    },
    -- Data (base: byte)
    data = {
        MB = { toBase = 1000000, fromBase = 0.000001 },
        GB = { toBase = 1000000000, fromBase = 0.000000001 },
        TB = { toBase = 1000000000000, fromBase = 0.000000000001 },
    },
    -- Speed (base: m/s)
    speed = {
        mph = { toBase = 0.44704, fromBase = 2.23694 },
        kph = { toBase = 0.277778, fromBase = 3.6 },
        ["m/s"] = { toBase = 1, fromBase = 1 },
    },
}

-- Unit to category mapping
local unitCategories = {
    m = "length", km = "length", mi = "length", ft = "length",
    ["in"] = "length", cm = "length", mm = "length",
    kg = "weight", g = "weight", lb = "weight", oz = "weight",
    C = "temperature", F = "temperature", K = "temperature",
    MB = "data", GB = "data", TB = "data",
    mph = "speed", kph = "speed", ["m/s"] = "speed",
}

function M.convert(value, fromUnit, toUnit)
    local fromCat = unitCategories[fromUnit]
    local toCat = unitCategories[toUnit]

    if not fromCat or not toCat or fromCat ~= toCat then
        return nil, "incompatible units"
    end

    local numericValue = tonumber(value)
    if not numericValue then
        return nil, "invalid value"
    end

    local category = conversions[fromCat]

    -- Temperature special handling
    if fromCat == "temperature" then
        local f = category[fromUnit].toF(numericValue)
        local result = category[toUnit].fromF(f)
        return result
    end

    -- Standard conversion through base unit
    local fromFactor = category[fromUnit].toBase
    local toFactor = category[toUnit].fromBase
    local baseValue = numericValue * fromFactor
    local result = baseValue * toFactor

    return result
end

function M.formatConversion(value, fromUnit, toUnit)
    local result, err = M.convert(value, fromUnit, toUnit)
    if err then
        return nil, err
    end

    -- Format with appropriate precision
    local formatted
    if math.abs(result) < 0.01 then
        formatted = string.format("%.6g", result)
    elseif math.abs(result) >= 1000 then
        formatted = string.format("%.2f", result)
    else
        formatted = string.format("%.2f", result)
        -- Remove trailing zeros
        formatted = formatted:gsub("%.?0+$", "")
    end

    return formatted .. " " .. toUnit
end

return M
