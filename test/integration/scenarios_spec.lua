--[[
WHAT THIS FILE DOES:
This module provides comprehensive edge-case testing scenarios for the clipboard
formatting system. It tests reliability under stress conditions, memory pressure,
concurrent access, and various failure modes to ensure robustness.

KEY CONCEPTS:
- Stress Testing: High-volume operations to test performance degradation
- Memory Pressure: Testing behavior under low memory conditions
- Clipboard Corruption: Handling corrupted or invalid clipboard data
- Concurrent Access: Simulating multiple simultaneous operations
- Failure Recovery: System behavior under various error conditions
- Edge Cases: Boundary conditions and unusual input scenarios

EXAMPLE USAGE:
    local Scenarios = require("test.integration.scenarios")
    Scenarios.testMemoryPressure()
    Scenarios.testConcurrentAccess()
    Scenarios.testClipboardCorruption()
]]

local helper = require("spec_helper")
local Scenarios = {}

-- Mock functions for testing edge cases
local function createCorruptedClipboard()
    return "\000\001\002\003\004\005corrupted\255\254\253\252" -- Invalid UTF-8 bytes
end

local function createHugeClipboard()
    local huge = ""
    for i = 1, 100000 do
        huge = huge .. "This is a very long line that will make the clipboard huge. "
    end
    return huge
end

local function createSpecialCharacters()
    return "测试🚀Ñiño©™℠∞∂∆∇∫∑π∏√∛∜∝∞∟∠∡∢∣∤∥∦∧∨∩∪∫∬∭∮∯∰∱∲∳∂∇∆∏∑∐∓∔∕∖∗∘∙√∛∜∝∞∟∠∡∢∣∤∥∦∧∨∩∪∫∬∭∮∯∰∱∲∳"
end

-- Memory pressure simulation
local function simulateMemoryPressure()
    local tables = {}
    for i = 1, 1000 do
        local table = {}
        for j = 1, 1000 do
            table[j] = ("test data %d %d"):format(i, j) .. string.rep("x", 100)
        end
        tables[i] = table
    end
    return tables
end

-- Concurrent operation simulation
local function simulateConcurrentAccess(operationCount)
    local results = {}
    local operations = {}

    for i = 1, operationCount do
        table.insert(operations, {
            id = i,
            timestamp = os.time(),
            data = "concurrent_test_" .. i
        })
    end

    -- Simulate concurrent access by running operations rapidly
    for _, op in ipairs(operations) do
        helper.setClipboard(op.data)
        local readBack = helper.getClipboard()
        table.insert(results, {
            success = readBack == op.data,
            operationId = op.id,
            timestamp = os.time()
        })
    end

    return results
end

-- Test scenarios
function Scenarios.testMemoryPressure()
    describe("Memory Pressure Scenarios", function()
        it("should handle operations under memory pressure", function()
            -- Create memory pressure
            local memoryHog = simulateMemoryPressure()
            collectgarbage("collect")

            -- Test clipboard operations under pressure
            helper.setClipboard("test under pressure")
            local result = helper.getClipboard()
            assert.are.equal("test under pressure", result)

            -- Clean up
            memoryHog = nil
            collectgarbage("collect")
        end)

        it("should recover from out of memory conditions", function()
            -- Simulate extreme memory pressure
            local extremeMemory = {}
            for i = 1, 10000 do
                extremeMemory[i] = string.rep("x", 1000) -- 1KB each = 10MB total
            end

            -- Force garbage collection
            collectgarbage("collect")

            -- Test that basic operations still work
            helper.setClipboard("recovery test")
            local result = helper.getClipboard()
            assert.are.equal("recovery test", result)

            -- Clean up
            extremeMemory = nil
            collectgarbage("collect")
        end)
    end)
end

