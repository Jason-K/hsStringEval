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

return M
