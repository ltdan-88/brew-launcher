# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
