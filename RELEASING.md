# Releasing a new version

Cheat sheet for cutting a new `brew-launcher` release. The Homebrew tap
(`ltdan-88/homebrew-brew-launcher`) updates itself automatically — you never
hand-edit its formula or compute a sha256 by hand.

`main` is protected — no direct pushes, even for a release. The version bump
rides inside the feature/fix PR that earns the release, not a separate commit.

## Every release

1. **Bump the version** in `bin/brew-launcher`, as part of the PR for
   whatever you're shipping:
   ```zsh
   VERSION="X.Y.Z"
   ```
   Update the README and `CHANGELOG.md` too if features/shortcuts changed.

2. **Branch, commit, push, open a PR, wait for CI, squash-merge** — the
   normal flow for any change here, nothing release-specific about it.

3. **Tag the merged commit and push the tag** — this is what triggers
   everything. Tags aren't restricted by branch protection, so this part
   still pushes directly:
   ```bash
   git checkout main
   git pull origin main
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

### If `brew upgrade` fails with a formula syntax error

This means the tap repo on GitHub is fine — it's your **local** tap clone
(`$(brew --prefix)/Library/Taps/ltdan-88/homebrew-brew-launcher`) that's
gotten into a bad state, usually leftover conflict markers from an old
`brew update` auto-stash that never got resolved. Fix:

```bash
cd "$(brew --prefix)/Library/Taps/ltdan-88/homebrew-brew-launcher"
git status               # confirm it's the local clone that's broken, not origin
git reset --hard origin/main
git stash list            # inspect before dropping, in case anything looks intentional
git stash clear            # only if everything listed is old junk, not real edits
brew upgrade brew-launcher
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
# fix VERSION= via a normal branch/PR/merge (see "Every release" above),
# then re-tag the corrected commit on main:
git tag vX.Y.Z
git push origin vX.Y.Z
```

## One-time setup (already done)

- Repo secret `HOMEBREW_TAP_TOKEN` on `brew-launcher`: a fine-grained PAT
  scoped to `homebrew-brew-launcher` only, Contents: Read and write.
  Expires periodically (recommended: 90 days) — see the "Bad credentials"
  fix above when it lapses.

- Branch protection on `main`: PR required, all CI checks required, no
  force-pushes or deletions. The repo owner can still bypass it if a real
  emergency needs a direct push — everyone/everything else goes through a
  PR. Doesn't restrict tags, so step 3 above is unaffected.
