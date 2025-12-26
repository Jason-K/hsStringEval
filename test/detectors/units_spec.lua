describe("units detector", function()
    local UnitsDetector
    local patterns

    setup(function()
        UnitsDetector = require("src.detectors.units")
        patterns = require("src.utils.patterns").all()
    end)

    local function createContext()
        return {
            logger = { d = function() end, i = function() end, w = function() end, e = function() end },
            config = {},
            patterns = patterns,
            pdMapping = {},
            formatters = {},
        }
    end

    it("converts km to mi", function()
        local ctx = createContext()
        local detector = UnitsDetector(ctx)
        local result = detector.match(detector, "100km to mi", ctx)
        assert.is_not_nil(result)
        assert.is_true(result:match("62") ~= nil)
    end)

    it("converts lb to kg", function()
        local ctx = createContext()
        local detector = UnitsDetector(ctx)
        local result = detector.match(detector, "150lb to kg", ctx)
        assert.is_not_nil(result)
        assert.is_true(result:match("68") ~= nil)
    end)

    it("converts F to C", function()
        local ctx = createContext()
        local detector = UnitsDetector(ctx)
        local result = detector.match(detector, "72F to C", ctx)
        assert.is_not_nil(result)
        assert.is_true(result:match("22") ~= nil)
    end)

    it("returns nil for non-conversion input", function()
        local ctx = createContext()
        local detector = UnitsDetector(ctx)
        local result = detector.match(detector, "hello world", ctx)
        assert.is_nil(result)
    end)
end)
