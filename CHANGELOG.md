# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.20.0] — 2026-08-26

### Added

- **A tenth theme: `red-sands`** — a genuinely red theme (deep brick-red
  background, warm cream text) rather than a theme that merely uses red
  as one accent among several, which was every option so far. From the
  iTerm2-Color-Schemes collection, the reference most terminal color
  schemes get ported through — checked against real popularity data,
  including a first candidate (Rosé Pine) that turned out to have a
  purple background despite its "rose" branding, before settling on
  this one.

## [0.19.0] — 2026-08-26

### Added

- **Two Solarized themes: `solarized-dark` and `solarized-light`** — the
  first light-background option, and the first theme here that spans a
  full color wheel (yellow/orange/red/green/blue accents) rather than
  leaning blue-and-purple like every theme before it. Uses Ethan
  Schoonover's own published hex values for both, sharing the same
  accent set — only the base tones swap which end is background vs.
  foreground, same as the original spec does. 9 themes total now.

## [0.18.1] — 2026-08-25

### Fixed

- **Clicking `[Presets]` in the footer did nothing.** The F9 → Launch Preset
  swap in v0.18.0 updated the footer text and the action it should trigger,
  but missed a separate list that decides which clicked footer words are
  recognized at all — it still only recognized F9's old label
  ("Shortcut"), so a real mouse click on the new "[Presets]" word was
  silently ignored while the direct F9 keypress worked fine. Found by a
  user testing mouse support after the update.

## [0.18.0] — 2026-08-25

### Added

- **F9 launches a preset from the picker** — lists your presets, launches
  the one you pick, reattaching if it's already running. Given a footer
  key of its own (`[Presets]`, ⌥P alias) since running a preset is
  something you'd reach for repeatedly, unlike the one-time setup
  actions that live in More.

### Changed

- **F9 no longer creates a desktop shortcut** — moved to `F4 → More →
  Create shortcut` instead, with no direct key. It's made once per tool
  and rarely touched again, closer in spirit to Theme and Create Preset
  than to Hide/Favorite/Categorize, which get exercised repeatedly as
  you curate your list. Works exactly the same, just one menu away.

## [0.17.0] — 2026-08-25

### Added

- **An in-app "Create Preset" screen (`F4 → Create Preset`)** — writes a
  preset file for you instead of hand-editing one. Multi-select which
  tools go in it (Tab marks, Enter confirms), then name it: type a new
  name, or pick an existing preset to replace. Draws from your whole
  toolset regardless of which view was open when you started, same as
  Categorize already does. Picking an existing name asks for
  confirmation before replacing it.

## [0.16.0] — 2026-08-25

### Added

- **Presets: `brew-launcher --preset <name>`** — launches every command
  listed in `~/.config/brew-launcher/presets/<name>` together, one per
  tmux pane (`tmux select-layout tiled`), so a whole "morning setup" of
  tools comes up in one shot. One command per line, `#` comments and
  blank lines skipped, same convention as the ignore file — hand-edited,
  no in-app creation UI yet.

  Unlike the `tmux` terminal backend, this always starts (or reattaches
  to) a tmux session — invoking `--preset` by name is itself the
  opt-in, so there's no ambiguity about whether tmux gets bootstrapped.
  Re-running the same preset while its session is already alive
  reattaches (or, from inside another tmux session, switches the
  client) instead of spawning a duplicate.

## [0.15.0] — 2026-08-25

### Added

- **A tmux terminal backend: `BREW_LAUNCHER_TERMINAL=tmux`** — opens a
  picked tool in a new tmux window, same "picker stays put" idea as the
  Ghostty backend, just terminal-agnostic instead of tied to one app.
  Strictly opt-in: it only opens a new window when you're already inside
  a tmux session (`$TMUX` set); outside of one it falls back to launching
  in place, same as `current`. It never starts tmux or a session on its
  own — this project has consistently avoided behavior that changes
  based on what happens to be installed, and auto-bootstrapping into
  tmux would be exactly that, plus disruptive to anyone already running
  their own tmux elsewhere.

## [0.14.0] — 2026-08-25

### Added

