#!/usr/bin/env lua

--[[
WHAT THIS FILE DOES:
Builds a distributable ClipboardFormatter.spoon package from the source repository.
Copies runtime files, configurations, and documentation into the proper Spoon structure.

USAGE:
    lua packaging/make_spoon.lua [--output-dir <path>] [--version <version>]

EXAMPLE:
    lua packaging/make_spoon.lua --output-dir packaging/build --version 1.0.0
]]

local lfs
local ok, _ = pcall(function()
    lfs = require("lfs")
end)
if not ok then
    print("WARNING: LuaFileSystem (lfs) not available, using shell commands for directory operations")
    lfs = nil
end

-- SETUP: Configuration
local DEFAULT_OUTPUT_DIR = "packaging/build"
local DEFAULT_VERSION = "1.0"
local SPOON_NAME = "ClipboardFormatter.spoon"

-- HELPER: Cross-version os.execute success detector.
local function commandOk(...)
    local a, b, c = ...
    if type(a) == "number" then
        return a == 0
    end
    if type(a) == "boolean" then
        if a then
            return true
        end
        return b == "exit" and c == 0
    end
    return b == "exit" and c == 0
end

-- HELPER: Return absolute path for relative path values.
local function toAbsolutePath(path, rootDir)
    if type(path) ~= "string" or path == "" then
        return path
    end
    if path:sub(1, 1) == "/" then
        return path
    end
    return string.format("%s/%s", rootDir, path)
end

-- HELPER: Resolve repository root from this script path.
local function resolveRootDir()
    local scriptPath = arg and arg[0] or "packaging/make_spoon.lua"
    if scriptPath:sub(1, 1) ~= "/" then
        local cwd = lfs and lfs.currentdir() or (os.getenv("PWD") or ".")
        scriptPath = cwd .. "/" .. scriptPath
    end
    scriptPath = scriptPath:gsub("/+", "/")
    local rootDir = scriptPath:match("^(.*)/packaging/make_spoon%.lua$")
    if not rootDir then
        rootDir = lfs and lfs.currentdir() or (os.getenv("PWD") or ".")
    end
    return rootDir
end

-- Parse command-line arguments
local function parseArgs(args)
    local opts = {
        outputDir = DEFAULT_OUTPUT_DIR,
        version = DEFAULT_VERSION,
    }

    local i = 1
    while i <= #args do
        if args[i] == "--output-dir" then
            i = i + 1
            opts.outputDir = args[i]
        elseif args[i] == "--version" then
            i = i + 1
            opts.version = args[i]
        elseif args[i] == "--help" or args[i] == "-h" then
            print([[
Usage: lua packaging/make_spoon.lua [OPTIONS]

Options:
  --output-dir <path>  Output directory for the built Spoon (default: packaging/build)
  --version <version>  Version number for the Spoon (default: 1.0)
  --help, -h           Show this help message

Example:
  lua packaging/make_spoon.lua --output-dir dist --version 1.0.0
]])
            os.exit(0)
        end
        i = i + 1
    end

    return opts
end

-- Execute shell command and check result
local function exec(cmd, description)
    print(string.format("[STEP] %s", description or cmd))
    local ok = commandOk(os.execute(cmd))
    if not ok then
        error(string.format("Command failed: %s", cmd))
    end
end

