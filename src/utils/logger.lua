local M = {}

local LEVEL_ORDER = {
    debug = 10,
    info = 20,
    warning = 30,
    error = 40,
    fault = 50,
}

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

local function normalizeLevel(level)
    if type(level) ~= "string" then
        return nil
    end
    return LEVEL_ALIASES[level:lower()]
end

local function shouldWrite(level, threshold)
    if not level or not threshold then
        return false
    end
    return (LEVEL_ORDER[level] or 0) >= (LEVEL_ORDER[threshold] or math.huge)
end

local function jsonEscape(str)
    return (str or ""):gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\r", "\\r"):gsub("\n", "\\n")
end

local function structuredLine(payload)
    local parts = {}
    if payload.timestamp then
        table.insert(parts, string.format('"timestamp":"%s"', jsonEscape(payload.timestamp)))
    end
    table.insert(parts, string.format('"level":"%s"', jsonEscape(payload.level)))
    table.insert(parts, string.format('"message":"%s"', jsonEscape(payload.message)))
    return "{" .. table.concat(parts, ",") .. "}"
end

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

local function formatMessage(fmt, ...)
    if fmt == nil then
        return ""
    end
    local argc = select("#", ...)
    if argc > 0 and type(fmt) == "string" then
        local ok, formatted = pcall(string.format, fmt, ...)
        if ok then
            return formatted
        end
    end
    if argc == 0 then
        return tostring(fmt)
    end
    local parts = { tostring(fmt) }
    for index = 1, argc do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    return table.concat(parts, " ")
end

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
    }

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

    logger.d = function(fmt, ...)
        emit("d", "debug", fmt, ...)
    end
    logger.i = function(fmt, ...)
        emit("i", "info", fmt, ...)
    end
    logger.w = function(fmt, ...)
        emit("w", "warning", fmt, ...)
    end
    logger.e = function(fmt, ...)
        emit("e", "error", fmt, ...)
    end
    logger.f = function(fmt, ...)
        emit("f", "fault", fmt, ...)
    end

    logger.setLogLevel = function(_, newLevel)
        local resolved = resolveLogLevelValue(newLevel)
        if sink.setLogLevel then
            consoleLevel = applySinkLogLevel(sink, resolved, consoleLevel) or consoleLevel
        end
    end

    logger.setFileLevel = function(_, newLevel)
        fileLevel = normalizeLevel(newLevel)
    end

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
