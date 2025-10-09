local pkgRoot = (...):match("^(.*)%.detectors%.pd$")
local defaultCurrency = require(pkgRoot .. ".formatters.currency")

return function(deps)
    local logger = deps and deps.logger
    local benefitPerWeek = (deps and deps.config and deps.config.pd and deps.config.pd.benefitPerWeek) or 290
    local formatters = deps and deps.formatters

    return {
        id = "pd_conversion",
        priority = 70,
        match = function(_, text, context)
            local percent = tonumber(text:upper():match("^(%d+)%%*%s*[PD]+$"))
            if not percent then
                return nil
            end
            local mapping = (context and context.pdMapping) or {}
            local weeks = mapping[percent]
            if not weeks then
                return nil
            end
            local formatterSource = (context and context.formatters) or formatters
            local currencyFormatter = (formatterSource and formatterSource.currency) or defaultCurrency
            if type(currencyFormatter) ~= "table" or type(currencyFormatter.format) ~= "function" then
                currencyFormatter = defaultCurrency
            end
            local amount = weeks * benefitPerWeek
            local formatted = currencyFormatter.format(amount)
            if not formatted then
                if logger and logger.w then
                    logger.w("Currency formatting failed for PD amount")
                end
                return nil
            end
            return string.format("%d%% PD = %.2f weeks = %s", percent, weeks, formatted)
        end,
    }
end
