-- Standardized Mock Helper for ClipboardFormatter Tests
-- Provides consistent APIs for creating mocks, spies, and stubs

local M = {}

--- Create a spy that records all calls to a function
-- @param originalFn Optional original function to wrap
-- @return Spy table that records calls, with {calls, original, reset}
function M.spy(originalFn)
    local spy = {
        calls = {},
        original = originalFn,
    }

    setmetatable(spy, {
        __call = function(_, ...)
            table.insert(spy.calls, { ... })
            if type(originalFn) == "function" then
                return originalFn(...)
            end
        end,
    })

    function spy.reset()
        spy.calls = {}
    end

    return spy
end

--- Assert that a spy was called with specific arguments
-- @param spy The spy to check
-- @param ... Expected arguments (use nil for wildcard)
-- @return true if called with matching arguments, false otherwise
function M.spyCalledWith(spy, ...)
    local expected = { ... }
    for _, call in ipairs(spy.calls) do
        local match = true
        for i, arg in ipairs(expected) do
            if expected[i] ~= nil and call[i] ~= expected[i] then
                match = false
                break
            end
        end
        if match then
            return true
        end
    end
    return false
end

--- Get the number of times a spy was called
-- @param spy The spy to check
-- @return Number of calls
function M.spyCallCount(spy)
    return #spy.calls
end

--- Reset a spy's call history
-- @param spy The spy to reset
function M.spyReset(spy)
    if type(spy) == "table" and type(spy.reset) == "function" then
        spy:reset()
    else
        spy.calls = {}
    end
end

--- Create a stub that returns a fixed value
-- @param returnValue The value to return
-- @return Stub function
function M.stub(returnValue)
    return function()
        return returnValue
    end
end

--- Create a stub that returns values from a sequence
-- @param ... Values to return in sequence
-- @return Stub function
function M.stubSequence(...)
    local values = { ... }
    local index = 1
    return function()
        if index <= #values then
            local result = values[index]
            index = index + 1
            return result
        end
        return values[#values]
    end
end

--- Create a mock object with specified methods
-- @param methodSpec Table mapping method names to return values or functions
-- @return Mock object with mocked methods
function M.mock(methodSpec)
    local mock = {}
    for methodName, returnValueOrFn in pairs(methodSpec) do
        if type(returnValueOrFn) == "function" then
            mock[methodName] = returnValueOrFn
        else
            mock[methodName] = function()
                return returnValueOrFn
            end
        end
    end
    return mock
end

--- Create a mock logger that captures log messages
-- @param level Optional log level (default: "debug")
-- @return Mock logger with messages table
function M.mockLogger(level)
    local logger = {
        level = level or "debug",
        messages = {},
    }

    local function log(method)
        return function(self, ...)
            table.insert(logger.messages, { method = method, args = { ... } })
        end
    end

    logger.d = log("d")
    logger.i = log("i")
    logger.w = log("w")
    logger.e = log("e")
    logger.f = log("f")
    logger.setLogLevel = function(_, newLevel)
        logger.level = newLevel
    end

    return logger
end

--- Create a mock configuration
-- @param overrides Optional table with config overrides
-- @return Mock configuration table
function M.mockConfig(overrides)
    local defaults = require("ClipboardFormatter.src.config.defaults")
    local config = {}

    -- Deep copy defaults
    for section, values in pairs(defaults) do
        config[section] = {}
        if type(values) == "table" then
            for k, v in pairs(values) do
                config[section][k] = v
            end
        else
            config[section] = values
        end
    end

    -- Apply overrides
    if overrides then
        for section, values in pairs(overrides) do
            if type(values) == "table" then
                config[section] = config[section] or {}
                for k, v in pairs(values) do
                    config[section][k] = v
                end
            else
                config[section] = values
            end
        end
    end

    return config
end

--- Create a mock PD mapping
-- @param entries Optional table of PD entries
-- @return Mock PD mapping table
function M.mockPdMapping(entries)
    return entries or {
        ["10%"] = "1 week",
        ["25%"] = "3 weeks",
        ["50%"] = "6 weeks",
        ["60%"] = "9 weeks",
        ["75%"] = "15 weeks",
        ["80%"] = "21 weeks",
        ["90%"] = "30 weeks",
        ["100%"] = "Lifetime",
    }
end

--- Create a mock detector
-- @param spec Detector specification with id, priority, match function
-- @return Mock detector object
function M.mockDetector(spec)
    spec = spec or {}
    local detector = {
        id = spec.id or "mock_detector",
        priority = spec.priority or 100,
        match = spec.match or function()
            return nil
        end,
    }
    if spec.dependencies then
        detector.dependencies = spec.dependencies
    end
    return detector
end

--- Create a detector context for testing
-- @param overrides Optional context overrides
-- @return Detector context table
function M.mockContext(overrides)
    local patterns = require("ClipboardFormatter.src.utils.patterns")
    local formatters = require("ClipboardFormatter.src.formatters")
    local defaults = require("ClipboardFormatter.src.config.defaults")

    local context = {
        logger = M.mockLogger(),
        config = M.mockConfig(),
        patterns = patterns.all(),
        formatters = formatters,
        pdMapping = M.mockPdMapping(),
    }

    if overrides then
        for k, v in pairs(overrides) do
            context[k] = v
        end
    end

    return context
end

--- Create a mock that errors on call
-- @param errorMessage Optional error message
-- @return Function that throws an error
function M.stubError(errorMessage)
    errorMessage = errorMessage or "Mock error"
    return function()
        error(errorMessage)
    end
end

--- Track if a function was called
-- @param fn Function to track
-- @return Tracked function and table with {called, callCount, lastArgs}
function M.track(fn)
    local tracker = {
        called = false,
        callCount = 0,
        lastArgs = nil,
    }

    return function(...)
        tracker.called = true
        tracker.callCount = tracker.callCount + 1
        tracker.lastArgs = { ... }
        if type(fn) == "function" then
            return fn(...)
        end
    end, tracker
end

--- Create a partial mock of an object
-- @param obj Original object
-- @param methodSpec Table mapping method names to mocks
-- @return Object with specified methods replaced
function M.partialMock(obj, methodSpec)
    local mock = {}
    for k, v in pairs(obj) do
        mock[k] = v
    end
    for methodName, returnValueOrFn in pairs(methodSpec) do
        if type(returnValueOrFn) == "function" then
            mock[methodName] = returnValueOrFn
        else
            mock[methodName] = function()
                return returnValueOrFn
            end
        end
    end
    return mock
end

--- Assert a spy was called exactly N times
-- @param spy The spy to check
-- @param expectedCount Expected number of calls
-- @return true if call count matches, false otherwise
function M.assertCallCount(spy, expectedCount)
    return #spy.calls == expectedCount
end

--- Assert a spy was never called
-- @param spy The spy to check
-- @return true if never called, false otherwise
function M.assertNeverCalled(spy)
    return #spy.calls == 0
end

--- Get the first call to a spy
-- @param spy The spy to check
-- @return First call arguments or nil
function M.getFirstCall(spy)
    if #spy.calls > 0 then
        return table.unpack(spy.calls[1])
    end
    return nil
end

--- Get the last call to a spy
-- @param spy The spy to check
-- @return Last call arguments or nil
function M.getLastCall(spy)
    if #spy.calls > 0 then
        return table.unpack(spy.calls[#spy.calls])
    end
    return nil
end

return M
