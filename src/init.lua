local obj = {}
obj.__index = obj

obj.name = "ClipboardFormatter"
obj.version = "1.0"
obj.author = "Jason K"
obj.homepage = "https://github.com/Jason-K/hsStringEval"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local moduleName = ...
local packageRoot = nil

-- Ensure local modules resolve whether loaded as a spoon bundle or direct source require.
local sourcePath = debug.getinfo(1, "S").source
local scriptDir = sourcePath:match("^@(.*/)")
if scriptDir then
    local localLua = scriptDir .. "?.lua"
    local localInit = scriptDir .. "?/init.lua"
    if not package.path:find(localLua, 1, true) then
        package.path = package.path .. ";" .. localLua
    end
    if not package.path:find(localInit, 1, true) then
        package.path = package.path .. ";" .. localInit
    end
end

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
    requireFromRoot("detectors.units"),
    requireFromRoot("detectors.time_calc"),
}

--- ClipboardFormatter:init(opts) -> self
--- Method
--- Initialise the spoon, load configuration, register detectors, and optionally install hotkey helpers
---
--- Parameters:
---  * opts - Optional table with keys:
---    * config - Table of configuration overrides (see docs/configuration.md)
---    * hooks - Hook table or function applied after initialisation
---    * hooksFile - Path to a Lua file that returns a hooks table
---
--- Returns:
---  * The ClipboardFormatter instance (self)
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

    -- Keep nil so submodules use unprefixed local requires.
    self._packageRoot = packageRoot

    pdMappingSystem.load(self)
    hookSystem.apply(self, opts.hooks)
    hookSystem.loadFromFile(self, opts.hooksFile)
    if self.config.hotkeys and self.config.hotkeys.installHelpers then
        hotkeySystem.installHelpers(self)
    end

    return self
end

--- ClipboardFormatter:loadPDMapping([customPath]) -> table
--- Method
--- Load the PD (Permanent Disability) percentage-to-weeks mapping from disk
---
--- Parameters:
---  * customPath - Optional absolute path to a mapping file. Tried first; falls back to bundled and configured paths
---
--- Returns:
---  * Table mapping percentage integers to week values
function obj:loadPDMapping(customPath)
    return pdMappingSystem.load(self, customPath)
end

--- ClipboardFormatter:reloadPDMapping([path]) -> table
--- Method
--- Reload the PD mapping, clearing the cache first
---
--- Parameters:
---  * path - Optional path to reload from. Defaults to the last successfully loaded path
---
--- Returns:
---  * Table mapping percentage integers to week values
function obj:reloadPDMapping(path)
    return pdMappingSystem.reload(self, path)
end

--- ClipboardFormatter:getClipboardContent() -> string or nil
--- Method
--- Return the current primary pasteboard contents
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string with the clipboard contents, or nil if empty
function obj:getClipboardContent()
    return clipboardSystem.get(self)
end

--- ClipboardFormatter:processClipboard(content) -> string or nil
--- Method
--- Run content through the detector registry and return the formatted result
---
--- Parameters:
---  * content - String to evaluate
---
--- Returns:
---  * Formatted string if a detector matched, or nil
function obj:processClipboard(content)
    return processing.process(self, content)
end

--- ClipboardFormatter:registerDetector(detector) -> detector
--- Method
--- Add a custom detector to the registry
---
--- Parameters:
---  * detector - Table with at least an `id` string and a `match(self, text[, context])` function
---
--- Returns:
---  * The detector table that was registered
function obj:registerDetector(detector)
    if not detector or type(detector.match) ~= "function" then
        error("Detector must provide a match function")
    end
    self.registry:register(detector)
    return detector
end

--- ClipboardFormatter:registerFormatter(id, formatter) -> formatter
--- Method
--- Register or replace a formatter module accessible to detectors via context.formatters
---
--- Parameters:
---  * id - Non-empty string key for the formatter (e.g. "arithmetic")
---  * formatter - Any value; conventionally a table with a `process` function
---
--- Returns:
---  * The formatter value that was stored
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

--- ClipboardFormatter:getFormatter(id) -> any or nil
--- Method
--- Retrieve a registered formatter by id
---
--- Parameters:
---  * id - The formatter key passed to registerFormatter
---
--- Returns:
---  * The formatter value, or nil if not found
function obj:getFormatter(id)
    if not self.formatters then
        return nil
    end
    return self.formatters[id]
