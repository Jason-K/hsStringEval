local pkgRoot = (...):match("^(.*)%.utils%.detector_factory$")

local DetectorFactory = {}

-- Default error handler for detectors
local function defaultErrorHandler(detectorId, error, logger)
    if logger and logger.w then
        logger.w(("%s detector failed: %s"):format(detectorId, tostring(error)))
    end
    return nil
end

-- Default formatter resolver that handles fallback logic
local function defaultFormatterResolver(formatterKey, context, formatters, defaultFormatter)
    local formatterSource = (context and context.formatters) or formatters
    local formatter = (formatterSource and formatterSource[formatterKey]) or defaultFormatter

    if type(formatter) ~= "table" then
        formatter = defaultFormatter
    end

    return formatter
end

-- Validate that required formatter methods exist
local function validateFormatter(formatter, requiredMethods)
    if type(formatter) ~= "table" then
        return false, "Formatter is not a table"
    end

    for _, method in ipairs(requiredMethods) do
        if type(formatter[method]) ~= "function" then
            return false, ("Missing required method: %s"):format(method)
        end
    end

    return true, nil
end

-- Create a standardized detector with common validation and error handling
function DetectorFactory.create(config)
    -- Validate required parameters
    if type(config) ~= "table" then
        error("DetectorFactory.create requires a config table")
    end

    local id = config.id
    local priority = config.priority or 100
    local formatterKey = config.formatterKey
    local requiredMethods = config.requiredMethods or {"isCandidate", "process"}
    local defaultFormatter = config.defaultFormatter
    local candidateCheck = config.candidateCheck
    local processFn = config.processFn
    local customMatch = config.customMatch
    local errorHandler = config.errorHandler or defaultErrorHandler
    local formatterResolver = config.formatterResolver or defaultFormatterResolver

    if not id then
        error("DetectorFactory.create requires an id")
    end

    if not formatterKey then
        error("DetectorFactory.create requires a formatterKey")
    end

    if not defaultFormatter then
        error("DetectorFactory.create requires a defaultFormatter")
    end

    -- Return the standardized detector
    return {
        id = id,
        priority = priority,
        match = function(_, text, context)
            -- Use custom match function if provided, otherwise use standard pattern
            if customMatch then
                return customMatch(text, context, {
                    formatterResolver = formatterResolver,
                    errorHandler = errorHandler,
                    validateFormatter = validateFormatter
                })
            end

            -- Standard detector pattern
            local logger = (context and context.logger) or (config.deps and config.deps.logger)
            local formatters = (context and context.formatters) or (config.deps and config.deps.formatters)

            -- Resolve formatter using the resolver function
            local formatter = formatterResolver(formatterKey, context, formatters, defaultFormatter)

            -- Validate formatter has required methods
            local isValid, validationError = validateFormatter(formatter, requiredMethods)
            if not isValid then
                return errorHandler(id, validationError, logger)
            end

            -- Check if text is a candidate
            if candidateCheck then
                local isCandidate = candidateCheck(text, context, formatter)
                if not isCandidate then
                    return nil
                end
            elseif requiredMethods[1] == "isCandidate" then
                -- Default candidate check using formatter
                if not formatter.isCandidate(text, context) then
                    return nil
                end
            elseif requiredMethods[1] == "isRangeCandidate" then
                -- Special case for date range detector
                if not formatter.isRangeCandidate(text, context) then
                    return nil
                end
            end

            -- Process the text
            local processFunction = processFn
            if not processFunction then
                -- Determine the right process method based on required methods
                if requiredMethods[2] == "describeRange" then
                    processFunction = formatter.describeRange
                elseif requiredMethods[2] == "format" then
                    processFunction = formatter.format
                else
                    processFunction = formatter.process
                end
            end
            local ok, result = pcall(processFunction, text, context)

            if not ok then
                return errorHandler(id, result, logger)
            end

            return result
        end,
    }
end

-- Create a detector with custom logic (for complex detectors like navigation)
function DetectorFactory.createCustom(config)
    if type(config) ~= "table" then
        error("DetectorFactory.createCustom requires a config table")
    end

    local id = config.id
    local priority = config.priority or 100
    local customMatch = config.customMatch

    if not id then
        error("DetectorFactory.createCustom requires an id")
    end

    if not customMatch then
        error("DetectorFactory.createCustom requires a customMatch function")
    end

    return {
        id = id,
        priority = priority,
        match = function(_, text, context)
            local logger = (context and context.logger) or (config.deps and config.deps.logger)
            local ok, result = pcall(customMatch, text, context)

            if not ok then
                if logger and logger.w then
                    logger.w(("%s detector failed: %s"):format(id, tostring(result)))
                end
                return nil
            end

            return result
        end,
    }
end

return DetectorFactory
