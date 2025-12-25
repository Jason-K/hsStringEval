local info = debug.getinfo(1, "S")
local specPath = info and info.source and info.source:match("^@(.+)$") or ""
local projectRoot = specPath:match("^(.*)/test/spec_helper%.lua$")
if not projectRoot then
    projectRoot = specPath:match("^(.*)/test/") or ""
end
if projectRoot ~= "" and projectRoot:sub(-1) ~= "/" then
    projectRoot = projectRoot .. "/"
end

local CF_PREFIX = "ClipboardFormatter.src."

package.path = table.concat({
    projectRoot .. "test/?.lua",
    projectRoot .. "test/?/init.lua",
    projectRoot .. "src/?.lua",
    projectRoot .. "src/?/init.lua",
    package.path,
}, ";")

local function tryLoadModule(relative)
    if relative == nil or relative == "" then
        return nil, "not found"
    end
    local basePath = projectRoot .. "src/" .. relative:gsub("%.", "/")
    local candidatePaths = {
        basePath .. ".lua",
        basePath .. "/init.lua",
    }
    for _, path in ipairs(candidatePaths) do
        local chunk, err = loadfile(path)
        if chunk then
            return chunk, path
        elseif err and not err:match("No such file") then
            return nil, err
        end
    end
    return nil, "not found"
end

