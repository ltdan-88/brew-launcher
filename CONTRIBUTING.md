# Contributing

Thanks for taking a look. Issues and pull requests are welcome.

## Running from source

```bash
git clone https://github.com/ltdan-88/brew-launcher.git
cd brew-launcher
./bin/brew-launcher
```

Run it as `./bin/brew-launcher` — a bare `brew-launcher` runs the
Homebrew-installed copy, not your working tree.

The launcher writes to real config and cache locations. To keep your own setup
out of it while testing:

```bash
XDG_CONFIG_HOME=/tmp/bl-test/config \
XDG_CACHE_HOME=/tmp/bl-test/cache \
  ./bin/brew-launcher
```

## Before opening a PR

`main` is protected — every change goes through a PR with CI passing, no
direct pushes (the repo owner can still push directly in a real emergency;
nothing else can). CI runs `zsh -n` plus a full suite of fixture-based
behavior tests — see [.github/workflows/lint.yml](.github/workflows/lint.yml)
for what each job covers. You can run the whole suite locally too:

```bash
zsh -n bin/brew-launcher
for t in test/*.sh; do zsh "$t"; done
```

The fixture tests exist because a syntax check alone once missed a real bug
(a cache-writing bug that made the alphabetically-last tool invisible
everywhere in the app) — each one guards a specific failure shape that's
already happened once.

Interactive behavior can't be covered by CI — if you change anything in the fzf
loop, please actually run it and say so in the PR.

## Scope and constraints

This project is deliberately small. It's one zsh script plus a Python helper for
parsing Homebrew's JSON, and it should stay that way:

- **No new required runtime dependencies.** zsh, python3, fzf and the
  Homebrew CLI only — no Node, Rust, Go, SQLite, or background daemons.
  tmux is the one exception, and it's optional: only needed if you actually
  use the tmux terminal backend or presets, checked for and errored on
  clearly if missing, never assumed.
- **It's a launcher, not a package manager.** Installing, upgrading and removing
  packages is Homebrew's job. The `*` update marker is informational.
- **Prefer the simple option.** When a clever feature and a simple one both
  work, the simple one wins.

Some things have been considered and deliberately left out — Homebrew Cask/GUI
apps (already in `/Applications` and reachable via Spotlight), and heuristics
that try to guess which binaries are "real" beyond the existing suffix filter.

If you're planning something substantial, open an issue first so we can talk
about fit before you spend time on it. See [EXTENDING.md](EXTENDING.md) for
what's a stable interface (config/category/preset files, `--list`, CLI
flags) vs. internal implementation detail (the cache file, `--internal-*`
flags) — useful context before proposing a change to either.

## Style

Match the surrounding code. The script leans on comments that explain **why**,
particularly where something non-obvious is load-bearing — for example why the
click handler re-runs the script as a subprocess, or why certain loop variables
must be `local`. Those comments have already prevented regressions; please keep
that habit.

## Releases

See [RELEASING.md](RELEASING.md). Once your PR is merged, tagging the merged
commit is all that's needed — the Homebrew tap updates itself.
