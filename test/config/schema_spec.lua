---@diagnostic disable: undefined-global, undefined-field

describe("Configuration Schema Validator", function()
    local config_validator
    local defaults

    setup(function()
        config_validator = require("ClipboardFormatter.src.config.validator")
        defaults = require("ClipboardFormatter.src.config.defaults")
    end)

    it("should pass valid config", function()
        local config = {
            pd = { benefitPerWeek = 300 }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_true(valid)
        assert.is_nil(errors)
    end)

    it("should fail on type mismatch", function()
        local config = {
            pd = { benefitPerWeek = "not a number" }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_false(valid)
        assert.is_not_nil(errors)
        assert.is_truthy(errors[1]:match("expected number"))
    end)

    it("should validate nested config", function()
        local config = {
            selection = { copyDelayMs = "invalid" }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_false(valid)
        assert.is_not_nil(errors)
        assert.is_truthy(errors[1]:match("selection.copyDelayMs"))
    end)

    it("should accept nil values for optional fields", function()
        local config = {
            pd = { benefitPerWeek = nil }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_true(valid)
        assert.is_nil(errors)
    end)

    it("should validate boolean fields", function()
        local config = {
            selection = { retryWithEventtap = "not a boolean" }
        }

        local valid, errors = config_validator.validate(config, defaults)

        assert.is_false(valid)
        assert.is_not_nil(errors)
        assert.is_truthy(errors[1]:match("expected boolean"))
    end)
end)
