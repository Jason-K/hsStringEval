local pkgRoot = (...):match("^(.*)%.detectors%.phone$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local defaultFormatter = require(pkgRoot .. ".formatters.phone")

return function(deps)
    return DetectorFactory.create({
        id = "phone",
        priority = 50,
        formatterKey = "phone",
        defaultFormatter = defaultFormatter,
        requiredMethods = {"isCandidate", "format"}, -- phone uses "format" instead of "process"
        deps = deps,
    })
end
