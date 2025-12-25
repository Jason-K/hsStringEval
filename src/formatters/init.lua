-- Formatters module - exports all formatter modules
local M = {
    arithmetic = require("ClipboardFormatter.src.formatters.arithmetic"),
    currency = require("ClipboardFormatter.src.formatters.currency"),
    date = require("ClipboardFormatter.src.formatters.date"),
    phone = require("ClipboardFormatter.src.formatters.phone"),
}

return M