- **Two retro monochrome themes: `green` and `amber`** — the real colors
  green- and amber-phosphor CRT terminals displayed (`#33ff66` and
  `#ffbf00`, checked against real historical values, not guessed).
  Deliberately single-hue: every slot in each palette stays inside that one
  color, varied by brightness, matching what the actual hardware could
  physically show — no off-hue accent the way the other five themes have.

- **The Theme picker now shows a short description next to each name**
  (`gruvbox   Warm, low-contrast — brown background, retro accents`), so
  you don't have to already know what a theme looks like to pick one.

## [0.13.0] — 2026-08-25

### Added

- **A "Theme" option in the More menu (`F4`) picks a color theme in-app** —
  no terminal, no hand-editing the config file. Since colors are resolved
  once at startup and can't repaint an already-running screen, picking a
  new one offers to relaunch immediately; declining still saves the choice
  for next time.

  Reuses the config file's own `set_config_value()` writer to update just
  the `THEME=` line, preserving everything else already in the file —
  other settings, hand-written comments included.

## [0.12.0] — 2026-08-25

### Added

- **A persisted config file** (`~/.config/brew-launcher/config`) for defaults
  that previously needed exporting an env var every session. Two keys:
  `TERMINAL=` and `THEME=` (see below), plain `KEY=value` lines, `#` comments
  and blank lines ignored. It's the one file under `CONFIG_DIR` you write
  yourself — nothing in the launcher generates it, and it's parsed as plain
  data rather than sourced as shell code, staying consistent with every other
  file there (`ignore`, `categories/*`, `launch-history`) being inert.
  `BREW_LAUNCHER_TERMINAL` / `BREW_LAUNCHER_THEME` still win over it for one
  run, same precedence env vars already had.

- **Five color themes**: `catppuccin` (the existing default), `gruvbox`,
  `tokyonight`, `nord`, `dracula` — checked against real theme-popularity
  data rather than picked from memory, same discipline as `Most Used`/
  `Recently Added`'s naming. Set with `BREW_LAUNCHER_THEME=<name>` or the
  config file's `THEME=`. An unrecognized name is rejected with the valid
  list shown, matching the fail-fast convention `BREW_LAUNCHER_TERMINAL`
  already had — a silent fallback would hide a typo instead of surfacing it.

## [0.11.0] — 2026-08-25

### Added

- **The details pane (`F3`) now shows when you installed a tool, and what
  version is available if it's outdated.** "Installed" is deliberately not
  labeled "Released" — it's when *you* ran the install, not when the
  developers published that version, since Homebrew doesn't track the
  latter anywhere locally and there's no single consistent place to fetch
  it from across every formula's own upstream project.

  `Update available` shows the same thing the list's `*` marker already
  signals, just with the actual version number attached instead of having
  to go check `brew outdated` yourself.

### Fixed

- **A real desync bug, caught before release**: `rebuild_cache()` and
  `refresh_outdated_if_stale()` each fetched "what's outdated" independently.
  When the latter was changed to also capture version numbers, the former
  kept its own old, name-only fetch — so every fresh cache rebuild silently
  overwrote the correct data with the old format immediately afterward, and
  "Update available" would go missing right after the exact refresh meant to
  populate it. Fixed by consolidating both into one shared
  `fetch_outdated_formulae()`, which also means this specific class of bug
  can't recur — there's no longer a second copy to fall out of sync.

- The outdated-info file also gets a format-detection check independent of
  its normal TTL: an old-format file (no version column) forces an
  immediate refresh instead of silently reading as "nothing is outdated"
  for up to the usual 6-hour window.

  Cache format version bumped (metadata labels widen from 12 to 18 columns
  to fit "Update available"); existing caches rebuild once automatically.

## [0.10.0] — 2026-08-25

### Added

- **Most Used and Recently Added**, two new computed views in the `F2`
  picker alongside `All`/`Favorites`/`Hidden`. Neither is something you set
  up: `Most Used` tracks what you actually launch (a plain append-only log
  at `~/.config/brew-launcher/launch-history`, tallied on demand — not a
  running counter file that needs rewriting on every launch), and
  `Recently Added` reads the install timestamp Homebrew already records for
  every formula, so it costs nothing new to capture. Both cap themselves to
  the 15 most relevant tools, so they stay a short, useful list rather than
  becoming "everything, just re-sorted."

  Names match what's already industry-standard for this — literally what
  Windows' own Start Menu and Chrome's new-tab page call the same idea.

