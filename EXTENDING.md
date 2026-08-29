# Extending brew-launcher

This project is a single zsh script with no plugin system — "extending" it
means scripting against it (cron jobs, dotfiles, other tools reading its
data) or editing its config by hand. This doc draws the line between what's
safe to build on and what's internal implementation detail that can change
without notice, so that line doesn't have to be guessed at from the source.

If you're planning something that needs more than what's below, open an
issue first — same guidance [CONTRIBUTING.md](CONTRIBUTING.md) already gives
for substantial code changes.

## Safe to build on

These are treated as a real interface: changes to their meaning or shape
would be called out in [CHANGELOG.md](CHANGELOG.md), not made silently.

### CLI flags

```bash
brew-launcher --list             # see below
brew-launcher --refresh          # rebuild the cache, exit 0/1
brew-launcher --preset <name>    # launch a preset by name, exit 0/1
brew-launcher --diagnose         # health check, exit 0 if no problems found
brew-launcher --version          # "brew-launcher X.Y.Z", exit 0
brew-launcher --help             # exit 0
```

An unrecognized flag prints an error to stdout and exits 1.

### `--list` output

Six tab-separated fields, one row per visible (non-hidden) tool, no header
row:

```
command<TAB>formula<TAB>version<TAB>size<TAB>outdated(0 or 1)<TAB>description
```

This is the supported way to read brew-launcher's data from another script.
Don't parse the cache file directly — see [Internal, don't build on
this](#internal-dont-build-on-this) below for why.

### Environment variables

`BREW_LAUNCHER_TERMINAL` and `BREW_LAUNCHER_THEME` — documented in
`--help` and the README's [Configuration](README.md#configuration) section.
Both win over the config file's own `TERMINAL=`/`THEME=` for that one
invocation.

### The config file

`~/.config/brew-launcher/config` (or `$XDG_CONFIG_HOME/brew-launcher/config`)
— plain `KEY=value` lines, one per line, `#` comments and blank lines
ignored. Recognized keys: `TERMINAL`, `THEME`, `DEFAULT_CATEGORIES`,
`DEFAULT_HIDDEN`, `OPEN_TO_CATEGORIES`, `SORT`, `ALT_KEYBINDS` — see the
README's Configuration section for each one's values. An unrecognized key is
silently ignored, not an error, so this file stays forward-compatible with
older launcher versions reading a config written by a newer one.

This file is parsed as inert data, never sourced or executed — see
[SECURITY.md](SECURITY.md).

### Category and preset files

`~/.config/brew-launcher/categories/<Name>` and
`~/.config/brew-launcher/presets/<name>` — one command name per line, `#`
comments and blank lines ignored, same format as the ignore file
(`~/.config/brew-launcher/ignore`). All hand-editable; the in-app pickers
just write the same format. A preset file's line *order* is meaningful
(launch order); a category file's is not.

### Exit codes

`0` on success, `1` on a real error (missing dependency, invalid argument,
`--diagnose` finding a problem, a `--preset`/`--refresh` failure). Safe to
check in scripts.

## Internal, don't build on this

These can change shape, get renamed, or disappear entirely in any release,
including a patch release — they're implementation detail, not interface.

- **The cache file** (`$XDG_CACHE_HOME/brew-launcher/entries`) — its
  tab-separated column count and order have already changed multiple times
  (`CACHE_FORMAT_VERSION` is at 9 as of this writing) and will keep
  changing as features are added. Use `--list` instead if you need
  brew-launcher's data from another script.
- **`--internal-*` flags** (`--internal-footer-click`,
  `--internal-preview`, `--internal-preview-category`,
  `--internal-preview-preset`, `--internal-preview-action`,
  `--internal-preset-tab`) — these exist purely so fzf's own mouse-click
  and preview-pane binds can re-invoke this script as a subprocess. Their
  arguments, output format, and existence at all are not a public API and
  carry no compatibility guarantee.
- **Everything else under the cache directory** — `state`, `outdated`,
  `previews/`, `homebrew-usage`, `footer-click.<pid>` — all internal,
  disposable, and safe to delete by hand at any time (the launcher rebuilds
  what it needs).
- **`~/.config/brew-launcher/launch-history`** — an internal append-only
  log the Most Used view tallies on demand. Format not guaranteed.
- **Function names and internal script structure** — this is one zsh
  script; nothing about how it's organized internally is part of any
  interface.

## Adding a new terminal backend or package-manager source

Both have come up before and were deliberately scoped down rather than
built generically — see the project's own history in
[CHANGELOG.md](CHANGELOG.md) and the discussion in past issues/PRs before
proposing either. The short version: terminal backends need a real
external-control mechanism (AppleScript, a CLI/RPC protocol) to justify a
new case in the `BREW_LAUNCHER_TERMINAL` switch, and this project is
deliberately Homebrew-only — see [CONTRIBUTING.md](CONTRIBUTING.md)'s scope
section.
