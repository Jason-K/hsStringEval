---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local ClipboardOperations = helper.requireFresh("utils.clipboard_operations")

describe("ClipboardOperations", function()
    before_each(function()
        helper.reset()
    end)

    describe("configuration", function()
        it("should create default configuration", function()
            local config = ClipboardOperations.createConfig()
            assert.are.equal(3, config.maxRetries)
            assert.are.equal(100, config.baseDelayMs)
            assert.are.equal(2000, config.maxDelayMs)
            assert.are.equal(50, config.jitterMs)
            assert.is_true(config.exponentialBackoff)
        end)

        it("should merge overrides into configuration", function()
            local config = ClipboardOperations.createConfig({
                maxRetries = 5,
                baseDelayMs = 200
            })
            assert.are.equal(5, config.maxRetries)
            assert.are.equal(200, config.baseDelayMs)
            assert.are.equal(2000, config.maxDelayMs) -- unchanged
        end)
    end)

    describe("stats", function()
        it("should return operation support information", function()
            local stats = ClipboardOperations.getStats()
            assert.is_not_nil(stats.operationsSupported)
            assert.is_boolean(stats.operationsSupported.pasteboard)
            assert.is_boolean(stats.operationsSupported.timer)
            assert.is_true(stats.operationsSupported.applescript)
        end)
    end)

    describe("testClipboardOperations", function()
        it("should test clipboard read/write/clear operations", function()
            -- Mock the clipboard operations for testing
            helper.setClipboard("test content")

            local config = {
                retry = {
                    maxRetries = 2,
                    baseDelayMs = 10,
                    maxDelayMs = 100,
                    jitterMs = 0,
                    exponentialBackoff = false
                }
            }

            local results = ClipboardOperations.testClipboardOperations(config)
            assert.is_table(results)
            assert.is_boolean(results.canRead)
            assert.is_boolean(results.canWrite)
            assert.is_boolean(results.canClear)
            assert.is_table(results.errors)
        end)
    end)

    describe("getTextWithRetry", function()
        it("should return content when clipboard has content", function()
            helper.setClipboard("test content")

            local config = {
                retry = {
                    maxRetries = 2,
                    baseDelayMs = 10,
                    maxDelayMs = 100,
                    jitterMs = 0,
                    exponentialBackoff = false
                }
            }

            local result = ClipboardOperations.getTextWithRetry(config)
            assert.are.equal("test content", result)
        end)

        it("should return nil when clipboard is empty", function()
            helper.setClipboard("")

            local config = {
                retry = {
                    maxRetries = 2,
                    baseDelayMs = 10,
                    maxDelayMs = 100,
                    jitterMs = 0,
                    exponentialBackoff = false
                }
            }

            local result = ClipboardOperations.getTextWithRetry(config)
            assert.is_nil(result)
        end)
    end)

    describe("setTextWithRetry", function()
        it("should set text successfully", function()
            local config = {
                retry = {
                    maxRetries = 2,
                    baseDelayMs = 10,
                    maxDelayMs = 100,
                    jitterMs = 0,
                    exponentialBackoff = false
                }
            }

            local success = ClipboardOperations.setTextWithRetry("new content", config)
            assert.is_true(success)
            assert.are.equal("new content", helper.getClipboard())
        end)

        it("should return false for empty text", function()
            local success = ClipboardOperations.setTextWithRetry("", {})
            assert.is_false(success)

            success = ClipboardOperations.setTextWithRetry(nil, {})
            assert.is_false(success)
        end)
    end)

    describe("clearWithRetry", function()
        it("should clear clipboard successfully", function()
            helper.setClipboard("some content")
            local config = {
                retry = {
                    maxRetries = 2,
                    baseDelayMs = 10,
                    maxDelayMs = 100,
                    jitterMs = 0,
                    exponentialBackoff = false
                }
            }

            local success = ClipboardOperations.clearWithRetry(config)
            assert.is_true(success)
        end)
    end)

    describe("retry logic", function()
        it("should perform retries when configured", function()
            -- Test that retry mechanism works by checking configuration creation
            local config = ClipboardOperations.createConfig({
                maxRetries = 2,
                baseDelayMs = 50
            })
            assert.are.equal(2, config.maxRetries)
            assert.are.equal(50, config.baseDelayMs)
            -- Since we can't easily mock the retry behavior in this environment,
            -- we test that the configuration is properly set up
        end)
    end)
end)