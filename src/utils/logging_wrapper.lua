--[[
Logging wrapper with built-in safety checks

Provides null-safe logging that gracefully handles missing or nil loggers.
]]

local M = {}

--[[
Create a safe logger wrapper

@param logger optional logger instance
@return table with safe logging methods
]]
function M.wrap(logger)
    local noop = function() end

    return {
        d = logger and logger.d or noop,  -- debug
        i = logger and logger.i or noop,  -- info
        w = logger and logger.w or noop,  -- warn
        e = logger and logger.e or noop,  -- error
        -- Original logger for direct access if needed
        _logger = logger
    }
end

--[[
Check if logger is available and has a specific level

@param logger logger instance
@param level string log level (d, i, w, e)
@return boolean true if logging is available
]]
function M.canLog(logger, level)
    return logger ~= nil and logger[level] ~= nil
end

--[[
Conditional debug logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.debug(logger, format_string, ...)
    if M.canLog(logger, "d") then
        logger:d(string.format(format_string, ...))
    end
end

--[[
Conditional info logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.info(logger, format_string, ...)
    if M.canLog(logger, "i") then
        logger:i(string.format(format_string, ...))
    end
end

--[[
Conditional warning logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.warn(logger, format_string, ...)
    if M.canLog(logger, "w") then
        logger:w(string.format(format_string, ...))
    end
end

--[[
Conditional error logging

@param logger logger instance
@param format_string printf-style format
@param ... format arguments
]]
function M.error(logger, format_string, ...)
    if M.canLog(logger, "e") then
        logger:e(string.format(format_string, ...))
    end
end

return M
