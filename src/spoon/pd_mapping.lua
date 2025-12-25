-- PD (Permanent Disability) Mapping Management for ClipboardFormatter
-- Handles PD mapping file loading and caching

local M = {}

--- Load PD mapping from candidate paths
-- Tries multiple paths in order: customPath, bundled, legacy, fallback
-- @param instance The ClipboardFormatter spoon instance
-- @param customPath Optional custom path to load from first
-- @return The loaded PD mapping table
function M.load(instance, customPath)
    local pdCache = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.pd_cache")
    local candidates = {}

    if customPath then
        table.insert(candidates, customPath)
    end

    if instance.spoonPath then
        if instance.config.pd.bundledFile then
            table.insert(candidates, instance.spoonPath .. "/" .. instance.config.pd.bundledFile)
        end
        if instance.config.pd.legacyFile then
            table.insert(candidates, instance.spoonPath .. "/" .. instance.config.pd.legacyFile)
        end
    end

    if instance.config.pd.fallbackPath then
        table.insert(candidates, instance.config.pd.fallbackPath)
    end

    for _, path in ipairs(candidates) do
        local map = pdCache.load(path, instance.logger)
        if next(map) then
            instance.pdMappingPath = path
            instance.pdMapping = map
            if instance.logger and instance.logger.i then
                instance.logger.i("Loaded PD mapping from " .. path)
            end
            return map
        end
    end

    instance.pdMapping = {}
    if instance.logger and instance.logger.w then
        instance.logger.w("Unable to load PD mapping; PD conversions disabled")
    end
    return instance.pdMapping
end

--- Reload PD mapping from a specific path or the last loaded path
-- @param instance The ClipboardFormatter spoon instance
-- @param path Optional path to reload from. If not provided, uses pdMappingPath
-- @return The reloaded PD mapping table
function M.reload(instance, path)
    local pdCache = require((instance._packageRoot or "ClipboardFormatter.src") .. ".utils.pd_cache")
    local target = path or instance.pdMappingPath
    if not target then
        return M.load(instance, path)
    end
    local map = pdCache.reload(target, instance.logger)
    if next(map) then
        instance.pdMappingPath = target
        instance.pdMapping = map
        if instance.logger and instance.logger.i then
            instance.logger.i("Reloaded PD mapping from " .. target)
        end
        return map
    end
    if instance.logger and instance.logger.w then
        instance.logger.w("Reloaded PD mapping but no data found at " .. target)
    end
    return map
end

return M
