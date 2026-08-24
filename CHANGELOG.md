# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
