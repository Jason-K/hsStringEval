---@diagnostic disable: undefined-global, undefined-field

describe("String Processing", function()
    local string_proc

    setup(function()
        string_proc = require("ClipboardFormatter.src.utils.string_processing")
    end)

    describe("normalizeLocalizedNumber", function()
        it("should handle comma decimal separator", function()
            assert.equals("123.45", string_proc.normalizeLocalizedNumber("123,45"))
        end)

        it("should handle dot decimal separator", function()
            assert.equals("123.45", string_proc.normalizeLocalizedNumber("123.45"))
        end)

        it("should remove thousand separators", function()
            assert.equals("1234567.89", string_proc.normalizeLocalizedNumber("1,234,567.89"))
        end)

        it("should handle European thousand separators", function()
            assert.equals("1234567.89", string_proc.normalizeLocalizedNumber("1.234.567,89"))
        end)

        it("should handle numbers without decimal part", function()
            assert.equals("1234567", string_proc.normalizeLocalizedNumber("1,234,567"))
        end)

        it("should pass through non-string input", function()
            assert.equals(123, string_proc.normalizeLocalizedNumber(123))
            assert.is_nil(string_proc.normalizeLocalizedNumber(nil))
        end)
    end)

    describe("urlEncode", function()
        it("should encode special characters", function()
            local encoded = string_proc.urlEncode("hello world")
            assert.equals("hello+world", encoded)
        end)

        it("should encode spaces as plus", function()
            assert.equals("foo+bar", string_proc.urlEncode("foo bar"))
        end)

        it("should preserve safe characters", function()
            local input = "abc123_-~."
            assert.equals(input, string_proc.urlEncode(input))
        end)

        it("should encode reserved characters", function()
            local encoded = string_proc.urlEncode("test@example.com")
            assert.is_truthy(encoded:match("test%%40example"))
        end)

        it("should pass through non-string input", function()
            assert.equals(123, string_proc.urlEncode(123))
        end)
    end)

    describe("extractExpression", function()
        it("should extract after equals sign", function()
            assert.equals("1 + 2", string_proc.extractExpression("Result: 3 = 1 + 2"))
        end)

        it("should extract after colon", function()
            assert.equals("search term", string_proc.extractExpression("Search: :search term"))
        end)

        it("should extract last word", function()
            assert.equals("bar", string_proc.extractExpression("foo baz bar"))
        end)

        it("should return content if no marker", function()
            assert.equals("hello", string_proc.extractExpression("hello"))
        end)

        it("should handle empty string", function()
            assert.equals("", string_proc.extractExpression(""))
        end)

        it("should handle whitespace-only string", function()
            assert.equals("", string_proc.extractExpression("   "))
        end)

        it("should handle newline before expression", function()
            assert.equals("15/3", string_proc.extractExpression("line1\n15/3"))
        end)

        it("should handle tab before expression", function()
            assert.equals("10*2", string_proc.extractExpression("result:\t10*2"))
        end)

        it("should return nil for non-string input", function()
            assert.is_nil(string_proc.extractExpression(123))
            assert.is_nil(string_proc.extractExpression(nil))
        end)
    end)

    describe("trim", function()
        it("should trim leading whitespace", function()
            assert.equals("hello", string_proc.trim("  hello"))
        end)

        it("should trim trailing whitespace", function()
            assert.equals("hello", string_proc.trim("hello  "))
        end)

        it("should trim both ends", function()
            assert.equals("hello", string_proc.trim("  hello  "))
        end)

        it("should handle tabs", function()
            assert.equals("hello", string_proc.trim("\thello\t"))
        end)

        it("should handle newlines", function()
            assert.equals("hello", string_proc.trim("\nhello\n"))
        end)

        it("should handle empty string", function()
            assert.equals("", string_proc.trim(""))
        end)

        it("should handle whitespace-only string", function()
            assert.equals("", string_proc.trim("   "))
        end)

        it("should pass through non-string input", function()
            assert.equals(123, string_proc.trim(123))
        end)
    end)
end)