- **Every view in the picker now shows a count.** `Games (3)`, `Hidden (13)`
  — mainly useful for noticing a category has quietly emptied out, which
  wasn't visible before without opening it. `All` is left out on purpose:
  it isn't a filtered subset the way the others are.

- Categories you created yourself are marked with `· ` in the picker, so
  they're easy to tell apart from the built-in views above them (`All`,
  `Favorites`, `Hidden`, and now `Most Used`/`Recently Added`). Doesn't
  reuse the main list's own `#`/`*` markers — those already mean something
  specific there.

### Fixed

- A real bug turned up while building the ranking for the two new views:
  `sort_prep=("${(On)sort_prep}")` — sorting an array with the result
  wrapped in double quotes — collapses the whole sorted result into one
  glued-together string instead of a real array, silently dropping every
  element after the first. Caught visually (15 expected entries showed as
  1) before release, not after; a regression test
  (`test/computed-view-fixtures.sh`) now guards this specific failure
  shape.

## [0.9.2] — 2026-08-25

### Changed

- **Your own categories are now marked with `·` in the view picker**, so
  they're easy to tell apart from the built-in views above them (`All`,
  `Favorites`, `Hidden`). Doesn't reuse the main list's `#`/`*` markers —
  those already mean something specific there (categorized / outdated), and
  reusing them here for something different would confuse rather than
  clarify.

  The marker is display-only: picking a marked row still stores and uses
  the plain category name, same as before.

## [0.9.1] — 2026-08-25

### Changed

- **Pressing Enter now launches the exact path the cache already verified**,
  instead of doing a fresh lookup on every launch. This closes a narrow gap
  where something on `PATH` could change between browsing the list and
  pressing Enter, so what launches wasn't always guaranteed to be what was
  shown.

  This doesn't trade away picking up Homebrew upgrades: Homebrew re-points
  the same path on every upgrade rather than making a new one, so the
  cached path stays valid across upgrades on its own. Only a full uninstall
  invalidates it, and that case falls back to a fresh lookup automatically.

  Verified directly: shadowed a real command with a decoy earlier on `PATH`
  (which a fresh lookup would have found first) and confirmed the launcher
  still launched the real one from the cache; then made the cached path
  point at a file that doesn't exist and confirmed it fell back to a live
  lookup instead of erroring.

  Cache format version bumped (adds an 8th column, the resolved path);
  existing caches rebuild once automatically. `--list`'s documented 6-field
  output is unaffected.

### Added

- `test/ignore-fixtures.sh` — hide/unhide round-trips, duplicate-hide is a
  no-op, blank lines and `#` comments in a hand-edited ignore file are
  skipped rather than treated as commands.
- `test/dedup-fixtures.sh` — duplicate command names across formulae are
  reduced to one entry, with the dropped one(s) still reported.
- `test/category-fixtures.sh` — sources `load_category_names()` directly
  against a fixture categories directory (no fzf or brew needed), covering
  reserved-name skipping (`All`/`Hidden` hand-made files) and that
  `Favorites` is pinned first rather than just happening to sort there.
- `test/list-fixtures.sh` — a second CI test covering hidden-entry
  filtering and `--list`'s 6-field output shape, built against a cache
  and state file written directly rather than a real Homebrew install.
  `test/cache-roundtrip.sh` skips on a bare runner with no formulae
  installed; this one never does, since it needs no real formulae to
  begin with.
- README now documents the 60-second cache-freshness window from
  0.5.1 and points at `F5` as the way to skip it.

## [0.9.0] — 2026-08-25

### Added

- **Linux desktop shortcuts.** `F9` previously only worked on macOS; it now
  writes a `.desktop` entry to `~/.local/share/applications/` on Linux, the
  XDG-conventional location every major desktop environment already watches
  — the tool appears in the application menu with no further setup, opening
  in the default terminal (`Terminal=true`). Verified against a real
  `desktop-file-validate` run, not just written to spec from memory.

  The actual launch command lives in a small companion script rather than
  directly in the `.desktop` file's `Exec=` line — that field isn't run
  through a shell per the XDG spec, and its quoting rules are a real source
  of cross-desktop-environment bugs. A plain path to a self-contained script
  sidesteps that entirely, mirroring how the macOS `.command` file already
  works.

