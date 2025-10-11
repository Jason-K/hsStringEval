local obj = {}
obj.__index = obj

obj.name = "ClipboardFormatter"
obj.version = "1.0"
obj.author = "Jason K"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local moduleName = ...
local packageRoot = moduleName and moduleName:match("^(.*)%.init$") or "ClipboardFormatter.src"

local function requireFromRoot(path)
    if packageRoot == nil or packageRoot == "" then
        return require(path)
    end
    return require(packageRoot .. "." .. path)
end

local defaults = requireFromRoot("config.defaults")
local loggerFactory = requireFromRoot("utils.logger")
local strings = requireFromRoot("utils.strings")
local patterns = requireFromRoot("utils.patterns")
local pdCache = requireFromRoot("utils.pd_cache")
local hsUtils = requireFromRoot("utils.hammerspoon")
local clipboardIO = requireFromRoot("clipboard.io")
local selection = requireFromRoot("clipboard.selection")
local registryFactory = requireFromRoot("detectors.registry")

local detectorConstructors = {
    requireFromRoot("detectors.arithmetic"),
    requireFromRoot("detectors.date"),
    requireFromRoot("detectors.pd"),
    requireFromRoot("detectors.combinations"),
    requireFromRoot("detectors.phone"),
    requireFromRoot("detectors.navigation"),
}

local function deepCopy(tbl)
    if type(tbl) ~= "table" then return tbl end
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = deepCopy(v)
    end
    return result
end

local function deepMerge(base, overrides)
    if type(overrides) ~= "table" then return base end
    for k, v in pairs(overrides) do
        if type(v) == "table" and type(base[k]) == "table" then
            deepMerge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

function obj:init(opts)
    opts = opts or {}
    self.config = deepCopy(defaults)
    if opts.config then
        deepMerge(self.config, opts.config)
    end

    local loggingConfig = self.config.logging or {}
    local loggerLevel = loggingConfig.level or self.config.loggerLevel
    self.config.loggerLevel = loggerLevel
    self.logger = loggerFactory.new(self.name or "ClipboardFormatter", loggerLevel, loggingConfig)
    self.patterns = patterns.all()
    self.formatters = {
        arithmetic = requireFromRoot("formatters.arithmetic"),
        currency = requireFromRoot("formatters.currency"),
        date = requireFromRoot("formatters.date"),
        phone = requireFromRoot("formatters.phone"),
    }
    self._hotkeyHelpers = nil
    self._lastProcessing = nil

    self.registry = registryFactory.new(self.logger)
    self.detectors = {}

    for _, constructor in ipairs(detectorConstructors) do
        local detector = constructor({
            logger = self.logger,
            config = self.config,
            formatters = self.formatters,
        })
        table.insert(self.detectors, detector)
        self.registry:register(detector)
    end

    self:loadPDMapping()
    self:applyHooks(opts.hooks)
    self:loadHooksFromFile(opts.hooksFile)
    if self.config.hotkeys and self.config.hotkeys.installHelpers then
        self:installHotkeyHelpers()
    end

    return self
end

function obj:loadPDMapping(customPath)
    local candidates = {}

    if customPath then
        table.insert(candidates, customPath)
    end

    if self.spoonPath then
        if self.config.pd.bundledFile then
            table.insert(candidates, self.spoonPath .. "/" .. self.config.pd.bundledFile)
        end
        if self.config.pd.legacyFile then
            table.insert(candidates, self.spoonPath .. "/" .. self.config.pd.legacyFile)
        end
    end

    if self.config.pd.fallbackPath then
        table.insert(candidates, self.config.pd.fallbackPath)
    end

    for _, path in ipairs(candidates) do
        local map = pdCache.load(path, self.logger)
        if next(map) then
            self.pdMappingPath = path
            self.pdMapping = map
            if self.logger and self.logger.i then
                self.logger.i("Loaded PD mapping from " .. path)
            end
            return map
        end
    end

    self.pdMapping = {}
    if self.logger and self.logger.w then
        self.logger.w("Unable to load PD mapping; PD conversions disabled")
    end
    return self.pdMapping
end

function obj:reloadPDMapping(path)
    local target = path or self.pdMappingPath
    if not target then
        return self:loadPDMapping(path)
    end
    local map = pdCache.reload(target, self.logger)
    if next(map) then
        self.pdMappingPath = target
        self.pdMapping = map
        if self.logger and self.logger.i then
            self.logger.i("Reloaded PD mapping from " .. target)
        end
        return map
    end
    if self.logger and self.logger.w then
        self.logger.w("Reloaded PD mapping but no data found at " .. target)
    end
    return map
end

function obj:getClipboardContent()
    return clipboardIO.getPrimaryPasteboard()
end

function obj:processClipboard(content)
    local trimmed = strings.trim(content)
    if trimmed == "" then
        return nil
    end
    local processingCfg = self.config.processing or {}
    local throttleMs = tonumber(processingCfg.throttleMs) or 0
    local now = hsUtils.nowMillis()
    local last = self._lastProcessing
    if throttleMs > 0 then
        if type(last) == "table" then
            local sameFingerprint = last.fingerprint == trimmed
            local withinWindow = (now - last.timestamp) <= throttleMs
            if sameFingerprint and withinWindow then
                if self.logger and self.logger.d then
                    self.logger.d("Skipping processing within throttle window")
                end
                return last.result, last.matchedId, last.rawResult, last.sideEffect
            end
        end
    end
    local context = {
        logger = self.logger,
        config = self.config,
        patterns = self.patterns,
        pdMapping = self.pdMapping or {},
        formatters = self.formatters,
    }
    local result, matchedId, rawResult = self.registry:process(trimmed, context)
    local sideEffect = context.__lastSideEffect
    self._lastProcessing = {
        fingerprint = trimmed,
        timestamp = now,
        result = result,
        matchedId = matchedId,
        rawResult = rawResult,
        sideEffect = sideEffect,
    }
    return result, matchedId, rawResult, sideEffect
