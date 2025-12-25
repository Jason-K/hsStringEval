--[[
  Provides a flexible logging utility that can direct messages to the Hammerspoon
  console, a log file, or both, with support for structured JSON output.

  This module is designed to be a robust replacement for `hs.logger`, offering
  more control over log levels for different outputs (sinks) and allowing for
  dynamic configuration of logging behavior at runtime. It includes features
  like log level normalization, structured logging, and fallback mechanisms for
  environments where Hammerspoon's native utilities are not available.
--]]
local M = {}

-- Defines the numerical hierarchy of log levels.
-- This table maps log level names to integer values, allowing for easy
-- comparison to determine if a message of a certain level should be logged.
local LEVEL_ORDER = {
    debug = 10,
    info = 20,
    warning = 30,
    error = 40,
    fault = 50,
}

-- Provides a mapping from common aliases to normalized log level names.
-- This allows for flexibility in specifying log levels, accommodating both
-- full names and common abbreviations (e.g., "warn" for "warning").
local LEVEL_ALIASES = {
    d = "debug",
    debug = "debug",
    i = "info",
    info = "info",
    w = "warning",
    warn = "warning",
    warning = "warning",
    e = "error",
    error = "error",
    f = "fault",
    fault = "fault",
}

--[[
  Normalizes a log level string to its canonical name.

  Given a string, this function attempts to convert it into a standardized log
  level name (e.g., "warn" becomes "warning"). It performs a case-insensitive
  lookup in the `LEVEL_ALIASES` table.

  @param level (string) The log level string to normalize.
  @return (string|nil) The normalized log level name, or `nil` if the input is
                      not a string or cannot be normalized.
--]]
local function normalizeLevel(level)
    if type(level) ~= "string" then
        return nil
    end
    return LEVEL_ALIASES[level:lower()]
end

--[[
  Determines whether a log message should be written based on the current threshold.

  This function compares the numerical value of a message's log level against a
  specified threshold. It returns `true` if the message's level is at or above
  the threshold, indicating that it should be logged.

  @param level (string) The normalized log level of the message.
  @param threshold (string) The normalized log level threshold.
  @return (boolean) `true` if the message should be written, `false` otherwise.
--]]
local function shouldWrite(level, threshold)
    if not level or not threshold then
        return false
    end
    return (LEVEL_ORDER[level] or 0) >= (LEVEL_ORDER[threshold] or math.huge)
end

--[[
  Escapes characters in a string to ensure it is a valid JSON string value.

  This function takes a string and escapes backslashes, double quotes, carriage
  returns, and newlines, which is essential for embedding the string within a
  JSON structure.

  @param str (string) The string to escape.
  @return (string) The JSON-escaped string.
--]]
local function jsonEscape(str)
    return (str or ""):gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\r", "\\r"):gsub("\n", "\\n")
end

--[[
  Formats a log entry as a single-line JSON object.

  Constructs a JSON string from a payload table containing log details such as
  timestamp, level, and message. This is used for structured logging output.

  @param payload (table) A table with `timestamp`, `level`, and `message` keys.
  @return (string) A JSON-formatted string representing the log entry.
--]]
local function structuredLine(payload)
    local parts = {}
    if payload.timestamp then
        table.insert(parts, string.format('"timestamp":"%s"', jsonEscape(payload.timestamp)))
    end
    table.insert(parts, string.format('"level":"%s"', jsonEscape(payload.level)))
    table.insert(parts, string.format('"message":"%s"', jsonEscape(payload.message)))
    return "{" .. table.concat(parts, ",") .. "}"
end

--[[
  Trims leading and trailing whitespace from a string.

  @param value (string) The string to trim.
  @return (string|nil) The trimmed string, or `nil` if the input is not a string
                      or if the result is empty.
--]]
local function trim(value)
    if type(value) ~= "string" then
        return nil
    end
    local trimmed = value:match("^%s*(.-)%s*$")
    if trimmed == nil or trimmed == "" then
        return nil
    end
    return trimmed
end

--[[
  Recursively resolves a log level from various possible input types.

  This function is designed to robustly determine a log level from numbers,
  strings, or tables. It can handle nested tables and various keys to find a
  valid log level value.

  @param value (any) The value to resolve into a log level.
  @return (string|number|nil) The resolved log level, which could be a normalized
                              string or a number, or `nil` if resolution fails.
--]]
local function resolveLogLevelValue(value)
    if type(value) == "number" then
        return value
    end
    if type(value) == "string" then
        local trimmed = trim(value)
        if not trimmed then
            return nil
        end
        local numeric = tonumber(trimmed)
        if numeric then
            return numeric
        end
        return LEVEL_ALIASES[trimmed:lower()] or trimmed:lower()
    end
    if type(value) == "table" then
        local keys = { "level", "logLevel", "value", "default", 1 }
        for _, key in ipairs(keys) do
            local resolved = resolveLogLevelValue(value[key])
            if resolved ~= nil then
                return resolved
            end
        end
    end
    return nil
