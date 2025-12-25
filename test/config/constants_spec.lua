---@diagnostic disable: undefined-global, undefined-field

describe("Constants", function()
    local constants

    setup(function()
        constants = require("ClipboardFormatter.src.config.constants")
    end)

    it("should define all priority constants", function()
        assert.equals(100, constants.PRIORITY.ARITHMETIC)
        assert.equals(70, constants.PRIORITY.PD_CONVERSION)
        assert.equals(60, constants.PRIORITY.COMBINATIONS)
        assert.equals(10000, constants.PRIORITY.NAVIGATION)
        assert.equals(90, constants.PRIORITY.PHONE)
    end)

    it("should define all time constants", function()
        assert.equals(300, constants.TIME.SELECTION_COPY_DELAY)
        assert.equals(600, constants.TIME.SELECTION_TIMEOUT)
        assert.equals(60, constants.TIME.SELECTION_PASTE_DELAY)
        assert.equals(20000, constants.TIME.SELECTION_FALLBACK_DELAY)
        assert.equals(500, constants.TIME.THROTTLE_DEFAULT)
    end)

    it("should define cache constants", function()
        assert.equals(100, constants.CACHE.PATTERN_MAX_SIZE)
        assert.equals(10, constants.CACHE.PATTERN_MEMORY_THRESHOLD_MB)
        assert.equals(50, constants.CACHE.LRU_INITIAL_CAPACITY)
    end)

    it("should define PD defaults", function()
        assert.equals(290, constants.PD.BENEFIT_PER_WEEK)
    end)

    it("should define pattern names", function()
        assert.equals("arithmetic", constants.PATTERNS.ARITHMETIC)
        assert.equals("combination", constants.PATTERNS.COMBINATION)
        assert.equals("phone", constants.PATTERNS.PHONE)
    end)

    it("should define error messages", function()
        assert.equals("missing required dependency", constants.ERRORS.MISSING_DEPENDENCY)
        assert.equals("invalid detector specification", constants.ERRORS.INVALID_DETECTOR_SPEC)
        assert.equals("pattern not found in registry", constants.ERRORS.PATTERN_NOT_FOUND)
        assert.equals("formatter method not found", constants.ERRORS.FORMATTER_MISSING)
    end)

    it("should define validation constants", function()
        assert.equals(100000, constants.VALIDATION.MAX_CLIPBOARD_LENGTH)
        assert.equals(3, constants.VALIDATION.MAX_SELECTION_RETRIES)
    end)
end)