### Fixed

- **A shortcut for a one-shot CLI closed its window instead of showing the
  output.** Both `create_macos_shortcut` and the new Linux path used a bare
  `exec` into the command — the same bug already fixed for the two
  interactive launch paths in 0.8.0, just not yet applied here. Same fix:
  run the command, then fall through to a fresh interactive shell in the
  same window, rather than exec-ing straight into it.

  **Existing shortcuts made before this release still have the old
  behavior** — regenerating one means deleting the file and pressing `F9`
  again; there's no way to patch an existing shortcut in place from inside
  the launcher.

## [0.8.1] — 2026-08-25

### Fixed

- **The launcher could fail to start on Linux at all.** The shebang was a
  hardcoded `#!/bin/zsh`; most Linux distros either don't install zsh by
  default or put it at `/usr/bin/zsh` instead. Changed to
  `#!/usr/bin/env zsh`, and the Homebrew tap formula now declares
  `depends_on "zsh"` on Linux (macOS already ships it, so this was never
  needed there).

- **Cache freshness checks crashed on Linux with "bad math expression".**
  `stat -f %m` (BSD/macOS) and `stat -c %Y` (GNU/Linux) were tried in one
  line joined by `||`, assuming the wrong one would simply fail. It
  doesn't: GNU `stat -f` is a real, different flag ("filesystem status"
  instead of "format string") — it prints an unrelated multi-line dump to
  stdout before exiting non-zero, and since it failed, the `||` fallback
  ran too and appended its own output, leaving a mix of both results
  where a single timestamp was expected. Found by the first real CI run
  on a Linux runner, added in this same release. Fixed with an explicit
  `uname -s` branch instead of the try-both assumption.

## [0.8.0] — 2026-08-24

### Fixed

- **A one-shot CLI (`eza`, `jq`, `shellcheck`, ...) no longer leaves the tab
  looking dead.** Launching used a bare `exec` into the command — right for a
  TUI that takes over the screen until you quit it, but a one-shot prints and
  exits in under a second, and `exec` leaves nothing running in the terminal
  afterward. The tab then closes or sits inert, which reads as "the launcher
  is broken," even though the command worked.

  Both launch paths (Ghostty, current-terminal) now run the command and fall
  through to a fresh interactive shell in the same tab afterward, rather than
  exec-ing straight into it — the same thing typing the command into an
  ordinary terminal tab would do. No classification of "is this a TUI?" was
  needed: the fix is the same for both cases, because it's really the same
  bug wearing two faces — it was always true that quitting a TUI also left an
  exec'd tab with nothing to show for it, just less noticeable, since you'd
  meant to be done with it anyway.

## [0.7.2] — 2026-08-24

### Added

- **`F1` / `⌥?` opens an in-app help screen** — every key, both tiers, the
  marker legend, mouse support, and the 60s cache-freshness note, without
  leaving the launcher or reaching for the README. Purely informational:
  every row is inert, and Enter, Esc, or clicking `[Back]` all just return to
  where you were.

  Deliberately left off the footer and the More menu. `F1` = help is close to
  universal, so teaching it would spend space on something most people
  already know to try — the same reasoning that kept it unassigned since
  0.7.0.

## [0.7.1] — 2026-08-24

### Fixed

- **The `Categories` row in the details pane was misaligned.** The label is
  exactly as wide as the column that held it, so its value started one space
  after the label where every other row had three — it read as a rendering
  glitch and was easy to skim past. Metadata labels are now padded to 12.

  The cache format version is bumped with it: without that, a cache written by
  0.7.0 would keep its 10-wide baked labels while the live category line used
  12, misaligning the row in the opposite direction.

## [0.7.0] — 2026-08-24

### Changed

