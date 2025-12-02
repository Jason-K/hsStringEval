---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")

describe("formatters", function()
    before_each(function()
        helper.reset()
    end)

    it("formats currency strings", function()
        local currency = helper.requireFresh("formatters.currency")
        assert.equal("$10.00", currency.format(10))
        assert.equal("-$1,234.57", currency.format(-1234.567))
        assert.is_nil(currency.format("not a number"))
    end)

    it("evaluates arithmetic expressions", function()
        local arithmetic = helper.requireFresh("formatters.arithmetic")
        assert.is_true(arithmetic.isCandidate("1+1"))
        assert.is_true(arithmetic.isCandidate("2^3"))
    assert.is_true(arithmetic.isCandidate("1.234,5 + 2"))
        assert.is_false(arithmetic.isCandidate("05/05/23"))
        assert.equal("2", arithmetic.process("1+1"))
        assert.equal("$200.00", arithmetic.process("$100*2"))
        assert.equal("1", arithmetic.process("10 % 3"))
        assert.equal("9", arithmetic.process("2^3+1"))
    assert.equal("1236.5", arithmetic.process("1.234,5 + 2"))
    assert.equal("1236.5", arithmetic.process("1,234.5 + 2"))
        assert.is_nil(arithmetic.process("bad"))
        -- Test multiple dollar signs in expressions
        assert.is_true(arithmetic.isCandidate("$120422.50-$118063.37"))
        assert.is_true(arithmetic.isCandidate("$120422.50-118063.37"))
        assert.is_true(arithmetic.isCandidate("120422.50-$118063.37"))
        assert.equal("$2,359.13", arithmetic.process("$120422.50-$118063.37"))
        assert.equal("$2,359.13", arithmetic.process("$120422.50-118063.37"))
        assert.equal("$2,359.13", arithmetic.process("120422.50-$118063.37"))
        local templated = arithmetic.process("$170.89/7", {
            config = {
                templates = {
                    arithmetic = "${input} = ${result}",
                },
            },
        })
        assert.equal("$170.89/7 = $24.41", templated)
        local nonCurrencyTemplate = arithmetic.process("2+2", {
            config = {
                templates = {
                    arithmetic = "${input} → ${result}",
                },
            },
        })
        assert.equal("2+2 → 4", nonCurrencyTemplate)
        local blockingPatterns = {
            arithmetic_candidate = {
                match = function()
                    return nil
                end,
            },
        }
        assert.is_false(arithmetic.isCandidate("1+1", { patterns = blockingPatterns }))
        assert.is_nil(arithmetic.process("1+1", { patterns = blockingPatterns }))
    end)

    it("describes date ranges", function()
        local dateFormatter = helper.requireFresh("formatters.date")
        assert.is_true(dateFormatter.isRangeCandidate("5/6/23 to 6/14/23"))
        assert.is_true(dateFormatter.isRangeCandidate("May 6, 2023 to June 7, 2023"))
        assert.is_true(dateFormatter.isRangeCandidate("2023-05-06T10:00:00Z through 2023-05-07"))
        assert.is_false(dateFormatter.isRangeCandidate("05/06/2023"))
        local desc = dateFormatter.describeRange("5/6/23 to 6/7/23")
        assert.equal("05/06/2023 to 06/07/2023, 33 days", desc)
        assert.equal("05/06/2023 to 06/07/2023, 33 days", dateFormatter.describeRange("May 6, 2023 to June 7, 2023"))
        assert.equal("05/06/2023 to 06/07/2023, 33 days", dateFormatter.describeRange("May 6 to June 7, 2023"))
        assert.equal("05/06/2023 to 05/07/2023, 2 days", dateFormatter.describeRange("2023-05-06T10:00:00Z to 2023-05-07"))
        assert.equal("12/30/2023 to 01/02/2024, 4 days", dateFormatter.describeRange("Dec 30, 2023 to Jan 2"))
        assert.equal("12/30/2023 to 01/02/2024, 4 days", dateFormatter.describeRange("Dec 30 to Jan 2, 2024"))
        assert.equal("05/06/2023 to 06/07/2023, 33 days", dateFormatter.describeRange("May 6 – June 7, 2023"))
        local blockingPatterns = {
            date_token = {
                match = function()
                    return nil
                end,
                gmatch = function()
                    return function() end
                end,
            },
            date_token_iso = {
                match = function()
                    return nil
                end,
                gmatch = function()
                    return function() end
                end,
            },
            date_token_text = {
                match = function()
                    return nil
                end,
                gmatch = function()
                    return function() end
                end,
            },
        }
        assert.is_false(dateFormatter.isRangeCandidate("5/6/23 to 6/14/23", { patterns = blockingPatterns }))
        assert.is_nil(dateFormatter.describeRange("5/6/23 to 6/7/23", { patterns = blockingPatterns }))
    end)

    it("formats phone annotations", function()
        local phone = helper.requireFresh("formatters.phone")
        assert.is_true(phone.isCandidate("5551234567;note"))
        assert.equal("(555) 123-4567,,,note", phone.format("5551234567;note"))
        assert.is_nil(phone.format("short;note"))
        local blockingPatterns = {
            phone_semicolon = {
                match = function()
                    return nil
                end,
                contains = function()
                    return false
                end,
            },
        }
        assert.is_false(phone.isCandidate("5551234567;note", { patterns = blockingPatterns }))
    end)
end)
