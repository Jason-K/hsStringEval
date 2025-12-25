-- Hook System for ClipboardFormatter
-- Manages runtime extension hooks for formatters and detectors

local M = {}

--- Apply hooks to the ClipboardFormatter instance
-- @param instance The ClipboardFormatter spoon instance
-- @param hooks Either a function or a table with 'formatters' and/or 'detectors' functions
function M.apply(instance, hooks)
    if hooks == nil then return end
    if type(hooks) == "function" then
        local ok, err = pcall(hooks, instance)
        if not ok and type(instance.logger) == "table" and instance.logger.w then
            instance.logger.w("Hook function failed: " .. tostring(err))
        end
        return
    end
    if type(hooks) == "table" then
        if type(hooks.formatters) == "function" then
            local okFormatters, errFormatters = pcall(hooks.formatters, instance)
            if not okFormatters and type(instance.logger) == "table" and instance.logger.w then
                instance.logger.w("Formatter hook failed: " .. tostring(errFormatters))
            end
        end
        if type(hooks.detectors) == "function" then
            local ok, err = pcall(hooks.detectors, instance)
            if not ok and type(instance.logger) == "table" and instance.logger.w then
                instance.logger.w("Detector hook failed: " .. tostring(err))
            end
        end
    end
end

--- Load hooks from a file
-- @param instance The ClipboardFormatter spoon instance
-- @param path Optional path to hooks file. If not provided, uses spoonPath + "/config/user_hooks.lua"
-- @return true if hooks were loaded, false otherwise
function M.loadFromFile(instance, path)
    local hookPath = path
    if not hookPath and instance.spoonPath then
        hookPath = instance.spoonPath .. "/config/user_hooks.lua"
    end
    if not hookPath then
        return false
    end
    local chunk, err = loadfile(hookPath)
    if not chunk then
        if instance.logger and instance.logger.d then
            instance.logger.d("No user hooks loaded: " .. tostring(err))
        end
        return false
    end
    local ok, hooks = pcall(chunk)
    if not ok then
        if instance.logger and instance.logger.w then
            instance.logger.w("Failed to execute hooks file: " .. tostring(hooks))
        end
        return false
    end
    M.apply(instance, hooks)
    return true
end

return M
