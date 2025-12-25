---@diagnostic disable: undefined-global, undefined-field

describe("Mock Helper", function()
    local mock

    setup(function()
        mock = require("mock_helper")
    end)

    describe("spy", function()
        it("should record function calls", function()
            local fn = mock.spy(function(a, b)
                return a + b
            end)
            local result = fn(2, 3)

            assert.equals(5, result)
            assert.equals(1, #fn.calls)
            assert.equals(2, fn.calls[1][1])
            assert.equals(3, fn.calls[1][2])
        end)

        it("should record multiple calls", function()
            local fn = mock.spy()
            fn(1)
            fn(2)
            fn(3)

            assert.equals(3, #fn.calls)
        end)

        it("should support spyCalledWith assertion", function()
            local fn = mock.spy()
            fn("hello", "world")
            fn("foo", "bar")

            assert.is_true(mock.spyCalledWith(fn, "hello", "world"))
            assert.is_true(mock.spyCalledWith(fn, "foo", "bar"))
            assert.is_false(mock.spyCalledWith(fn, "baz", "qux"))
        end)

        it("should support spyCallCount", function()
            local fn = mock.spy()
            fn()
            fn()
            fn()

            assert.equals(3, mock.spyCallCount(fn))
        end)

        it("should support spyReset", function()
            local fn = mock.spy()
            fn(1)
            fn(2)

            assert.equals(2, #fn.calls)
            mock.spyReset(fn)
            assert.equals(0, #fn.calls)
        end)

        it("should get first and last calls", function()
            local fn = mock.spy()
            fn("first")
            fn("middle")
            fn("last")

            assert.equals("first", mock.getFirstCall(fn))
            assert.equals("last", mock.getLastCall(fn))
        end)
    end)

    describe("stub", function()
        it("should return a fixed value", function()
            local fn = mock.stub(42)
            assert.equals(42, fn())
            assert.equals(42, fn())
        end)

        it("should support return sequence", function()
            local fn = mock.stubSequence(1, 2, 3)
            assert.equals(1, fn())
            assert.equals(2, fn())
            assert.equals(3, fn())
            -- Should keep returning last value
            assert.equals(3, fn())
        end)

        it("should support error stub", function()
            local fn = mock.stubError("Test error")
            assert.has_error(function()
                fn()
            end, "Test error")
        end)
    end)

    describe("mock", function()
        it("should create mock object with methods", function()
            local obj = mock.mock({
                getValue = 42,
                setName = function()
                    return "set"
                end,
            })

            assert.equals(42, obj:getValue())
            assert.equals("set", obj:setName())
        end)

        it("should support partial mock", function()
            local original = {
                method1 = function()
                    return "original1"
                end,
                method2 = function()
                    return "original2"
                end,
            }

            local partial = mock.partialMock(original, {
                method1 = function()
                    return "mocked1"
                end,
            })

            assert.equals("mocked1", partial:method1())
            assert.equals("original2", partial:method2())
        end)
    end)

    describe("mockLogger", function()
        it("should create a mock logger that captures messages", function()
            local logger = mock.mockLogger()

            logger:i("info message")
            logger:w("warning message")

            assert.equals(2, #logger.messages)
            assert.equals("i", logger.messages[1].method)
            assert.equals("info message", logger.messages[1].args[1])
            assert.equals("w", logger.messages[2].method)
            assert.equals("warning message", logger.messages[2].args[1])
        end)

        it("should support setLogLevel", function()
            local logger = mock.mockLogger("info")
            assert.equals("info", logger.level)

            logger:setLogLevel("debug")
            assert.equals("debug", logger.level)
        end)
    end)

    describe("mockConfig", function()
        it("should create a mock config with defaults", function()
            local config = mock.mockConfig()

            assert.is_not_nil(config.processing)
            assert.is_not_nil(config.selection)
            assert.is_not_nil(config.pd)
            assert.is_not_nil(config.logging)
        end)

        it("should support config overrides", function()
            local config = mock.mockConfig({
                processing = {
                    throttleMs = 1000,
                },
            })

            assert.equals(1000, config.processing.throttleMs)
        end)
    end)

    describe("mockPdMapping", function()
        it("should create a mock PD mapping with defaults", function()
            local pd = mock.mockPdMapping()

            assert.equals("1 week", pd["10%"])
            assert.equals("Lifetime", pd["100%"])
        end)

        it("should support custom entries", function()
            local pd = mock.mockPdMapping({
                ["5%"] = "0.5 weeks",
            })

            assert.equals("0.5 weeks", pd["5%"])
        end)
    end)

    describe("mockDetector", function()
        it("should create a mock detector with defaults", function()
            local detector = mock.mockDetector()

            assert.equals("mock_detector", detector.id)
            assert.equals(100, detector.priority)
            assert.is_function(detector.match)
        end)

        it("should support custom detector spec", function()
            local detector = mock.mockDetector({
                id = "custom_detector",
                priority = 50,
                match = function()
                    return "result"
                end,
            })

            assert.equals("custom_detector", detector.id)
            assert.equals(50, detector.priority)
            assert.equals("result", detector:match())
        end)

        it("should support dependencies", function()
            local detector = mock.mockDetector({
                dependencies = { "logger", "config" },
            })

            assert.is_not_nil(detector.dependencies)
            assert.equals(2, #detector.dependencies)
        end)
    end)

    describe("mockContext", function()
        it("should create a detector context with defaults", function()
            local context = mock.mockContext()

            assert.is_not_nil(context.logger)
            assert.is_not_nil(context.config)
            assert.is_not_nil(context.patterns)
            assert.is_not_nil(context.formatters)
            assert.is_not_nil(context.pdMapping)
        end)

        it("should support context overrides", function()
            local customLogger = mock.mockLogger()
            local context = mock.mockContext({
                logger = customLogger,
            })

            assert.equals(customLogger, context.logger)
        end)
    end)

    describe("track", function()
        it("should track function calls", function()
            local fn, tracker = mock.track(function(x)
                return x * 2
            end)

            local result = fn(5)

            assert.is_true(tracker.called)
            assert.equals(1, tracker.callCount)
            assert.equals(5, tracker.lastArgs[1])
            assert.equals(10, result)
        end)

        it("should track multiple calls", function()
            local fn, tracker = mock.track()

            fn()
            fn()
            fn()

            assert.equals(3, tracker.callCount)
        end)
    end)

    describe("assertions", function()
        it("should assert call count", function()
            local fn = mock.spy()
            fn()
            fn()

            assert.is_true(mock.assertCallCount(fn, 2))
            assert.is_false(mock.assertCallCount(fn, 3))
        end)

        it("should assert never called", function()
            local fn = mock.spy()

            assert.is_true(mock.assertNeverCalled(fn))
            fn()
            assert.is_false(mock.assertNeverCalled(fn))
        end)
    end)
end)
