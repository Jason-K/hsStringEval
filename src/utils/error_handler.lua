--[[
Error handling utilities for ClipboardFormatter

Provides consistent error handling patterns across all modules.
]]

local M = {}

-- Error types
local ErrorTypes = {
    VALIDATION = "validation",
    RUNTIME = "runtime",
    DEPENDENCY = "dependency",
    CONFIGURATION = "configuration"
}

--[[
Wrap a function call with consistent error handling

@param fn function to execute
@param context string describing where the error occurred
@param errorHandler optional custom error handler
@return boolean success, any result or error message
]]
function M.safeCall(fn, context, errorHandler)
    local success, result = pcall(fn)

    if not success then
        if errorHandler then
            return false, errorHandler(result)
        end

        -- Default error formatting
        local errorMsg = string.format("[%s] %s", context or "unknown", tostring(result))
        return false, errorMsg
    end

    return true, result
end

--[[
Create a typed error

@param errorType string from ErrorTypes
@param message string error description
@param details optional table with additional context
@return table error object
]]
function M.makeError(errorType, message, details)
    return {
        type = errorType or "runtime",
        message = message,
        details = details or {},
        timestamp = os.time()
    }
end

--[[
Log error with context

@param logger logger instance
@param context string describing the operation
@param error any error value
]]
function M.logError(logger, context, error)
    if not logger or not logger.e then return end

    local errorStr = error
    if type(error) == "table" then
        errorStr = string.format("%s: %s", error.type, error.message)
    end

    logger.e(string.format("[%s] %s", context, errorStr))
end

M.ErrorTypes = ErrorTypes

return M
