local pkgRoot = (...):match("^(.*)%.detectors%.pd$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local defaultCurrency = require(pkgRoot .. ".formatters.currency")

return function(deps)
    return DetectorFactory.createCustom({
        id = "pd_conversion",
        priority = 70,
        dependencies = {"config", "formatters"},
        deps = deps,
        customMatch = function(text, context)
            local percent = tonumber(text:upper():match("^(%d+)%%*%s*[PD]+$"))
            if not percent then
                return nil
            end
            local mapping = (context and context.pdMapping) or {}
            local weeks = mapping[percent]
            if not weeks then
                return nil
            end

            -- deps.config and deps.formatters are now injected by factory
            local benefitPerWeek = (deps.config and deps.config.pd and deps.config.pd.benefitPerWeek) or 290
            local currencyFormatter = (deps.formatters and deps.formatters.currency) or defaultCurrency
            if type(currencyFormatter) ~= "table" or type(currencyFormatter.format) ~= "function" then
                currencyFormatter = defaultCurrency
            end
            local amount = weeks * benefitPerWeek
            local formatted = currencyFormatter.format(amount)
            if not formatted then
                error("Currency formatting failed for PD amount")
            end
            return string.format("%d%% PD = %.2f weeks = %s", percent, weeks, formatted)
        end,
    })
end
