local pkgRoot = (...):match("^(.*)%.detectors%.date$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local defaultFormatter = require(pkgRoot .. ".formatters.date")

return function(deps)
    return DetectorFactory.create({
        id = "date_range",
        priority = 80,
        dependencies = {"patterns"},
        formatterKey = "date",
        defaultFormatter = defaultFormatter,
        requiredMethods = {"isRangeCandidate", "describeRange"}, -- date uses custom method names
        deps = deps,
    })
end
