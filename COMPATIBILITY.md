# Compatibility

What's supported, what's optional, and what's known not to work — pulled
into one place rather than scattered across the README and `--help`. Run
[`brew-launcher --diagnose`](README.md#reference) to check your own machine
against all of this directly.

## Operating systems

| OS | Support |
|---|---|
| macOS | Full support, including the Ghostty terminal backend and Automator-app desktop shortcuts. |
| Linux | Full support via the `current` and `tmux` terminal backends, and `.desktop` shortcuts. No Ghostty backend (Ghostty itself runs on Linux, but it has no external-control mechanism there the way its macOS AppleScript support gives it — see [Terminal backends](#terminal-backends)). |
| Windows | Not supported natively. Works under WSL, which counts as Linux from the launcher's point of view. |

Homebrew Cask/GUI apps are deliberately out of scope on every OS — they
already live in `/Applications` (or your Linux desktop's app menu) and are
reachable via Spotlight/your app launcher, so this launcher would just be a
redundant path to the same thing. This is a design choice, not a
compatibility gap.

## Dependencies

| Dependency | Required? | Needed for |
|---|---|---|
| [Homebrew](https://brew.sh/) | Yes | Everything — this launcher only shows what Homebrew already installed. |
| zsh | Yes | The launcher itself. Ships with macOS; most Linux distros need it installed explicitly (the Homebrew formula adds this as a dependency automatically on Linux). |
| [fzf](https://github.com/junegunn/fzf) | Yes | The picker UI. The launcher refuses to start without it. |
| python3 | Yes | Parses Homebrew's JSON output when building the cache. Already present on most systems. |
| tmux | No | Only for `BREW_LAUNCHER_TERMINAL=tmux` and Presets. Both stay visible in the UI even without it — pressing them explains the install command rather than being hidden outright. |
| osascript | No (macOS only) | The Ghostty terminal backend. Ships with macOS; nothing to install. |

`brew-launcher --diagnose` reports the actual state of every row above on
your machine, with resolved paths.

## Terminal backends

| `BREW_LAUNCHER_TERMINAL` | Platform | Behavior |
|---|---|---|
| `auto` (default) | Any | Picks the best of the three below for your situation — see the README's [Terminal backends](README.md#terminal-backends) section for the exact decision order (SSH-aware). |
| `current` | Any | Runs in place, in whatever terminal you launched from. Always available, on every platform. |
| `ghostty` | macOS only | Opens a new Ghostty tab via AppleScript. Requires Ghostty.app and `osascript`; errors cleanly if either is missing. Not available on Linux — Ghostty there has no equivalent external-control hook. |
| `tmux` | Any (with tmux installed) | Opens a new tmux window, but only when you're already inside a tmux session (`$TMUX` set) — never starts one for you. Falls back to `current` otherwise. |

## Desktop shortcuts (Actions → Create Shortcut)

| OS | What gets created |
|---|---|
| macOS | A double-clickable Automator app-style shortcut under `/Applications/TUIs/`. |
| Linux | A `.desktop` file under `~/.local/share/applications/`, validated against `desktop-file-validate` during development. |
| Anything else | Not offered — hidden from the footer/menu rather than shown and failing. |

## Option-key (⌥) aliases

The ⌥ aliases (⌥V, ⌥D, ⌥R, …) work out of the box in Ghostty and most
modern terminals. In stock macOS Terminal.app, they need *Use Option as
Meta Key* enabled (Preferences → Profiles → Keyboard) first. The F-keys
underneath them always work regardless, on every terminal — the aliases
exist only because F-keys need Fn on most Mac laptops.

## SSH

`auto` detects an SSH session via the standard `SSH_TTY`/`SSH_CONNECTION`/
`SSH_CLIENT` environment variables and never reaches for the Ghostty backend
there (no display to open a window in) — see the README for the exact
fallback order.

**Known issue, not a brew-launcher bug:** connecting from a Windows PC's
built-in OpenSSH client, resizing the terminal window while brew-launcher is
running can leave menus small or mispositioned and mouse clicks landing in
the wrong place. Root cause is Windows' bundled OpenSSH having a known
unreliable window-resize (SIGWINCH) forwarding bug — independent of which
terminal app hosts the SSH session; switching terminal apps alone doesn't
fix it. **Workaround confirmed working:** use [PuTTY](https://www.putty.org/)
(or PuTTY portable) instead of the Windows OpenSSH client.

## Shell

The launcher is a single zsh script (`#!/usr/bin/env zsh`) plus a python3
helper invoked internally — no other language runtime is involved, and
nothing here needs a specific zsh version beyond what macOS/Homebrew already
ship.
