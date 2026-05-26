local pkgRoot = (...):match("^(.*)%.detectors%.navigation$")
local strings = require(pkgRoot and (pkgRoot .. ".utils.strings") or "utils.strings")
local getSecret = require(pkgRoot and (pkgRoot .. ".utils.get_secret") or "utils.get_secret")

local KAGI_OP_REF = "op://hpaclcqmdqacxdeqxywenzin4y/p7dlzzwmc327pgnleepa3w2jxq/privUrl"
local KAGI_DEFAULT_BASE_URL = "https://kagi.com/search?q="
local cachedKagiBaseUrl = nil

local function hasHS()
    return type(hs) == "table"
end

local function isHttpUrl(text)
    return type(text) == "string" and text:match("^https?://.+") ~= nil
end

local TRACKING_QUERY_PARAMS = {
    dclid = true,
    fbclid = true,
    gclid = true,
    igshid = true,
    mc_cid = true,
    mc_eid = true,
    mkt_tok = true,
    msclkid = true,
    ref_src = true,
    ref_url = true,
    si = true,
    s_cid = true,
    yclid = true,
    zanpid = true,
    _hsenc = true,
    _hsmi = true,
    __hssc = true,
    __hstc = true,
    hsctatracking = true,
}
local function extractScheme(text)
    return type(text) == "string" and text:match("^([%a][%w%+%-%._]*)%:") or nil
end

