local pkgRoot = (...):match("^(.*)%.detectors%.arithmetic$")
local defaultFormatter = require(pkgRoot .. ".formatters.arithmetic")

return function(deps)
    local logger = deps and deps.logger
    local formatters = deps and deps.formatters
    return {
        id = "arithmetic",
        priority = 100,
        match = function(_, text, context)
            local formatterSource = (context and context.formatters) or formatters
            local arithmeticFormatter = (formatterSource and formatterSource.arithmetic) or defaultFormatter
            if type(arithmeticFormatter) ~= "table" then
                arithmeticFormatter = defaultFormatter
            end
            if type(arithmeticFormatter.isCandidate) ~= "function" or type(arithmeticFormatter.process) ~= "function" then
                return nil
            end
            if not arithmeticFormatter.isCandidate(text, context) then
                return nil
            end
            local ok, result = pcall(arithmeticFormatter.process, text, context)
            if not ok then
                if logger and logger.w then
                    logger.w("Arithmetic detector failed: " .. tostring(result))
                end
                return nil
            end
            return result
        end,
    }
end
