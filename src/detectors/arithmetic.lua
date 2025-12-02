local pkgRoot = (...):match("^(.*)%.detectors%.arithmetic$")
local DetectorFactory = require(pkgRoot .. ".utils.detector_factory")
local defaultFormatter = require(pkgRoot .. ".formatters.arithmetic")

return function(deps)
    return DetectorFactory.create({
        id = "arithmetic",
        priority = 100,
        formatterKey = "arithmetic",
        defaultFormatter = defaultFormatter,
        deps = deps,
    })
end