- **The keys are renumbered so the ones you press live on `F2`–`F5`.** First
  tier had drifted onto `F3`, `F8` and `F9` — the three keys you press most
  were the three hardest to reach, which is backwards on a laptop that needs
  `Fn`.

  | Key | Action | Tier |
  |---|---|---|
  | `F2` / `⌥V` | Views | first |
  | `F3` / `⌥D` | Details | first |
  | `F4` / `⌥M` | More | first |
  | `F5` / `⌥R` | Refresh | first |
  | `F6` / `⌥H` | Hide | in More |
  | `F7` / `⌥F` | Favorite | in More |
  | `F8` / `⌥C` | Categorize | in More |
  | `F9` / `⌥S` | Create shortcut | in More |

  **The Option aliases don't move at all** — `⌥V`, `⌥D`, `⌥M`, `⌥R`, `⌥H`,
  `⌥F`, `⌥C`, `⌥S` are exactly as they were, so anyone using those sees no
  change.

- **`F5` / `⌥R` Refresh is back in the first tier**, on the number it has in
  every browser and file manager. `F3` for Details echoes `F3` = *view* from
  the Norton/Midnight Commander lineage.

- `F1` is now deliberately left unassigned: it means *help* nearly everywhere,
  and assigning it to something else would be a mistake worth avoiding.

- The More menu holds four actions now that Refresh has moved out of it.

### Fixed

- Every screenshot and GIF in the README has been re-recorded. `demo.gif` still
  showed **v0.4.2** — a footer with `[Hidden]`, `[Category]`, `+ Fav` and
  `* Update`, none of which have existed since 0.5.0.

## [0.6.0] — 2026-08-24

### Added

- **`F9` / `⌥M` — a More menu**, holding the second-tier actions: hide,
  favorite, categorize, create shortcut, and refresh the cache. Each one is
  listed with its own key beside it, so the menu teaches its shortcuts rather
  than replacing them — every action stays directly available from the list.

### Changed

- **The footer now shows only what browsing needs**: `[Views]`, `[Details]`
  and `[More]`. It previously carried seven actions on every launch, six of
  which are things you do while *setting the launcher up* — in bursts, and then
  almost never again.

  The split is by what you're doing, not by how often. Finding something and
  running it is what the launcher is for; organizing and maintenance are not,
  and they were taking six of the seven slots you look at every time.

  Nothing is lost: `F2`, `F4`, `F5`, `F6` and `F7` all still work directly from
  the list, exactly as before.

- As a side effect the footer now fits terminals down to ~60 columns, where
  even the 0.5.5 responsive layout had to start dropping actions.

## [0.5.5] — 2026-08-24

### Changed

- **Two Option aliases now match their labels.** `⌥A` → **`⌥C`** for Categorize
  (the `A` was left over from when F7 was "Add to category") and `⌥P` →
  **`⌥D`** for Details (`P` was fzf's word for the pane, not the launcher's).
  The F-keys are unchanged, so only the aliases move. Every alias is now the
  first letter of what the footer calls it.

- **The footer adapts to the terminal width.** It needs 138 columns, and fzf
  truncates silently — at 100 columns the last two items vanished, at 80
  columns three did, including keys with no other route to discovery.

  It now gives up the cheapest thing first: spacing before any action, the
  Option aliases before the marker legend, and `[Refresh]` last, since it's the
  escape hatch for the cache TTL. At 80 columns five actions fit where
  previously four were cut off mid-word.

### Fixed

- `[Shortcut]` no longer appears in the footer on Linux, where pressing it
  could only print "Shortcuts are only supported on macOS" and pause. One of
  seven footer slots was permanently dead weight there.
- Footer clicks work on the narrow layout, which renders a bare `F4` rather
  than `F4/⌥S`.

## [0.5.4] — 2026-08-24

### Added

- **The details pane now names the categories an entry is filed under.** The
  `#` marker in the list says an entry is categorized but not *where*, which
  previously meant stepping through the **F3** views to find out.

  This one line is looked up live rather than cached, because `F6`/`F7` change
  it constantly and a baked-in answer would be stale the moment it was toggled.
  It sits inside the metadata block, not at the end, so it stays on screen
  without scrolling on formulae with long dependency or caveat sections.

### Changed

- The cache format version is bumped again, so details text written by 0.5.3
  gains the slot the category list goes in. Without it the pane would keep
  rendering, just never showing categories.

## [0.5.3] — 2026-08-24

### Added

