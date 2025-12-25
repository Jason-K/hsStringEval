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
local ConfigManager = requireFromRoot("config.manager")
local loggerFactory = requireFromRoot("utils.logger")
local strings = requireFromRoot("utils.strings")
local patterns = requireFromRoot("utils.patterns")
local pdCache = requireFromRoot("utils.pd_cache")
local hsUtils = requireFromRoot("utils.hammerspoon")
local clipboardIO = requireFromRoot("clipboard.io")
local selection = requireFromRoot("clipboard.selection_modular")
local registryFactory = requireFromRoot("detectors.registry")
local hookSystem = requireFromRoot("spoon.hooks")
local hotkeySystem = requireFromRoot("spoon.hotkeys")
local pdMappingSystem = requireFromRoot("spoon.pd_mapping")
local clipboardSystem = requireFromRoot("spoon.clipboard")
local processing = requireFromRoot("spoon.processing")

local detectorConstructors = {
    requireFromRoot("detectors.arithmetic"),
    requireFromRoot("detectors.date"),
    requireFromRoot("detectors.pd"),
    requireFromRoot("detectors.combinations"),
    requireFromRoot("detectors.phone"),
    requireFromRoot("detectors.navigation"),
}

function obj:init(opts)
    opts = opts or {}

    -- Load and validate configuration using ConfigManager
    local logger = nil
    if opts.config and opts.config.logging then
        -- Create a temporary logger for validation errors
        local tempLevel = opts.config.logging.level or defaults.loggerLevel
        logger = loggerFactory.new(self.name or "ClipboardFormatter", tempLevel, opts.config.logging)
    end

    self.config = ConfigManager.load(defaults, opts.config, logger)

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
    self.pdMapping = {}

    for _, constructor in ipairs(detectorConstructors) do
        local detector = constructor({
            logger = self.logger,
            config = self.config,
            patterns = self.patterns,
            formatters = self.formatters,
            pdMapping = self.pdMapping,
        })
        table.insert(self.detectors, detector)
        self.registry:register(detector)
    end

    -- Store packageRoot for use by spoon modules
    self._packageRoot = packageRoot

    pdMappingSystem.load(self)
    hookSystem.apply(self, opts.hooks)
    hookSystem.loadFromFile(self, opts.hooksFile)
    if self.config.hotkeys and self.config.hotkeys.installHelpers then
        hotkeySystem.installHelpers(self)
    end

    return self
end

-- Forwarding methods for PD mapping system (backward compatibility)
function obj:loadPDMapping(customPath)
    return pdMappingSystem.load(self, customPath)
end

function obj:reloadPDMapping(path)
    return pdMappingSystem.reload(self, path)
end

-- Forwarding methods for clipboard system (backward compatibility)
function obj:getClipboardContent()
    return clipboardSystem.get(self)
end

-- Forwarding methods for processing system (backward compatibility)
function obj:processClipboard(content)
    return processing.process(self, content)
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

-- Forwarding methods for hook system (backward compatibility)
function obj:applyHooks(hooks)
    return hookSystem.apply(self, hooks)
end

function obj:loadHooksFromFile(path)
    return hookSystem.loadFromFile(self, path)
end

-- Forwarding methods for hotkey system (backward compatibility)
function obj:installHotkeyHelpers()
    return hotkeySystem.installHelpers(self)
end

function obj:removeHotkeyHelpers()
    return hotkeySystem.removeHelpers(self)
end

function obj:bindHotkeys(mapping)
    return hotkeySystem.bindHotkeys(self, mapping)
end

-- Forwarding methods for processing system (backward compatibility)
function obj:formatClipboardDirect()
    return processing.formatClipboardDirect(self)
end

function obj:formatClipboardSeed(opts)
    return processing.formatClipboardSeed(self, opts)
end

function obj:cutLineAndFormatSeed(opts)
    return processing.cutLineAndFormatSeed(self, opts)
end

function obj:formatSelection()
    return processing.formatSelection(self)
end

function obj:formatSelectionSeed()
    return processing.formatSelectionSeed(self)
end

return obj
