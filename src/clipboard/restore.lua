local moduleRoot = (...):match("^(.*)%.restore$")
local io = require(moduleRoot .. ".io")

local M = {}

function M.to(original)
    if original == nil then
        io.clearPrimaryPasteboard()
    else
        io.setPrimaryPasteboard(original)
    end
end

return M