- **`F8` / `⌥P` opens a details pane** showing the highlighted tool's homepage,
  license, size, tap, dependencies and caveats — the `brew info` output you
  previously had to quit the launcher to read. It follows the cursor,
  `Shift-Up`/`Shift-Down` scrolls it, and it starts closed.

  The text is generated when the cache is built, from Homebrew JSON that was
  already being fetched, so showing the pane costs a `cat`. Calling `brew info`
  live would have cost ~0.6s on every cursor move.

  The pane sits below the list rather than beside it: at any usable terminal
  width a side pane truncates the footer, hiding half the key hints.

### Changed

- The cache format version is bumped, so the first run after upgrading rebuilds
  once to generate the details text. Without this an existing cache would still
  validate as fresh and the pane would stay empty indefinitely.

## [0.5.2] — 2026-08-24

### Changed

- **Deleting a category now asks first**, and shows how many entries it holds.
  Every other action in the launcher is a toggle you can undo with the same key;
  this one is irreversible, and the v0.5.0 unification moved it into the main
  view picker where it's much easier to reach by accident. Cancel is the default
  and Esc also cancels.

## [0.5.1] — 2026-08-24

### Changed

- **Launches are ~40x faster.** Startup was ~0.55s, and ~0.54s of that was two
  `brew` calls run on *every* launch purely to ask whether anything had been
  installed or removed. That answer is now trusted for 60 seconds, so repeat
  launches take ~0.01s.

  The trade is a window where a just-installed tool isn't listed yet. It's
  bounded to a minute, `F5` forces a refresh immediately, and `--refresh` ignores
  the TTL entirely. Past the window the check runs exactly as before, so a real
  change is still picked up.

## [0.5.0] — 2026-08-24

### Changed

- **Keys have moved.** `F5` is now **Refresh**, matching the convention it has
  almost everywhere else; the view picker moved to `F3`.

  | Key | Was | Now |
  |---|---|---|
  | `F2` / `⌥H` | Hide | Hide **or unhide** |
  | `F3` / `⌥V` | Hidden entries | **Views** |
  | `F5` / `⌥C` → `⌥R` | Category picker | **Refresh** |

  `F4`, `F6` and `F7` are unchanged. The grouping is now legible: `F2`/`F6`/`F7`
  toggle something about the selected entry, `F3` changes what you're looking at,
  `F5` refreshes.

- **Hidden is an ordinary view, not a separate screen.** It appears in the `F3`
  picker alongside All, Favorites and your categories. `Enter` launches in every
  view now, and `F2` unhides — where previously the hidden screen was the one
  place a familiar key meant something different. Removes ~100 lines that
  duplicated the main list renderer.

- Footer legend now reads `+ Favorited  # Categorized  * Outdated`. "Update"
  read as a verb in a footer where every other item is an action, implying the
  launcher would update something — it never does. The `#` marker was also
  shown in the list but never explained. The legend moved to the first footer
  line, which had room; the two lines are now balanced (114 / 118 columns
  instead of 65 / 141).
- `All` and `Hidden` are reserved view names. Creating a category with
  either name is refused, and a hand-made file with those names is skipped
  rather than listed twice — previously it would appear as a duplicate row,
  be shadowed by the built-in view, and be undeletable.

### Added

- **`F5` / `⌥R` refreshes the cache without leaving the launcher** — previously
  this meant quitting and running `--refresh` from the shell.

## [0.4.2] — 2026-08-24

### Fixed

- Cursor no longer jumps to the top of the list after favoriting (F6) or
  categorizing (F7) an entry. `build_entries()` read the cache into *global*
  `command`/`formula` variables — the same names the launcher loop uses for the
  selected entry — so finishing the read loop blanked them and the saved cursor
  position was silently an empty string. The loop variables are now `local`.

## [0.4.1] — 2026-08-24

### Fixed

- **The alphabetically-last tool never appeared in the launcher.** The cache was
  written without a trailing newline, and shell `while read` loops do not
  process a final line lacking a newline terminator, so the last entry was
  dropped everywhere — the picker, `--list`, and the hidden-entries screen — with
  no error of any kind.
- Added a cache format version, checked during validation. Without it the fix
  above would never have reached anyone whose existing cache still validated as
  fresh.
