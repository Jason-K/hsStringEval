local caches = {}

local function readFile(path, logger)
    local map = {}
    if not path or path == "" then
        if logger and logger.w then
            logger.w("PD cache: empty path provided")
        end
        return map
    end

    local file, err = io.open(path, "r")
    if not file then
        if logger and logger.w then
            logger.w(string.format("PD cache: unable to open '%s': %s", path, tostring(err)))
        end
        return map
    end

    for line in file:lines() do
        local key, value = tostring(line):match("(%d+)%s*:%s*([%d%.]+)")
        if key and value then
            map[tonumber(key)] = tonumber(value)
        end
    end

    file:close()
    return map
end

local M = {}

function M.load(path, logger)
    if caches[path] then
        return caches[path]
    end
    local map = readFile(path, logger)
    caches[path] = map
    return map
end

function M.reload(path, logger)
    if not path then
        return {}
    end
    caches[path] = readFile(path, logger)
    return caches[path]
end

function M.reloadAll(logger)
    for path in pairs(caches) do
        caches[path] = readFile(path, logger)
    end
    return caches
end

function M.get(path, percent)
    if not caches[path] then return nil end
    return caches[path][percent]
end

function M.clear(path)
    if path then
        caches[path] = nil
    else
        caches = {}
    end
end

function M.available(path)
    return caches[path] ~= nil and next(caches[path]) ~= nil
end

return M
