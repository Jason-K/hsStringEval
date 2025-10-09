# ClipboardFormatter Roadmap

## Phase 1 – Foundation & Cleanup

- [x] **Finalize module boundaries**: ensure every `src/` component has a clear owner (clipboard, detectors, formatters, utilities) and document the public API surface.
- [x] **Centralize shared helpers**: move any remaining AppleScript/eventtap copy logic into reusable utility functions to avoid duplication across modules.
- [x] **Configuration clarity**: add inline docs or dedicated markdown detailing configurable options (selection timings, PD files, restore flags, hook entry points).
- [x] **Lint/test setup**: introduce `luacheck` (or equivalent) and wire the Busted suite into a simple CI workflow (GitHub Actions or local script).

## Phase 2 – Performance & Reliability

- [x] **Pattern & format caching**: expand `utils.patterns` to precompile frequently used regexes and date formatters.
- [x] **Clipboard throttling**: track recently processed clipboard hashes to skip redundant work during rapid invocations.
- [x] **Adaptive waits**: replace fixed `hs.timer.usleep` delays with `hs.timer.waitUntil` loops, keeping configurable fallbacks for edge cases. _(Clipboard workflows now use adaptive waits via `utils.hammerspoon.waitForClipboardChange` with bounded polling fallbacks.)_
- [x] **PD cache controls**: expose commands or settings to reload the PD mapping and avoid unnecessary file reads.

## Phase 3 – Functional Enhancements

- [x] **Arithmetic upgrades**: support modulus, exponentiation, and localized number formats, guarding against invalid input.
- [x] **Richer date parsing**: extend date detectors/formatters to accept textual months (e.g., `May 6, 2023`), ISO timestamps, and inferred years.
- [x] **Result templating**: allow custom output patterns (e.g., choose between `"$170.89/7 = $24.41"` and `"$170.89 ÷ 7 → $24.41"`) via configuration. _(Arithmetic formatter now honors configurable templates; expand to additional detectors as needed.)_
- [x] **Formatter hooks**: expand hook support so users can register custom detectors/formatters at runtime without modifying core files. _(Runtime hook tables can now register/override formatters via `registerFormatter`.)_

## Phase 4 – User Experience & Integration

- [x] **Hotkey helpers**: reintroduce convenience globals (`FormatClip`, `FormatSelected`) or wrapper functions for easy bindings. _(Optional global helpers now install via `config.hotkeys.installHelpers` or `installHotkeyHelpers()`.)_
- [x] **Logging controls**: provide severity toggles and optional structured logs to aid troubleshooting without excessive alerts. _(Configurable logging settings now support level overrides and structured output.)_
- [x] **Documentation polish**: update README and docs with end-to-end setup examples (install rocks, run tests, integrate with `init.lua`). _(README quick start and `docs/setup.md` now cover dependencies, testing, deployment, and configuration.)_
- [x] **Release checklist**: define packaging steps for distributing the spoon (version tagging, changelog, artifact delivery). _(`docs/release_checklist.md` outlines validation, packaging, tagging, and post-release steps.)_
