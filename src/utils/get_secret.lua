local cache = {}

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end
local function get_secret(op_ref)
    if type(op_ref) ~= "string" or op_ref == "" then
        return nil
    end
    if not op_ref:match("^op://") then
        return nil
    end
    if cache[op_ref] ~= nil then
        return cache[op_ref] ~= false and cache[op_ref] or nil
    end

    local cmd = "command -v op >/dev/null 2>&1 && op read --no-newline " .. shell_quote(op_ref) .. " 2>/dev/null || true"
    local handle = io.popen(cmd)
    if not handle then
        cache[op_ref] = false
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    result = type(result) == "string" and result:gsub("%s+$", "") or ""
    cache[op_ref] = (result ~= "" and result) or false
    return cache[op_ref] ~= false and cache[op_ref] or nil
end

return get_secret
