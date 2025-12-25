--[[
Unified configuration accessor with safe nested access

Provides consistent access to configuration with fallbacks and validation.
]]

local M = {}

--[[
Get a nested config value safely

@param config table configuration object
@param path string dot-notation path (e.g., "pd.benefitPerWeek")
@param default any default value if path not found
@return any config value or default
]]
function M.get(config, path, default)
    if type(config) ~= "table" then return default end
    if type(path) ~= "string" or path == "" then return default end

    local current = config
    local keys = {}

    -- Split path by dots
    for key in path:gmatch("[^%.]+") do
        table.insert(keys, key)
    end

    -- Traverse nested structure
    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            return default
        end
        current = current[key]
    end

    return current
end

--[[
Merge user config with defaults

User config takes precedence over defaults.
@param defaults table default configuration
@param user table user configuration (can be nil)
@return table merged configuration
]]
function M.merge(defaults, user)
    local result = {}

    -- Copy defaults
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            result[k] = M.merge(v, {})
        else
            result[k] = v
        end
    end

    -- Overlay user config
    if user then
        for k, v in pairs(user) do
            if type(v) == "table" and type(result[k]) == "table" then
                result[k] = M.merge(result[k], v)
            else
                result[k] = v
            end
        end
    end

    return result
end

--[[
Create a context-aware config accessor

@param deps table injected dependencies
@param context table runtime context (optional)
@return table accessor with get() method
]]
function M.accessor(deps, context)
    local merged = M.merge(deps.config or {}, (context or {}).config or {})

    return {
        get = function(self, path, default)
            return M.get(merged, path, default)
        end,

        raw = merged  -- For raw access if needed
    }
end

return M
