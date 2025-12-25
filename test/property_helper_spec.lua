---@diagnostic disable: undefined-global, undefined-field

describe("Property Helper", function()
    local prop

    setup(function()
        prop = require("property_helper")
        prop.setSeed(12345) -- Use fixed seed for reproducibility
    end)

    describe("generators", function()
        it("should generate random integers", function()
            local val = prop.int(1, 10)
            assert.is_true(val >= 1 and val <= 10)
        end)

        it("should generate random floats", function()
            local val = prop.float(0, 1)
            assert.is_true(val >= 0 and val <= 1)
        end)

        it("should generate random strings", function()
            local str = prop.string(10)
            assert.equals(10, #str)
        end)

        it("should generate alphanumeric strings", function()
            local str = prop.alnum(10)
            assert.equals(10, #str)
            assert.is_true(str:match("^%w+$") ~= nil)
        end)

        it("should generate digit strings", function()
            local str = prop.digits(5)
            assert.equals(5, #str)
            assert.is_true(str:match("^%d+$") ~= nil)
        end)

        it("should generate arithmetic expressions", function()
            local expr = prop.arithmeticExpr(1)
            assert.is_not_nil(expr:match("[%d%+%-%*%(%)]"))
        end)

        it("should generate date strings", function()
            local date = prop.dateString()
            assert.is_not_nil(date:match("%d%d%d%d%-%d%d%-%d%d"))
        end)

        it("should generate phone numbers", function()
            local phone = prop.phoneNumber()
            assert.is_not_nil(phone:match("%(%d%d%d%) %d%d%d%-%d%d%d%d"))
        end)

        it("should generate percentages", function()
            local pct = prop.percentage()
            assert.is_not_nil(pct:match("%d+%%"))
        end)

        it("should generate currency amounts", function()
            local curr = prop.currency()
            assert.is_not_nil(curr:match("%$%d+%.%d%d"))
        end)

        it("should select one of a table", function()
            local tbl = { "a", "b", "c", "d" }
            local val = prop.oneOf(tbl)
            assert.is_true(val == "a" or val == "b" or val == "c" or val == "d")
        end)

        it("should generate random booleans", function()
            local bool = prop.boolean()
            assert.is_true(type(bool) == "boolean")
        end)

        it("should generate whitespace", function()
            local ws = prop.whitespace(5)
            assert.is_true(ws:match("^%s*$") ~= nil)
        end)

        it("should generate wrapped strings", function()
            local str = prop.wrappedString("test")
            assert.is_true(str:match("test") ~= nil)
        end)

        it("should generate seed formats", function()
            local seed = prop.seedFormat(42)
            assert.is_true(seed:match("^[=:]%s*42$") ~= nil)
        end)
    end)

    describe("edgeCases", function()
        it("should return int edge cases", function()
            local cases = prop.edgeCases("int")
            assert.is_true(#cases > 0)
            assert.is_true(cases[1] == 0) -- First case should be 0
        end)

        it("should return float edge cases", function()
            local cases = prop.edgeCases("float")
            assert.is_true(#cases > 0)
        end)

        it("should return string edge cases", function()
            local cases = prop.edgeCases("string")
            assert.is_true(#cases > 0)
        end)

        it("should return arithmetic edge cases", function()
            local cases = prop.edgeCases("arithmetic")
            assert.is_true(#cases > 0)
        end)
    end)

    describe("forAll property testing", function()
        it("should pass a property that always holds", function()
            local property = function(x)
                return x + 1 > x
            end
            local generator = function()
                return prop.int(0, 100)
            end
            local success, failCount = prop.forAll(property, generator, 100)
            assert.is_true(success)
            assert.equals(0, failCount)
        end)

        it("should fail a property that doesn't always hold", function()
            local property = function(x)
                return x > 50 -- Fails for x <= 50
            end
            local generator = function()
                return prop.int(0, 100)
            end
            local success, failCount = prop.forAll(property, generator, 100)
            assert.is_false(success)
            assert.is_true(failCount > 0)
        end)

        it("should handle generator functions that use iteration index", function()
            local values = {}
            local generator = function(i)
                return i * 2
            end
            local property = function(x)
                table.insert(values, x)
                return true
            end
            prop.forAll(property, generator, 5)
            assert.equals(5, #values)
        end)
    end)

    describe("property wrapper", function()
        it("should run property tests successfully", function()
            local property = function(x)
                return x >= 0 and x <= 100
            end
            local generator = function()
                return prop.int(0, 100)
            end
            local success, failCount, failureInput = prop.property(
                "value in range",
                property,
                generator,
                100
            )
            assert.is_true(success)
            assert.equals(0, failCount)
        end)

        it("should report failing inputs", function()
            local property = function(x)
                return x ~= 5
            end
            local generator = function()
                return prop.int(1, 10)
            end
            local success, failCount, failureInput = prop.property(
                "not five",
                property,
                generator,
                100
            )
            assert.is_false(success)
            assert.is_true(failCount > 0)
        end)
    end)

    describe("setSeed", function()
        it("should set random seed for reproducibility", function()
            prop.setSeed(42)
            local val1 = prop.int(1, 1000)

            prop.setSeed(42)
            local val2 = prop.int(1, 1000)

            assert.equals(val1, val2)
        end)

        it("should return the seed value", function()
            local seed = prop.setSeed(999)
            assert.equals(999, seed)
        end)

        it("should use current time when no seed provided", function()
            local seed = prop.setSeed()
            assert.is_not_nil(seed)
            assert.is_true(seed > 0)
        end)
    end)

    describe("subset", function()
        it("should generate empty subset when minSize is 0", function()
            local tbl = { "a", "b", "c", "d", "e" }
            local subset = prop.subset(tbl, 0, 0)
            assert.equals(0, #subset)
        end)

        it("should generate subset within size range", function()
            local tbl = { "a", "b", "c", "d", "e" }
            local subset = prop.subset(tbl, 2, 3)
            assert.is_true(#subset >= 2 and #subset <= 3)
        end)

        it("should generate full subset when maxSize equals table size", function()
            local tbl = { "a", "b", "c" }
            local subset = prop.subset(tbl, 3, 3)
            assert.equals(3, #subset)
        end)

        it("should handle empty input table", function()
            local subset = prop.subset({}, 0, 5)
            assert.equals(0, #subset)
        end)
    end)

    describe("int generator with defaults", function()
        it("should use default range when no args provided", function()
            local val = prop.int()
            assert.is_true(val >= 0 and val <= 100)
        end)

        it("should use only max when min not provided", function()
            local val = prop.int(nil, 50)
            assert.is_true(val >= 0 and val <= 50)
        end)
    end)

    describe("string generator with defaults", function()
        it("should use random length when no length provided", function()
            local str = prop.string()
            assert.is_true(#str >= 1 and #str <= 20)
        end)
    end)
end)