end

--[[
  Applies a log level to a sink, with an optional fallback level.

  This function attempts to set the log level on a given sink object (e.g., an
  `hs.logger` instance). If setting the primary level fails or is not provided,
  it tries again with the fallback level.

  @param sink (table) The logging sink object, which must have a `setLogLevel` method.
  @param level (any) The desired log level to apply.
  @param fallback (any) The fallback log level to apply if the primary one fails.
  @return (any|nil) The log level that was successfully applied, or `nil`.
--]]
local function applySinkLogLevel(sink, level, fallback)
    if not sink or type(sink.setLogLevel) ~= "function" then
        return nil
    end
    if level ~= nil then
        local ok = pcall(function()
            sink:setLogLevel(level)
        end)
        if ok then
            return level
        end
    end
    if fallback ~= nil then
        local ok = pcall(function()
            sink:setLogLevel(fallback)
        end)
        if ok then
            return fallback
        end
    end
    return nil
end
--[[
  Builds a fallback logger for environments without `hs.logger`.

  When `hs.logger` is not available, this function creates a simple logger-like
  table that captures log messages in memory. This is useful for testing or
  running in non-Hammerspoon environments.

  @param level (string) The initial log level for the fallback logger.
  @return (table) A fallback logger object with standard logging methods.
--]]
local function buildFallback(level)
    local logger = {
        level = level or "warning",
        messages = {},
    }
    local function log(method)
        return function(_, ...)
            table.insert(logger.messages, {
                method = method,
                args = { ... },
            })
        end
    end
    logger.d = log("debug")
    logger.i = log("info")
    logger.w = log("warning")
    logger.e = log("error")
    logger.f = log("fault")
    logger.setLogLevel = function(_, newLevel)
        logger.level = newLevel
    end
    return logger
end

--[[
  Formats a log message, similar to `string.format` but with fallbacks.

  If the first argument is a format string and subsequent arguments are provided,
  it attempts to use `string.format`. If that fails or is not applicable, it
  concatenates all arguments into a single space-separated string.

  @param fmt (any) The format string or the first value to be logged.
  @param ... (any) Additional values to format or concatenate.
  @return (string) The formatted log message.
--]]
local function formatMessage(fmt, ...)
    if fmt == nil then
        return ""
    end
    local argc = select("#", ...)
    if argc == 0 then
        return tostring(fmt)
    end
    local parts = { tostring(fmt) }
    for index = 1, argc do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    return table.concat(parts, " ")
end

--[[
  Ensures that the directory for a given file path exists.

  If the environment provides `hs.fs`, this function will check for the
  existence of the parent directory of the specified path and create it if it
  does not exist.

  @param path (string) The full file path.
--]]
local function ensureDirectory(path)
    if type(path) ~= "string" or path == "" then
        return
    end
    local directory = path:match("(.+)/[^/]+$")
    if not directory or directory == "" then
        return
    end
    if type(hs) == "table" and hs.fs then
        local attrs = hs.fs.attributes(directory)
        if attrs and attrs.mode == "directory" then
            return
        end
        hs.fs.mkdir(directory)
    end
end

