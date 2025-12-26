describe("time_calc detector", function()
    local TimeCalcDetector
    local patterns

    setup(function()
        TimeCalcDetector = require("src.detectors.time_calc")
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

    it("calculates 9am + 2h", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "9am + 2h", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("11:") ~= nil)
    end)

    it("calculates 14:30 - 45m", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "14:30 - 45m", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("13:45") ~= nil)
    end)

    it("calculates now + 30m", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "now + 30m", createContext())
        assert.is_not_nil(result)
    end)

    it("returns nil for non-time input", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "hello world", createContext())
        assert.is_nil(result)
    end)
end)
