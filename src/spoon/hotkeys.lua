-- Hotkey Helpers for ClipboardFormatter
-- Manages hotkey binding and global helper function installation

local M = {}

-- Helper hotkey definitions (wrapped to use instance context)
local helperHotkeys = {
    FormatClip = function(self)
        return self:formatClipboardDirect()
    end,
    FormatClipSeed = function(self)
        return self:formatClipboardSeed()
    end,
    -- Selects to beginning of line, cuts, evaluates the seed at the end of the
    -- selection, pastes the result, and restores the original clipboard.
    -- Useful when calling from Karabiner so timing is handled inside Hammerspoon.
    FormatCutSeed = function(self)
        -- Select to beginning of line, then run the robust selection-based flow
        if type(hs) == "table" and hs.eventtap then
            hs.eventtap.keyStroke({ "cmd", "shift" }, "left", 0)
            hs.timer.doAfter(0.08, function()
                self:formatSelectionSeed()
            end)
            return true
        end
        return self:formatSelectionSeed()
    end,
    FormatSelected = function(self)
        if self.logger and self.logger.d then
            self.logger.d("FormatSelected wrapper called")
        end
        return self:formatSelection()
    end,
}

--- Install hotkey helper functions to global namespace
-- @param instance The ClipboardFormatter spoon instance
-- @return Table of installed helpers for tracking
function M.installHelpers(instance)
    M.removeHelpers(instance)
    instance._hotkeyHelpers = {}
    for name, fn in pairs(helperHotkeys) do
        local wrapper = function()
            return fn(instance)
        end
        _G[name] = wrapper
        instance._hotkeyHelpers[name] = wrapper
    end
    return instance._hotkeyHelpers
end

--- Remove hotkey helper functions from global namespace
-- @param instance The ClipboardFormatter spoon instance
function M.removeHelpers(instance)
    if not instance._hotkeyHelpers then
        return
    end
    for name, wrapper in pairs(instance._hotkeyHelpers) do
        if _G[name] == wrapper then
            _G[name] = nil
        end
    end
    instance._hotkeyHelpers = nil
end

--- Bind hotkeys to spoon methods
-- @param instance The ClipboardFormatter spoon instance
-- @param mapping Hotkey mapping table
function M.bindHotkeys(instance, mapping)
    local hs = _G.hs
    if not hs or not hs.spoons or not hs.fnutils then
        if instance.logger and instance.logger.w then
            instance.logger.w("Hammerspoon not available for hotkey binding")
        end
        return
    end

    local spec = {
        format = hs.fnutils.partial(instance.formatClipboardDirect, instance),
        -- New binding for seed-on-selection formatting
        formatSelectionSeed = hs.fnutils.partial(instance.formatSelectionSeed, instance),
        formatSeed = hs.fnutils.partial(instance.formatClipboardSeed, instance),
        formatSelection = hs.fnutils.partial(instance.formatSelection, instance),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
end

return M
