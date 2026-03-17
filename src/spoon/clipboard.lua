-- Clipboard Operations for ClipboardFormatter
-- Handles clipboard I/O operations

local M = {}

local function requireFromInstance(instance, path)
    if instance and type(instance._packageRoot) == "string" and instance._packageRoot ~= "" then
        return require(instance._packageRoot .. "." .. path)
    end
    return require(path)
end

--- Get current clipboard content
-- @param instance The ClipboardFormatter spoon instance
-- @return The current clipboard content as a string
function M.get(instance)
    local clipboardIO = requireFromInstance(instance, "clipboard.io")
    return clipboardIO.getPrimaryPasteboard()
end

return M
