---@diagnostic disable: undefined-global, undefined-field

describe("Error Handler", function()
    local error_handler

    setup(function()
        error_handler = require("ClipboardFormatter.src.utils.error_handler")
    end)

    it("should wrap successful calls", function()
        local fn = function() return "success" end
        local success, result = error_handler.safeCall(fn, "test_operation")

        assert.is_true(success)
        assert.equals("success", result)
    end)

    it("should wrap failed calls with context", function()
        local fn = function() error("test error") end
        local success, result = error_handler.safeCall(fn, "test_operation")

        assert.is_false(success)
        assert.is_truthy(result:match("test_operation"))
        assert.is_truthy(result:match("test error"))
    end)

    it("should use custom error handler", function()
        local fn = function() error("test error") end
        local customHandler = function(err) return "CUSTOM: " .. err end
        local success, result = error_handler.safeCall(fn, "test_operation", customHandler)

        assert.is_false(success)
        assert.is_truthy(result:match("CUSTOM:"))
    end)

    it("should create typed errors", function()
        local err = error_handler.makeError("validation", "Invalid input", {field = "value"})

        assert.equals("validation", err.type)
        assert.equals("Invalid input", err.message)
        assert.equals("value", err.details.field)
        assert.is_not_nil(err.timestamp)
    end)

    it("should log errors with logger", function()
        local lastMsg = nil
        local mockLogger = {
            e = function(msg)
                lastMsg = msg
            end
        }

        local err = error_handler.makeError("runtime", "Something failed")
        error_handler.logError(mockLogger, "test_context", err)

        assert.is_truthy(lastMsg:match("test_context"))
        assert.is_truthy(lastMsg:match("Something failed"))
    end)

    it("should log error strings directly", function()
        local lastMsg = nil
        local mockLogger = {
            e = function(msg)
                lastMsg = msg
            end
        }

        error_handler.logError(mockLogger, "test_context", "plain error string")

        assert.is_truthy(lastMsg:match("test_context"))
        assert.is_truthy(lastMsg:match("plain error string"))
    end)

    it("should handle nil logger gracefully", function()
        -- Should not throw
        local ok, err = pcall(function()
            error_handler.logError(nil, "test_context", "error")
        end)

        assert.is_true(ok)
    end)

    it("should provide error type constants", function()
        assert.equals("validation", error_handler.ErrorTypes.VALIDATION)
        assert.equals("runtime", error_handler.ErrorTypes.RUNTIME)
        assert.equals("dependency", error_handler.ErrorTypes.DEPENDENCY)
        assert.equals("configuration", error_handler.ErrorTypes.CONFIGURATION)
    end)
end)