--[[
  Appends a formatted log line to a file.

  Opens the specified file in append mode and writes a log message, prefixed
  with a timestamp and the log level.

  @param path (string) The path to the log file.
  @param level (string) The log level of the message.
  @param message (string) The log message to write.
--]]
local function appendLine(path, level, message)
    if not path or path == "" or not message or message == "" then
        return
    end
    local file = io.open(path, "a")
    if not file then
        return
    end
    file:write(string.format("%s [%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), level, message))
    file:close()
end

--[[
  Creates and configures a new logger instance.

  This is the main constructor for the logger. It sets up the console and file
  sinks based on the provided options, and returns a logger object with methods
  for logging at different levels (`d`, `i`, `w`, `e`, `f`).

  @param name (string) The name of the logger, used by `hs.logger`.
  @param level (string) The default log level for all sinks.
  @param opts (table, optional) A table of options to configure the logger:
    - `consoleLevel` (string): The log level for the console sink.
    - `fileLevel` (string): The log level for the file sink.
    - `logFile` (string|boolean): The path to the log file. `false` disables file logging.
    - `structured` (boolean): If `true`, console output will be in JSON format.
    - `includeTimestamp` (boolean): If `false`, timestamps are omitted from structured logs.
  @return (table) The new logger instance.
--]]
function M.new(name, level, opts)
    opts = opts or {}
    local defaultConsoleLevel = resolveLogLevelValue("warning") or "warning"
    local requestedConsole = opts.consoleLevel or opts.level or level
    local consoleLevel = resolveLogLevelValue(requestedConsole) or defaultConsoleLevel
    local sink
    if type(hs) == "table" and hs.logger and type(hs.logger.new) == "function" then
        sink = hs.logger.new(name, consoleLevel or defaultConsoleLevel)
        if sink.setLogLevel then
            consoleLevel = applySinkLogLevel(sink, consoleLevel, defaultConsoleLevel) or consoleLevel
        end
    else
        local fallbackString = normalizeLevel(consoleLevel) or normalizeLevel(defaultConsoleLevel) or "warning"
        sink = buildFallback(fallbackString)
    end

    local logFile = opts.logFile
    if logFile == false then
        logFile = nil
    elseif logFile == nil and type(hs) == "table" and type(hs.configdir) == "string" then
        logFile = hs.configdir .. "/logs/hsStringEval.log"
    end
    if logFile then
        ensureDirectory(logFile)
    end

    local fileLevel = normalizeLevel(opts.fileLevel or opts.level or level or "info")
    if not logFile then
        fileLevel = nil
    end

    local structured = opts.structured == true
    local includeTimestamp = opts.includeTimestamp ~= false
    local logger = {
        messages = sink.messages,
        level = normalizeLevel(consoleLevel) or normalizeLevel(defaultConsoleLevel) or "warning",
    }

    --[[
      Internal function to emit a log message to the configured sinks.

      This function formats the message, checks if it meets the file log level
      threshold, and then sends it to the appropriate sink (file and/or console).
      It handles both plain and structured logging formats.

      @param method (string) The short name of the sink method to call (e.g., "d", "i").
      @param severity (string) The normalized severity level of the message.
      @param ... (any) The arguments for the log message, to be formatted.
    --]]
    local function emit(method, severity, ...)
        local message = formatMessage(...)
        if message == "" then
            return
        end

        if logFile and shouldWrite(severity, fileLevel) then
            appendLine(logFile, severity:upper(), message)
        end
        local sinkMethod = sink[method]
        if type(sinkMethod) ~= "function" then
            return
        end
        if structured then
            local payload = {
                level = severity,
                message = message,
            }
            if includeTimestamp then
                payload.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            end
            sinkMethod(sink, structuredLine(payload))
        else
            sinkMethod(sink, message)
        end
    end

    --[[
      Logs a message at the 'debug' level.
      @param fmt (string) The format string.
      @param ... (any) Values to be formatted.
    --]]
    logger.d = function(self, fmt, ...)
        emit("d", "debug", fmt, ...)
    end
    --[[
      Logs a message at the 'info' level.
      @param self (table) The logger instance.
      @param fmt (string) The format string.
      @param ... (any) Values to be formatted.
    --]]
    logger.i = function(self, fmt, ...)
        emit("i", "info", fmt, ...)
    end
    --[[
      Logs a message at the 'warning' level.
      @param self (table) The logger instance.
      @param fmt (string) The format string.
      @param ... (any) Values to be formatted.
    --]]
    logger.w = function(self, fmt, ...)
        emit("w", "warning", fmt, ...)
    end
    --[[
      Logs a message at the 'error' level.
      @param self (table) The logger instance.
      @param fmt (string) The format string.
      @param ... (any) Values to be formatted.
    --]]
    logger.e = function(self, fmt, ...)
        emit("e", "error", fmt, ...)
    end
    --[[
      Logs a message at the 'fault' level.
      @param self (table) The logger instance.
      @param fmt (string) The format string.
      @param ... (any) Values to be formatted.
    --]]
    logger.f = function(self, fmt, ...)
        emit("f", "fault", fmt, ...)
    end

    --[[
      Sets the log level for the console sink at runtime.
      @param _ (table) The logger instance (self).
      @param newLevel (string) The new log level to set.
    --]]
    logger.setLogLevel = function(_, newLevel)
        local resolved = resolveLogLevelValue(newLevel)
        local normalized = normalizeLevel(resolved) or normalizeLevel(consoleLevel) or "warning"
        logger.level = normalized
        if sink.setLogLevel then
            consoleLevel = applySinkLogLevel(sink, resolved, consoleLevel) or consoleLevel
        end
    end

    --[[
      Sets the log level for the file sink at runtime.
      @param _ (table) The logger instance (self).
      @param newLevel (string) The new log level to set.
    --]]
    logger.setFileLevel = function(_, newLevel)
        fileLevel = normalizeLevel(newLevel)
    end

    --[[
      Sets the path for the log file at runtime.
      @param _ (table) The logger instance (self).
      @param path (string|boolean) The new path for the log file, or `false` to disable.
    --]]
    logger.setLogFile = function(_, path)
        if path == false then
            logFile = nil
            return
        end
        if type(path) ~= "string" or path == "" then
            return
        end
        logFile = path
        ensureDirectory(logFile)
    end

    return logger
end

return M
