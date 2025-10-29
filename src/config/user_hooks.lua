-- User hooks for hsStringEval (copied from config/user_hooks.example.lua)
-- Customize as needed; see docs/configuration.md for details.

return {
    formatters = function(formatter)
        formatter:registerFormatter("echo", {
            process = function(_, value)
                return "echo: " .. tostring(value)
            end,
        })
    end,
    detectors = function(formatter)
        formatter:registerDetector({
            id = "example_hook",
            priority = 10,
            match = function(_, text)
                if text == "ping" then
                    return "pong"
                end
                local custom = text:match("^echo:(.+)$")
                if custom and formatter.formatters then
                    local echoFormatter = formatter.formatters.echo
                    if echoFormatter and echoFormatter.process then
                        return echoFormatter.process(echoFormatter, custom)
                    end
                end
                return nil
            end,
        })
    end,
}
