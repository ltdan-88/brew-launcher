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

It's a single zsh file. No daemon, no database, no config to write, and startup
is instant after the first run.

## Quick start

```bash
brew install ltdan-88/brew-launcher/brew-launcher
brew-launcher
```

That's it — nothing to configure. Type to search, **Enter** to launch, **Esc** to quit.

**Requirements:** macOS or Linux · [Homebrew](https://brew.sh/) · python3 (already on most systems).
[fzf](https://github.com/junegunn/fzf) is installed automatically as a dependency.

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

### One place to switch views

<p align="center"><img src="assets/categories.gif" alt="Opening the view picker, filtering to a category, and stepping back out"></p>

**F3** opens the view picker: `All`, `Favorites`, `Hidden`, then your own
categories. Group tools however you think about them — Games, Editors,
Monitoring. **Esc** steps back one level at a time (filtered view → picker →
everything → quit) rather than dumping you out.

**Ctrl-D** in that picker deletes the highlighted category. It asks first and
shows how many entries the category holds — every other action here is a toggle
you can undo with the same key, so this is the one worth pausing on. `All`,
`Hidden` and `Favorites` can't be deleted.

### Favorites

<p align="center"><img src="assets/favorites.gif" alt="Toggling a favorite with F6; the marker appears and the cursor stays put"></p>

**F6** toggles a favorite instantly — no prompt. **F7** does the same for any
other category: instant while you're viewing one, or it asks which, if you're
not.

### Hide what you don't use

<p align="center"><img src="assets/hidden.gif" alt="Hiding an entry with F2, then finding it again in the Hidden view"></p>

**F2** hides an entry — it stays installed, Homebrew is untouched. Hidden isn't a
special screen: it's just another view in the picker, so **Enter** still launches
and **F2** unhides. Same key, opposite direction, exactly like Favorites.

### The full details, without leaving

<p align="center"><img src="assets/details.gif" alt="Toggling the details pane with F8; it follows the cursor down the list"></p>

**F8** opens a details pane under the list — homepage, license, size, tap,
dependencies and any caveats — and it follows the cursor as you move. It's the
`brew info` output you'd otherwise quit and go look up, except it's already on
disk: the text is written when the cache is built, so the pane is instant rather
than the ~0.6s a live `brew info` costs on every keystroke.

**Shift-Up** / **Shift-Down** scrolls it for long entries. It starts closed and
stays closed until you ask for it.

### Launch without leaving the launcher

On macOS with [Ghostty](https://ghostty.org/), picking a tool opens it in a
**new tab**, so the launcher stays where it is and you can fire off several in a
row. Everywhere else it launches in place. See [Terminal backends](#terminal-backends).

### macOS shortcuts

**F4** writes a `.command` file to `/Applications/TUIs/` — double-click it, drag
it to the Dock, or bind it to a hotkey in System Settings. Give it a custom icon
via Finder → Get Info and it behaves like any other app.

### Mouse support

Click a row to select it, double-click to launch. Footer items shown in
`[brackets]` are clickable too and do exactly what the key beside them does —
clicking `[Hide]` is the same as pressing F2. Unbracketed footer text (the
marker legend, "Navigate") is explanatory and deliberately inert.

## Reference

| Key | Action |
|---|---|
| **Enter** | Launch selected application |
| **F2** / **⌥H** | Hide — or unhide, in the Hidden view |
| **F3** / **⌥V** | Switch view (All · Favorites · Hidden · categories) |
| **F4** / **⌥S** | Create macOS shortcut |
| **F5** / **⌥R** | Refresh the cache without leaving |
| **F6** / **⌥F** | Toggle Favorites for selected entry |
| **F7** / **⌥A** | Categorize selected entry (adds or removes) |
| **F8** / **⌥P** | Show or hide the details pane |
| **Shift-Up/Down** | Scroll the details pane |
| **Esc** | Go back one level, or quit |

**F2**, **F6** and **F7** all toggle something about the highlighted entry;
**F3** and **F8** change what you're looking at. **F5** is refresh, matching the
convention everywhere else.

The ⌥ (Option) aliases exist because F-keys need Fn on most Mac laptops. In
stock Terminal.app, enable *Use Option as Meta Key* in the profile's Keyboard
settings first; Ghostty supports it out of the box.

```bash
brew-launcher --refresh   # rebuild the application cache
brew-launcher --list      # tab-separated plain text, for scripting
brew-launcher --help
```

## Terminal backends

By default the best available option is chosen: Ghostty on macOS if installed,
otherwise the current terminal. Override with `BREW_LAUNCHER_TERMINAL`:

```bash
export BREW_LAUNCHER_TERMINAL=auto      # default
export BREW_LAUNCHER_TERMINAL=current   # run in this terminal
export BREW_LAUNCHER_TERMINAL=ghostty   # new Ghostty tab (macOS)
```

## Configuration

There's nothing you *have* to configure — the in-app keys write these for you.
They're plain text if you'd rather edit them directly, one command per line:

```
~/.config/brew-launcher/ignore              # hidden entries
~/.config/brew-launcher/categories/<name>   # one file per category
~/.config/brew-launcher/categories/Favorites
```

Categories match on **command** name, not formula name — one formula can provide
several commands (`midnight-commander` provides `mc`). Use `brew-launcher --list`
to look one up.

## How it works

Homebrew is queried once and the result cached, so startup after the first run
is effectively instant. The cache invalidates itself when your installed
formulae change; the "update available" check refreshes on its own schedule so
it can't go stale for days.

Discovery walks each formula's `opt/<name>/bin`, keeps executables that are
actually reachable on your `PATH`, and drops obvious helper binaries. Only
formulae you installed on purpose are listed.

Roughly 2,000 lines of zsh plus a small Python helper for parsing Homebrew's
JSON — no Node, no Rust, no daemon, no SQLite.

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

**Versions look out of date.** The update check runs on a timer, not every
launch. `brew-launcher --refresh` forces it.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Release history
is in [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE)
