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
