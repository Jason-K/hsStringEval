local pkgRoot = (...):match("^(.*)%.clipboard%.io$")
local hsUtils = require(pkgRoot .. ".utils.hammerspoon")

local M = {}

function M.getPrimaryPasteboard()
    if not hsUtils.hasPasteboard() then return nil end

    local content = hsUtils.getPasteboard()
    if type(content) == "string" and content ~= "" then
        return content
    end

    content = hsUtils.getPasteboard("find")
    if type(content) == "string" and content ~= "" then
        return content
    end

    local result = hsUtils.readClipboardFallback()
    if type(result) == "string" and result ~= "" then
        return result
    end
    return nil
end

function M.setPrimaryPasteboard(value)
    hsUtils.setPasteboard(value)
end

function M.clearPrimaryPasteboard()
    hsUtils.clearPasteboard()
end

return M
