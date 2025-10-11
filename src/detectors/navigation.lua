local pkgRoot = (...):match("^(.*)%.detectors%.navigation$")
local strings = require(pkgRoot .. ".utils.strings")

local function hasHS()
    return type(hs) == "table"
end

local function isHttpUrl(text)
    return type(text) == "string" and text:match("^https?://.+") ~= nil
end

local function extractScheme(text)
    return type(text) == "string" and text:match("^([%a][%w%+%-%._]*)%:") or nil
end

local function isAppUrl(text)
    local scheme = extractScheme(text)
    if not scheme then
        return false
    end
    local lower = scheme:lower()
    return lower ~= "http" and lower ~= "https"
end

local function isLocalPath(text)
    if type(text) ~= "string" then
        return false
    end
    if text:match("^~/%S") or text:match("^/%S") then
        return true
    end
    if text:match("^%./%S") or text:match("^%.%./%S") then
        return true
    end
    return false
end

local function expandPath(path)
    if type(path) ~= "string" or path == "" then
        return path
    end
    if path:sub(1, 1) == "~" then
        local home = os.getenv("HOME") or ""
        if path == "~" then
            return home
        end
        return home .. path:sub(2)
    end
    if path:sub(1, 1) == "." and hasHS() and hs.fs and hs.fs.pathToAbsolute then
        local absolute = hs.fs.pathToAbsolute(path)
        if type(absolute) == "string" and absolute ~= "" then
            return absolute
        end
    end
    return path
end

local function runTask(executable, args, logger)
    if not (hasHS() and hs.task and type(hs.task.new) == "function") then
        if logger and logger.w then
            logger.w("hs.task unavailable; cannot launch '" .. tostring(executable) .. "'")
        end
        return false, "hs.task unavailable"
    end
    local child = hs.task.new(executable, function() end, function() return true end, args)
    if not child then
        if logger and logger.w then
            logger.w("Failed to spawn '" .. tostring(executable) .. "'")
        end
        return false, "failed to spawn"
    end
    child:start()
    return true
end

local function openInQSpace(path, logger)
    local expanded = expandPath(path)
    local ok, err = runTask("/usr/bin/open", { "-a", "QSpace Pro", expanded }, logger)
    if not ok then
        return false, err
    end
    return true, {
        type = "qspace",
        path = expanded,
        message = "Opened in QSpace",
    }
end

local function openUrl(url, logger)
    if hasHS() and hs.urlevent and type(hs.urlevent.openURL) == "function" then
        local ok, err = pcall(hs.urlevent.openURL, url)
        if not ok then
            if logger and logger.w then
                logger.w("openURL failed: " .. tostring(err))
            end
            return false, err
        end
        return true, {
            type = "browser",
            url = url,
            message = "Opened in browser",
        }
    end
    local ok, err = runTask("/usr/bin/open", { url }, logger)
    if not ok then
        return false, err
    end
    return true, {
        type = "browser",
        url = url,
        message = "Opened in browser",
    }
end

local function openAppUrl(url, logger)
    local ok, err = runTask("/usr/bin/open", { "-u", url }, logger)
    if not ok then
        return false, err
    end
    return true, {
        type = "app_url",
        url = url,
        message = "Opened application URL",
    }
end

local function urlEncode(str)
    return (str:gsub("([^%w%-_%.~])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function openKagiSearch(query, logger)
    local encoded = urlEncode(query)
    local url = "https://kagi.com/search?q=" .. encoded
    local ok, meta = openUrl(url, logger)
    if not ok then
        return false, meta
    end
    meta = meta or {}
    meta.type = "kagi_search"
    meta.url = url
    meta.query = query
    meta.message = "Searching Kagi"
    return true, meta
end

return function(deps)
    local logger = deps and deps.logger
    return {
        id = "navigation",
        priority = 10000,
        match = function(_, text, context)
            if type(context) ~= "table" then
                context = {}
            end
            if context.__matches and #context.__matches > 0 then
                return nil
            end
            local trimmed = strings.trim(text)
            if trimmed == "" then
                return nil
            end

            if isLocalPath(trimmed) then
                local ok, meta = openInQSpace(trimmed, logger)
                if ok then
                    context.__lastSideEffect = meta
                    context.__handledByNavigation = true
                    return { output = trimmed, sideEffectOnly = true }
                end
                return nil
            end

            if isHttpUrl(trimmed) then
                local ok, meta = openUrl(trimmed, logger)
                if ok then
                    context.__lastSideEffect = meta
                    context.__handledByNavigation = true
                    return { output = trimmed, sideEffectOnly = true }
                end
                return nil
            end

            if isAppUrl(trimmed) then
                local ok, meta = openAppUrl(trimmed, logger)
                if ok then
                    context.__lastSideEffect = meta
                    context.__handledByNavigation = true
                    return { output = trimmed, sideEffectOnly = true }
                end
                return nil
            end

            local ok, meta = openKagiSearch(trimmed, logger)
            if ok then
                context.__lastSideEffect = meta
                context.__handledByNavigation = true
                return { output = trimmed, sideEffectOnly = true }
            end
            return nil
        end,
    }
end
