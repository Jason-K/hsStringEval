local pkgRoot = (...):match("^(.*)%.config%.manager$")

local ConfigManager = {}

-- Valid logger levels
local VALID_LOGGER_LEVELS = {
    debug = true,
    info = true,
    warn = true,
    warning = true,
    error = true,
}

-- Configuration validation schema
local CONFIG_VALIDATORS = {
    -- Core logging configuration
    loggerLevel = function(value)
        if type(value) ~= "string" then
            return false, "loggerLevel must be a string"
        end
        local normalized = value:lower()
        if not VALID_LOGGER_LEVELS[normalized] then
            local validLevels = {}
            for level, _ in pairs(VALID_LOGGER_LEVELS) do
                table.insert(validLevels, level)
            end
            return false, ("loggerLevel must be one of: %s"):format(table.concat(validLevels, ", "))
        end
        return true, nil
    end,

    -- Throttle configuration
    throttleMs = function(value)
        if type(value) ~= "number" then
            return false, "throttleMs must be a number"
        end
        if value < 0 then
            return false, "throttleMs must be non-negative"
        end
        return true, nil
    end,

    -- Selection timing configuration
    selection = function(config)
        if type(config) ~= "table" then
            return false, "selection must be a table"
        end

        local numericFields = {
            "waitAfterClearMs", "modifierCheckInterval", "copyDelayMs",
            "pasteDelayMs", "pollIntervalMs", "maxPolls"
        }

        for _, field in ipairs(numericFields) do
            if config[field] ~= nil then
                if type(config[field]) ~= "number" or config[field] < 0 then
                    return false, ("selection.%s must be a non-negative number"):format(field)
                end
            end
        end

        if config.retryWithEventtap ~= nil and type(config.retryWithEventtap) ~= "boolean" then
            return false, "selection.retryWithEventtap must be a boolean"
        end

        return true, nil
    end,

    -- PD configuration
    pd = function(config)
        if type(config) ~= "table" then
            return false, "pd must be a table"
        end

        if config.benefitPerWeek ~= nil then
            if type(config.benefitPerWeek) ~= "number" or config.benefitPerWeek <= 0 then
                return false, "pd.benefitPerWeek must be a positive number"
            end
        end

        local pathFields = {"bundledFile", "legacyFile", "fallbackPath"}
        for _, field in ipairs(pathFields) do
            if config[field] ~= nil and type(config[field]) ~= "string" then
                return false, ("pd.%s must be a string"):format(field)
            end
        end

        return true, nil
    end,

    -- Hotkey configuration
    hotkeys = function(config)
        if type(config) ~= "table" then
            return false, "hotkeys must be a table"
        end

        if config.installHelpers ~= nil and type(config.installHelpers) ~= "boolean" then
            return false, "hotkeys.installHelpers must be a boolean"
        end

        return true, nil
    end,

    -- Template configuration
    templates = function(config)
        if type(config) ~= "table" then
            return false, "templates must be a table"
        end

        if config.arithmetic ~= nil and type(config.arithmetic) ~= "string" then
            return false, "templates.arithmetic must be a string"
        end

        return true, nil
    end,

    -- Logging structure configuration (defined later to avoid forward reference)
    logging = function(config) end,

    -- General boolean configuration
    restoreClipboard = function(value)
        if value ~= nil and type(value) ~= "boolean" then
            return false, "restoreClipboard must be a boolean"
        end
        return true, nil
    end,
}