end

--- ClipboardFormatter:setLogLevel(level)
--- Method
--- Change the active log level at runtime without reloading the spoon
---
--- Parameters:
---  * level - One of "debug", "info", "warning", "error"
---
--- Returns:
---  * None
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

--- ClipboardFormatter:applyHooks(hooks)
--- Method
--- Apply a hook table or function to the spoon instance after initialisation
---
--- Parameters:
---  * hooks - A function called with `self`, or a table with optional keys `formatters` and `detectors` (each a function called with `self`)
---
--- Returns:
---  * None
function obj:applyHooks(hooks)
    return hookSystem.apply(self, hooks)
end

--- ClipboardFormatter:loadHooksFromFile(path)
--- Method
--- Load a hooks table from a Lua file and apply it to the spoon instance
---
--- Parameters:
---  * path - Absolute path to a Lua file that returns a hooks table
---
--- Returns:
---  * None
function obj:loadHooksFromFile(path)
    return hookSystem.loadFromFile(self, path)
end

--- ClipboardFormatter:installHotkeyHelpers() -> table
--- Method
--- Install global helper functions (FormatClip, FormatClipSeed, FormatCutSeed, FormatSelected) for use with Karabiner or direct hotkey bindings
---
--- Parameters:
---  * None
---
--- Returns:
---  * Table of installed helper functions keyed by name
function obj:installHotkeyHelpers()
    return hotkeySystem.installHelpers(self)
end

--- ClipboardFormatter:removeHotkeyHelpers()
--- Method
--- Remove global helper functions previously installed by installHotkeyHelpers
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:removeHotkeyHelpers()
    return hotkeySystem.removeHelpers(self)
end

--- ClipboardFormatter:bindHotkeys(mapping)
--- Method
--- Bind hotkeys to spoon actions using the standard Hammerspoon hotkey mapping convention
---
--- Parameters:
---  * mapping - Table with action name keys and {modifiers, key} values.
---    Supported actions: format, formatSeed, cutLineAndFormatSeed, formatSelection, formatSelectionSeed
---
--- Returns:
---  * None
function obj:bindHotkeys(mapping)
    return hotkeySystem.bindHotkeys(self, mapping)
end

--- ClipboardFormatter:formatClipboardDirect() -> boolean
--- Method
--- Format the entire current clipboard through the detector registry and replace it with the result
---
--- Parameters:
---  * None
---
--- Returns:
---  * true if the clipboard was changed, false otherwise
function obj:formatClipboardDirect()
    return processing.formatClipboardDirect(self)
end

--- ClipboardFormatter:formatClipboardSeed([opts]) -> boolean
--- Method
--- Extract the trailing expression (seed) from the clipboard, format it, and write prefix+result back
---
--- Parameters:
---  * opts - Optional table. Set `autoPaste = true` to immediately paste after formatting
---
--- Returns:
---  * true if the clipboard was changed, false otherwise
function obj:formatClipboardSeed(opts)
    return processing.formatClipboardSeed(self, opts)
end

--- ClipboardFormatter:cutLineAndFormatSeed([opts]) -> boolean
--- Method
--- Select-to-line-start, cut, evaluate the trailing seed, then paste the formatted result in-place
---
--- Parameters:
---  * opts - Optional table of timing overrides
---
--- Returns:
---  * true if the line was changed, false otherwise
function obj:cutLineAndFormatSeed(opts)
    return processing.cutLineAndFormatSeed(self, opts)
end

--- ClipboardFormatter:formatSelection() -> boolean
--- Method
--- Capture the currently selected text, format it through the detector registry, and replace the selection
---
--- Parameters:
---  * None
---
--- Returns:
---  * true if the selection was changed, false otherwise
function obj:formatSelection()
    return processing.formatSelection(self)
end

--- ClipboardFormatter:formatSelectionSeed() -> boolean
--- Method
--- Capture the currently selected text, extract and format only its trailing seed, then replace the selection
---
--- Parameters:
---  * None
---
--- Returns:
---  * true if the selection was changed, false otherwise
function obj:formatSelectionSeed()
    return processing.formatSelectionSeed(self)
end

return obj
