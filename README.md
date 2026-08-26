<h1 align="center">brew-launcher</h1>

<p align="center">
  <strong>You installed 40 terminal tools. You remember six.</strong><br>
  A fast launcher for the Homebrew CLI apps you already have — browse, search, and run them without remembering names.
</p>

<p align="center">
  <a href="https://github.com/ltdan-88/brew-launcher/releases"><img alt="Version" src="https://img.shields.io/github/v/tag/ltdan-88/brew-launcher?label=version&color=89b4fa"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-a6e3a1"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-cba6f7">
  <a href="https://github.com/ltdan-88/brew-launcher/actions"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/ltdan-88/brew-launcher/lint.yml?branch=main&label=ci"></a>
</p>

<p align="center">
  <img src="assets/demo.gif" alt="brew-launcher demo: searching, favoriting, and filtering by category">
</p>

## Why this exists

`brew list` gives you names. That's the problem — six months later, `bbrew`,
`bastet` and `mole` are just words, and the tool you actually wanted stays
installed and unused.

`brew-launcher` shows you the same list **with what each thing actually does**,
its version, and its size — then launches it.

```
bastet          0.43.2_14   317.2KB   Bastard Tetris
bbrew           2.3.2       7.9MB     TUI for managing Homebrew, Flatpak, and Mac App Store packages
mole            1.51.0*     9.7MB     Deep clean and optimize your Mac
```