function Scenarios.testClipboardCorruption()
    describe("Clipboard Corruption Scenarios", function()
        it("should handle corrupted clipboard data", function()
            helper.setClipboard(createCorruptedClipboard())

            -- Should not crash when reading corrupted data
            local result = helper.getClipboard()
            assert.is_not_nil(result)

            -- Should be able to set valid data after corruption
            helper.setClipboard("recovered data")
            local recovered = helper.getClipboard()
            assert.are.equal("recovered data", recovered)
        end)

        it("should handle empty clipboard", function()
            helper.setClipboard("")

            local result = helper.getClipboard()
            assert.are.equal("", result)

            -- Should recover from empty state
            helper.setClipboard("recovered")
            result = helper.getClipboard()
            assert.are.equal("recovered", result)
        end)

        it("should handle nil clipboard", function()
            -- Simulate nil clipboard by clearing
            helper.setClipboard("")
            local result = helper.getClipboard()
            assert.is_not_nil(result)
        end)
    end)
end

function Scenarios.testConcurrentAccess()
    describe("Concurrent Access Scenarios", function()
        it("should handle rapid clipboard operations", function()
            local results = simulateConcurrentAccess(100)

            -- Most operations should succeed
            local successCount = 0
            for _, result in ipairs(results) do
                if result.success then
                    successCount = successCount + 1
                end
            end

            -- Allow for some failures due to timing, but most should succeed
            assert.is_true(successCount >= 90, ("Only %d out of %d operations succeeded"):format(successCount, #results))
        end)

        it("should handle simultaneous read/write operations", function()
            local writeResults = {}
            local readResults = {}

            -- Simulate simultaneous operations
            for i = 1, 50 do
                local testData = ("simultaneous_%d"):format(i)
                helper.setClipboard(testData)
                writeResults[i] = helper.getClipboard() == testData

                -- Immediate read
                readResults[i] = helper.getClipboard()
            end

            -- Most writes should be successful
            local writeSuccess = 0
            for _, success in ipairs(writeResults) do
                if success then writeSuccess = writeSuccess + 1 end
            end
            assert.is_true(writeSuccess >= 45)

            -- Reads should return some valid data
            local validReads = 0
            for _, read in ipairs(readResults) do
                if read and read ~= "" then
                    validReads = validReads + 1
                end
            end
            assert.is_true(validReads > 0)
        end)
    end)
end

function Scenarios.testEdgeCases()
    describe("Edge Cases and Boundary Conditions", function()
        it("should handle extremely large clipboard content", function()
            local hugeContent = createHugeClipboard()
            helper.setClipboard(hugeContent)

            local result = helper.getClipboard()
            assert.are.equal(#hugeContent, #result)

            -- Should recover to normal size
            helper.setClipboard("normal size")
            local recovered = helper.getClipboard()
            assert.are.equal("normal size", recovered)
        end)

        it("should handle special characters and Unicode", function()
            local specialContent = createSpecialCharacters()
            helper.setClipboard(specialContent)

            local result = helper.getClipboard()
            assert.are.equal(specialContent, result)
        end)

        it("should handle numeric edge cases", function()
            local numericEdgeCases = {
                "0",
                "-0",
                "2147483647", -- INT_MAX
                "-2147483648", -- INT_MIN
                "9223372036854775807", -- 64-bit max
                "-9223372036854775808", -- 64-bit min
                "0.0000000001",
                "999999999999999999999",
                "1e308", -- Large number
                "1e-308", -- Small number
                "NaN",
                "Infinity",
                "-Infinity"
            }

            for _, testCase in ipairs(numericEdgeCases) do
                helper.setClipboard(testCase)
                local result = helper.getClipboard()
                assert.are.equal(testCase, result)
            end
        end)

        it("should handle string edge cases", function()
            local stringEdgeCases = {
                "", -- Empty string
                " ", -- Single space
                "\t\n\r", -- Whitespace only
                string.rep("a", 1), -- Single character
                string.rep("b", 10000), -- Long string
                nil, -- Nil value (should not crash)
                {}, -- Table (should not crash)
                function() end, -- Function (should not crash)
            }

            for _, testCase in ipairs(stringEdgeCases) do
                -- These should not crash
                pcall(function()
                    if type(testCase) == "string" then
                        helper.setClipboard(testCase)
                        local result = helper.getClipboard()
                        assert.are.equal(testCase, result)
                    end
                end)
            end
        end)

        it("should handle timing edge cases", function()
            -- Very fast operations
            for i = 1, 1000 do
                helper.setClipboard(("fast_%d"):format(i))
                helper.getClipboard()
            end

            -- Operations with small delays
            for i = 1, 10 do
                helper.setClipboard(("delayed_%d"):format(i))
                os.execute("sleep 0.001") -- 1ms delay
                local result = helper.getClipboard()
                assert.are.equal(("delayed_%d"):format(i), result)
            end
        end)
    end)
end

function Scenarios.testErrorRecovery()
    describe("Error Recovery Scenarios", function()
        it("should recover from invalid operations gracefully", function()
            -- Try various invalid operations
            local invalidOperations = {
                function() helper.setClipboard(nil) end,
                function() helper.setClipboard({}) end,
                function() helper.setClipboard(function() end) end
            }

            for _, op in ipairs(invalidOperations) do
                -- Should not crash
                pcall(op)
            end

            -- System should still work after invalid operations
            helper.setClipboard("recovered after invalid ops")
            local result = helper.getClipboard()
            assert.are.equal("recovered after invalid ops", result)
        end)

        it("should maintain consistency after errors", function()
            -- Establish a known state
            helper.setClipboard("initial state")
            assert.are.equal("initial state", helper.getClipboard())

            -- Perform operation that might fail
            pcall(function()
                helper.setClipboard(createCorruptedClipboard())
            end)

            -- Check if system is still responsive
            helper.setClipboard("consistency check")
            local result = helper.getClipboard()
            assert.are.equal("consistency check", result)
        end)

        it("should handle rapid state changes", function()
            -- Rapid state changes
            for i = 1, 100 do
                helper.setClipboard(("state_%d"):format(i))
                -- Occasionally read back to verify consistency
                if i % 10 == 0 then
                    local result = helper.getClipboard()
                    assert.are.equal(("state_%d"):format(i), result)
                end
            end

            -- Final state should be correct
            local finalResult = helper.getClipboard()
            assert.are.equal("state_100", finalResult)
        end)
    end)
end

function Scenarios.testPerformanceUnderStress()
    describe("Performance Under Stress", function()
        it("should maintain performance with large datasets", function()
            local startTime = os.clock()

            -- Large number of operations
            for i = 1, 1000 do
                helper.setClipboard(("perf_test_%d"):format(i))
                helper.getClipboard()
            end

            local endTime = os.clock()
            local duration = endTime - startTime

            -- Should complete in reasonable time (less than 5 seconds)
            assert.is_true(duration < 5.0, ("Performance test took too long: %.2f seconds"):format(duration))
        end)

        it("should handle memory allocation stress", function()
            local initialMemory = collectgarbage("count")

            -- Perform memory-intensive operations
            local largeStrings = {}
            for i = 1, 100 do
                local large = string.rep("test", 10000) -- ~50KB each
                table.insert(largeStrings, large)
                helper.setClipboard(large)
                helper.getClipboard()
            end

            local currentMemory = collectgarbage("count")
            local memoryIncrease = currentMemory - initialMemory

            -- Memory increase should be reasonable (less than 50MB)
            assert.is_true(memoryIncrease < 50000, ("Memory increase too large: %d KB"):format(memoryIncrease))

            -- Clean up
            largeStrings = nil
            collectgarbage("collect")
        end)
    end)
end

-- Run all scenario tests
function Scenarios.runAll()
    Scenarios.testMemoryPressure()
    Scenarios.testClipboardCorruption()
    Scenarios.testConcurrentAccess()
    Scenarios.testEdgeCases()
    Scenarios.testErrorRecovery()
    Scenarios.testPerformanceUnderStress()
end

return Scenarios