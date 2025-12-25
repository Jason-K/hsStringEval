--[[
Configuration validator

Validates user configuration against the schema.
]]

local pkgRoot = (...):match("^(.*)%.config%.validator$")
local schema = require(pkgRoot and (pkgRoot .. ".config.schema") or "ClipboardFormatter.src.config.schema")
local config_accessor = require(pkgRoot and (pkgRoot .. ".utils.config_accessor") or "ClipboardFormatter.src.utils.config_accessor")

local M = {}

--[[
Validate configuration against schema

@param config table user configuration
@param defaults table default configuration
@return boolean true if valid
@return table|nil validation errors
]]
function M.validate(config, defaults)
    local errors = {}
    local merged = config_accessor.merge(defaults, config or {})

    for section, fields in pairs(schema) do
        if merged[section] then
            for field, expectedType in pairs(fields) do
                local value = merged[section][field]
                if value ~= nil and type(value) ~= expectedType then
                    table.insert(errors, string.format(
                        "%s.%s: expected %s, got %s",
                        section, field, expectedType, type(value)
                    ))
                end
            end
        end
    end

    return #errors == 0, #errors > 0 and errors or nil
end

return M