local function decodeUrlComponent(value)
    if type(value) ~= "string" then
        return ""
    end
    local plusDecoded = value:gsub("+", " ")
    return (plusDecoded:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function shouldStripQueryParam(paramKey)
    if type(paramKey) ~= "string" or paramKey == "" then
        return false
    end
    local normalized = decodeUrlComponent(paramKey):lower()
    if normalized:match("^utm_") then
        return true
    end
    return TRACKING_QUERY_PARAMS[normalized] == true
end

local function stripTrackingQueryParams(url)
    if type(url) ~= "string" then
        return url, false
    end

    local urlWithoutFragment, fragment = url:match("^(.-)#(.*)$")
    if not urlWithoutFragment then
        urlWithoutFragment = url
    end

    local base, query = urlWithoutFragment:match("^(.-)%?(.*)$")
    if not base then
        return url, false
    end

    local keptParts = {}
    local strippedAny = false
    for part in query:gmatch("[^&]+") do
        local key = part:match("^([^=]+)") or ""
        if shouldStripQueryParam(key) then
            strippedAny = true
        else
            table.insert(keptParts, part)
        end
    end

    if not strippedAny then
        return url, false
    end

    local sanitized = base
    if #keptParts > 0 then
        sanitized = sanitized .. "?" .. table.concat(keptParts, "&")
    end
    if fragment ~= nil and fragment ~= "" then
        sanitized = sanitized .. "#" .. fragment
    end
    return sanitized, true
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

local function openInFinder(path, logger, config)
    local expanded = expandPath(path)
    -- Determine which file manager app to use
    local finderApp = "qspace" -- default to QSpace Pro if available, otherwise fallback to Finder
    if config then
        local finderSettings = config.finderReplacement or {}
        local defaultFinder = finderSettings.default or "bloom"
        if defaultFinder == "qspace" then
            finderApp = "QSpace Pro"
        end
    end

    local ok, err = runTask("/usr/bin/open", { "-a", finderApp, expanded }, logger)
    if not ok then
        return false, err
    end
    return true, {
        type = "finder",
        app = finderApp,
        path = expanded,
        message = "Opened in " .. finderApp,
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

local function normalizeKagiBaseUrl(url)
    if type(url) ~= "string" then
        return nil
    end
    local trimmed = strings.trim(url)
    if trimmed == "" then
        return nil
    end
    return trimmed
end

local function safeUrlPreview(url)
    if type(url) ~= "string" then
        return "<nil>"
    end
    local head = url:sub(1, 48)
    if #url > 48 then
        return head .. "..."
    end
    return head
end

local function resolveKagiBaseUrl(logger, config)
    if cachedKagiBaseUrl then
        if logger and logger.d then
            logger.d("Navigation Kagi base URL source=cache preview=" .. safeUrlPreview(cachedKagiBaseUrl))
        end
        return cachedKagiBaseUrl
    end

    local navigation = (type(config) == "table" and type(config.navigation) == "table") and config.navigation or {}
    local configuredBaseUrl = normalizeKagiBaseUrl(navigation.kagiPrivateSearchBaseUrl)
    if configuredBaseUrl then
        cachedKagiBaseUrl = configuredBaseUrl
        if logger and logger.d then
            logger.d("Navigation Kagi base URL source=config.navigation.kagiPrivateSearchBaseUrl preview=" ..
            safeUrlPreview(cachedKagiBaseUrl))
        end
        return cachedKagiBaseUrl
    end

    local opRef = normalizeKagiBaseUrl(navigation.kagiPrivateSearchOpRef) or KAGI_OP_REF
    local fromOp = nil
    if type(getSecret) == "function" then
        fromOp = normalizeKagiBaseUrl(getSecret(opRef))
    end

    cachedKagiBaseUrl = fromOp or KAGI_DEFAULT_BASE_URL
    if logger and logger.d then
        local source = fromOp and ("op(" .. opRef .. ")") or "default"
        logger.d("Navigation Kagi base URL source=" .. source .. " preview=" .. safeUrlPreview(cachedKagiBaseUrl))
    end
    return cachedKagiBaseUrl
end

local function openKagiSearch(query, logger, config)
    local encoded = urlEncode(query)
    local base_url = resolveKagiBaseUrl(logger, config)
    local url = base_url .. encoded
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

local function looksLikeArithmetic(text)
    if type(text) ~= "string" then return false end
    local trimmed = strings.trim(text)
    -- Strip dollar signs before checking if it's an arithmetic expression
    -- This allows expressions like "$120-$50" to be recognized as arithmetic
    local withoutCurrency = trimmed:gsub("%$", "")
    -- Check if it's a simple arithmetic expression (numbers and operators only)
    -- Include 'c' and 'C' for combination operations (e.g., "12c12")
    return withoutCurrency:match("^[%d%.%s%(%)%+%-%*/%%^cC]+$") ~= nil
end
local DetectorFactory = require(pkgRoot and (pkgRoot .. ".utils.detector_factory") or "utils.detector_factory")

return function(deps)
    return DetectorFactory.createCustom({
        id = "navigation",
        priority = 10000,
        dependencies = { "logger", "config" },
        deps = deps,
        customMatch = function(text, context)
            if type(context) ~= "table" then
                context = {}
            end
            if context.__matches and #context.__matches > 0 then
                return nil
            end
            -- Skip navigation if the text looks like an arithmetic expression
            -- This prevents false matches when arithmetic detector fails for other reasons
            if looksLikeArithmetic(text) then
                return nil
            end
            local trimmed = strings.trim(text)
            if trimmed == "" then
                return nil
            end

            -- deps.logger is injected by factory, context can override
            local logger = deps.logger or (context and context.logger)

            if isLocalPath(trimmed) then
                local config = deps.config or (context and context.config)
                local ok, meta = openInFinder(trimmed, logger, config)
                if ok then
                    context.__lastSideEffect = meta
                    context.__handledByNavigation = true
                    return { output = trimmed, sideEffectOnly = true }
                end
                return nil
            end

            if isHttpUrl(trimmed) then
                local sanitizedUrl, strippedTracking = stripTrackingQueryParams(trimmed)
                local ok, meta = openUrl(sanitizedUrl, logger)
                if ok then
                    if strippedTracking and logger and logger.d then
                        logger.d("Navigation stripped tracking query params from URL")
                    end
                    if type(meta) == "table" then
                        meta.originalUrl = trimmed
                        meta.sanitizedUrl = sanitizedUrl
                        meta.trackingStripped = strippedTracking
                    end
                    context.__lastSideEffect = meta
                    context.__handledByNavigation = true
                    return { output = sanitizedUrl, sideEffectOnly = true }
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

            local config = deps.config or (context and context.config)
            local ok, meta = openKagiSearch(trimmed, logger, config)
            if ok then
                context.__lastSideEffect = meta
                context.__handledByNavigation = true
                return { output = trimmed, sideEffectOnly = true }
            end
            return nil
        end,
    })
end