- Category edits no longer create their temp file inside the categories
  directory, where an interrupted edit left a phantom selectable category behind.
- Category names typed via F7 are validated: `/` previously failed silently with
  no feedback, and `..` escaped the categories directory.
- `rebuild_cache` no longer leaks three of its four temp files on one
  early-return path.
- The footer click file is PID-suffixed so two launchers running side by side
  can't consume each other's clicks.

### Added

- `test/cache-roundtrip.sh` — a real behavior test covering the cache write/read
  round trip, verified to fail on the pre-fix code. CI previously ran `zsh -n`
  only and could not have caught this class of bug.

## [0.4.0] — 2026-08-24

### Added

- **Categories.** Group tools into named categories and jump between filtered
  views with **F5**. `Ctrl-D` in the picker deletes a category.
- **Favorites.** **F6** toggles instantly, with no prompt.
- **F7 / Categorize** — instant toggle while viewing a category, or a
  type-or-pick prompt otherwise. Never touches Favorites; F6 owns that.
- Row markers: `+` favorited, `#` in some category, `*` update available.
- **Mouse support.** Click a row to select, double-click to launch. Footer items
  in `[brackets]` are clickable and mirror their keyboard shortcut.
- `Esc` now steps back one level at a time: filtered view → picker → all → quit.

## [0.3.0] — 2026-08-23

### Added

- `--list` — tab-separated plain-text output for scripting and shell completion.
- Option-key aliases (⌥H / ⌥V / ⌥S) alongside the F-keys, since F-keys require
  Fn on most Mac laptops.
- The version is shown in the border label.
- CI: `zsh -n` syntax check on every push and pull request.

### Changed

- The update indicator moved onto the version itself (`1.4.7*`). It was
  previously an `↑`, which collided in meaning with the footer's own
  `↑ ↓ Navigate` hint.

### Fixed

- The outdated-package check refreshes on its own schedule instead of only when
  installed formulae change, so it can no longer go stale for days.
- Hiding and restoring entries no longer flickers back to the shell.
- Argument validation: unrecognized flags now error instead of being ignored.
- Shortcut creation (F4) is correctly gated to macOS.
- Duplicate command names across formulae are reported instead of silently dropped.

## [0.2.1] — 2026-08-23

### Added

- Automated release pipeline — pushing a tag updates the Homebrew tap formula
  (downloads the tarball, computes its checksum, commits) with no manual steps.

### Fixed

- The Automator launcher opened in the current Ghostty tab instead of a new one,
  so launching it from an existing session typed into whatever you were doing.

## [0.2.0] — 2026-08-22

### Added

- Hide and restore entries (**F2** / **F3**), stored in a plain ignore file.
- macOS `.command` shortcut creation (**F4**).
- Configurable terminal backend via `BREW_LAUNCHER_TERMINAL`, with Linux support
  through the current-terminal backend.

## [0.1.2] — 2026-08-22

### Added

- Version, size, and outdated indicator in the list.
- Formula name shown as the primary name, with the command in parentheses when
  they differ.

## [0.1.1] — 2026-08-22

### Added

- Launch selected applications in a new Ghostty tab on macOS.

## [0.1.0] — 2026-08-22

Initial release — fzf-based picker over installed Homebrew CLI applications.

[0.14.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.14.0
[0.13.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.13.0
[0.12.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.12.0
[0.11.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.11.0
[0.10.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.10.0
[0.9.2]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.9.2
[0.9.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.9.1
[0.9.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.9.0
[0.8.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.8.1
[0.8.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.8.0
[0.7.2]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.7.2
[0.7.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.7.1
[0.7.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.7.0
[0.6.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.6.0
[0.5.5]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.5.5
[0.5.4]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.5.4
[0.5.3]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.5.3
[0.5.2]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.5.2
[0.5.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.5.1
[0.5.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.5.0
[0.4.2]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.4.2
[0.4.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.4.1
[0.4.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.4.0
[0.3.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.3.0
[0.2.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.2.1
[0.2.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.2.0
[0.1.2]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.1.2
[0.1.1]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.1.1
[0.1.0]: https://github.com/ltdan-88/brew-launcher/releases/tag/v0.1.0
