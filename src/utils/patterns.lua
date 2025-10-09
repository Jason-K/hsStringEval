local rawPatterns = {
    arithmetic_candidate = "^%s*%$?[%d%.,%s%(%)%+%-%*/%%^]+$",
    phone_semicolon = "%d+;.+",
    date_token = "%d+[/%.-]%d+[/%.-]%d+",
    date_full = "^%d%d?[/%.-]%d%d?[/%.-]%d%d%d?%d?$",
    date_token_iso = "%d%d%d%d[/%.-]%d%d[/%.-]%d%d",
    date_token_text = "[%a%.]+%s+%d%d?[, ]*%d?%d?%d?%d?",
    date_range_dash = "^(%d+[/%.-]%d+[/%.-]%d+)%-(%d+[/%.-]%d+[/%.-]%d+)$",
    localized_number = "^%s*[+-]?[%d%.%,]+%s*$",
}

local compiled = {}

local function compile(name)
    local pattern = rawPatterns[name]
    if not pattern then
        return nil
    end
    if not compiled[name] then
        compiled[name] = {
            raw = pattern,
            contains = function(text)
                return type(text) == "string" and text:find(pattern) ~= nil
            end,
            match = function(text)
                if type(text) ~= "string" then return nil end
                return text:match(pattern)
            end,
            gmatch = function(text)
                if type(text) ~= "string" then
                    return function() end
                end
                return text:gmatch(pattern)
            end,
        }
    end
    return compiled[name]
end

local function snapshot()
    local result = {}
    for name in pairs(rawPatterns) do
        result[name] = compile(name)
    end
    return result
end

local M = {}

function M.register(name, pattern)
    rawPatterns[name] = pattern
    compiled[name] = nil
end

function M.ensure(name, pattern)
    if rawPatterns[name] == nil then
        M.register(name, pattern)
    end
    return compile(name)
end

function M.get(name)
    local entry = compile(name)
    return entry and entry.raw or nil
end

function M.compiled(name)
    return compile(name)
end

function M.match(name, text)
    local entry = compile(name)
    if not entry then return nil end
    return entry.match(text)
end

function M.contains(name, text)
    local entry = compile(name)
    if not entry then return false end
    return entry.contains(text)
end

function M.all()
    return snapshot()
end

return M
