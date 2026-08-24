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

Both gates run in CI on every pull request:

```bash
zsh -n bin/brew-launcher      # syntax
zsh test/cache-roundtrip.sh   # behavior
```

`cache-roundtrip.sh` covers the cache write/read path via `--list`, which needs
no TTY. It exists because a syntax check alone missed a bug that made the
alphabetically-last tool invisible everywhere in the app.

Interactive behavior can't be covered by CI — if you change anything in the fzf
loop, please actually run it and say so in the PR.

## Scope and constraints

This project is deliberately small. It's one zsh script plus a Python helper for
parsing Homebrew's JSON, and it should stay that way:

- **No new runtime dependencies.** zsh, python3, fzf and the Homebrew CLI only —
  no Node, Rust, Go, SQLite, or background daemons.
- **It's a launcher, not a package manager.** Installing, upgrading and removing
  packages is Homebrew's job. The `*` update marker is informational.
- **Prefer the simple option.** When a clever feature and a simple one both
  work, the simple one wins.

Some things have been considered and deliberately left out — Homebrew Cask/GUI
apps (already in `/Applications` and reachable via Spotlight), and heuristics
that try to guess which binaries are "real" beyond the existing suffix filter.

If you're planning something substantial, open an issue first so we can talk
about fit before you spend time on it.

## Style

Match the surrounding code. The script leans on comments that explain **why**,
particularly where something non-obvious is load-bearing — for example why the
click handler re-runs the script as a subprocess, or why certain loop variables
must be `local`. Those comments have already prevented regressions; please keep
that habit.

## Releases

See [RELEASING.md](RELEASING.md). Tagging is all that's needed — the Homebrew
tap updates itself.
