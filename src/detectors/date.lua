local pkgRoot = (...):match("^(.*)%.detectors%.date$")
local defaultFormatter = require(pkgRoot .. ".formatters.date")

return function(deps)
    local logger = deps and deps.logger
    local formatters = deps and deps.formatters
    return {
        id = "date_range",
        priority = 80,
        match = function(_, text, context)
            local formatterSource = (context and context.formatters) or formatters
            local dateFormatter = (formatterSource and formatterSource.date) or defaultFormatter
            if type(dateFormatter) ~= "table" then
                dateFormatter = defaultFormatter
            end
            if type(dateFormatter.isRangeCandidate) ~= "function" or type(dateFormatter.describeRange) ~= "function" then
                return nil
            end
            if not dateFormatter.isRangeCandidate(text, context) then
                return nil
            end
            local ok, result = pcall(dateFormatter.describeRange, text, context)
            if not ok then
                if logger and logger.w then
                    logger.w("Date detector failed: " .. tostring(result))
                end
                return nil
            end
            return result
        end,
    }
end
