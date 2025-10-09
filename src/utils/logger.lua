local M = {}

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
    logger.d = log("d")
    logger.i = log("i")
    logger.w = log("w")
    logger.e = log("e")
    logger.f = log("f")
    logger.setLogLevel = function(_, newLevel)
        logger.level = newLevel
    end
    return logger
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

function M.new(name, level, opts)
    opts = opts or {}
    local initialLevel = level or opts.level or "warning"
    local sink
    if type(hs) == "table" and hs.logger and type(hs.logger.new) == "function" then
        sink = hs.logger.new(name, initialLevel)
    else
        sink = buildFallback(initialLevel)
    end

    if sink.setLogLevel and opts.level then
        sink:setLogLevel(opts.level)
    end

    if not opts.structured then
        return sink
    end

    local includeTimestamp = opts.includeTimestamp ~= false
    local methodLevels = {
        d = "debug",
        i = "info",
        w = "warning",
        e = "error",
        f = "fault",
    }

    local wrapper = {
        messages = sink.messages,
        setLogLevel = function(_, newLevel)
            if sink.setLogLevel then
                sink:setLogLevel(newLevel)
            end
        end,
    }
    setmetatable(wrapper, {
        __index = sink,
    })

    local function emit(method, levelName, ...)
        local args = { ... }
        local segments = {}
        for i, value in ipairs(args) do
            segments[i] = tostring(value)
        end
        local message = table.concat(segments, " ")
        local payload = {
            level = levelName,
            message = message,
        }
        if includeTimestamp then
            payload.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        end
        local line = structuredLine(payload)
        if type(sink[method]) == "function" then
            sink[method](sink, line)
        end
    end

    for method, levelName in pairs(methodLevels) do
        local methodName = method
        local levelLabel = levelName
        wrapper[methodName] = function(_, ...)
            emit(methodName, levelLabel, ...)
        end
    end

    return wrapper
end

return M
