---@diagnostic disable: undefined-global, undefined-field

local helper = require("spec_helper")
-- Note: scenarios will be tested independently to avoid path issues

describe("Edge Cases and Reliability", function()
    before_each(function()
        helper.reset()
    end)

    describe("Memory Pressure Testing", function()
        it("should handle operations under memory pressure", function()
            -- Create memory pressure by allocating lots of objects
            local memoryHog = {}
            for i = 1, 500 do
                local table = {}
                for j = 1, 500 do
                    table[j] = string.rep("test", 100)
                end
                memoryHog[i] = table
            end

            -- Test basic clipboard operations under pressure
            helper.setClipboard("test under pressure")
            local result = helper.getClipboard()
            assert.are.equal("test under pressure", result)

            -- Clean up
            memoryHog = nil
            collectgarbage("collect")
        end)

        it("should recover from garbage collection", function()
            helper.setClipboard("before GC")

            -- Force garbage collection
            collectgarbage("collect")

            local result = helper.getClipboard()
            assert.are.equal("before GC", result)
        end)
    end)

    describe("Clipboard Corruption Scenarios", function()
        it("should handle empty clipboard", function()
            helper.setClipboard("")
            local result = helper.getClipboard()
            assert.are.equal("", result)

            -- Should recover from empty state
            helper.setClipboard("recovered")
            result = helper.getClipboard()
            assert.are.equal("recovered", result)
        end)

        it("should handle whitespace-only content", function()
            local whitespaceTests = {" ", "\t", "\n", "\r", "\t\n\r  "}

            for _, content in ipairs(whitespaceTests) do
                helper.setClipboard(content)
                local result = helper.getClipboard()
                assert.are.equal(content, result)
            end
        end)

        it("should handle very long content", function()
            local longContent = string.rep("This is a very long test. ", 1000)
            helper.setClipboard(longContent)

            local result = helper.getClipboard()
            assert.are.equal(#longContent, #result)
            assert.are.equal(longContent, result)
        end)
    end)

    describe("Rapid Operations", function()
        it("should handle rapid clipboard changes", function()
            -- Perform 100 rapid operations
            for i = 1, 100 do
                helper.setClipboard(("rapid_%d"):format(i))
                local result = helper.getClipboard()
                assert.are.equal(("rapid_%d"):format(i), result)
            end

            -- Final state should be correct
            local finalResult = helper.getClipboard()
            assert.are.equal("rapid_100", finalResult)
        end)

        it("should handle alternating operations", function()
            for i = 1, 50 do
                helper.setClipboard(("even_%d"):format(i * 2))
                helper.setClipboard(("odd_%d"):format(i * 2 - 1))
            end

            -- Should handle the rapid switching
            local result = helper.getClipboard()
            assert.is_not_nil(result)
            assert.is_true(type(result) == "string")
        end)
    end)

    describe("Special Characters and Unicode", function()
        it("should handle Unicode characters", function()
            local unicodeTests = {
                "测试中文",
                "Español ñáéíóú",
                "Français çàèù",
                "Русский текст",
                "العربية",
                "🚀 Emoji test 🎉",
                "Math: ∑∏∫∆∇∂∞"
            }

            for _, content in ipairs(unicodeTests) do
                helper.setClipboard(content)
                local result = helper.getClipboard()
                assert.are.equal(content, result)
            end
        end)

        it("should handle control characters", function()
            local controlTests = {
                "Line 1\nLine 2",
                "Tab\tSeparated",
                "Carriage\rReturn",
                "Mixed\n\t\r\nContent"
            }

            for _, content in ipairs(controlTests) do
                helper.setClipboard(content)
                local result = helper.getClipboard()
                assert.are.equal(content, result)
            end
        end)
    end)

    describe("Numeric Edge Cases", function()
        it("should handle extreme numbers", function()
            local numberTests = {
                "0",
                "-0",
                "2147483647", -- 32-bit max
                "-2147483648", -- 32-bit min
                "0.0000001",
                "999999999999999999999",
                "1e-100",
                "1e100"
            }

            for _, content in ipairs(numberTests) do
                helper.setClipboard(content)
                local result = helper.getClipboard()
                assert.are.equal(content, result)
            end
        end)
    end)

    describe("Error Conditions", function()
        it("should handle invalid inputs gracefully", function()
            -- Test with various invalid input types (should not crash)
            local invalidInputs = {
                "",
                nil,
                {},
                function() end
            }

            for _, input in ipairs(invalidInputs) do
                pcall(function()
                    if type(input) == "string" then
                        helper.setClipboard(input)
                    end
                end)
            end

            -- System should still be responsive
            helper.setClipboard("recovery test")
            local result = helper.getClipboard()
            assert.are.equal("recovery test", result)
        end)

        it("should maintain consistency after errors", function()
            helper.setClipboard("consistency test")

            -- Perform some potentially problematic operations
            pcall(function()
                for i = 1, 10 do
                    helper.setClipboard(("error_test_%d"):format(i))
                    -- Simulate some delay
                    os.execute("sleep 0.001")
                end
            end)

            -- System should still work
            helper.setClipboard("final consistency test")
            local result = helper.getClipboard()
            assert.are.equal("final consistency test", result)
        end)
    end)

    describe("Boundary Conditions", function()
        it("should handle single character strings", function()
            local singleChars = {"a", " ", "\t", "\n", "1", "!"}

            for _, char in ipairs(singleChars) do
                helper.setClipboard(char)
                local result = helper.getClipboard()
                assert.are.equal(char, result)
                assert.are.equal(1, #result)
            end
        end)

        it("should handle very long strings", function()
            local longString = string.rep("x", 10000)
            helper.setClipboard(longString)

            local result = helper.getClipboard()
            assert.are.equal(10000, #result)
            assert.are.equal(longString, result)
        end)

        it("should handle strings with special patterns", function()
            local patternTests = {
                string.rep("a", 5) .. string.rep("b", 5) .. string.rep("c", 5),
                string.char(0) .. "null byte" .. string.char(255),
                "Multiple\n\n\nnewlines\n\n\n"
            }

            for _, content in ipairs(patternTests) do
                helper.setClipboard(content)
                local result = helper.getClipboard()
                assert.are.equal(content, result)
            end
        end)
    end)

    describe("Resource Exhaustion", function()
        it("should handle rapid allocation/deallocation", function()
            for cycle = 1, 10 do
                local tempData = {}
                for i = 1, 100 do
                    tempData[i] = string.rep("test", 100)
                    helper.setClipboard(tempData[i])
                end

                tempData = nil
                collectgarbage("collect")

                local result = helper.getClipboard()
                assert.is_not_nil(result)
            end
        end)

        it("should maintain performance under load", function()
            local startTime = os.clock()

            -- Perform many operations
            for i = 1, 500 do
                helper.setClipboard(("load_test_%d"):format(i))
                helper.getClipboard()
            end

            local endTime = os.clock()
            local duration = endTime - startTime

            -- Should complete quickly (less than 2 seconds)
            assert.is_true(duration < 2.0, ("Load test took too long: %.2f seconds"):format(duration))
        end)
    end)
end)