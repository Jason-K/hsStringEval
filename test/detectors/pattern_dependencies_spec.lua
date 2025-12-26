describe("detector pattern dependencies", function()
    local DetectorFactory = require("src.utils.detector_factory")
    local patterns = require("src.utils.patterns")

    -- Mock formatter for testing
    local mockFormatter = {
        isCandidate = function() return true end,
        process = function() return nil end
    }

    it("validates patterns exist when declared", function()
        local detector = DetectorFactory.create({
            id = "test_detector",
            patternDependencies = { "arithmetic_candidate", "date_full" },
            formatterKey = "arithmetic",
            defaultFormatter = mockFormatter,
            deps = { patterns = patterns },
        })
        -- Should not throw; patterns exist
        assert.is_not_nil(detector)
    end)

    it("throws error for missing pattern", function()
        local ok, err = pcall(function()
            DetectorFactory.create({
                id = "test_detector",
                patternDependencies = { "nonexistent_pattern" },
                formatterKey = "arithmetic",
                defaultFormatter = mockFormatter,
                deps = { patterns = patterns },
            })
        end)
        assert.is_false(ok)
        -- Check that the error message mentions the missing pattern
        local errStr = tostring(err)
        assert.is_true(errStr:find("nonexistent_pattern") ~= nil,
            "Expected error to mention 'nonexistent_pattern', got: " .. errStr)
    end)
end)
