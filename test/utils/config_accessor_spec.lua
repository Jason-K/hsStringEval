---@diagnostic disable: undefined-global, undefined-field

describe("Config Accessor", function()
    local config_accessor

    setup(function()
        config_accessor = require("ClipboardFormatter.src.utils.config_accessor")
    end)

    describe("get", function()
        it("should get nested values", function()
            local config = {
                pd = { benefitPerWeek = 290 },
                selection = { copyDelayMs = 50 }
            }

            assert.equals(290, config_accessor.get(config, "pd.benefitPerWeek"))
            assert.equals(50, config_accessor.get(config, "selection.copyDelayMs"))
        end)

        it("should return default for missing path", function()
            local config = { pd = {} }

            assert.equals(100, config_accessor.get(config, "pd.missing", 100))
            assert.equals(nil, config_accessor.get(config, "totally.missing"))
        end)

        it("should handle nil config", function()
            assert.equals("default", config_accessor.get(nil, "any.path", "default"))
        end)

        it("should handle non-table config gracefully", function()
            assert.equals("default", config_accessor.get("not a table", "any.path", "default"))
            assert.equals("default", config_accessor.get(123, "any.path", "default"))
        end)

        it("should get top-level values", function()
            local config = { topLevel = "value" }

            assert.equals("value", config_accessor.get(config, "topLevel"))
        end)

        it("should handle empty path", function()
            local config = { key = "value" }

            -- Empty path should return the config itself or default
            local result = config_accessor.get(config, "", "default")
            -- For empty path with no default, returns config
            -- For empty path with default, returns default if config is nil
        end)
    end)

    describe("merge", function()
        it("should merge user config over defaults", function()
            local defaults = {
                a = 1,
                b = { x = 10, y = 20 }
            }
            local user = {
                b = { y = 99 },
                c = 30
            }

            local result = config_accessor.merge(defaults, user)

            assert.equals(1, result.a)
            assert.equals(10, result.b.x)  -- Default preserved
            assert.equals(99, result.b.y)  -- User override
            assert.equals(30, result.c)    -- New value
        end)

        it("should handle nil user config", function()
            local defaults = { a = 1, b = 2 }
            local result = config_accessor.merge(defaults, nil)

            assert.equals(1, result.a)
            assert.equals(2, result.b)
        end)

        it("should not mutate original tables", function()
            local defaults = { a = 1, b = { x = 10 } }
            local user = { b = { y = 20 } }
            local originalDefaults = { a = 1, b = { x = 10 } }
            local originalUser = { b = { y = 20 } }

            local result = config_accessor.merge(defaults, user)

            assert.same(originalDefaults, defaults)
            assert.same(originalUser, user)
        end)

        it("should deep merge nested tables", function()
            local defaults = {
                level1 = {
                    level2 = {
                        a = 1,
                        b = 2
                    }
                }
            }
            local user = {
                level1 = {
                    level2 = {
                        b = 99,
                        c = 3
                    }
                }
            }

            local result = config_accessor.merge(defaults, user)

            assert.equals(1, result.level1.level2.a)
            assert.equals(99, result.level1.level2.b)
            assert.equals(3, result.level1.level2.c)
        end)
    end)

    describe("accessor", function()
        it("should create context-aware accessor", function()
            local deps = { config = { pd = { benefitPerWeek = 290 } } }
            local context = { config = { pd = { benefitPerWeek = 500 } } }

            local accessor = config_accessor.accessor(deps, context)

            assert.equals(500, accessor:get("pd.benefitPerWeek"))
        end)

        it("should use defaults when context has no override", function()
            local deps = { config = { pd = { benefitPerWeek = 290 } } }
            local context = {}

            local accessor = config_accessor.accessor(deps, context)

            assert.equals(290, accessor:get("pd.benefitPerWeek"))
        end)

        it("should provide raw access to merged config", function()
            local deps = { config = { a = 1, b = 2 } }
            local context = { config = { b = 99, c = 3 } }

            local accessor = config_accessor.accessor(deps, context)

            assert.equals(1, accessor.raw.a)
            assert.equals(99, accessor.raw.b)  -- Context override
            assert.equals(3, accessor.raw.c)    -- Context new value
        end)

        it("should handle nil deps config", function()
            local deps = {}
            local context = {}

            local accessor = config_accessor.accessor(deps, context)

            assert.equals("default", accessor:get("any.path", "default"))
        end)
    end)
end)
