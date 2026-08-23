# Releasing a new version

Cheat sheet for cutting a new `brew-launcher` release. The Homebrew tap
(`ltdan-88/homebrew-brew-launcher`) updates itself automatically — you never
hand-edit its formula or compute a sha256 by hand.

## Every release

1. **Bump the version** in `bin/brew-launcher`:
   ```zsh
   VERSION="X.Y.Z"
   ```
   Update the README too if features/shortcuts changed.

2. **Commit and push to `main`**:
   ```bash
   git add -A
   git commit -m "Prepare vX.Y.Z release"
   git push origin main
   ```

3. **Tag and push the tag** — this is what triggers everything:
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. **Watch it run** (optional, takes ~30s):
   ```bash
   gh run watch --repo ltdan-88/brew-launcher
   ```
   Or check the [Actions tab](https://github.com/ltdan-88/brew-launcher/actions).

That's it. The workflow (`.github/workflows/update-tap-formula.yml`) downloads
the tag's tarball, computes its sha256, and pushes the updated
`Formula/brew-launcher.rb` (url, sha256, version) directly to the tap repo's
`main` branch.

## Verify (optional)

```bash
brew update
brew upgrade brew-launcher   # or: brew install ltdan-88/brew-launcher/brew-launcher
brew-launcher --version      # should print vX.Y.Z
```

## If the workflow fails

Check the failed step in the [Actions tab](https://github.com/ltdan-88/brew-launcher/actions).

- **"VERSION does not match tag"** — you tagged before bumping `VERSION=` in
  `bin/brew-launcher`, or the two don't agree. Fix the script, re-tag (see
  "Fixing a bad tag" below), and push again.

- **"Bad credentials" on the tap checkout step** — `HOMEBREW_TAP_TOKEN` has
  expired or was revoked. Fix:
  1. GitHub → Settings → Developer settings → Personal access tokens →
     Fine-grained tokens → generate a new one scoped to just
     `homebrew-brew-launcher`, permission **Contents: Read and write**.
  2. Copy the token value (shown once).
  3. `gh secret set HOMEBREW_TAP_TOKEN --repo ltdan-88/brew-launcher` and
     paste it at the prompt.
  4. Re-run the failed workflow: `gh run rerun --repo ltdan-88/brew-launcher --failed`
     (no need to re-tag).

## Fixing a bad tag

If you tagged too early or the tag doesn't match what's on `main`:

```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
# fix VERSION= / commit / push to main, then re-tag:
git tag vX.Y.Z
git push origin vX.Y.Z
```

## One-time setup (already done)

- Repo secret `HOMEBREW_TAP_TOKEN` on `brew-launcher`: a fine-grained PAT
  scoped to `homebrew-brew-launcher` only, Contents: Read and write.
  Expires periodically (recommended: 90 days) — see the "Bad credentials"
  fix above when it lapses.
