--[[
Configuration schema definition

Defines the expected structure and types for all configuration values.
]]

local M = {}

return {
    pd = {
        bundledFile = "string",
        legacyFile = "string",
        fallbackPath = "string",
        benefitPerWeek = "number",
    },

    processing = {
        throttleMs = "number",
    },

    selection = {
        waitAfterClearMs = "number",
        modifierCheckInterval = "number",
        copyDelayMs = "number",
        pasteDelayMs = "number",
        pollIntervalMs = "number",
        maxPolls = "number",
        retryWithEventtap = "boolean",
    },

    logging = {
        level = "string",
        structured = "boolean",
        includeTimestamp = "boolean",
    },

    templates = {
        arithmetic = "string",
    },
}
