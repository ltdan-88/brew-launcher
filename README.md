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
backend or Presets — see [Configuration](#configuration). Full platform/backend
matrix, including what's macOS-only vs. Linux-only: [COMPATIBILITY.md](COMPATIBILITY.md).

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

Every list is alphabetical by default. **F4 → Actions → Settings → Sort**
switches to size instead, largest first — handy for "what's actually taking
up space" without leaving for `ncdu`. Only reorders; nothing is filtered or
capped.
Doesn't touch `Most Used` or `Recently Added`, which already have their own
meaningful order.

**F4 → Actions → Settings → Compact View** drops the version and size columns
entirely — raised live as "detailed vs clean view," then taken further:
"I would even go further and hide all the category, favorites etc. flags (#,
+ etc.)" So it does — the `+`/`#`/`*` markers go too, along with the
footer's legend explaining them (nothing left to explain), leaving just the
name and description. Off by default (every column and marker shown, as
above); applies everywhere a row shows up, not only the main list.

The top border also shows how much disk space Homebrew's own installs are
using and how much is still free on the volume — visible on `All`, hidden on
filtered views to leave room for the view's own name.

The same `*` marker appears after brew-launcher's own version number in that
border, on every screen, once a newer brew-launcher itself is installable —
`v0.38.0*`. It's the exact same outdated-formula check that powers the marker
above; brew-launcher is just another installed formula to it. Run
`brew upgrade brew-launcher` and it's gone on the next launch.

### Two tiers of keys, plus Settings

<p align="center"><img src="assets/more.gif" alt="Opening the Actions menu with F4 and favoriting an entry from it"></p>

The footer shows what browsing needs — **Views**, **Details** — plus
**Actions**, **Presets**, since running one is worth a key of its own, and
**Help** last (lowest priority, first dropped on a narrow terminal — most
people already know F1 means help, but not everyone does). Organizing —
hide, favorite, categorize — and setup — create a preset, create a
shortcut, back up — live behind **F4 / ⌥M**, labeled **Actions** rather than
something vaguer, since it's a right-click-menu equivalent: whatever's
highlighted when you press it is what it acts on, and its own border label
says so by name (`Actions on fastfetch`), not just the generic word. Hide,
Favorite and Categorize still have a direct key too; the setup actions are
Actions-only, since they're one-time rather than everyday. Launch Preset
isn't offered here at all — **F9** already runs it directly and sits in the
footer on every screen Actions is reachable from, so a second, Actions-only
path to the exact same thing would just be redundant. **Refresh** (**F5**)
used to sit in the footer too — raised live: "Remove refresh from main menu
and place it into actions?" It's an Actions row now, right before Settings;
**F5** / **⌥R** still work as a direct keypress everywhere they always did,
same as Hide/Favorite/Categorize's own keys, this just stopped spending a
permanent footer slot on something reached for far less often than the rest.

The menu names each action in words and prints its shortcut next to it, which
makes it easier to discover than an F-number in a crowded footer, and means it
teaches you the key and then gets out of the way. Rows are grouped by what
they need: entry-scoped actions (Hide, Favorite, Categorize) and their bulk
counterparts right under them, then the two "build something new" actions,
Create Preset and Create Shortcut, right after — closer in spirit to those
than to a setting — then **Settings** itself, then Backup last. A details
pane below the list — on by default, no toggle to remember — spells out what
the highlighted row actually does.

**Hide Multiple**, **Favorite Multiple**, and **Categorize Multiple** — raised
live: "I like the behavior of how we create presets (adding TUIs with tab).
Would it be feasible to implement this behavior for Hide, Favorite, and
Categorize as well?" Each opens a Tab-to-mark picker over whatever's
currently on screen — fzf's own built-in multi-select, not Create Preset's
custom ordered-badge mechanism, since order doesn't matter for any of these
three, only membership does — and acts on every marked tool at once, or just
the highlighted one if nothing was marked. A marked batch always moves to
one end state rather than toggling each tool individually based on whatever
it happened to already be: Hide Multiple hides everything marked (skipping
anything already hidden), Favorite Multiple favorites everything marked
(skipping anything already favorited) — a per-item toggle across a batch you
just selected together would be a confusing surprise otherwise. Both relabel
to their inverse (**Unhide Multiple**, **Unfavorite Multiple**) while
viewing Hidden/Favorites, same as **F6**'s own per-entry label, since
everything on screen there is already hidden/favorited. Categorize Multiple
prompts for a category once for the whole marked batch — unless you're
already viewing a real category, in which case every marked entry is
necessarily already a member, so it removes them instantly instead, same as
**F8**'s own instant per-entry toggle in that same context.