-- Main build function
local function build(opts, rootDir)
    print("=" .. string.rep("=", 70))
    print("  ClipboardFormatter Spoon Builder")
    print("=" .. string.rep("=", 70))
    print(string.format("Output directory: %s", opts.outputDir))
    print(string.format("Version: %s", opts.version))
    print("")

    -- SETUP: Define paths
    local outputDir = toAbsolutePath(opts.outputDir, rootDir)
    local spoonDir = string.format("%s/%s", outputDir, SPOON_NAME)

    -- STEP 1: Clean and create output directory
    exec(string.format('rm -rf "%s"', spoonDir), "Clean previous build")
    exec(string.format('mkdir -p "%s"', spoonDir), "Create Spoon directory")

    -- STEP 2: Copy all runtime source files from src/
    -- src/init.lua becomes the top-level Spoon init.lua; all subdirectories map directly.
    exec(
        string.format(
            'rsync -a --exclude=".DS_Store" --exclude="*.bak" "%s/src/" "%s/"',
            rootDir, spoonDir
        ),
        "Copy src/ runtime into Spoon bundle"
    )

    -- STEP 3: Update version in init.lua
    local sedCmd = string.format(
        [[sed -i.bak 's/obj\.version = ".*"/obj.version = "%s"/' "%s/init.lua" && rm "%s/init.lua.bak"]],
        opts.version, spoonDir, spoonDir
    )
    exec(sedCmd, string.format("Set version to %s", opts.version))

    -- STEP 4: Copy user_hooks example into config/ so first-time users see the template
    exec(
        string.format('cp "%s/config/user_hooks.example.lua" "%s/config/user_hooks.example.lua" 2>/dev/null || true',
            rootDir, spoonDir),
        "Copy user_hooks.example.lua"
    )

    -- STEP 5: Copy essential documentation
    local topLevelDocs = { "README.md", "LICENSE", "CLAUDE.md" }
    local subDocs = {
        "docs/configuration.md",
        "docs/modules.md",
        "docs/setup.md",
        "docs/testing.md",
        "docs/hammerspoon_integration.md",
    }

    exec(string.format('mkdir -p "%s/docs"', spoonDir), "Create docs directory")

    for _, doc in ipairs(topLevelDocs) do
        exec(
            string.format('cp "%s/%s" "%s/%s" 2>/dev/null || true', rootDir, doc, spoonDir, doc),
            string.format("Copy %s", doc)
        )
    end

    for _, doc in ipairs(subDocs) do
        local filename = doc:match("([^/]+)$")
        exec(
            string.format('cp "%s/%s" "%s/docs/%s" 2>/dev/null || true',
                rootDir, doc, spoonDir, filename),
            string.format("Copy %s", doc)
        )
    end

    -- STEP 6: Generate docs.json
    print("[STEP] Generating docs.json...")
    local genDocsScript = rootDir .. "/tools/generate_docs_json.lua"

    local docsGenExists = commandOk(os.execute(string.format('test -f "%s"', genDocsScript)))

    if docsGenExists then
        local docGenCmd = string.format('cd "%s" && lua tools/generate_docs_json.lua', rootDir)
        local docGenResult = commandOk(os.execute(docGenCmd))

        if docGenResult then
            exec(
                string.format('cp "%s/docs.json" "%s/docs.json" 2>/dev/null || echo "Warning: docs.json not found after generation"',
                    rootDir, spoonDir),
                "Copy generated docs.json"
            )
        else
            print("Warning: Failed to generate docs.json — Spoon will be built without it")
        end
    else
        -- Fall back to copying a pre-existing docs.json if the generator is absent
        exec(
            string.format('cp "%s/docs.json" "%s/docs.json" 2>/dev/null || true',
                rootDir, spoonDir),
            "Copy existing docs.json (generator not found)"
        )
    end

    -- STEP 7: Create a VERSION file
    exec(
        string.format('echo "%s" > "%s/VERSION"', opts.version, spoonDir),
        "Create VERSION file"
    )

    -- STEP 8: Create installation instructions
    local installDoc = string.format([[
# Installing ClipboardFormatter Spoon

## Installation

1. Copy the entire `%s` directory to `~/.hammerspoon/Spoons/`
2. Add the following to your `~/.hammerspoon/init.lua`:

```lua
local ClipboardFormatter = hs.loadSpoon("ClipboardFormatter")
ClipboardFormatter:init()
ClipboardFormatter:installHotkeyHelpers()
```

3. Reload Hammerspoon (⌘⌥⌃R)

## Configuration

### User Hooks

Copy the example hooks file to supply custom detectors and formatters:

```bash
cp ~/.hammerspoon/Spoons/%s/config/user_hooks.example.lua \
   ~/.hammerspoon/Spoons/%s/config/user_hooks.lua
```

### Custom Configuration

Pass an options table to `init()`:

```lua
local ClipboardFormatter = hs.loadSpoon("ClipboardFormatter")
ClipboardFormatter:init({
    config = {
        logLevel = "info",
        enableClipboardWatch = true,
    }
})
ClipboardFormatter:installHotkeyHelpers()
```

## Documentation

- Configuration: `docs/configuration.md`
- Hammerspoon Integration: `docs/hammerspoon_integration.md`
- Module Reference: `docs/modules.md`

## Version

%s
]], SPOON_NAME, SPOON_NAME, SPOON_NAME, opts.version)

    local installFile = io.open(spoonDir .. "/INSTALL.md", "w")
    if installFile then
        installFile:write(installDoc)
        installFile:close()
        print("[STEP] Created INSTALL.md")
    end

    -- STEP 9: Create a ZIP archive
    print("")
    print("[STEP] Creating distributable archive...")
    local zipName = string.format("ClipboardFormatter-%s.zip", opts.version)
    local zipPath = string.format("%s/%s", outputDir, zipName)

    exec(
        string.format('cd "%s" && zip -r "%s" "%s" -x "*.DS_Store" "*/__pycache__/*"',
                      outputDir, zipName, SPOON_NAME),
        "Create ZIP archive"
    )

    -- SUCCESS: Print summary
    print("")
    print("=" .. string.rep("=", 70))
    print("  Build Complete!")
    print("=" .. string.rep("=", 70))
    print(string.format("Spoon directory: %s", spoonDir))
    print(string.format("ZIP archive: %s", zipPath))
    print("")
    print("Installation instructions:")
    print(string.format("  1. Unzip and copy %s to ~/.hammerspoon/Spoons/", SPOON_NAME))
    print("  2. Add to ~/.hammerspoon/init.lua:")
    print("       local ClipboardFormatter = hs.loadSpoon(\"ClipboardFormatter\")")
    print("       ClipboardFormatter:init()")
    print("       ClipboardFormatter:installHotkeyHelpers()")
    print("  3. Reload Hammerspoon")
    print("")
    print("See INSTALL.md in the Spoon directory for detailed instructions.")
    print("=" .. string.rep("=", 70))
end

-- MAIN: Entry point
local function main()
    local opts = parseArgs(arg)
    local rootDir = resolveRootDir()

    -- GUARD: Validate expected source layout
    local hasSrc = commandOk(os.execute(string.format('test -f "%s/src/init.lua"', rootDir)))
    local hasSrcClipboard = commandOk(os.execute(string.format('test -d "%s/src/clipboard"', rootDir)))
    local hasTools = commandOk(os.execute(string.format('test -d "%s/tools"', rootDir)))

    if not (hasSrc and hasSrcClipboard and hasTools) then
        print("ERROR: Could not locate required ClipboardFormatter source directories")
        print("       Resolved root: " .. tostring(rootDir))
        print("       Expected: src/init.lua, src/clipboard/, tools/")
        os.exit(1)
    end

    -- ACTION: Build the Spoon
    local ok, err = pcall(function()
        build(opts, rootDir)
    end)

    if not ok then
        print("")
        print("=" .. string.rep("=", 70))
        print("  BUILD FAILED")
        print("=" .. string.rep("=", 70))
        print("Error: " .. tostring(err))
        print("=" .. string.rep("=", 70))
        os.exit(1)
    end
end

main()
