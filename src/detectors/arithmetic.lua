local pkgRoot = (...):match("^(.*)%.detectors%.arithmetic$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local defaultFormatter = require(pkgRoot .. ".formatters.arithmetic")

return function(deps)
    return DetectorFactory.create({
        id = "arithmetic",
        priority = 100,
        dependencies = {"patterns"},
        patternDependencies = {"arithmetic_candidate", "date_full", "localized_number", "percentage_of", "percentage_add", "percentage_sub"},
        formatterKey = "arithmetic",
        defaultFormatter = defaultFormatter,
        deps = deps,
    })
end
