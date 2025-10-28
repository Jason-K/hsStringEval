# GEMINI.md

## Project Overview

This project is a [Hammerspoon](https://www.hammerspoon.org/) "spoon" that provides advanced clipboard formatting functionality. It is written in Lua and designed to be modular and testable outside of the main Hammerspoon environment.

The core functionality includes:

*   **Detectors:** For identifying different types of content in the clipboard, such as arithmetic expressions, dates, phone numbers, and more.
*   **Formatters:** For transforming the detected content into a desired format.
*   **Clipboard/Selection Utilities:** For interacting with the system clipboard and selected text.
*   **Configuration:** The spoon is configurable, allowing users to customize its behavior, add their own formatters and detectors through hooks.

The project is structured with its source code in the `src/` directory, unit tests in the `test/` directory, and helper scripts for development in the `scripts/` directory.

## Building and Running

This is a Lua project and does not require a traditional build step. The primary way to run the code is through the test suite.

### Testing

The project uses [Busted](https://lunarmodules.github.io/busted/) for testing.

To run the tests:

1.  **Install dependencies:**
    ```bash
    ./scripts/install_test_deps.sh
    ```

2.  **Run the test suite:**
    ```bash
    ./scripts/test.sh
    ```

### Linting

The project uses `luacheck` for linting.

To run the linter:

1.  **Install luacheck:**
    ```bash
    luarocks install luacheck
    ```

2.  **Run the linter:**
    ```bash
    ./scripts/lint.sh
    ```

### Continuous Integration

The project uses GitHub Actions for CI. The CI pipeline runs the linter and the test suite on every push to the `main` branch or to a feature branch. The configuration is in `.github/workflows/ci.yml`.

## Development Conventions

*   **Code Style:** The code style is enforced by `luacheck` with the configuration in `.luacheckrc`. It uses a standard Lua style.
*   **Testing:** All modules have corresponding unit tests in the `test/` directory. New features should be accompanied by tests.
*   **Modularity:** The code is organized into modules to promote reusability and testability. The main spoon logic is in `src/init.lua`, with detectors, formatters, and utilities in their respective subdirectories.
