local Registry = {}
Registry.__index = Registry

local function sortDetectors(self)
    table.sort(self.detectors, function(a, b)
        return (a.priority or 0) < (b.priority or 0)
    end)
end

function Registry.new(logger, detectors)
    local self = setmetatable({
        detectors = detectors or {},
        logger = logger,
    }, Registry)
    sortDetectors(self)
    return self
end

function Registry:register(detector)
    table.insert(self.detectors, detector)
    sortDetectors(self)
end

local function normalizeResult(result)
    if type(result) == "string" then
        return result
    elseif type(result) == "table" and result.output then
        return result.output
    end
    return result
end

function Registry:process(text, context)
    local matched, matchedId, rawResult
    if type(context) ~= "table" then
        context = {}
    end
    context.__matches = context.__matches or {}
    for _, detector in ipairs(self.detectors) do
        local ok, result = pcall(detector.match, detector, text, context)
        if ok and result then
            if self.logger and self.logger.d then
                self.logger.d(string.format("Detector '%s' matched", detector.id or "?"))
            end
            table.insert(context.__matches, { id = detector.id, raw = result })
            context.__lastMatchId = detector.id
            context.__matched = true
            if not matched then
                matched = normalizeResult(result)
                matchedId = detector.id
                rawResult = result
            end
        elseif not ok and self.logger and self.logger.e then
            self.logger.e(string.format("Detector '%s' error: %s", detector.id or "unknown", result))
        end
    end
    return matched, matchedId, rawResult
end

return Registry
