---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
local ConfigManager = helper.requireFresh("config.manager")

describe("ConfigManager", function()
    local defaultConfig = {
        loggerLevel = "warning",
        throttleMs = 500,
        selection = {
            waitAfterClearMs = 100,
            copyDelayMs = 300,
            retryWithEventtap = true,
        },
        pd = {
            benefitPerWeek = 290,
            bundledFile = "data/pd.txt",
        },
        hotkeys = {
            installHelpers = false,
        },
        templates = {
            arithmetic = nil,
        },
        logging = {
            structured = false,
            includeTimestamp = true,
        },
        restoreClipboard = true,
    }

    describe("load", function()
        it("should return default config when no user config provided", function()
            local result = ConfigManager.load(defaultConfig)
            assert.are.equal(defaultConfig.loggerLevel, result.loggerLevel)
            assert.are.equal(defaultConfig.throttleMs, result.throttleMs)
            assert.are.equal(defaultConfig.selection.waitAfterClearMs, result.selection.waitAfterClearMs)
        end)

        it("should merge user config with defaults", function()
            local userConfig = {
                loggerLevel = "debug",
                throttleMs = 1000,
            }
            local result = ConfigManager.load(defaultConfig, userConfig)
            assert.are.equal("debug", result.loggerLevel)
            assert.are.equal(1000, result.throttleMs)
            assert.are.equal(100, result.selection.waitAfterClearMs) -- from default
        end)

        it("should validate logger levels", function()
            local invalidConfig = { loggerLevel = "invalid" }
            assert.has_error(function()
                ConfigManager.load(defaultConfig, invalidConfig)
            end)
        end)

        it("should validate numeric fields", function()
            local invalidConfig = { throttleMs = -100 }
            assert.has_error(function()
                ConfigManager.load(defaultConfig, invalidConfig)
            end)
        end)

        it("should validate selection config", function()
            local invalidConfig = {
                selection = {
                    waitAfterClearMs = "not-a-number",
                    retryWithEventtap = "not-a-boolean",
                }
            }
            assert.has_error(function()
                ConfigManager.load(defaultConfig, invalidConfig)
            end)
        end)

        it("should validate pd config", function()
            local invalidConfig = {
                pd = {
                    benefitPerWeek = -100,
                    bundledFile = 123,
                }
            }
            assert.has_error(function()
                ConfigManager.load(defaultConfig, invalidConfig)
            end)
        end)

        it("should normalize logger levels to lowercase", function()
            local userConfig = { loggerLevel = "DEBUG" }
            local result = ConfigManager.load(defaultConfig, userConfig)
            assert.are.equal("debug", result.loggerLevel)
        end)
    end)

    describe("validateOption", function()
        it("should validate individual options correctly", function()
            local isValid, errorMsg = ConfigManager.validateOption("loggerLevel", "info")
            assert.is_true(isValid)
            assert.is_nil(errorMsg)

            isValid, errorMsg = ConfigManager.validateOption("loggerLevel", "invalid")
            assert.is_false(isValid)
            assert.is_not_nil(errorMsg)

            isValid, errorMsg = ConfigManager.validateOption("throttleMs", 500)
            assert.is_true(isValid)
            assert.is_nil(errorMsg)

            isValid, errorMsg = ConfigManager.validateOption("throttleMs", -100)
            assert.is_false(isValid)
            assert.is_not_nil(errorMsg)
        end)

        it("should allow unknown options", function()
            local isValid, errorMsg = ConfigManager.validateOption("unknownOption", "value")
            assert.is_true(isValid)
            assert.is_nil(errorMsg)
        end)
    end)

    describe("isValidLoggerLevel", function()
        it("should validate logger levels correctly", function()
            assert.is_true(ConfigManager.isValidLoggerLevel("debug"))
            assert.is_true(ConfigManager.isValidLoggerLevel("info"))
            assert.is_true(ConfigManager.isValidLoggerLevel("warn"))
            assert.is_true(ConfigManager.isValidLoggerLevel("warning"))
            assert.is_true(ConfigManager.isValidLoggerLevel("error"))
            assert.is_false(ConfigManager.isValidLoggerLevel("invalid"))
            assert.is_false(ConfigManager.isValidLoggerLevel(123))
            assert.is_false(ConfigManager.isValidLoggerLevel(nil))
        end)
    end)

    describe("getValidKeys", function()
        it("should return list of valid configuration keys", function()
            local keys = ConfigManager.getValidKeys()
            assert.is_not_nil(keys)
            assert.is_true(#keys > 0)
            -- Check that some expected keys are present
            local keySet = {}
            for _, key in ipairs(keys) do
                keySet[key] = true
            end
            assert.is_not_nil(keySet.loggerLevel)
            assert.is_not_nil(keySet.throttleMs)
            assert.is_not_nil(keySet.selection)
        end)
    end)
end)