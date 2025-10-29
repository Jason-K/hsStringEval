local M = {}

function M.trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$") or ""
end

function M.split(str, sep)
    if not str or str == "" then return {} end
    sep = sep or "%s"
    local pattern = string.format("([^%s]+)", sep)
    local out = {}
    for part in str:gmatch(pattern) do
        table.insert(out, part)
    end
    return out
end

function M.containsOnly(str, allowed)
    if not str then return false end
    return str:match(string.format("^[%s]+$", allowed)) ~= nil
end

function M.startsWith(str, prefix)
    if not str or not prefix then return false end
    return str:sub(1, #prefix) == prefix
end

function M.equalFold(a, b)
    if a == nil or b == nil then return false end
    return a:lower() == b:lower()
end

function M.normalizeMinus(str)
    if not str then return str end
    str = str:gsub("–", "-")
    str = str:gsub("—", "-")
    str = str:gsub("−", "-")
    return str
end

function M.extractSeed(str)
    if not str or str == "" then
        return "", ""
    end

    -- Common separators that typically precede an evaluatable expression
    -- Note: we look for these followed by whitespace to avoid matching things like "https:"
    local separators = { "=%s", ":%s", "%(", "%[", "{" }
    local lastSepPos = 0

    -- Find the last occurrence of any separator
    for _, sep in ipairs(separators) do
        local searchPos = 1
        while true do
            local pos = str:find(sep, searchPos)
            if not pos then
                break
            end
            -- Find where the non-whitespace starts after this separator
            local afterSep = str:find("[^%s]", pos + 1)
            if afterSep and afterSep - 1 > lastSepPos then
                lastSepPos = afterSep - 1
            end
            searchPos = pos + 1
        end
    end

    if lastSepPos > 0 then
        local prefix = str:sub(1, lastSepPos)
        local seed = str:sub(lastSepPos + 1)
        return prefix, seed
    end

    -- No separator found - look for the last whitespace
    local lastWhitespace = 0
    for i = 1, #str do
        if str:sub(i, i):match("%s") then
            lastWhitespace = i
        end
    end

    if lastWhitespace > 0 then
        local prefix = str:sub(1, lastWhitespace)
        local seed = str:sub(lastWhitespace + 1)
        return prefix, seed
    end

    -- No whitespace, entire string is the seed
    return "", str
end
return M