All three, plus Create Preset, only appear when there's an actual list of
tools to work from — none of them are offered in Actions when it's opened
from the view picker (**F2**) itself, since a list of categories isn't a
list of tools to hide/favorite/categorize/bundle into a preset. Raised
live: "in the view picker, when you select hide/favorite/categorize
multiple, it shows 0 entries... I would prefer if menu entries like
hide/favorite/categorize multiple only show up when usable." Create Preset
used to force the full `All` list regardless of context (masking this same
inconsistency for itself); it now draws from whatever's actually on screen,
same as the three above.

Raised live: "it seems Actions menu mixes up actual Actions and System
Settings, how do we solve this (e.g. create a separate Settings menu)?" —
Actions used to also hold every standing preference (Theme, Default
Categories, Default Hidden, Open to Categories, Sort, Details, Alt
Keybinds) inline, mixing "things you do" with "things you set" in one list.
**Settings** is a screen of its own now, one level down from Actions, the
same way Theme or Create Preset already were — no key of its own (every
F1-F9 is spoken for, and settings are visited far less often than
Hide/Favorite/Categorize), just a single row that opens it.

Every row in Settings is an on/off (or two-way) switch — Default
Categories, Default Hidden, and Open to Categories (see [Bundled
defaults](#bundled-defaults) below), Sort (Name/Size), Details, which
mirrors **F3** itself so its current state is visible without opening the
pane, Details Position (Bottom/Top — see [The full details, without
leaving](#the-full-details-without-leaving)), and Alt Keybinds, which
controls whether the footer ever shows a key's **⌥** alias at all (on by
default) — off keeps the footer to plain F-keys even on a terminal wide
enough to fit the aliases — plus Theme, which opens its own picker rather
than flipping in place. All of the
toggles flip with **Space** as well as Enter, and reopen Settings right
after so you can touch more than one without leaving. Settings has its own
always-on details pane too, explaining each one. Esc from Settings goes
back to Actions, not all the way out to the main list; Theme returns to
Settings once it's done, same as Create Preset returns to Actions.

**F4**, **F5**, and **F9** also work from inside the view picker (**F2**)
itself, not just the main list — no row needs to be highlighted for either
of the first two, so Actions opens there with just **Refresh**, **Settings**,
and **Backup** (none of them need a highlighted row, but Hide/Favorite/
Categorize/their bulk versions/Create Preset/Create Shortcut all need an
actual list of tools to work from, which the view picker doesn't have) and
its border label just says "Actions," with no row to name. Esc backs out to
the view picker, not all the way to `All`.

### One place to switch views

<p align="center"><img src="assets/categories.gif" alt="Opening the view picker, filtering to a category, and stepping back out"></p>

**F2** opens the view picker: `All`, `Favorites`, then your own categories —
each marked with `·` so they're easy to tell apart from the built-in views —
followed by `Most Used`, `Recently Added`, and `Hidden` last. Group tools
however you think about them — Games, Editors, Monitoring. Every row shows how
many entries it holds, including `All` — which excludes `Hidden` the same way
the real view does, so the two counts add up to your real total rather than
`All` silently meaning something narrower than its name suggests. **Esc**
steps back one level at a time (details pane → filtered view → picker →
everything → quit) rather than dumping you out.

`Most Used` and `Recently Added` are computed, not something you set up —
`Most Used` tracks what you actually launch, and `Recently Added` reads the
install date Homebrew already records for every formula. Both cap themselves
to the 15 most relevant tools, so they stay a short, useful list instead of
turning into "everything, just re-sorted."

**F3** previews what's actually inside the highlighted category — every
command it holds, with its description, at a glance rather than opening it
to find out. Includes tools that are only there via the
[bundled defaults](#bundled-defaults) too, not just ones filed by hand — the
preview shows what F2 would actually list if you opened it, regardless of
who did the categorizing.

**Ctrl-R** in that picker renames the highlighted category — type a new name
over the prefilled current one and press Enter. A category's name is just its
filename under `~/.config/brew-launcher/categories`, so renaming is nothing
more than that; nothing else needs updating. A category that only exists via
the [bundled defaults](#bundled-defaults), with no real file of its own yet,
needs one entry categorized into it with F8 first.

**Ctrl-D** in that picker deletes the highlighted category. It asks first and
shows how many entries the category holds — every other action here is a toggle
you can undo with the same key, so this is the one worth pausing on. `All`,
`Hidden`, `Favorites`, `Most Used` and `Recently Added` can neither be renamed
nor deleted.

Once your categories are actually populated, **F4 → Actions → Settings →
Open to Categories** opens straight into this picker on every launch
instead of `All` — a long flat list stops being the first thing you see.
Esc from it still falls back to `All`, exactly like pressing Esc from F2
any other time.

### Favorites

<p align="center"><img src="assets/favorites.gif" alt="Toggling a favorite with F7; the marker appears and the cursor stays put"></p>

**F7** toggles a favorite instantly — no prompt. **F8** does the same for any
other category: instant while you're viewing one, or it asks which, if you're
not. Doing this to several tools at once? **F4 → Actions → Favorite
Multiple** / **Categorize Multiple** mark a batch with Tab and act on all of
them together — see [Two tiers of keys, plus Settings](#two-tiers-of-keys-plus-settings).

Uninstalling a favorited or categorized tool doesn't leave it behind forever —
the next real cache rebuild (`--refresh`, **F5**, or the periodic background
one) drops it from every category file it was in, Favorites included. There's
no live hook into `brew uninstall` itself, so this happens whenever the
launcher next confirms what's actually installed, not the instant it happens
elsewhere.

### Hide what you don't use

<p align="center"><img src="assets/hidden.gif" alt="Hiding an entry with F6, then finding it again in the Hidden view"></p>

**F6** hides an entry — it stays installed, Homebrew is untouched. Hidden isn't a
special screen: it's just another view in the picker, so **Enter** still launches
and **F6** unhides. Same key, opposite direction, exactly like Favorites.
**F4 → Actions → Hide Multiple** does the same for a Tab-marked batch instead
of one entry at a time.

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
**F4 → Actions → Settings → Default Categories** / **Default Hidden** — see
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

Same idea for presets: if the highlighted command is part of one or more, a
`Presets` line names them — the reverse of [the F9 picker's own details
pane](#launch-several-tools-together), which shows a preset's commands
rather than a command's presets. Omitted when it isn't in any.

**Shift-Up** / **Shift-Down** scrolls it for long entries. It starts closed and
stays closed until you ask for it. While it's open, **Esc** closes it first —
the footer says `[Close]` instead of the usual `[Quit]`/`[Views]` so it's
never a surprise — and only takes you further back on the next press. That's
specifically for a pane opened with **F3** itself, though — turn it on from
**F4 → Actions → Settings → Details** instead and it's a standing choice,
not a peek:
Esc leaves it alone and skips straight to whatever it would otherwise do, so
turning Details on there doesn't get quietly undone by the very next Esc.

**F4 → Actions → Settings → Details Position** switches which side of the
screen it opens on — `Bottom` (the default, below the list) or `Top` (above
it). Applies everywhere a details/preview pane shows up (the main list, F2,
F9, and Actions/Settings' own always-on panes), not just this one.



### Launch without leaving the launcher

On macOS with [Ghostty](https://ghostty.org/), picking a tool opens it in a
**new tab**, so the launcher stays where it is and you can fire off several in a
row. Inside a tmux session, `BREW_LAUNCHER_TERMINAL=tmux` does the same with a
**new window** instead. Everywhere else it launches in place. See
[Configuration](#configuration).

This works the same for a long-running TUI (`htop`, `lazygit`) and a one-shot
CLI that prints and exits (`eza`, `jq`, `shellcheck`) — quitting or finishing
either one brings the launcher right back, in that same tab or window, so you
can pick the next tool without running `brew-launcher` again. Want a plain
shell instead? Open a new tab or window for that, same as you would with any
other terminal app — the launcher reappearing is the more useful default for
what a launcher's actually for.

Either way, it pauses first with **press any key to return to brew-launcher**
rather than bringing the picker back instantly — for a one-shot CLI that's the
difference between actually seeing its output and having the picker paint
over it before you get the chance.

### Launch several tools together

<p align="center"><img src="assets/presets.gif" alt="Creating a preset by marking tools with Tab, naming it, then launching it with F9"></p>

A preset is a named group of tools that all open together, one per tmux pane —
your morning setup in one shot instead of launching each tool by hand.

**F4 → Actions → Create Preset** picks the tools, from whatever view is currently on
screen (`All`, a category, Favorites — the same list you were already
looking at, not always the full toolset): **Tab** marks one and shows a
number badge for the order it'll launch in (top to bottom, left to right in
the tmux layout), Tab again on a marked tool unmarks it and renumbers the
rest down, and **Enter** saves them in that exact order — not the
alphabetical order they're listed in. Enter with nothing marked shows an
error rather than quietly saving a one-tool "preset." Only offered when
there's an actual list to build from, so it isn't in Actions when opened
from the view picker (**F2**) itself. **F9** lists your presets and
launches the one you pick — in its own window when there's somewhere to put
one, otherwise reattaching to it if it's already running rather than opening
a second copy (see [Configuration](#configuration) for exactly which). Its
own details pane — always on, no toggle needed — previews what's in the
highlighted preset: every command, numbered and with its description, in the
order it launches in (not alphabetical — this is the same order Tab built
when you created it). **Ctrl-E** on a highlighted preset lets you rearrange
it — raised live: "option to rearrange TUIs in existing presets." The same
Tab-to-mark screen Create Preset uses, but seeded with the preset's current
members already badged in their current order instead of starting blank:
Tab still marks/unmarks, and unmarking then remarking a tool moves it to the
end, so reordering means doing that to whichever tools need to move, in the
order you want them to land in. You can add tools that weren't in the
preset or unmark ones to drop them, too — it isn't limited to reordering.
Builds its list from the full toolset regardless of whatever view you
happen to be browsing, unlike Create Preset — the point here is managing
everything already in the preset, not building from what's on screen. That
includes tools you've since hidden with F6: a preset member you only ever
run *through* the preset is exactly the kind of thing you'd hide from
everyday browsing, so hiding one no longer makes it vanish from its own
preset's edit screen. A member that's been fully uninstalled since, though,
has no row left to show at all — dropped with a one-line note when you open
the editor, rather than left in to silently break the numbering on
everything after it. Saves straight back to the same preset, no naming step.
**Ctrl-R** on a
highlighted preset renames it — same "type a new
name over the prefilled current one" as renaming a category, since a preset
is exactly the same shape: a name that's just its filename under
`~/.config/brew-launcher/presets`. If a session for that preset is already
running, it keeps working under the old name until it ends — renaming the
file doesn't reach into a live tmux session to match. **Ctrl-D** on a
highlighted preset deletes it instead — same confirm-first prompt as deleting
a category, showing how many commands it holds before anything's removed.
File format and the `--preset` CLI flag are also in
[Configuration](#configuration).

Presets need [tmux](#terminal-backends). **F9** and **F4 → Actions → Create Preset**
both stay visible either way — Create Preset's hint reads "needs tmux" in
place of the usual keybind when it's missing, and pressing either explains
the exact install command rather than silently failing.

### Custom launch flags

Raised live: "option to always run a TUI with specific commands?" — and
separately, the same question for a preset member. One answer covers both:
**F4 → Actions → Launch Flags** on a highlighted entry sets extra arguments to
always pass it when it launches — `--tree`, `-w /some/path`, whatever the tool
actually takes. Prefilled with whatever's already set, so editing is just
typing over it; the row's own hint in Actions shows the current flags too, so
you don't have to open the prompt to check. Blank clears it — typing nothing
and pressing Enter is a real, different answer from Esc here, not the same
"never mind" every other prompt treats it as.

Stored per command, the same key every marker in the main list already keys
off (favorited, categorized, hidden), so it applies wherever that command
actually launches — the main list's own Enter, *and* any preset it's a member
of. Configuring it once covers both; there's no separate per-preset version to
keep in sync.

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

The Settings row itself shows how many there are — **Themes (10)** — and
opening it shows a short description next to each name plus where the
current one sits among them (`3 of 10`), so you don't have to guess from the
name alone or scroll to find your place. Picking one writes the config file
for you — no terminal needed — and offers to relaunch immediately since
colors are resolved once at startup. Env var and config-file syntax are in
[Configuration](#configuration).

### Desktop shortcuts

**F4 → Actions → Create Shortcut** makes a tool show up outside the launcher too.

On macOS it writes a `.command` file to `/Applications/TUIs/` — double-click
it, drag it to the Dock, or bind it to a hotkey in System Settings. Give it a
custom icon via Finder → Get Info and it behaves like any other app.

On Linux it writes a `.desktop` entry to `~/.local/share/applications/`, which
every major desktop environment already watches — it appears in your
application menu with no further setup, launching in your default terminal.

Either way it's the same shell command underneath, so a one-shot CLI's output
stays readable: the window drops to a live shell afterward instead of closing
the instant the command finishes.

### Update everything at once

Raised live: "Action to launch TUI update or update all TUIs with command?"
**F4 → Actions → Update All** runs `brew upgrade` for everything outdated, in
a real terminal so you actually see its output — the same three
current-terminal/tmux/Ghostty paths a normal tool launch already goes
through, not a hidden background call. The row shows how many formulae are
outdated right now (the same count the `*` marker and F3 details pane are
already reading), and doesn't offer anything to confirm when there's nothing
to do. Asks first — this can take a while — Cancel is listed first, same
convention as every other confirm here. Relaunches the picker afterward same
as any other launch; **F5** picks up the new versions right away rather than
waiting on the next automatic check.

### Backup

**F4 → Actions → Backup** writes one file — always
`~/brew-launcher-backup.tar.gz`, overwritten on every run, so it's something
you point a synced folder (iCloud Drive, Dropbox) at once and forget about
rather than clean up after — with everything needed to rebuild this exact
setup on a fresh machine:

- A Brewfile from `brew bundle dump`: every installed formula, cask and tap,
  including the tap this launcher itself comes from.
- `brew-launcher-config/`, a copy of `~/.config/brew-launcher` — categories,
  presets, hidden entries, favorites, theme, terminal backend. `brew bundle`
  has no idea this launcher exists, so this is the half it can't cover.

Restoring on a fresh machine is two manual steps rather than a launcher
action of its own: untar the archive, run
`brew bundle install --file=Brewfile`, then copy `brew-launcher-config` back
to `~/.config/brew-launcher`.

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
| **Esc** | Go back one level; on `All`, asks Quit or Cancel first | footer |
| **F4** / **⌥M** | Open the Actions menu — also works from the view picker | footer |
| **F9** / **⌥P** | Launch a preset (reattaches if it's already running) — also works from the view picker; its own details pane is always on, previewing what's in the highlighted preset | footer |
| **Ctrl-E** | Rearrange (add/remove/reorder tools in) the highlighted preset — in the F9 picker | picker |
| **Ctrl-R** | Rename the highlighted preset — in the F9 picker | picker |
| **Ctrl-D** | Delete the highlighted preset — in the F9 picker | picker |
| **F5** / **⌥R** | Refresh the cache — also works from the view picker; not in the footer, but always available directly | Actions |
| **F6** / **⌥H** | Hide — or unhide, in the Hidden view | Actions |
| **F7** / **⌥F** | Toggle Favorites for selected entry | Actions |
| **F8** / **⌥C** | Categorize selected entry (adds or removes) | Actions |
| **F3** | Preview what's in the highlighted category — in the F2 picker | picker |
| **Ctrl-R** | Rename the highlighted category — in the F2 picker | picker |
| **Ctrl-D** | Delete the highlighted category — in the F2 picker | picker |
| **F1** / **⌥?** | Open this reference in the launcher — also in the footer, last | footer |
| — | Hide/Unhide multiple entries (Tab to mark) | Actions only |
| — | Favorite/Unfavorite multiple entries (Tab to mark) | Actions only |
| — | Categorize multiple entries (Tab to mark) | Actions only |
| — | Create a new preset | Actions only |
| — | Create a desktop shortcut (macOS or Linux) | Actions only |
| — | Set custom launch flags for the highlighted entry | Actions only |
| — | Update All — run brew upgrade for everything outdated | Actions only |
| — | Open Settings | Actions only |
| — | Back up installed apps + launcher config to one file | Actions only |
| — | Switch color theme | Settings only |
| — | Toggle Default Categories / Default Hidden | Settings only |
| — | Toggle Open to Categories | Settings only |
| — | Sort by name or size | Settings only |
| — | Toggle Compact View (hide version/size columns and +/#/\* markers) | Settings only |
| — | Toggle the details pane (mirrors F3) | Settings only |
| — | Toggle where the details pane opens — top or bottom | Settings only |
| — | Toggle Alt Keybinds (show/hide the ⌥ aliases in the footer) | Settings only |

Each Option alias matches its label — **⌥H**ide, **⌥V**iews, **⌥P**resets,
**⌥R**efresh, **⌥F**avorite, **⌥C**ategorize, **⌥D**etails. They exist because
F-keys need Fn on most Mac laptops. In stock Terminal.app, enable *Use Option
as Meta Key* in the profile's Keyboard settings first; Ghostty supports it out
of the box.

<details>
<summary>Why the keys are split this way</summary>

**F1** is deliberately unassigned — it means *help* nearly everywhere, and the
launcher may want it later. The footer keys sit on **F2**–**F4** plus **F9**
because those are the ones you press constantly, and they're the easiest to
reach on a laptop that needs **Fn**.

The split is by what you're doing, not by how often. Finding, browsing, and
running something together with launching a preset are what you open the
launcher for, so those stay on screen. Organizing — hiding, favoriting,
categorizing — and setup — building a preset, making a shortcut, adjusting a
setting — are things you do in bursts, and they were costing footer slots
you'd otherwise look at on every single launch. **F9** followed the same
logic in
reverse: unlike making a shortcut (once per tool, rarely repeated), running a
preset is something you'd reach for over and over, so it earned a footer key
of its own — and, once that key existed everywhere Actions is reachable
from, a matching Actions row would've just been the same action twice, so it
isn't offered there at all. **F5** (Refresh) used to sit in the footer too,
matching the convention it has in every browser and file manager, but it's
reached for far less often than the others — raised live: "Remove refresh
from main menu and place it into actions?" It moved to Actions (still
pressable directly at any time, same as F6/F7/F8), freeing a permanent
footer slot for something used only occasionally.

The menu lists each action's key beside it, so it teaches its own shortcuts
and works itself out of a job.

The footer also adapts to the terminal, dropping the marker legend and then
the Option aliases (unless Alt Keybinds is off, in which case they're never
shown in the first place) rather than letting fzf cut an item off mid-word.
The view picker (**F2**) and preset picker (**F9**) degrade the same way,
down to wrapping their own footer across two lines if even the tightest
single-line rendering doesn't fit — they used to have a fixed footer of
their own that could overflow, and Alt Keybinds now applies there too, so
neither picker disagrees with the main list about whether an alias shows.
Create shortcut isn't offered on any platform besides macOS and Linux, since
there's nowhere to put the result elsewhere.

</details>

```bash
brew-launcher --refresh          # rebuild the application cache
brew-launcher --list             # tab-separated plain text, for scripting
brew-launcher --preset devops    # launch a preset directly, no picker
brew-launcher --diagnose         # check dependencies, config and cache health
brew-launcher --help
```

## Configuration

Nothing here is required reading — everything in the launcher works with zero
configuration. Expand this if you want to change the terminal backend, theme,
bundled-defaults behavior, or preset file format.

<details>
<summary><strong>Show configuration details</strong></summary>

The in-app keys (Theme, Create Preset) write these files for you. They're
plain text if you'd rather edit them directly, one setting or command per
line, `#` comments and blank lines ignored:

```
~/.config/brew-launcher/config              # TERMINAL=, THEME=, DEFAULT_CATEGORIES=, DEFAULT_HIDDEN=, OPEN_TO_CATEGORIES=, SORT=, ALT_KEYBINDS= — see below
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
otherwise the current terminal — **unless you're connected over SSH**, where
there's no display to open a Ghostty window in even if it's installed on the
machine. Override with `BREW_LAUNCHER_TERMINAL`:

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

`auto` itself is SSH-aware, so this is usually nothing you need to set by
hand: connected over SSH (detected via the standard `SSH_TTY`/
`SSH_CONNECTION`/`SSH_CLIENT` env vars) and already inside a tmux session, it
picks `tmux`; over SSH without one, `current`. Reported live: launching a
single tool over SSH used to still reach for Ghostty and just hang, since
`auto` had no way to tell "a Mac with Ghostty installed" from "a Mac with
Ghostty installed that I can't currently see."

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

Two switches control it: `Actions → Settings → Default Categories` and
`Actions → Settings → Default Hidden` (`DEFAULT_CATEGORIES` /
`DEFAULT_HIDDEN` in `config`, each `on`/`off`, default `on`). Your own F6
(hide) or F8
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
bootstrapped. Re-running an unchanged preset while it's still running
reattaches you to it rather than spawning a duplicate; editing the preset
first (fewer or more commands) rebuilds the session fresh instead, so the
pane count always matches what the file says now.

The status bar is also forced on for every preset session, regardless of
what your own tmux config does elsewhere — a preset that ends up with just
one pane (a one-tool preset, or one tool skipped because it wasn't found)
would otherwise look exactly like a plain shell prompt, with nothing on
screen to say a preset launched at all. The status bar always names the
session (`blpreset-<name>`), so that's never ambiguous.

Mouse mode is turned on for every preset session (scoped to that session
only — it won't change mouse behavior anywhere else you use tmux), so you
can click a pane to focus it or drag a border to resize it. Two built-in
tmux keys are usually more useful than resizing by hand, mouse or otherwise:
**prefix + z** zooms the focused pane to fill the whole window and back
(the fastest way to focus on one tool without reshaping the layout for
everyone else), and **prefix + Ctrl-arrow** nudges a border a cell at a
time if you do want to reshape it. Default prefix is Ctrl-b unless your
tmux config remaps it.

**How a preset actually shows up on screen depends on how you're connected**
— a multi-pane preset earns its own window rather than swallowing whatever's
already open, whenever there's somewhere to put one:

- **Local Mac with Ghostty** — opens a brand new Ghostty **window** (never a
  tab, unlike single-tool launches — a preset holding several TUIs deserves
  more than a corner of whatever's already there). The launcher you ran it
  from keeps running exactly as it was; nothing about it is touched. Closing
  or detaching from that window later relaunches the launcher right there.
- **Over SSH (or no Ghostty), already inside a tmux session** — your client
  switches to the preset's session instead. Detaching (**prefix + d**) later,
  or the preset session ending, relaunches the launcher in the window you
  switched from — it's not still sitting there in the background the way an
  earlier version of this doc claimed; testing with a real attached client
  found that pane actually closes the moment the switch completes, since
  nothing was left running in it. Relaunching in its place is what makes
  this recoverable in practice, not the pane surviving on its own.
- **Over SSH (or no Ghostty), not inside tmux** — takes over the current
  window — there's no GUI to open a window in and no existing tmux session
  to switch within, so taking over the only screen there is is the only way
  to show a multi-pane preset at all. Says so before doing it. Detaching or
  the preset ending relaunches the launcher right there too, same as the
  other two cases. Run brew-launcher itself inside a tmux session (`tmux`
  then `brew-launcher`) to get the switch-instead-of-takeover behavior above
  — this is exactly the setup
  [BREW_LAUNCHER_TERMINAL=tmux](#terminal-backends) is for.

Detecting "connected over SSH" uses the standard `SSH_TTY` / `SSH_CONNECTION`
/ `SSH_CLIENT` environment variables — the same signal most SSH-aware tools
check.

</details>

## How it works

Curious how it stays instant with no daemon and no database? Expand this —
otherwise, nothing here changes how you use it.

<details>
<summary><strong>Show the caching internals</strong></summary>

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

</details>

## Troubleshooting

**Not sure what's wrong.** Run `brew-launcher --diagnose` first — it checks
dependencies (required and optional), which terminal backend `auto` actually
resolves to on your machine, and whether the config/cache directories exist,
are writable, and are in the shape the launcher expects. It works even if a
dependency is missing, so it's the right first step whether the launcher
won't start at all or something just looks off.

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
off from **F4 → Actions → Settings → Default Categories** / **Default
Hidden**.

## Security

Found a vulnerability? See [SECURITY.md](SECURITY.md) for how to report it.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). Release history
is in [CHANGELOG.md](CHANGELOG.md). Scripting against brew-launcher, or curious
what's safe to rely on vs. internal implementation detail? See
[EXTENDING.md](EXTENDING.md).

## License

[MIT](LICENSE)
