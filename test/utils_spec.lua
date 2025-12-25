---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")

describe("utils modules", function()
    before_each(function()
        helper.reset()
    end)

    it("creates loggers with adjustable levels", function()
        local loggerModule = helper.requireFresh("utils.logger")
        local logger = loggerModule.new("test", "debug")
        assert.equal("debug", logger.level)
        logger:setLogLevel("info")
        assert.equal("info", logger.level)
        logger:d("hello")
        assert.equal("hello", logger.messages[1].args[1])
    end)

    it("emits structured log entries when enabled", function()
        local loggerModule = helper.requireFresh("utils.logger")
        local logger = loggerModule.new("test", "info", {
            structured = true,
            includeTimestamp = false,
        })
    logger:w("hello", "world")
    local entry = logger.messages[#logger.messages]
    assert.same("w", entry.method)
    assert.equal('{"level":"warning","message":"hello world"}', entry.args[1])
        logger:setLogLevel("error")
        assert.equal("error", logger.level)
    end)

    it("properly stringifies multiple args in structured mode", function()
        local loggerModule = helper.requireFresh("utils.logger")
        local logger = loggerModule.new("test", "info", {
            structured = true,
            includeTimestamp = false,
        })
        logger:w("hello", "world")
        local entry = logger.messages[#logger.messages]
        assert.equal('{"level":"warning","message":"hello world"}', entry.args[1])
    end)

    it("handles string helpers", function()
        local strings = helper.requireFresh("utils.strings")
        assert.equal("abc", strings.trim("  abc  "))
        assert.same({ "a", "b" }, strings.split("a,b", ","))
        assert.is_true(strings.containsOnly("123", "0-9"))
        assert.is_false(strings.containsOnly("12a", "0-9"))
        assert.is_true(strings.startsWith("foobar", "foo"))
        assert.is_false(strings.startsWith("bar", "foo"))
        assert.is_true(strings.equalFold("Foo", "foo"))
        assert.equal("1-2-3", strings.normalizeMinus("1−2—3"))
        local prefix, seed = strings.extractSeed("let x = 5 + 3")
        assert.equal("let x = ", prefix)
        assert.equal("5 + 3", seed)

        local p2, s2 = strings.extractSeed("result:\t10*2")
        assert.equal("result:\t", p2)
        assert.equal("10*2", s2)

        local p3, s3 = strings.extractSeed("line1\n15/3")
        assert.equal("line1\n", p3)
        assert.equal("15/3", s3)

        local p4, s4 = strings.extractSeed("no-whitespace")
        assert.equal("", p4)
        assert.equal("no-whitespace", s4)

        local p5, s5 = strings.extractSeed("")
        assert.equal("", p5)
        assert.equal("", s5)
    end)

    it("handles pure arithmetic with spaces", function()
        local strings = helper.requireFresh("utils.strings")
        local prefix, seed = strings.extractSeed("5 + 3")
        assert.equal("", prefix)
        assert.equal("5 + 3", seed)

        local p2, s2 = strings.extractSeed("(5 + 3) * 2")
        assert.equal("", p2)
        assert.equal("(5 + 3) * 2", s2)
    end)

    it("exposes compiled pattern helpers", function()
        local patterns = helper.requireFresh("utils.patterns")
        local raw = patterns.get("arithmetic_candidate")
        assert.is_string(raw)
        local compiled = patterns.compiled("arithmetic_candidate")
        assert.is_not_nil(compiled)
        assert.is_true(compiled.contains("$1 + 1"))
        assert.is_table(patterns.all())
    end)

    it("supports adaptive clipboard waits", function()
        local hsUtils = helper.requireFresh("utils.hammerspoon")
        helper.setClipboard("original")
        local none = hsUtils.waitForClipboardChange("original", {
            pollIntervalMs = 10,
            maxPolls = 2,
        })
        assert.is_nil(none)
        assert.is_true(helper.waitUntilCalls > 0)
        helper.setClipboard("changed")
        local immediate = hsUtils.waitForClipboardChange("original")
        assert.equal("changed", immediate)
    end)

    it("loads and caches PD mappings", function()
        helper.withTempFile("10: 2.5\n15: 3.0\n", function(path)
            local pdCache = helper.requireFresh("utils.pd_cache")
            local map = pdCache.load(path)
            assert.equal(2.5, map[10])
            assert.equal(2.5, pdCache.get(path, 10))
            assert.is_true(pdCache.available(path))
            local updated = "10: 3.5\n"
            helper.withTempFile(updated, function(reloadPath)
                pdCache.reload(reloadPath)
                assert.equal(3.5, pdCache.get(reloadPath, 10))
            end)
            pdCache.reload(path)
            assert.equal(2.5, pdCache.get(path, 10))
            pdCache.clear(path)
            assert.is_false(pdCache.available(path))
            pdCache.clear()
        end)
    end)
end)

describe("Detector Factory - Dependency Validation", function()
    local detector_factory
    local defaultFormatter

    setup(function()
        detector_factory = require("ClipboardFormatter.src.utils.detector_factory")
        defaultFormatter = require("ClipboardFormatter.src.formatters.arithmetic")
    end)

    it("should validate that declared dependencies are available", function()
        local ok, err = pcall(function()
            return detector_factory.create({
                id = "bad_detector",
                dependencies = {"nonexistent_dependency"},
                priority = 50,
                formatterKey = "arithmetic",
                defaultFormatter = defaultFormatter,
                deps = {}  -- Empty dependencies - missing "nonexistent_dependency"
            })
        end)

        assert.is_false(ok)
        assert.is_truthy(err:match("nonexistent_dependency") or err:match("not provided"))
    end)

    it("should allow detectors with no dependencies", function()
        local ok, detector = pcall(function()
            return detector_factory.create({
                id = "good_detector",
                dependencies = {},
                priority = 50,
                formatterKey = "arithmetic",
                defaultFormatter = defaultFormatter,
                deps = {}
            })
        end)

        assert.is_true(ok)
        assert.is_not_nil(detector)
        assert.equals("good_detector", detector.id)
    end)

    it("should allow detectors with valid dependencies", function()
        local patterns = require("ClipboardFormatter.src.utils.patterns")
        local ok, detector = pcall(function()
            return detector_factory.create({
                id = "valid_detector",
                dependencies = {"patterns"},
                priority = 50,
                formatterKey = "arithmetic",
                defaultFormatter = defaultFormatter,
                deps = { patterns = patterns.all() }
            })
        end)

        assert.is_true(ok)
        assert.is_not_nil(detector)
        assert.equals("valid_detector", detector.id)
    end)

    it("should validate dependencies for createCustom as well", function()
        local ok, err = pcall(function()
            return detector_factory.createCustom({
                id = "bad_custom_detector",
                dependencies = {"missing_dep"},
                priority = 50,
                deps = {},
                customMatch = function() return nil end
            })
        end)

        assert.is_false(ok)
        assert.is_truthy(err:match("missing_dep") or err:match("not provided"))
    end)

    it("should inject declared dependencies into context for createCustom", function()
        local mockLogger = { d = function() end }
        local detector = detector_factory.createCustom({
            id = "custom_with_logger",
            dependencies = {"logger"},
            priority = 50,
            deps = { logger = mockLogger },
            customMatch = function(text, context)
                -- Logger should be injected into context
                return context.logger and "ok" or nil
            end
        })

        assert.is_not_nil(detector)
        local result = detector:match("test", {})
        assert.equals("ok", result)
    end)
end)