end

function obj:registerDetector(detector)
    if not detector or type(detector.match) ~= "function" then
        error("Detector must provide a match function")
    end
    self.registry:register(detector)
    return detector
end

function obj:registerFormatter(id, formatter)
    if type(id) ~= "string" or id == "" then
        error("Formatter id must be a non-empty string")
    end
    if formatter == nil then
        error("Formatter cannot be nil")
    end
    self.formatters[id] = formatter
    return formatter
end

function obj:getFormatter(id)
    if not self.formatters then
        return nil
    end
    return self.formatters[id]
end

function obj:setLogLevel(level)
    if type(level) ~= "string" or level == "" then
        return
    end
    if self.logger and self.logger.setLogLevel then
        self.logger:setLogLevel(level)
    end
    self.config.loggerLevel = level
    if type(self.config.logging) == "table" then
        self.config.logging.level = level
    end
end

local helperHotkeys = {
    FormatClip = function(self)
        return self:formatClipboardDirect()
    end,
    FormatSelected = function(self)
        return self:formatSelection()
    end,
}

function obj:installHotkeyHelpers()
    self:removeHotkeyHelpers()
    self._hotkeyHelpers = {}
    for name, fn in pairs(helperHotkeys) do
        local wrapper = function()
            return fn(self)
        end
        _G[name] = wrapper
        self._hotkeyHelpers[name] = wrapper
    end
    return self._hotkeyHelpers
end

function obj:removeHotkeyHelpers()
    if not self._hotkeyHelpers then
        return
    end
    for name, wrapper in pairs(self._hotkeyHelpers) do
        if _G[name] == wrapper then
            _G[name] = nil
        end
    end
    self._hotkeyHelpers = nil
end

function obj:applyHooks(hooks)
    if hooks == nil then return end
    if type(hooks) == "function" then
        local ok, err = pcall(hooks, self)
        if not ok and type(self.logger) == "table" and self.logger.w then
            self.logger.w("Hook function failed: " .. tostring(err))
        end
        return
    end
    if type(hooks) == "table" then
        if type(hooks.formatters) == "function" then
            local okFormatters, errFormatters = pcall(hooks.formatters, self)
            if not okFormatters and type(self.logger) == "table" and self.logger.w then
                self.logger.w("Formatter hook failed: " .. tostring(errFormatters))
            end
        end
        if type(hooks.detectors) == "function" then
            local ok, err = pcall(hooks.detectors, self)
            if not ok and type(self.logger) == "table" and self.logger.w then
                self.logger.w("Detector hook failed: " .. tostring(err))
            end
        end
    end
end

function obj:loadHooksFromFile(path)
    local hookPath = path
    if not hookPath and self.spoonPath then
        hookPath = self.spoonPath .. "/config/user_hooks.lua"
    end
    if not hookPath then
        return
    end
    local chunk, err = loadfile(hookPath)
    if not chunk then
        if self.logger and self.logger.d then
            self.logger.d("No user hooks loaded: " .. tostring(err))
        end
        return
    end
    local ok, hooks = pcall(chunk)
    if not ok then
        if self.logger and self.logger.w then
            self.logger.w("Failed to execute hooks file: " .. tostring(hooks))
        end
        return
    end
    self:applyHooks(hooks)
end

function obj:formatClipboardDirect()
    local clipboard = self:getClipboardContent()
    if not clipboard or clipboard == "" then
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Clipboard empty")
        end
        return false
    end

    local formatted, _, _, sideEffect = self:processClipboard(clipboard)
    if sideEffect then
        if type(hs) == "table" and hs.alert then
            local message = sideEffect.message or "Action executed"
            hs.alert.show(message)
        end
        return true
    end

    if type(formatted) == "string" and formatted ~= clipboard then
        clipboardIO.setPrimaryPasteboard(formatted)
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Formatted clipboard")
        end
        return true
    end

    if type(hs) == "table" and hs.alert then
        hs.alert.show("No formattable content in clipboard")
    end
    return false
end

function obj:formatSelection()
    local outcome = selection.apply(function(text)
        return self:processClipboard(text)
    end, {
        logger = self.logger,
        config = {
            waitAfterClearMs = self.config.selection.waitAfterClearMs,
            modifierCheckInterval = self.config.selection.modifierCheckInterval,
            copyDelayMs = self.config.selection.copyDelayMs,
            pasteDelayMs = self.config.selection.pasteDelayMs,
            pollIntervalMs = self.config.selection.pollIntervalMs,
            maxPolls = self.config.selection.maxPolls,
            retryWithEventtap = self.config.selection.retryWithEventtap,
        },
        restoreOriginal = self.config.restoreClipboard,
    })

    if outcome.success then
        if type(hs) == "table" and hs.alert then
            hs.alert.show("Formatted selection")
        end
        return true
    end

    if type(hs) == "table" and hs.alert then
        local reason = outcome.reason == "no_selection" and "Could not get selected text" or "No formatting needed"
        hs.alert.show(reason)
    end

    return false
end

function obj:bindHotkeys(mapping)
    local spec = {
        format = hs.fnutils.partial(self.formatClipboardDirect, self),
        formatSelection = hs.fnutils.partial(self.formatSelection, self),
    }
    hs.spoons.bindHotkeysToSpec(spec, mapping)
end

return obj
