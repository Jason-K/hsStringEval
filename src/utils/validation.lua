--[[
Validation framework for detectors and formatters

Provides reusable validators for common validation patterns.
]]

local M = {}

-- Error types for validation
local ValidationErrorTypes = {
    MISSING_METHOD = "missing_method",
    INVALID_TYPE = "invalid_type",
    INVALID_VALUE = "invalid_value",
    MISSING_FIELD = "missing_field"
}

--[[
Validate that a table has required methods

@param obj table to validate
@param methods table list of required method names
@return boolean true if valid
@return string|nil error message
]]
function M.hasMethods(obj, methods)
    if type(obj) ~= "table" then
        return false, string.format("Expected table, got %s", type(obj))
    end

    for _, method in ipairs(methods) do
        if type(obj[method]) ~= "function" then
            return false, string.format("Missing required method: %s", method)
        end
    end

    return true
end

--[[
Validate a function result

@param result any value to validate
@param expectedType string expected type (optional)
@return boolean true if valid
@return string|nil error message
]]
function M.validateResult(result, expectedType)
    if result == nil then
        return false, "Result is nil"
    end

    if expectedType then
        if type(result) ~= expectedType then
            return false, string.format("Expected %s, got %s", expectedType, type(result))
        end
    end

    return true
end

--[[
Validate detector spec

@param spec table detector specification
@return boolean true if valid
@return table|nil list of errors
]]
function M.validateDetectorSpec(spec)
    local errors = {}

    if type(spec) ~= "table" then
        return false, {"Expected spec to be a table"}
    end

    -- Required fields
    if not spec.name then
        table.insert(errors, "Missing required field: name")
    end

    if not spec.priority then
        table.insert(errors, "Missing required field: priority")
    end

    -- Validate methods
    if spec.pattern and type(spec.pattern) ~= "function" then
        table.insert(errors, "pattern must be a function")
    end

    if spec.formatter and type(spec.formatter) ~= "function" then
        table.insert(errors, "formatter must be a function")
    end

    return #errors == 0, #errors > 0 and errors or nil
end

--[[
Create a type validator

@param expectedType string expected Lua type
@return function validator function
]]
function M.type(expectedType)
    return function(value)
        return type(value) == expectedType,
               type(value) ~= expectedType and string.format("Expected %s, got %s", expectedType, type(value)) or nil
    end
end

--[[
Create a range validator for numbers

@param min number minimum value (inclusive)
@param max number maximum value (inclusive)
@return function validator function
]]
function M.range(min, max)
    return function(value)
        if type(value) ~= "number" then
            return false, string.format("Expected number, got %s", type(value))
        end

        return value >= min and value <= max,
               value < min and string.format("Value %s below minimum %s", value, min) or
               value > max and string.format("Value %s above maximum %s", value, max) or nil
    end
end

M.ValidationErrorTypes = ValidationErrorTypes

return M
