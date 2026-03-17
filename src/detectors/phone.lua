local pkgRoot = (...):match("^(.*)%.detectors%.phone$")
local DetectorFactory = require(pkgRoot and (pkgRoot .. ".utils.detector_factory") or "utils.detector_factory")
local defaultFormatter = require(pkgRoot and (pkgRoot .. ".formatters.phone") or "formatters.phone")

return function(deps)
    return DetectorFactory.create({
        id = "phone",
        priority = 50,
        dependencies = {"patterns"},
        patternDependencies = {"phone_semicolon"},
        formatterKey = "phone",
        defaultFormatter = defaultFormatter,
        requiredMethods = {"isCandidate", "format"}, -- phone uses "format" instead of "process"
        deps = deps,
    })
end
