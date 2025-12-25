---@diagnostic disable: undefined-global, undefined-field

describe("Logging Wrapper", function()
    local logging_wrapper

    setup(function()
        logging_wrapper = require("ClipboardFormatter.src.utils.logging_wrapper")
    end)

    it("should wrap a valid logger", function()
        local callLog = {}
        local mockLogger = {
            d = function(msg) table.insert(callLog, {"d", msg}) end,
            i = function(msg) table.insert(callLog, {"i", msg}) end,
            w = function(msg) table.insert(callLog, {"w", msg}) end,
            e = function(msg) table.insert(callLog, {"e", msg}) end
        }

        local wrapped = logging_wrapper.wrap(mockLogger)

        wrapped.d("debug message")
        wrapped.i("info message")
        wrapped.w("warning message")
        wrapped.e("error message")

        assert.equals(4, #callLog)
        assert.equals("d", callLog[1][1])
        assert.equals("debug message", callLog[1][2])
        assert.equals("i", callLog[2][1])
        assert.equals("info message", callLog[2][2])
        assert.equals("w", callLog[3][1])
        assert.equals("warning message", callLog[3][2])
        assert.equals("e", callLog[4][1])
        assert.equals("error message", callLog[4][2])
    end)

    it("should wrap nil logger without errors", function()
        local wrapped = logging_wrapper.wrap(nil)

        -- Should not throw
        wrapped.d("debug message")
        wrapped.i("info message")
        wrapped.w("warning message")
        wrapped.e("error message")

        assert.is_true(true)  -- If we get here, success
    end)

    it("should check logging availability", function()
        local validLogger = { d = function() end }
        assert.is_true(logging_wrapper.canLog(validLogger, "d"))
        assert.is_false(logging_wrapper.canLog(validLogger, "i"))
        assert.is_false(logging_wrapper.canLog(nil, "d"))
    end)

    it("should provide convenience debug function", function()
        local callLog = {}
        local mockLogger = {
            d = function(self, msg) table.insert(callLog, msg) end
        }

        logging_wrapper.debug(mockLogger, "value: %s", "test")

        assert.equals(1, #callLog)
        assert.equals("value: test", callLog[1])
    end)

    it("should provide convenience info function", function()
        local callLog = {}
        local mockLogger = {
            i = function(self, msg) table.insert(callLog, msg) end
        }

        logging_wrapper.info(mockLogger, "info: %s", "test")

        assert.equals(1, #callLog)
        assert.equals("info: test", callLog[1])
    end)

    it("should provide convenience warn function", function()
        local callLog = {}
        local mockLogger = {
            w = function(self, msg) table.insert(callLog, msg) end
        }

        logging_wrapper.warn(mockLogger, "warn: %s", "test")

        assert.equals(1, #callLog)
        assert.equals("warn: test", callLog[1])
    end)

    it("should provide convenience error function", function()
        local callLog = {}
        local mockLogger = {
            e = function(self, msg) table.insert(callLog, msg) end
        }

        logging_wrapper.error(mockLogger, "error: %s", "test")

        assert.equals(1, #callLog)
        assert.equals("error: test", callLog[1])
    end)

    it("should handle nil logger gracefully in convenience functions", function()
        -- Should not throw
        logging_wrapper.debug(nil, "test")
        logging_wrapper.info(nil, "test")
        logging_wrapper.warn(nil, "test")
        logging_wrapper.error(nil, "test")

        assert.is_true(true)
    end)

    it("should store original logger in wrapped object", function()
        local originalLogger = { d = function() end }
        local wrapped = logging_wrapper.wrap(originalLogger)

        assert.equals(originalLogger, wrapped._logger)
    end)

    it("should return nil as original logger when wrapping nil", function()
        local wrapped = logging_wrapper.wrap(nil)

        assert.is_nil(wrapped._logger)
    end)
end)
