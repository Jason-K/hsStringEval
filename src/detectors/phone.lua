local pkgRoot = (...):match("^(.*)%.detectors%.phone$")
local defaultFormatter = require(pkgRoot .. ".formatters.phone")

return function(deps)
    local logger = deps and deps.logger
    local formatters = deps and deps.formatters
    return {
        id = "phone",
        priority = 50,
        match = function(_, text, context)
            local formatterSource = (context and context.formatters) or formatters
            local phoneFormatter = (formatterSource and formatterSource.phone) or defaultFormatter
            if type(phoneFormatter) ~= "table" then
                phoneFormatter = defaultFormatter
            end
            if type(phoneFormatter.isCandidate) ~= "function" or type(phoneFormatter.format) ~= "function" then
                return nil
            end
            if not phoneFormatter.isCandidate(text, context) then
                return nil
            end
            local ok, result = pcall(phoneFormatter.format, text, context)
            if not ok then
                if logger and logger.w then
                    logger.w("Phone detector failed: " .. tostring(result))
                end
                return nil
            end
            return result
        end,
    }
end
