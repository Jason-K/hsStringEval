-- Clipboard Operations for ClipboardFormatter
-- Handles clipboard I/O operations

local M = {}

--- Get current clipboard content
-- @param instance The ClipboardFormatter spoon instance
-- @return The current clipboard content as a string
function M.get(instance)
    local clipboardIO = require((instance._packageRoot or "ClipboardFormatter.src") .. ".clipboard.io")
    return clipboardIO.getPrimaryPasteboard()
end

return M
