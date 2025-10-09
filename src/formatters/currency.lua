local M = {}

function M.format(number)
    local numeric = tonumber(number)
    if not numeric then
        return nil
    end

    local negative = numeric < 0
    local absNumber = math.abs(numeric)
    local rounded = math.floor(absNumber * 100 + 0.5) / 100

    local formatted
    if rounded < 1000 then
        formatted = string.format("%.2f", rounded)
    else
        local temp = string.format("%.2f", rounded)
        local whole, decimal = temp:match("(%d+)(%.%d+)")
        if whole and decimal then
            local withCommas = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            formatted = withCommas .. decimal
        else
            formatted = string.format("%.2f", rounded)
        end
    end

    if negative then
        return "-$" .. formatted
    end
    return "$" .. formatted
end

return M
