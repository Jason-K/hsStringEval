---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")

describe("detectors", function()
    before_each(function()
        helper.reset()
    end)

    it("processes detectors in priority order", function()
        local registry = helper.requireFresh("detectors.registry")
        local log = hs.logger.new("test", "debug")
        local firstCalled = {}
        local detectorA = { id = "a", priority = 10, match = function()
            table.insert(firstCalled, "a")
            return nil
        end }
        local detectorB = { id = "b", priority = 5, match = function()
            table.insert(firstCalled, "b")
            return "hit"
        end }
        local r = registry.new(log, { detectorB, detectorA })
        r:register({ id = "c", priority = 7, match = function()
            table.insert(firstCalled, "c")
            return nil
        end })
        local result, id = r:process("input", {})
        assert.equal("hit", result)
        assert.equal("b", id)
        assert.same({ "b", "c", "a" }, firstCalled)
    end)

    it("detects arithmetic expressions", function()
        local ctor = helper.requireFresh("detectors.arithmetic")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        assert.equal("arithmetic", detector.id)
        local output = detector:match("1+1")
        assert.equal("2", output)
        assert.equal("8", detector:match("2^3"))
        assert.equal("1", detector:match("10%3"))
        assert.equal("1236.5", detector:match("1.234,5+2"))
        assert.equal("1236.5", detector:match("1,234.5+2"))
        local context = {
            patterns = {
                arithmetic_candidate = {
                    match = function()
                        return nil
                    end,
                },
            },
        }
        local blocked = detector.match(detector, "1+1", context)
        assert.is_nil(blocked)
    end)

    it("applies arithmetic templates from context", function()
        local ctor = helper.requireFresh("detectors.arithmetic")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local output = detector:match("$10*2", {
            config = {
                templates = {
                    arithmetic = "${input} = ${result}",
                },
            },
        })
        assert.equal("$10*2 = $20.00", output)
    end)

    it("detects date ranges", function()
        local ctor = helper.requireFresh("detectors.date")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local output = detector:match("5/6/23 to 5/7/23")
        assert.matches("05/06/2023 to 05/07/2023", output)
        local textOutput = detector:match("May 6, 2023 to June 7, 2023")
        assert.matches("05/06/2023 to 06/07/2023", textOutput)
        local isoOutput = detector:match("2023-05-06T10:00:00Z through 2023-05-07")
        assert.matches("05/06/2023 to 05/07/2023", isoOutput)
        local inferredOutput = detector:match("Dec 30, 2023 to Jan 2")
        assert.matches("12/30/2023 to 01/02/2024", inferredOutput)
        local context = {
            patterns = {
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
            },
        }
        local blocked = detector.match(detector, "5/6/23 to 5/7/23", context)
        assert.is_nil(blocked)
    end)

    it("detects PD conversions", function()
        local ctor = helper.requireFresh("detectors.pd")
        local detector = ctor({ logger = hs.logger.new("test", "debug"), config = { pd = { benefitPerWeek = 300 } } })
        local output = detector:match("15pd", { pdMapping = { [15] = 10 } })
        assert.equal("15% PD = 10.00 weeks = $3,000.00", output)
    end)

    it("detects combination strings", function()
        local ctor = helper.requireFresh("detectors.combinations")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local output = detector:match("10 c 5 c 3")
        assert.equal("10% c 5% = 15% c 3% = 17%", output)
    end)

    it("detects annotated phone numbers", function()
        local ctor = helper.requireFresh("detectors.phone")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local output = detector:match("5551234567;home")
        assert.equal("(555) 123-4567,,,home", output)
        local context = {
            patterns = {
                phone_semicolon = {
                    match = function()
                        return nil
                    end,
                    contains = function()
                        return false
                    end,
                },
            },
        }
        local blocked = detector.match(detector, "5551234567;home", context)
        assert.is_nil(blocked)
    end)

    it("opens local paths in QSpace via navigation detector", function()
        local ctor = helper.requireFresh("detectors.navigation")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local context = {}
        local result = detector:match("~/Documents", context)
        assert.is_table(result)
        assert.equal("~/Documents", result.output)
        assert.is_true(result.sideEffectOnly)
        assert.is_table(context.__lastSideEffect)
        assert.equal("qspace", context.__lastSideEffect.type)
        assert.equal("Opened in QSpace", context.__lastSideEffect.message)
        assert.equal(1, #helper.taskInvocations)
        local invocation = helper.taskInvocations[1]
        assert.equal("/usr/bin/open", invocation.command)
        assert.same({ "-a", "QSpace Pro", (os.getenv("HOME") or "") .. "/Documents" }, invocation.args)
    end)

    it("opens http urls in the default browser", function()
        local ctor = helper.requireFresh("detectors.navigation")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local context = {}
        local url = "https://example.com/path"
        local result = detector:match(url, context)
        assert.is_table(result)
        assert.equal(url, result.output)
        assert.equal(url, helper.openedUrls[#helper.openedUrls])
        assert.equal("browser", context.__lastSideEffect.type)
    end)

    it("opens application urls using open -u", function()
        local ctor = helper.requireFresh("detectors.navigation")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local context = {}
        local appUrl = "obsidian://open?vault=Main"
        local result = detector:match(appUrl, context)
        assert.is_table(result)
        assert.equal(appUrl, result.output)
        assert.equal(1, #helper.taskInvocations)
        local invocation = helper.taskInvocations[1]
        assert.equal("/usr/bin/open", invocation.command)
        assert.same({ "-u", appUrl }, invocation.args)
        assert.equal("app_url", context.__lastSideEffect.type)
    end)

    it("falls back to Kagi search when no detectors match", function()
        local ctor = helper.requireFresh("detectors.navigation")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local context = {}
        local query = "example search"
        local _ = detector:match(query, context)
        assert.equal("kagi_search", context.__lastSideEffect.type)
        local opened = helper.openedUrls[#helper.openedUrls]
        assert.matches("https://kagi.com/search%?q=", opened)
        assert.matches("example%%20search", opened)
    end)

    it("skips navigation when a prior detector matches", function()
        local ctor = helper.requireFresh("detectors.navigation")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local context = { __matches = { { id = "arithmetic" } } }
        local result = detector:match("https://example.com", context)
        assert.is_nil(result)
        assert.equal(0, #helper.openedUrls)
    end)
    it("skips navigation for arithmetic-like expressions with dollar signs", function()
        local ctor = helper.requireFresh("detectors.navigation")
        local detector = ctor({ logger = hs.logger.new("test", "debug") })
        local context = {}
        -- Expressions with dollar signs should be recognized as arithmetic
        local result1 = detector:match("$120422.50-$118063.37", context)
        assert.is_nil(result1)
        assert.equal(0, #helper.openedUrls)

        local result2 = detector:match("$120422.50-118063.37", context)
        assert.is_nil(result2)
        assert.equal(0, #helper.openedUrls)

        local result3 = detector:match("120422.50-$118063.37", context)
        assert.is_nil(result3)
        assert.equal(0, #helper.openedUrls)
    end)
end)