-- Deep copy function for tables
local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
        setmetatable(copy, deepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Helper function to get table keys
local function getKeys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

-- Check if a table is a list (has numeric indices starting from 1)
local function isList(t)
    if type(t) ~= "table" then
        return false
    end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then
            return false
        end
    end
    return true
end

-- Normalize configuration values
local function normalizeConfig(config)
    local normalized = {}

    for key, value in pairs(config) do
        if key == "loggerLevel" and type(value) == "string" then
            normalized[key] = value:lower()
        elseif key == "logging" and type(value) == "table" and value.level then
            normalized[key] = deepCopy(value)
            normalized[key].level = value.level:lower()
        else
            normalized[key] = value
        end
    end

    return normalized
end

-- Validate a single configuration value
local function validateConfigValue(key, value)
    local validator = CONFIG_VALIDATORS[key]
    if validator then
        return validator(value)
    end

    -- For unknown keys, we'll accept them but could optionally warn
    return true, nil
end

-- Define the actual logging validator after CONFIG_VALIDATORS is fully defined
CONFIG_VALIDATORS.logging = function(config)
    if type(config) ~= "table" then
        return false, "logging must be a table"
    end

    if config.level ~= nil then
        local ok, err = CONFIG_VALIDATORS.loggerLevel(config.level)
        if not ok then
            return false, ("logging.%s"):format(err)
        end
    end

    if config.structured ~= nil and type(config.structured) ~= "boolean" then
        return false, "logging.structured must be a boolean"
    end

    if config.includeTimestamp ~= nil and type(config.includeTimestamp) ~= "boolean" then
        return false, "logging.includeTimestamp must be a boolean"
    end

    return true, nil
end

-- Main configuration validation function
local function validateConfig(config, path)
    if type(config) ~= "table" then
        return false, "configuration must be a table"
    end

    local errors = {}

    -- Validate each key in the configuration
    for key, value in pairs(config) do
        local isValid, errorMsg = validateConfigValue(key, value)
        if not isValid then
            local fullPath = path and ("%s.%s"):format(path, key) or key
            table.insert(errors, ("%s: %s"):format(fullPath, errorMsg))
        end
    end

    -- Validate nested configurations
    local nestedKeys = {"selection", "pd", "hotkeys", "templates", "logging"}
    for _, key in ipairs(nestedKeys) do
        if config[key] and type(config[key]) == "table" then
            local nestedPath = path and ("%s.%s"):format(path, key) or key
            local nestedValidator = CONFIG_VALIDATORS[key]
            if nestedValidator then
                local isValid, errorMsg = nestedValidator(config[key])
                if not isValid then
                    table.insert(errors, ("%s: %s"):format(nestedPath, errorMsg))
                end
            end
        end
    end

    if #errors > 0 then
        local combinedErrors = table.concat(errors, "; ")
        return false, ("Configuration validation failed: %s"):format(combinedErrors)
    end

    return true, nil
end

-- Deep merge configurations with user config taking precedence
local function mergeConfigs(defaults, user)
    local result = {}

    -- Copy defaults first
    for key, value in pairs(defaults) do
        if type(value) == "table" and not isList(value) then
            result[key] = deepCopy(value)
        else
            result[key] = value
        end
    end

    -- Overlay user config
    for key, value in pairs(user or {}) do
        if type(value) == "table" and type(result[key]) == "table" and not isList(value) then
            result[key] = mergeConfigs(result[key], value)
        else
            result[key] = value
        end
    end

    return result
end

-- Main configuration loading and validation
function ConfigManager.load(defaultConfig, userConfig, logger)
    -- Validate inputs
    if type(defaultConfig) ~= "table" then
        error("defaultConfig must be a table")
    end

    if userConfig ~= nil and type(userConfig) ~= "table" then
        error("userConfig must be a table or nil")
    end

    -- Validate default configuration
    local isValid, errorMsg = validateConfig(defaultConfig)
    if not isValid then
        error(("Invalid default configuration: %s"):format(errorMsg))
    end

    -- Validate user configuration if provided
    if userConfig then
        local userIsValid, userErrorMsg = validateConfig(userConfig)
        if not userIsValid then
            local message = ("Invalid user configuration: %s"):format(userErrorMsg)
            if logger and logger.e then
                logger.e(message)
            end
            error(message)
        end
    end

    -- Merge configurations
    local merged = mergeConfigs(defaultConfig, userConfig)

    -- Normalize the merged configuration
    local normalized = normalizeConfig(merged)

    -- Validate the final merged configuration
    local finalValid, finalError = validateConfig(normalized)
    if not finalValid then
        local message = ("Invalid merged configuration: %s"):format(finalError)
        if logger and logger.e then
            logger.e(message)
        end
        error(message)
    end

    return normalized
end

-- Get all valid configuration keys (for documentation/help)
function ConfigManager.getValidKeys()
    return getKeys(CONFIG_VALIDATORS)
end

-- Validate a single configuration option (for runtime validation)
function ConfigManager.validateOption(key, value)
    return validateConfigValue(key, value)
end

-- Check if a logger level is valid
function ConfigManager.isValidLoggerLevel(level)
    if type(level) ~= "string" then
        return false
    end
    return VALID_LOGGER_LEVELS[level:lower()] == true
end

return ConfigManager