# Release Checklist

Use this checklist to prepare and publish a new ClipboardFormatter (Hammerflow.spoon) release.

## 1. Pre-Release Validation

- Confirm roadmap items for the release are complete and documented.
- Update `src/init.lua` with the new semantic version (`obj.version`).
- Ensure README, configuration docs, and setup guide reflect any new features or configuration changes.
- Update or create release notes (e.g., `docs/CHANGELOG.md`) summarizing user-visible changes.
- Run the full test and lint suites:
  - `./scripts/test.sh`
  - `./scripts/lint.sh` (if luacheck is installed)
- Verify the example configuration in `config/user_hooks.example.lua` still loads without errors.

## 2. Packaging the Spoon

- Clean the working tree (`git status` should show no pending changes beyond the release updates).
- Rebuild the spoon directory for distribution:

  ```bash
  rm -rf ~/.hammerspoon/Spoons/ClipboardFormatter.spoon
  mkdir -p ~/.hammerspoon/Spoons/ClipboardFormatter.spoon
  rsync -a src/ ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/
  rsync -a config/ ~/.hammerspoon/Spoons/ClipboardFormatter.spoon/config/
  ```

- Optionally create a distributable archive:

  ```bash
  cd ~/.hammerspoon/Spoons
  zip -r ClipboardFormatter.spoon-vX.Y.Z.zip ClipboardFormatter.spoon
  ```

- Test the packaged spoon inside Hammerspoon (reload config and exercise the hotkeys/global helpers).

## 3. Tagging and Publishing

- Commit release updates with a descriptive message (e.g., `chore: prepare vX.Y.Z`).
- Create an annotated tag:

  ```bash
  git tag -a vX.Y.Z -m "ClipboardFormatter vX.Y.Z"
  git push origin main
  git push origin vX.Y.Z
  ```

- Draft a GitHub Release using the tag, attaching the zipped spoon artifact and pasting the release notes.

## 4. Post-Release Tasks

- Update `ROADMAP.md` or project tracking documents with any follow-up items.
- Announce the release (Slack, email, etc.) if applicable.
- Open issues for deferred work uncovered during release prep.