**This is a launcher, not a package manager.** If you want to *install and
remove* Homebrew packages interactively, [`taproom`](https://github.com/hzqtc/taproom)
and [`fzf-brew`](https://github.com/thirteen37/fzf-brew) already do that well.
This one is for the tools you've *already* installed and want to actually use.

It's a single zsh file. No daemon, no database, nothing you *have to*
configure — startup is instant after the first run.

## Quick start

```bash
brew install ltdan-88/brew-launcher/brew-launcher
brew-launcher
```

That's it — nothing to configure. Type to search, **Enter** to launch, **Esc** to quit.

**Requirements:** macOS or Linux · [Homebrew](https://brew.sh/) · python3 (already on most systems).
[fzf](https://github.com/junegunn/fzf) is installed automatically as a dependency.
Optional: [tmux](https://github.com/tmux/tmux), only if you use the tmux terminal
backend or Presets — see [Configuration](#configuration).

## What you get

### Everything you installed, described

<p align="center"><img src="assets/screenshot.png" alt="The main list showing name, version, size and description columns"></p>

Only tools **you** asked for — dependencies pulled in by other formulae are
filtered out. Type any part of a name *or a description* to fuzzy-search: typing
`weather` finds tools whose name never mentions it.

Three markers tell you the state of a row at a glance:

| Marker | Where | Meaning |
|---|---|---|
| `*` | after the version (`1.13.0*`) | Outdated — a newer version exists |
| `+` | before the name | Favorited |
| `#` | before the name | Categorized |

Both `+` and `#` can appear together (`+#`). These describe *state* — they
aren't things you press. Upgrading stays Homebrew's job.

The top border also shows how much disk space Homebrew's own installs are
using and how much is still free on the volume — visible on `All`, hidden on
filtered views to leave room for the view's own name.

### Two tiers of keys

<p align="center"><img src="assets/more.gif" alt="Opening the More menu with F4 and favoriting an entry from it"></p>

The footer shows what browsing needs — **Views**, **Details**, **Refresh** —
plus **Presets**, since running one is worth a key of its own. Organizing —
hide, favorite, categorize — and setup — theme, create a preset, create a
shortcut — live behind **F4 / ⌥M**. Hide, Favorite and Categorize still have
a direct key too; the setup actions are More-only, since they're one-time
rather than everyday.

The menu names each action in words and prints its shortcut next to it, which
makes it easier to discover than an F-number in a crowded footer, and means it
teaches you the key and then gets out of the way.

### One place to switch views

<p align="center"><img src="assets/categories.gif" alt="Opening the view picker, filtering to a category, and stepping back out"></p>

**F2** opens the view picker: `All`, `Favorites`, then your own categories —
each marked with `·` so they're easy to tell apart from the built-in views —
followed by `Most Used`, `Recently Added`, and `Hidden` last. Group tools
however you think about them — Games, Editors, Monitoring. Every view except `All` shows
how many entries it holds. **Esc** steps back one level at a time (filtered
view → picker → everything → quit) rather than dumping you out.

`Most Used` and `Recently Added` are computed, not something you set up —
`Most Used` tracks what you actually launch, and `Recently Added` reads the
install date Homebrew already records for every formula. Both cap themselves
to the 15 most relevant tools, so they stay a short, useful list instead of
turning into "everything, just re-sorted."

**Ctrl-D** in that picker deletes the highlighted category. It asks first and
shows how many entries the category holds — every other action here is a toggle
you can undo with the same key, so this is the one worth pausing on. `All`,
`Hidden`, `Favorites`, `Most Used` and `Recently Added` can't be deleted.

### Favorites

<p align="center"><img src="assets/favorites.gif" alt="Toggling a favorite with F7; the marker appears and the cursor stays put"></p>

**F7** toggles a favorite instantly — no prompt. **F8** does the same for any
other category: instant while you're viewing one, or it asks which, if you're
not.

### Hide what you don't use

<p align="center"><img src="assets/hidden.gif" alt="Hiding an entry with F6, then finding it again in the Hidden view"></p>

**F6** hides an entry — it stays installed, Homebrew is untouched. Hidden isn't a
special screen: it's just another view in the picker, so **Enter** still launches
and **F6** unhides. Same key, opposite direction, exactly like Favorites.

### Already organized on day one

A curated set of well-known formulae ships pre-categorized, and a short,
hand-reviewed list of commands that are genuinely just a multi-command
formula's minor helper scripts — not a second tool worth its own row — ships
pre-hidden. Both apply the moment the cache first builds, so a fresh install
already looks organized instead of handing you 40 unsorted rows to sort out
yourself. A bundled category shows up in **F2** right alongside your own,
even before you've filed anything into it by hand.

Your own **F6** or **F8** on any entry always overrides the bundled default
for that entry, no exceptions. Turn either mechanism off entirely from
**F4 → More → Default Categories** / **Default Hidden** — see
[Bundled defaults](#bundled-defaults) for exactly what's included and how an
override sticks.

### The full details, without leaving

<p align="center"><img src="assets/details.gif" alt="Toggling the details pane with F3; it follows the cursor down the list"></p>

**F3** opens a details pane under the list — homepage, license, size, tap, when
you installed it, dependencies and any caveats — and it follows the cursor as
you move. It's the `brew info` output you'd otherwise quit and go look up,
except it's already on disk: the text is written when the cache is built, so
the pane is instant rather than the ~0.6s a live `brew info` costs on every
keystroke. "Installed" is exactly that — when *you* installed the current
version, not when its developers released it; Homebrew doesn't track the
latter anywhere.

If a newer version exists, the pane shows it: `Update available  1.52.0`. Same
information the `*` marker in the list is already telling you, just with the
actual version number attached.

It also answers the one question the list can't. A `#` in the list tells you an
entry is filed somewhere, but not *where* — the pane names the categories, so
you don't have to go hunting through **F2** to find out. That line is omitted
when an entry isn't filed anywhere (so the `#` marker tells you which rows will
have it) and read fresh each time rather than cached, so it's correct the
moment you press **F7** or **F8**. If nothing's filed by hand but the [bundled
defaults](#bundled-defaults) place it somewhere, that shows too, marked
`(default)` so it's never confused with a category you actually chose.

**Shift-Up** / **Shift-Down** scrolls it for long entries. It starts closed and
stays closed until you ask for it.

### Launch without leaving the launcher

On macOS with [Ghostty](https://ghostty.org/), picking a tool opens it in a
**new tab**, so the launcher stays where it is and you can fire off several in a
row. Inside a tmux session, `BREW_LAUNCHER_TERMINAL=tmux` does the same with a
**new window** instead. Everywhere else it launches in place. See
[Configuration](#configuration).

This works the same for a long-running TUI (`htop`, `lazygit`) and a one-shot
CLI that prints and exits (`eza`, `jq`, `shellcheck`) — quitting or finishing
either one leaves you at a normal shell prompt in that tab, exactly like typing
the command yourself would.

### Launch several tools together

<p align="center"><img src="assets/presets.gif" alt="Creating a preset by multi-selecting tools with Tab, naming it, then launching it with F9"></p>

A preset is a named group of tools that all open together, one per tmux pane —
your morning setup in one shot instead of launching each tool by hand.

**F4 → Create Preset** picks the tools (Tab marks, Enter confirms) and names
it for you. **F9** lists your presets and launches the one you pick,
reattaching to it if it's already running rather than opening a second copy.
File format and the `--preset` CLI flag are in [Configuration](#configuration).

Presets need [tmux](#terminal-backends). Both stay visible in the footer and
More menu either way — the More menu's hint reads "needs tmux" in place of the
usual keybind when it's missing, and pressing either explains the exact
install command rather than silently failing.

### Color themes

<p align="center"><img src="assets/themes.png" alt="The same list rendered in all ten themes side by side, showing each palette's actual colors"></p>

Ten built-in palettes: five popular modern ones — `catppuccin` (the
default), `gruvbox`, `tokyonight`, `nord`, `dracula` — `solarized-dark` and
`solarized-light`, a matched pair sharing the same accent colors, for when
you want a genuine light background or a fuller spread of hues than the
mostly blue-and-purple set above — `red-sands`, a genuinely red theme
(deep brick-red background, not just a red accent) — and two real, older
ones, `green` and `amber`, the actual colors green- and amber-phosphor CRT
terminals displayed. The CRT pair is monochrome on purpose: that hardware
could only show one hue at varying brightness, so unlike the rest these
never reach for a second color.

**F4 → Theme** shows a short description next to each name, so you don't have
to guess from the name alone. Picking one writes the config file for you — no
terminal needed — and offers to relaunch immediately since colors are resolved
once at startup. Env var and config-file syntax are in
[Configuration](#configuration).

### Desktop shortcuts

**F4 → More → Create shortcut** makes a tool show up outside the launcher too.

On macOS it writes a `.command` file to `/Applications/TUIs/` — double-click
it, drag it to the Dock, or bind it to a hotkey in System Settings. Give it a
custom icon via Finder → Get Info and it behaves like any other app.

On Linux it writes a `.desktop` entry to `~/.local/share/applications/`, which
every major desktop environment already watches — it appears in your
application menu with no further setup, launching in your default terminal.

Either way it's the same shell command underneath, so a one-shot CLI's output
stays readable: the window drops to a live shell afterward instead of closing
the instant the command finishes.

### Mouse support

Click a row to select it, double-click to launch. Footer items shown in
`[brackets]` are clickable too and do exactly what the key beside them does —
clicking `[Views]` is the same as pressing F2. Unbracketed footer text (the
marker legend, "Navigate") is explanatory and deliberately inert.

## Reference

**F1** (no alias needed — it means *help* nearly everywhere) opens the same
reference below, from inside the launcher.

| Key | Action | |
|---|---|---|
| **Enter** | Launch selected application | footer |
| **F2** / **⌥V** | Switch view (All · Favorites · categories · Hidden) | footer |
| **F3** / **⌥D** | Show or hide the details pane | footer |
| **Shift-Up/Down** | Scroll the details pane | footer |
| **Esc** | Go back one level, or quit | footer |
| **F4** / **⌥M** | Open the More menu | footer |
| **F5** / **⌥R** | Refresh the cache without leaving | footer |
| **F9** / **⌥P** | Launch a preset (reattaches if it's already running) | footer |
| **F6** / **⌥H** | Hide — or unhide, in the Hidden view | More |
| **F7** / **⌥F** | Toggle Favorites for selected entry | More |
| **F8** / **⌥C** | Categorize selected entry (adds or removes) | More |
| **F1** | Open this reference in the launcher | — |
| — | Switch color theme | More only |
| — | Create a new preset | More only |
| — | Toggle Default Categories / Default Hidden | More only |
| — | Create a desktop shortcut (macOS or Linux) | More only |

Each Option alias matches its label — **⌥H**ide, **⌥V**iews, **⌥P**resets,
**⌥R**efresh, **⌥F**avorite, **⌥C**ategorize, **⌥D**etails. They exist because
F-keys need Fn on most Mac laptops. In stock Terminal.app, enable *Use Option
as Meta Key* in the profile's Keyboard settings first; Ghostty supports it out
of the box.

<details>
<summary>Why the keys are split this way</summary>

**F1** is deliberately unassigned — it means *help* nearly everywhere, and the
launcher may want it later. The footer keys sit on **F2**–**F5** plus **F9**
because those are the ones you press constantly, and they're the easiest to
reach on a laptop that needs **Fn**. **F5** is Refresh, matching the
convention it has in every browser and file manager.

The split is by what you're doing, not by how often. Finding, browsing, and
running something together with launching a preset are what you open the
launcher for, so those stay on screen. Organizing — hiding, favoriting,
categorizing — and setup — theming, building a preset, making a shortcut —
are things you do in bursts, and they were costing footer slots you'd
otherwise look at on every single launch. **F9** followed the same logic in
reverse: unlike making a shortcut (once per tool, rarely repeated), running a
preset is something you'd reach for over and over, so it earned a footer key
of its own rather than staying More-only.

The menu lists each action's key beside it, so it teaches its own shortcuts
and works itself out of a job.

The footer also adapts to the terminal, dropping the marker legend and then
the Option aliases rather than letting fzf cut an item off mid-word. Create
shortcut isn't offered on any platform besides macOS and Linux, since there's
nowhere to put the result elsewhere.

</details>

```bash
brew-launcher --refresh          # rebuild the application cache
brew-launcher --list             # tab-separated plain text, for scripting
brew-launcher --preset devops    # launch a preset directly, no picker
brew-launcher --help
```

## Configuration

There's nothing you *have to* configure — the in-app keys (Theme, Create
Preset) write these files for you. They're plain text if you'd rather edit
them directly, one setting or command per line, `#` comments and blank lines
ignored:

```
~/.config/brew-launcher/config              # TERMINAL=, THEME=, DEFAULT_CATEGORIES=, DEFAULT_HIDDEN= — see below
~/.config/brew-launcher/ignore               # hidden entries
~/.config/brew-launcher/shown                # bundled-hidden commands you F6'd back visible
~/.config/brew-launcher/category-exclude     # commands excluded from a bundled-only category via F8
~/.config/brew-launcher/categories/<name>    # one file per category
~/.config/brew-launcher/categories/Favorites
~/.config/brew-launcher/launch-history       # one line per launch, powers Most Used
~/.config/brew-launcher/presets/<name>       # one file per preset — see below
```

`config` and `presets/<name>` are the only files here you'd ever write
yourself. An env var (`BREW_LAUNCHER_TERMINAL`, `BREW_LAUNCHER_THEME`) always
wins over what `config` says, for that one run. Categories match on
**command** name, not formula name — one formula can provide several commands
(`midnight-commander` provides `mc`). Use `brew-launcher --list` to look one up.

### Terminal backends

By default the best available option is chosen: Ghostty on macOS if installed,
otherwise the current terminal. Override with `BREW_LAUNCHER_TERMINAL`:

```bash
export BREW_LAUNCHER_TERMINAL=auto      # default
export BREW_LAUNCHER_TERMINAL=current   # run in this terminal
export BREW_LAUNCHER_TERMINAL=ghostty   # new Ghostty tab (macOS)
export BREW_LAUNCHER_TERMINAL=tmux      # new tmux window
```

`tmux` is deliberately opt-in only — it never starts a tmux session for you.
Use it while you're already inside one and it opens tools in a new window
alongside the launcher; run it outside tmux and it just falls back to
`current`, same as if you hadn't set it.

### Theme

```bash
export BREW_LAUNCHER_THEME=nord   # for one session
```

```
# ~/.config/brew-launcher/config
THEME=nord
```

Valid names: `catppuccin`, `gruvbox`, `tokyonight`, `nord`, `dracula`,
`solarized-dark`, `solarized-light`, `red-sands`, `green`, `amber`. An
unrecognized name fails fast rather than silently falling back, matching
`BREW_LAUNCHER_TERMINAL`'s own convention.

### Bundled defaults

A curated, hand-reviewed dataset ships with the launcher: a formula ->
category mapping for ~140 well-known CLI/TUI tools, and a short list of
commands that are genuinely just a multi-command formula's minor helper
scripts rather than something worth surfacing on its own (`age-inspect`,
`calcurse-upgrade`, `chkfont`, and a handful of others — reviewed one at a
time, not filtered by a generic naming rule; see
[CONTRIBUTING.md](CONTRIBUTING.md) for why a blanket heuristic was rejected
instead). Both apply automatically, on every cache rebuild, to anything you
haven't already touched yourself — a fresh install already looks organized
without any setup.

Two switches control it: `More → Default Categories` and
`More → Default Hidden` (`DEFAULT_CATEGORIES` / `DEFAULT_HIDDEN` in
`config`, each `on`/`off`, default `on`). Your own F6 (hide) or F8
(categorize) choice on any individual entry always overrides the bundled
data for that entry, no matter what these two settings say — they're only
an escape hatch for someone who wants none of it applied, anywhere, from
the start.

A category that's entirely bundled (no real file behind it yet) still
shows up in the view picker and takes an F8 press like any other one:
pressing it again on a bundled-only membership excludes just that command
from the bundled category, rather than writing a redundant real entry.

### Presets

```bash
brew-launcher --preset devops
```

reads `~/.config/brew-launcher/presets/devops`, one command per line:

```
# ~/.config/brew-launcher/presets/devops
btop
lazygit
lazydocker
```

Every command opens as its own pane in one tmux session. Exactly 2 panes go
side by side (`even-horizontal`) — tmux's own "tiled" layout stacks a pair
top-to-bottom instead, since it grids by character cells rather than screen
aspect ratio, which wastes a wide monitor for the most common preset size.
3 or more panes still use `tiled`, where a grid is the right call. Unlike
`BREW_LAUNCHER_TERMINAL=tmux` above,
naming a preset on the command line *is* the opt-in — it always starts (or
reattaches to) a tmux session, no ambiguity about whether tmux gets
bootstrapped. Re-running the same preset while it's still running reattaches
you to it rather than spawning a duplicate.

## How it works

Homebrew is queried once and the result cached, so startup after the first run
is effectively instant. Whether anything was installed or removed is then only
re-checked every 60 seconds rather than on every launch — that single check
was ~0.54s of a ~0.55s startup, so trusting it briefly is most of the speedup.
A tool installed in the last minute can take up to that long to appear;
**F5** refreshes immediately if you don't want to wait. The "update available"
check runs on its own separate schedule so it can't go stale for days.

Discovery walks each formula's `opt/<name>/bin`, keeps executables that are
actually reachable on your `PATH`, and drops obvious helper binaries. Only
formulae you installed on purpose are listed. The same pass stamps each entry
with its bundled category and hidden status — see [Bundled
defaults](#bundled-defaults) — so nothing extra runs later just to apply
them.

One zsh file plus a small Python helper for parsing Homebrew's JSON — no
Node, no Rust, no daemon, no SQLite.

<details>
<summary><strong>Automator launcher (macOS)</strong></summary>

`extras/Brew Launcher.applescript` turns the launcher itself into a
double-clickable app:

1. Open **Automator** → new **Application**
2. Add a **Run AppleScript** action
3. Paste the contents of `extras/Brew Launcher.applescript`
4. Save as `Brew Launcher.app`, then add it to the Dock or bind a hotkey

It opens `brew-launcher` in a new Ghostty tab.
</details>

## Troubleshooting

**A tool I installed isn't listed.** Only formulae installed *on purpose* appear
— if it came in as a dependency it's filtered out. Run `brew-launcher --refresh`
if you installed it very recently.

**The ⌥ shortcuts do nothing.** In stock Terminal.app, enable *Use Option as
Meta Key* in the profile's Keyboard settings. The F-keys work regardless.

**Nothing launches in a new tab.** That's Ghostty-only, and macOS must allow
brew-launcher to control Ghostty (System Settings → Privacy & Security →
Automation).

**`BREW_LAUNCHER_TERMINAL=tmux` isn't opening a new window.** It only does
that from inside an existing tmux session (`$TMUX` set); otherwise it falls
back to launching in place, same as `current`.

**Presets/Create Preset say "needs tmux."** Install it with
`brew install tmux`; the moment it's on `$PATH` both work normally, no
restart required beyond the next launch. `--preset` from a terminal says so
explicitly too, since typing that flag already implies you know what it
needs.

**Versions look out of date.** The update check runs on a timer, not every
launch. `brew-launcher --refresh` forces it.

**Something's categorized or hidden and I never did that.** That's the
[bundled defaults](#bundled-defaults) — a curated set of category/hidden-
command defaults ships with the launcher and applies to anything you haven't
touched yourself. Press **F8** to file it somewhere else (or **F6** to
unhide it) and your choice sticks from then on, or turn the whole mechanism
off from **F4 → More → Default Categories** / **Default Hidden**.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Release history
is in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