table.insert(package.searchers, 1, function(name)
    local relative
    local effectiveName
    if name:sub(1, #CF_PREFIX) == CF_PREFIX then
        effectiveName = name
        relative = name:sub(#CF_PREFIX + 1)
    else
        effectiveName = CF_PREFIX .. name
        relative = name
    end

    if package.loaded[effectiveName] then
        return function()
            return package.loaded[effectiveName]
        end
    end

    local chunk, err = tryLoadModule(relative)
    if not chunk then
        if err ~= "not found" then
            return nil, err
        end
        return nil
    end

    return function(...)
        return chunk(effectiveName, ...)
    end
end)

package.preload["hs.ipc"] = function()
    return {}
end

-- Set up preload for Hammerspoon submodules that are required via require()
-- These will return the corresponding tables from the global hs stub
package.preload["hs.uielement"] = function()
    return hs.uielement
end

package.preload["hs.eventtap"] = function()
    return hs.eventtap
end

package.preload["hs.application"] = function()
    return hs.application
end

package.preload["hs.timer"] = function()
    return hs.timer
end

package.preload["hs.alert"] = function()
    return hs.alert
end

local helper = {
    projectRoot = projectRoot,
    alerts = {},
    keyStrokes = {},
    watchers = {},
    consoleCleared = false,
    createdDirs = {},
    lastHotkeySpec = nil,
    osascriptHandler = nil,
    waitUntilCalls = 0,
    taskInvocations = {},
    openedUrls = {},
}

local function toNamespaced(name)
    if name:sub(1, #CF_PREFIX) == CF_PREFIX then
        return name
    end
    return CF_PREFIX .. name
end

local clipboardState = {
    primary = "",
    find = "",
    selection = nil,
}

local function noop() end

local function makeLogger(name, level)
    local obj = {
        name = name,
        level = level,
        messages = {},
    }
    local function log(method)
        return function(self, ...)
            -- When real logger calls sinkMethod(sink, msg), skip the sink arg
            -- Detect this by checking if self has setLogLevel (real logger does, mock doesn't)
            local isRealLoggerCall = type(self.setLogLevel) == "function"
            local args = isRealLoggerCall and { ... } or { self, ... }
            table.insert(obj.messages, { method = method, args = args })
        end
    end
    obj.d = log("d")
    obj.i = log("i")
    obj.w = log("w")
    obj.e = log("e")
    obj.f = log("f")
    obj.setLogLevel = function(_, newLevel)
        obj.level = newLevel
    end
    return obj
end

local function resetHs()
    helper.alerts = {}
    helper.keyStrokes = {}
    helper.watchers = {}
    helper.consoleCleared = false
    helper.createdDirs = {}
    helper.lastHotkeySpec = nil
    helper.osascriptHandler = nil
    helper.pasteInvoked = false
    helper.windowFocused = false
    helper.modifiers = nil
    helper.waitUntilCalls = 0
    helper.taskInvocations = {}
    helper.openedUrls = {}
    clipboardState.primary = ""
    clipboardState.find = ""
    clipboardState.selection = nil
    _G.FormatClip = nil
    _G.FormatSelected = nil
end

resetHs()

local timerStub = {}
timerStub.usleep = function(...) end
timerStub.waitUntil = function(predicate, callback, interval)
    helper.waitUntilCalls = helper.waitUntilCalls + 1
    local attempts = 0
    local maxAttempts = 100
    while attempts < maxAttempts do
        attempts = attempts + 1
        local ok = predicate and predicate()
        if ok then
            if callback then
                callback()
            end
            return true
        end
        if interval and interval > 0 then
            -- no real sleeping in tests; loop counts emulate polling
        end
    end
    return false
end

local function pathwatcherNew(dir, callback)
    return {
        start = function()
            helper.watchers[dir] = callback
            return {
                stop = function()
                    helper.watchers[dir] = nil
                end,
            }
        end,
    }
end

local hsStub = {
    logger = { new = makeLogger },
    pasteboard = {
        getContents = function(which)
            if which == "find" then
                return clipboardState.find
            end
            return clipboardState.primary
        end,
        setContents = function(value)
            clipboardState.primary = value or ""
        end,
        clearContents = function()
            clipboardState.primary = ""
        end,
    },
    osascript = {
        applescript = function(script)
            if helper.osascriptHandler ~= nil then
                return helper.osascriptHandler(script)
            end
            if script:find('keystroke "c"') then
                clipboardState.primary = clipboardState.selection or clipboardState.primary
                return true, clipboardState.primary
            end
            if script:find('keystroke "v"') then
                helper.pasteInvoked = true
                return true, clipboardState.primary
            end
            return true, clipboardState.primary
        end,
    },
    timer = timerStub,
    eventtap = {
        keyStroke = function(mods, key, _)
            table.insert(helper.keyStrokes, { mods = mods, key = key })
            -- Simulate clipboard copy for Cmd+C keystroke
            if type(mods) == "table" and #mods == 1 and mods[1] == "cmd" and key == "c" then
                clipboardState.primary = clipboardState.selection or clipboardState.primary
            end
            -- Simulate clipboard paste for Cmd+V keystroke (for paste operations)
            if type(mods) == "table" and #mods == 1 and mods[1] == "cmd" and key == "v" then
                helper.pasteInvoked = true
            end
        end,
        checkKeyboardModifiers = function()
            return helper.modifiers
        end,
    },
    uielement = {
        focusedElement = function()
            -- Return nil to indicate no focused element available
            return nil
        end
    },
    application = {
        frontmostApplication = function()
            return {
                focusedWindow = function()
                    return {
                        focus = function()
                            helper.windowFocused = true
                        end,
                    }
                end,
                selectMenuItem = function(_, menuPath)
                    -- Mock implementation: return false to indicate menu item not found
                    -- This forces fallback to keystroke-based copy/paste
                    return false
                end,
            }
        end,
    },
    fnutils = {
        partial = function(fn, self)
            return function(...)
                return fn(self, ...)
            end
        end,
    },
    spoons = {
        bindHotkeysToSpec = function(spec, mapping)
            helper.lastHotkeySpec = { spec = spec, mapping = mapping }
        end,
    },
    alert = {
        show = function(message)
            table.insert(helper.alerts, message)
        end,
    },
    console = {
        clearConsole = function()
            helper.consoleCleared = true
        end,
        darkMode = noop,
    },
    window = setmetatable({}, {
        __newindex = function(t, key, value)
            rawset(t, key, value)
        end,
    }),
    fs = {
        attributes = function(path)
            local file = io.open(path, "r")
            if file then
                file:close()
                return { mode = "file" }
            end
            local ok = io.open(path .. "/.", "r")
            if ok then
                ok:close()
                return { mode = "directory" }
            end
            return nil
        end,
        mkdir = function(path)
            helper.createdDirs[path] = true
        end,
        pathToAbsolute = function(path)
            return path
        end,
    },
    pathwatcher = {
        new = pathwatcherNew,
    },
    task = {
        new = function(command, exitHandler, _, args)
            local record = {
                command = command,
                args = args,
                started = false,
            }
            table.insert(helper.taskInvocations, record)
            return {
                setEnvironment = function(_, env)
                    record.env = env
                end,
                start = function()
                    record.started = true
                    if type(exitHandler) == "function" then
                        exitHandler(0, nil, nil)
                    end
                    return true
                end,
            }
        end,
    },
    urlevent = {
        openURL = function(url)
            table.insert(helper.openedUrls, url)
            return true
        end,
    },
    spoonsLoaded = {},
}

_G.hs = hsStub

function helper.reset()
    resetHs()
end

function helper.setClipboard(value)
    clipboardState.primary = value or ""
end

function helper.getClipboard()
    return clipboardState.primary
end

function helper.setFindClipboard(value)
    clipboardState.find = value or ""
end

function helper.setSelectionText(value)
    clipboardState.selection = value
end

function helper.setOsascriptHandler(fn)
    helper.osascriptHandler = fn
end

function helper.requireFresh(name)
    local fullName = toNamespaced(name)
    package.loaded[name] = nil
    package.loaded[fullName] = nil
    local ok, result = pcall(require, fullName)
    if not ok then
        error(result)
    end
    package.loaded[name] = result
    return result
end

function helper.withTempFile(content, fn)
    local tmpName = os.tmpname()
    local file = assert(io.open(tmpName, "w"))
    file:write(content)
    file:close()
    local ok, err = pcall(fn, tmpName)
    os.remove(tmpName)
    if not ok then
        error(err)
    end
end

function helper.runWatcher(dir, ...)
    if helper.watchers[dir] then
        helper.watchers[dir](...)
    end
end

function helper.clearAlerts()
    helper.alerts = {}
end

return helper
