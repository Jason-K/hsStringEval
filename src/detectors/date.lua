local pkgRoot = (...):match("^(.*)%.detectors%.date$")
local DetectorFactory = require(pkgRoot and (pkgRoot .. ".utils.detector_factory") or "utils.detector_factory")
local defaultFormatter = require(pkgRoot and (pkgRoot .. ".formatters.date") or "formatters.date")

return function(deps)
    return DetectorFactory.create({
        id = "date_range",
        priority = 80,
        dependencies = {"patterns"},
        patternDependencies = {"date_token", "date_token_iso", "date_token_text"},
        formatterKey = "date",
        defaultFormatter = defaultFormatter,
        requiredMethods = {"isRangeCandidate", "describeRange"}, -- date uses custom method names
        deps = deps,
    })
end
