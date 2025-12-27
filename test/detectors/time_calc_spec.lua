describe("time_calc detector", function()
    local TimeCalcDetector
    local patterns
    local TimeMath

    setup(function()
        TimeCalcDetector = require("src.detectors.time_calc")
        patterns = require("src.utils.patterns").all()
        TimeMath = require("src.utils.time_math")
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

    -- Date arithmetic tests
    it("calculates today + 1 day", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "today + 1 day", createContext())
        assert.is_not_nil(result)
        -- Result should be in MM/DD/YYYY format
        assert.is_true(result:match("%d%d/%d%d/%d%d%d%d") ~= nil)
    end)

    it("calculates today + 1 week", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "today + 1 week", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("%d%d/%d%d/%d%d%d%d") ~= nil)
    end)

    it("calculates today - 1 day", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "today - 1 day", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("%d%d/%d%d/%d%d%d%d") ~= nil)
    end)

    it("calculates 12/16/25 + 1 day", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "12/16/25 + 1 day", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("12/17/2025") ~= nil)
    end)

    it("calculates 12/16/25 - 1 day", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "12/16/25 - 1 day", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("12/15/2025") ~= nil)
    end)

    it("calculates 2025-12-16 + 1 week", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "2025-12-16 + 1 week", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("12/23/2025") ~= nil)
    end)

    it("calculates 12/16 + 1 day (no year)", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "12/16 + 1 day", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("%d%d/%d%d/%d%d%d%d") ~= nil)
    end)

    it("calculates today + 1 month", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "today + 1 month", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("%d%d/%d%d/%d%d%d%d") ~= nil)
    end)

    it("calculates today + 1 year", function()
        local detector = TimeCalcDetector(createContext())
        local result = detector.match(detector, "today + 1 year", createContext())
        assert.is_not_nil(result)
        assert.is_true(result:match("%d%d/%d%d/%d%d%d%d") ~= nil)
    end)

    -- Test TimeMath parseDateDuration directly
    it("parses date duration with days", function()
        local duration = TimeMath.parseDateDuration("1 day")
        assert.is_not_nil(duration)
        assert.equals(1, duration.days)
    end)

    it("parses date duration with weeks", function()
        local duration = TimeMath.parseDateDuration("2 weeks")
        assert.is_not_nil(duration)
        assert.equals(2, duration.weeks)
    end)

    it("parses date duration with months", function()
        local duration = TimeMath.parseDateDuration("3 months")
        assert.is_not_nil(duration)
        assert.equals(3, duration.months)
    end)

    it("parses date duration with abbreviations", function()
        local duration = TimeMath.parseDateDuration("1d 2w 3mo")
        assert.is_not_nil(duration)
        assert.equals(1, duration.days)
        assert.equals(2, duration.weeks)
        assert.equals(3, duration.months)
    end)
end)
