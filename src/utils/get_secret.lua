local function get_secret(op_ref)
    local handle = io.popen('op read "' .. op_ref .. '" 2>/dev/null')
    if not handle then
        return nil
    end
    local result = handle:read("*a"):gsub("%s+$", "")
    handle:close()
    return result ~= "" and result or nil
end

return get_secret
