---@diagnostic disable: undefined-global, undefined-field

describe("Validation Framework", function()
    local validation

    setup(function()
        validation = require("ClipboardFormatter.src.utils.validation")
    end)

    describe("hasMethods", function()
        it("should validate existing methods", function()
            local obj = { foo = function() end, bar = function() end }
            local valid, err = validation.hasMethods(obj, {"foo", "bar"})

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail on missing method", function()
            local obj = { foo = function() end }
            local valid, err = validation.hasMethods(obj, {"foo", "bar"})

            assert.is_false(valid)
            assert.is_truthy(err:match("bar"))
        end)

        it("should fail on non-table", function()
            local valid, err = validation.hasMethods("string", {"foo"})

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected table"))
        end)
    end)

    describe("validateResult", function()
        it("should pass valid result", function()
            local valid, err = validation.validateResult("hello", "string")

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail on nil result", function()
            local valid, err = validation.validateResult(nil)

            assert.is_false(valid)
            assert.is_truthy(err:match("nil"))
        end)

        it("should fail on type mismatch", function()
            local valid, err = validation.validateResult(123, "string")

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected string"))
        end)

        it("should pass result without type check", function()
            local valid, err = validation.validateResult("any value")

            assert.is_true(valid)
            assert.is_nil(err)
        end)
    end)

    describe("validateDetectorSpec", function()
        it("should pass valid spec", function()
            local spec = {
                name = "test",
                priority = 50,
                pattern = function() end,
                formatter = function() end
            }

            local valid, errors = validation.validateDetectorSpec(spec)

            assert.is_true(valid)
            assert.is_nil(errors)
        end)

        it("should fail on missing fields", function()
            local spec = {}

            local valid, errors = validation.validateDetectorSpec(spec)

            assert.is_false(valid)
            assert.is_not_nil(errors)  -- errors is a table
            -- Check that expected errors are in the list
            assert.is_truthy(table.concat(errors):match("name"))
            assert.is_truthy(table.concat(errors):match("priority"))
        end)

        it("should fail on wrong types", function()
            local spec = {
                name = "test",
                priority = 50,
                pattern = "not a function",
                formatter = function() end
            }

            local valid, errors = validation.validateDetectorSpec(spec)

            assert.is_false(valid)
            assert.is_truthy(table.concat(errors):match("pattern"))
        end)
    end)

    describe("type validator", function()
        it("should validate correct type", function()
            local validator = validation.type("string")
            local valid, err = validator("hello")

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should fail wrong type", function()
            local validator = validation.type("string")
            local valid, err = validator(123)

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected string"))
        end)

        it("should validate number type", function()
            local validator = validation.type("number")
            local valid, err = validator(42)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate table type", function()
            local validator = validation.type("table")
            local valid, err = validator({})

            assert.is_true(valid)
            assert.is_nil(err)
        end)
    end)

    describe("range validator", function()
        it("should validate within range", function()
            local validator = validation.range(1, 10)
            local valid, err = validator(5)

            assert.is_true(valid)
            assert.is_nil(err)
        end)

        it("should validate at boundaries", function()
            local validator = validation.range(1, 10)
            local valid1, err1 = validator(1)
            local valid2, err2 = validator(10)

            assert.is_true(valid1)
            assert.is_nil(err1)
            assert.is_true(valid2)
            assert.is_nil(err2)
        end)

        it("should fail below minimum", function()
            local validator = validation.range(1, 10)
            local valid, err = validator(0)

            assert.is_false(valid)
            assert.is_truthy(err:match("below minimum"))
        end)

        it("should fail above maximum", function()
            local validator = validation.range(1, 10)
            local valid, err = validator(11)

            assert.is_false(valid)
            assert.is_truthy(err:match("above maximum"))
        end)

        it("should fail on non-number input", function()
            local validator = validation.range(1, 10)
            local valid, err = validator("not a number")

            assert.is_false(valid)
            assert.is_truthy(err:match("Expected number"))
        end)
    end)

    describe("ValidationErrorTypes", function()
        it("should provide error type constants", function()
            assert.equals("missing_method", validation.ValidationErrorTypes.MISSING_METHOD)
            assert.equals("invalid_type", validation.ValidationErrorTypes.INVALID_TYPE)
            assert.equals("invalid_value", validation.ValidationErrorTypes.INVALID_VALUE)
            assert.equals("missing_field", validation.ValidationErrorTypes.MISSING_FIELD)
        end)
    end)
end)
