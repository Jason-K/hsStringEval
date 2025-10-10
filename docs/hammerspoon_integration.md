# Hammerspoon Integration Workflow

This guide documents the end-to-end workflow that keeps the `ClipboardFormatter.spoon`
submodule inside `~/.hammerspoon` aligned with the `hsStringEval` repository. Follow
these steps whenever you develop new features or publish updates so both projects stay
in sync.

## Source of Truth

- Treat `~/Scripts/Metascripts/hsStringEval` as the canonical source for
  ClipboardFormatter code, tests, and documentation.
- The `Spoons/ClipboardFormatter.spoon` directory in `~/.hammerspoon` is a Git
  submodule that mirrors the GitHub repo. Avoid editing files directly inside the
  submodule; instead make changes in `hsStringEval`, run the tests, and push the
  commits upstream.

## Local Development Loop

1. **Develop** inside `hsStringEval`:
   - Modify files under `src/`, `config/`, or `docs/` as needed.
   - Run `./scripts/test.sh` to exercise the Busted suite.

2. **Reload Hammerspoon** to try the changes immediately. The root Hammerspoon
   `init.lua` extends `package.path` to include the local checkout, so you can
   iterate without touching the submodule pointer yet.

3. **Commit and push** the finished work in `hsStringEval`:

  ```bash
  git commit -am "feat: describe the change"
  git push origin main
  ```

## Updating the Submodule Pointer

Once the new commits are on GitHub:

1. Switch to the Hammerspoon repo:

  ```bash
  cd ~/.hammerspoon
  ```

1. Pull the latest `hsStringEval` revision into the submodule:

  ```bash
  git submodule update --remote Spoons/ClipboardFormatter.spoon
  ```

  This command rewrites the submodule pointer in `.git/modules` to the newest commit
  on the default branch.

1. Verify the recorded commit:

  ```bash
  git status -sb
  git submodule status
  ```

  You should see `Spoons/ClipboardFormatter.spoon` reported as modified and pointing
  to the expected hash.

1. Commit the pointer move in `.hammerspoon`:

  ```bash
  git commit -am "chore: bump ClipboardFormatter submodule"
  git push origin feature/hslauncher-core-cleanup
  ```

## Release Hygiene

- Always push `hsStringEval` before updating the `.hammerspoon` pointer so the
  referenced commit exists on GitHub.
- When packaging a release, follow `docs/release_checklist.md` and then repeat the
  submodule update so downstream clones pick up the tagged commit.
- Use `git submodule status` regularly to confirm there are no local edits inside the
  submodule tree.

## Troubleshooting

- If Hammerspoon reloads do not reflect changes, ensure the `package.path`
  extension in `~/.hammerspoon/init.lua` points at your checkout and that you have no
  stale compiled artifacts under `src/`.
- If `git submodule update --remote` fails, verify your SSH credentials and that the
  GitHub repo (`Jason-K/hsStringEval`) is accessible.
- For a clean slate, you can reset the submodule with:

  ```bash
  git submodule deinit Spoons/ClipboardFormatter.spoon
  git submodule update --init -- Spoons/ClipboardFormatter.spoon
  ```

  This re-checks out the tracked commit without disturbing your `hsStringEval`
  working tree.
