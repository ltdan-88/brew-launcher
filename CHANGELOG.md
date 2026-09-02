# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.69.0] — 2026-09-02

### Changed

- **Right-click now shows the same live "N marked" footer feedback as
  Tab/Shift-Tab.** Right-click already marked a row on its own (fzf's own
  default behavior whenever multi-select is on), but it was completely
  undocumented until a user found it themselves — nothing on screen ever
  prompted anyone to try it. That makes the instant feedback more
  important here than for Tab, not less: a text hint added to an
  already-packed footer wouldn't reach someone who never went looking for
  one, but reacting the moment they actually try right-clicking will.

## [0.68.0] — 2026-09-02

### Changed

- **Marking a row now updates the footer immediately, the instant Tab is
  pressed — how many are marked, and that Enter now launches them together**
  — instead of giving no feedback beyond the small marker dot until an
  action was actually taken. Raised live: someone marking a row out of
  curiosity had no way to discover what happens next without already
  knowing to check F4. Updates live inside the still-open list, via fzf's
  own `transform-footer` hooked onto Tab/Shift-Tab, using fzf's own
  selection-count tracking — no lag, confirmed with a real fzf session.

## [0.67.0] — 2026-09-02

### Changed

- **The F2 view picker now leads with Most Used, Recently Launched, and
  Recently Added, ahead of Favorites and your categories** (Hidden still
  lands last). Typing still jumps straight to any view regardless of
  position, so this mainly helps browsing or arrowing down: your own recent
  activity is usually a faster memory jog than which category you filed
  something under a while back, and the three computed views need no setup
  at all, unlike Favorites or a category.

## [0.66.0] — 2026-09-02

### Changed

- **Detaching from an ad-hoc Tab-and-Enter launch (mark rows on the main
  list, no saved preset involved) now closes its Ghostty window and ends the
  session, instead of relaunching a second picker there.** A saved preset
  keeps relaunching the picker into its new window on detach — that's the
  deliberate payoff for detaching rather than quitting, since the session
  stays reattachable later via F9. A one-off launch has no F9 entry to come
  back to, so the same relaunch just left its session running invisibly in
  the background with no way back to it, plus a second live picker in the
  new window — exactly the redundant-instance clutter already fixed for
  single-tool Ghostty launches. Detaching now behaves the same way quitting
  a single tool already does: the window closes, nothing lingers.

## [0.65.0] — 2026-09-02

### Fixed

- **The v0.64.0 fix for the wrong-Ghostty-window bug below didn't actually fix
  it** — a short pause was the wrong remedy for the wrong diagnosis. Reading
  Ghostty's own scripting dictionary source directly (`macos/Ghostty.sdef` in
  its GitHub repo) settled it: a Ghostty `window` never has a "focused
  terminal" property at all — only a `tab` does. The line asking a freshly
  created window for its "focused terminal" was never a real, window-scoped
  lookup; it was quietly resolving through some undefined fallback the whole
  time, no delay could have fixed that. The real fix goes through the
  window's own "selected tab" first (a brand new window always has exactly
  one, so this is never ambiguous) before asking that tab — which genuinely
  has "focused terminal" — for its terminal. Applied to both the ad-hoc
  multi-launch path and the regular single-tool Ghostty launch path.

## [0.64.0] — 2026-09-02

### Fixed

- **Marking several tools and launching them together could open a genuinely
  new, empty Ghostty window with a bare shell, while the actual session ended
  up attached in a tab on the already-open launcher window instead.** Not a
  caught failure — the fallback path never ran, and no forced-tabbing system
  preference was in play either. The real cause: right after Ghostty is asked
  to create a window, asking it for its "focused terminal" isn't guaranteed to
  mean the window just created — without a beat for window-server focus to
  catch up, it can resolve to whichever terminal already held focus, so the
  command meant for the new window landed in the old one instead. A tool
  launched on its own into a fresh Ghostty tab could hit the same silent
  race, just less noticeably. Both paths now give a newly created
  window/tab a short pause before asking it for its focused terminal.

## [0.63.0] — 2026-09-02

### Changed

- **A tool opened in its own Ghostty tab or tmux window now closes that
  tab/window on quit, instead of falling back to a plain shell.** v0.62.0
  fixed the redundant-live-launcher problem by dropping to a plain shell, but
  that meant the tab stayed open needing a manual `exit` — not what the very
  original version of this feature actually did before a one-shot CLI's fast
  exit turned out to close the tab before there was any chance to read its
  output. The real fix keeps that original closing behavior (confirmed live:
  tmux closes a window on its own once nothing's left running in it; Ghostty
  the same way, since it can't be told to close a tab directly) and keeps the
  keypress pause too, so a fast command's output survives on screen until a
  key is pressed and a long-running TUI's tab closes cleanly the moment you
  quit it — matching what quitting a tool this way did years ago, without
  reintroducing the bug that pause was originally added to fix.

## [0.62.0] — 2026-09-02

### Fixed

- **Quitting a tool opened in its own Ghostty tab or tmux window no longer
  leaves a second, fully live launcher behind.** Both paths open a disposable
  surface for one tool while the launcher you invoked it from keeps running,
  untouched, in whichever tab or window you started from. Since v0.34.0,
  quitting there relaunched the picker anyway — reasonable in isolation, but
  it meant every tool opened this way left a redundant standing instance:
  launch and quit a few tools and you'd end up with several extra live
  launchers in tabs nobody was using, on top of the one already running where
  you started. Both paths now drop to a plain shell instead, matching the
  behavior from before v0.34.0. `current` terminal mode is unchanged —
  relaunching there stays correct, since it's the only way back to the picker
  at all once the tool exits.
  - tmux closes the window on its own once its one pane's process exits with
    nothing keeping it alive; no explicit close needed.
  - Ghostty can't close its own tab — checked live, its AppleScript
    dictionary has no `close` command and Accessibility-based control doesn't
    see its windows either — so a plain shell is the closest fix available
    for that path.
  - Neither path pauses for a keypress before dropping to the shell any
    more: that pause existed to hold a one-shot CLI's output on screen before
    the picker's own alternate-screen redraw would paint over it, and nothing
    here takes over the screen the way the picker did.

## [0.61.0] — 2026-09-02

### Changed

- **Every entry-scoped action is now explicit about the marked set.** Marking
  landed in 0.59.0, but only Hide, Favorite, Categorize and Enter honored it —
  Update, Create Shortcut, Launch Flags and Run With Args silently acted on
  the highlighted row while marks sat visibly on screen, which reads as a bug
  even though each half was individually reasonable.
  - **Update** upgrades every marked formula that's actually outdated, in a
    single `brew upgrade` run rather than one terminal handover per tool.
    Already-current marked tools are filtered out; if none of them have
    updates, it says so and runs nothing.
  - **Create Shortcut** makes one shortcut per marked entry.
  - **Launch Flags** and **Run With Args** still act on one tool — both store
    or take a single typed value, which has no coherent meaning across several
    — but now say so in their header when more than one row is marked, instead
    of ignoring the marks without comment.

## [0.60.0] — 2026-09-01

### Added

- **Launch History (Actions → Launch History)** — shows what's been recorded,
  each tool and how many times it was launched, highest first, and can clear
  the whole record (`Ctrl-D`, confirmed first). Every launch has always been
  appended to `~/.config/brew-launcher/launch-history`, and Most Used and
  Recently Launched are tallied from it, but there was no way to see or clear
  that record from inside the app — deleting the file by hand was the only
  option, which made both of those views effectively unmanageable. The Actions
  row shows the total before it's opened. Clearing reloads the tally and
  rebuilds the list immediately, so neither view is left showing counts from a
  file that no longer exists.

## [0.59.0] — 2026-09-01

### Added

- **Tab marks rows on the main list, and every action acts on the marked
  set** — falling back to the highlighted row when nothing is marked. Hiding,
  favoriting or categorizing several tools is now the same key as doing one,
  just with marks set first. A marked batch goes one direction rather than
  toggling each entry independently, so a mixed batch ends up all the same way
  instead of some on and some off. Marks show as `●`, the footer advertises
  `Tab  Mark`, and fzf's own info line shows the count.
- **Enter with several marked launches them all together**, one per tmux pane
  — a preset without having to name and save one. Runs through the exact same
  pane-building, layout and Launch Flags machinery `--preset` already uses
  (commands handed in directly instead of read from a file), so it inherits
  that behavior wholesale, including reattaching rather than duplicating when
  the same set is launched again. Needs tmux, and says so in its own terms if
  it's missing.
- **Create Preset is seeded by whatever's marked**, arriving pre-numbered in
  the order it was marked. Its own ordered picker stays — a preset's launch
  order matters and marks carry no order — so marking gets the right tools in
  front of you and that screen is still where the order is decided.

### Removed

- **Hide Multiple / Favorite Multiple / Categorize Multiple** as separate
  Actions rows. Each used to open its own near-identical Tab-to-mark screen;
  all three are now just their single-entry counterpart acting on marks. This
  took the Actions menu from 15 rows to 12 and deleted the shared picker
  behind them outright.

## [0.58.0] — 2026-09-01

### Added

- **Ascending/descending sort direction, both for Name and Size** — Actions →
  Settings → Sort now cycles Name ↑ → Name ↓ → Size ↑ → Size ↓ and back,
  instead of a plain two-way Name/Size toggle. Clicking the NAME or SIZE
  column header picks that column directly, and clicking the same one again
  reverses direction — spreadsheet-style, rather than a blind toggle
  regardless of which column is clicked. The active column/direction shows
  as a small ↑/↓ right on its own header label, doubling as a hint that the
  header is clickable at all.
- **Custom theme discoverability** — `THEME=custom` (config-file only, no
  in-app picker row) is now mentioned in both the Theme screen's own header
  and the Settings row's own preview text, so browsing themes in-app
  surfaces that the option exists instead of it being README-only knowledge.

### Changed

- **F1 Help is now a topic menu** instead of one long scrolling list — Keys,
  Actions Menu, Settings Reference, and Mouse & Good to Know, each its own
  short screen. The single-list version had grown past 100 rows as features
  accumulated; this is the same "one level down, its own screen"
  restructuring Settings itself already went through for the same reason.
  Esc from a topic returns to the topic menu; Esc from there returns
  wherever F1 was opened from, same as before the split.

## [0.57.0] — 2026-09-01

### Added

- **Click the NAME or SIZE column header to sort by it** — the same
  alphabetical/largest-first toggle Actions → Settings → Sort already offers,
  now reachable directly from the main list without opening a menu. Clicking
  NAME picks name order, clicking SIZE picks size order — not a blind toggle,
  since the two clickable targets already say which answer you want. Compact
  View's header has no SIZE column to click at all, so it only ever responds
  to NAME there. Uses the same self-invoking-subprocess side-channel pattern
  as the existing footer clicks, but does its own column arithmetic against
  the rendered header string rather than relying on fzf's own word detection
  — that detection turns out to stop splitting on whitespace once
  `--delimiter` is set to something else, which the list already needs for
  its own real/display split.

## [0.56.0] — 2026-09-01

### Added

- **Custom color themes (`THEME=custom`)** — an 11th theme value alongside
  the ten built-in palettes, reading its actual colors from a new
  `CUSTOM_COLORS=` config-file line instead of a hardcoded one. Config-file
  only: there's no `BREW_LAUNCHER_CUSTOM_COLORS` env var, and it isn't
  offered as a row in Settings → Themes, since there's no fixed palette to
  show a description for. The value is fzf's own comma-separated `--color`
  format, the same 15 keys every built-in theme already sets — a
  copy-pasteable template (catppuccin's own string) is in the README.
  `THEME=custom` with no `CUSTOM_COLORS` line fails fast, matching the
  existing unrecognized-theme-name convention, rather than silently falling
  back to some default for a palette that's supposed to be yours.

### Changed

- **F1/Help now leads the footer** instead of trailing it, reading first the
  same way it numbers first. It used to sit last on the theory that F1
  meaning help is close to universal knowledge and cheapest to lose if a
  narrow terminal truncates the footer string — that protection turned out
  to be accidental rather than a real priority system (the footer has
  always been one plain string, truncated from wherever fzf runs out of
  room), so moving Help first just shifts that same truncation risk onto
  Presets instead.

## [0.55.0] — 2026-09-01

### Added

- **Update the highlighted entry (Actions → Update)** — Update All's own
  per-entry sibling: `brew upgrade` for just that one formula, through
  the same self-deleting-wrapper/three-way launch-path trick. No
  confirmation prompt — scoped to one formula rather than everything
  outdated, it's a smaller, quicker action, instant like Hide/Favorite
  rather than something worth pausing on. Shows the new version in its
  own row when one's actually available (the same `outdated_formulas`
  data the `*` marker and F3 details pane already read), and already
  up to date just says so and does nothing.

## [0.54.1] — 2026-08-31

### Added

- **Run With Args now previews the tool's own `--help` output.**
  `F3` / `⌥D` from the Run With Args prompt shows it in a preview
  pane — on demand only, never automatically: this install list is
  full of games and animations (`cmatrix`, `asciiquarium`,
  `moon-buggy`...) that may not recognize `--help` at all and would
  otherwise launch straight into their own full-screen mode the
  moment the prompt opened. A tool like that is killed after a second
  (by hand — no `timeout`/`gtimeout` on stock macOS) rather than left
  running, and just shows "No usage information available" instead.

## [0.54.0] — 2026-08-31

### Added

- **Recently Launched view.** A new computed view, alongside `Most
  Used` and `Recently Added` in the F2 picker — ranks by *when* you
  last launched a tool rather than how many times, so something
  you've only run once, moments ago, outranks something you run
  constantly but haven't opened in weeks. Same 15-tool cap as the
  other two computed views, and the same "can't be renamed or
  deleted" treatment.
- **Run With Args.** `F4 → Actions → Run With Args` on a highlighted
  entry launches it right now with extra arguments, just this once —
  a one-off, forgotten immediately after, distinct from the standing
  [Launch Flags](README.md#custom-launch-flags) setting. Prefilled
  with the current Launch Flags value, if any, as a convenient
  starting point, but leaving it blank and pressing Enter just runs
  the tool plain — there's nothing stored to clear the way there is
  in Launch Flags. Esc cancels without launching. A run started this
  way still counts toward `Most Used` and `Recently Launched`, like
  any other launch.

## [0.53.1] — 2026-08-31

### Fixed

- **The theme counter showed in the wrong place.** The position-among-ten
  indicator inside the Theme screen itself stays (a different,
  still-useful question — "where is the one I'm on now"); the
  Settings row itself now also shows the total, `Themes (10)`, same
  convention Settings' own row already uses for its own item count.
- **Editing a preset could silently break its own numbering.** Two
  real causes: a preset member you'd since hidden (F6) — still installed, just excluded from
  "All" the normal way — was excluded from the edit screen's own tool
  list the same way, even though it's exactly the kind of tool you'd
  hide precisely because you only run it via a preset. Fixed by
  clearing the hidden set for that one build. A genuinely uninstalled
  member has no row to show at all — now dropped with a one-line note
  when the editor opens, instead of silently occupying an invisible,
  unselectable slot in the badge sequence. Also fixed a related edge
  case caught while testing this: if every member turned out to be
  stale, the seeded state file ended up with one phantom blank-line
  entry instead of genuinely empty, which would have reproduced the
  exact same bug for a different reason.

### Changed

- **Compact View now also hides the `+`/`#`/`*` markers**, not just
  the version/size columns. The footer's legend explaining those
  markers is suppressed too, since there's nothing left to explain.

## [0.53.0] — 2026-08-31

### Added

- **Custom launch flags (Actions → Launch Flags)** — extra arguments
  to always pass a command whenever it launches, stored per command
  name, so it applies wherever that command actually launches — the
  main list's own Enter, and any
  preset it's a member of — from one config, not two. Prefilled with
  the current flags for editing; the Actions row shows them too, so
  there's no need to open the prompt just to check. Blank + Enter is
  a real "clear the flags" answer, correctly distinguished from Esc
  (the one prompt here where an empty result isn't automatically a
  Cancel).
- **Compact View (Actions → Settings → Compact View)** — a toggle for
  the main list's own VERSION/SIZE columns. Off (default) shows every
  column, as before; on drops VERSION/SIZE entirely, leaving just the marker, name, and
  description. Applies everywhere a row shows up, not only the main
  list.

### Fixed

- `preset-fixtures.sh`'s real-tmux-session tests could hang for
  real (confirmed live, once, for about two minutes) on a machine
  with Ghostty.app installed: `run_preset()` calls
  `preset_show_session()` once a session's panes are built (not just
  on a reattach), which without `SSH_TTY` set attempts real Ghostty
  AppleScript automation — apparently blocking on a permission
  negotiation nothing in a non-interactive test run can answer, rather
  than failing fast. Every real session-building invocation in that
  test now forces the SSH-simulated branch instead, same technique
  the test's own step 8 already used for exactly this reason.

## [0.52.0] — 2026-08-31

### Added

- **Update All (Actions → Update All)** runs `brew upgrade` for
  everything outdated. Runs in a real terminal, through the
  same current-terminal/tmux/Ghostty paths a normal tool launch
  already goes through (via a throwaway self-deleting script, so the
  three existing launch functions needed no changes), so you see its
  actual output rather than a hidden background call. The row shows
  how many formulae are outdated right now — the same count the `*`
  marker and F3 details pane already read — and doesn't offer anything
  to confirm when there's nothing to update. Asks first (Cancel
  listed first, same convention as every other confirm here), since
  this can take a while. Relaunches afterward same as any other
  launch; F5 picks up the new versions right away rather than waiting
  on the next automatic check.

## [0.51.0] — 2026-08-31

### Added

- **Ctrl-E on a highlighted preset (F9) rearranges it.** Before this,
  the only way to change a preset's order was Create Preset again with the
  same name, which always started blank — every tool had to be
  re-marked from scratch just to reorder. Ctrl-E opens the same
  Tab-to-mark screen Create Preset uses, but seeded with the preset's
  current members already badged in their current order: Tab still
  marks/unmarks, and unmarking then remarking a tool moves it to the
  end, so reordering means doing that to whichever tools need to move.
  Tools can be added or dropped there too, not just reordered. Saves
  straight back to the same preset, no naming step. Builds its own
  tool list from the full toolset regardless of whatever view is
  active, unlike Create Preset — editing needs to see everything
  already in the preset, not just what's currently on screen.

## [0.50.1] — 2026-08-31

### Added

- **Three more commands added to the bundled-hidden list**: `musikcubed`
  (musikcube's headless daemon, not meant to launch on its own), `vd`
  (visidata's own alias for its main binary — `visidata` already covers
  it, so having both showed the same tool twice), and `vd2to3.vdx`
  (visidata's one-shot file-conversion script, not an interactive
  tool). Confirmed by inspecting what these formulas actually install:
  a formula that ships
  more than one binary gets a row per binary by design (so linecast's 6
  view-shortcut binaries stay visible, each a genuinely different
  thing), but these three were auxiliary/duplicate, not genuinely
  separate tools, the same reasoning already covering `age-inspect` and
  `calcurse-caldav`/`-upgrade`/`-vdir`.

## [0.50.0] — 2026-08-31

### Changed

- **Refresh (F5) moved out of the main footer into Actions.**
  F5 / ⌥R still work as a direct keypress everywhere they always did —
  the main list and the view picker (F2) — same as F6/F7/F8, which
  are also listed in Actions despite having their own key. Only the
  permanent footer slot and the two now-unreachable click-word
  mappings are gone. Actions' Refresh row isn't gated on there being a
  highlighted entry, so it shows up from the view picker's own Actions
  too (alongside Settings and Backup).

### Added

- **Details Position (Actions → Settings → Details Position)** — a new
  toggle switching whether the details/preview pane opens above or
  below the list (`Top` / `Bottom`, default `Bottom`). Applies
  everywhere a details/preview pane shows up: the main list, F2, F9, and
  Actions/Settings' own always-on panes.

## [0.49.0] — 2026-08-31

### Added

- **The Theme screen (Actions → Settings → Theme) now shows where the
  current theme sits among all ten**, e.g. `Current: dracula  (5 of
  10)` — with ten to scroll through and nothing marking your place,
  there was no way to tell how many more there were below the fold.
- **The preset preview (F9's details pane) now numbers each entry**,
  e.g. `1. newsboat`, `2. weather`, instead of relying on position
  alone to show launch order.

### Fixed

- A few in-app and README references to Create Preset and Theme still
  said `F4 → Create Preset` / `F4 → Theme`, from before both moved a
  level down (Create Preset into Actions, Theme into Settings). Updated
  to the current paths (`F4 → Actions → Create Preset` /
  `F4 → Actions → Settings → Theme`).

## [0.48.0] — 2026-08-29

### Changed

- **The cache-writer moved out of `bin/brew-launcher` into a real
  standalone file, `lib/brew-launcher/cache_writer.py`.** It used to
  be a ~600-line python3 heredoc embedded inside `rebuild_cache()` —
  now it's an ordinary Python file with real syntax highlighting,
  `py_compile` in CI, and no ordering entanglement with the zsh code
  around it. No behavior change: same eight positional arguments, same
  output. `bin/brew-launcher` itself is ~600 lines smaller as a
  result. Homebrew installs now also ship `lib/brew-launcher/`
  alongside `bin/brew-launcher`; the tap formula's `install` block was
  updated separately to match, defensively (works against both old and
  new release tarball layouts).
- This was a scoped-down alternative to a full module split of the
  ~7,300-line script, considered and declined for now — no concrete
  pain point justified the risk of restructuring the file's top-level
  dispatch order, which is where two real past bugs (v0.4.2, v0.27.0)
  have lived. The cache-writer was the one piece that was both large
  (~8% of the file) and already fully self-contained, so it came out
  on its own with none of that risk.

## [0.47.0] — 2026-08-29

### Security

- **A formula description containing an embedded tab or newline could
  corrupt the cache's tab-separated row format.** A formula's
  description is free text a tap maintainer controls, not constrained
  by Homebrew's own name-safety rules — an embedded tab would shift
  every field after it one column over, and an embedded newline would
  end that row early and start a bogus new one out of whatever text
  followed. Found while writing a security regression test, not from a
  live report. Fixed by collapsing embedded tabs/newlines in the
  description to spaces during cache rebuild.

### Added

- **`test/security-fixtures.sh`**, a new regression suite for
  properties [SECURITY.md](SECURITY.md) claims: the cache-format fix
  above, confirmation that a config file with shell-metacharacter
  values is never executed (only ever parsed as plain KEY=value data)
  and that a malformed value is cleanly rejected, that every `mktemp`
  call in the script uses a randomized template, that all four places
  a typed name becomes a filename reject path traversal, and that
  launching still prefers the cache's resolved executable path over a
  fresh `PATH` lookup.

## [0.46.0] — 2026-08-29

### Added

- **`brew-launcher --diagnose`**, a new CLI command for checking the
  install: required/optional dependencies (with resolved paths),
  which terminal backend `auto` actually resolves to on this machine,
  and whether the config/cache directories exist, are writable, and
  are in the expected shape (cache format version, freshness against
  the TTL, entry/category/preset counts). Handled before the normal
  "brew/fzf/python3 required" startup check, like `--help`, so it
  still runs — and explains what's missing — when one of those isn't
  installed. Exits non-zero only if a real problem was found.
- **[SECURITY.md](SECURITY.md)**, a security policy: scope, how to
  report a vulnerability (GitHub private security advisories
  preferred), and a short list of hardening choices already in the
  script (inert config parsing, `mktemp`+traps for temp files,
  path-traversal validation on category/preset names, resolved-path
  caching for launched executables).

## [0.45.2] — 2026-08-28

### Fixed

- **Hide/Favorite/Categorize Multiple showed 0 entries from the view
  picker, making them unusable there.** Hide Multiple/Favorite Multiple/
  Categorize Multiple/Create Preset all pick tools from `$entries` —
  whatever's currently on screen — but the view picker (F2) has no
  such list of its own (it lists categories, not tools), so those rows
  had nothing real to draw from there.
  All four rows now only appear in Actions when it's opened with an
  actual highlighted entry (i.e. not from the view picker) — Settings
  and Backup are the only rows left there, since neither needs one.

### Changed

- **Create Preset now builds from whatever view is actually on
  screen**, not always the full `All` list. Browsing a category and pressing
  Create Preset now offers only that category's own tools, matching
  how the bulk actions already worked.

## [0.45.1] — 2026-08-28

### Fixed

- **Cancelling out of bulk categorize opened the "new or existing"
  naming prompt anyway, instead of actually cancelling.** Root cause: a
  genuine zsh quirk — `selected=("${(@f)$(cmd)}")` where `cmd` prints
  nothing (Esc pressed) produces a one-element array holding a single
  empty string, not a zero-element one, so the "was anything actually
  selected?" check was never true after Esc. bulk_hide()/
  bulk_favorite() happened to silently no-op anyway (their per-line
  loop skips the one empty line), but bulk_categorize() fell all the
  way through to prompting for a category name regardless. Fixed by
  capturing the raw fzf output first and only splitting it into an
  array when it's actually non-empty.

### Added

- **A Quit/Cancel confirm before Esc actually exits.** Esc on `All` (the one screen
  with nowhere further back to go) now opens a confirm — Cancel listed
  first, and Esc there means Cancel too, so a second stray Esc lands
  back on the list rather than compounding the first one.

## [0.45.0] — 2026-08-28

### Added

- **Bulk Hide, Favorite, and Categorize.** New Actions rows —
  **Hide Multiple**, **Favorite Multiple**,
  **Categorize Multiple** — each open a Tab-to-mark picker over
  whatever's currently on screen and act on every marked entry at
  once (or just the highlighted one, if nothing was marked). Unlike
  Create Preset's own picker, this uses fzf's plain built-in
  multi-select rather than the custom ordered-badge mechanism —
  launch order doesn't apply here, only membership does, so it needed
  far less machinery. A marked batch always moves to one end state
  (hidden / favorited / in the category) rather than toggling each
  entry individually based on its own prior state, which would be a
  confusing surprise for a batch you just selected together. Hide
  Multiple/Favorite Multiple relabel to their inverse while viewing
  Hidden/Favorites, same as F6's own per-entry label; Categorize
  Multiple prompts for a category once for the whole batch, or —
  while already viewing a real category — removes the marked batch
  from it instantly, same as F8's own instant per-entry toggle there.
- **A separate Settings screen.** Every standing preference (Theme,
  Default Categories, Default Hidden, Open to Categories, Sort,
  Details, Alt Keybinds) moved out of Actions into a new **Settings**
  screen, reached via a single Actions row — the same one-level-down
  pattern Theme or Create Preset already used. Actions now holds only
  one-shot actions; Settings has its own always-on details pane too.

## [0.44.1] — 2026-08-28

### Fixed

- **The footer went missing when launching straight into the view
  screen (Open to Categories on).** Actions → Open to Categories runs `pick_view()` once at
  startup, before the main loop — and `pick_view()` calls
  `build_picker_footer()`, which was defined hundreds of lines later
  in the script. zsh doesn't hoist function definitions, so that call
  silently failed ("command not found") and the footer variable came
  back empty. Investigating further turned up the same bug reaching
  several other Actions rows from that same startup screen (Create
  Preset, Backup, every settings toggle) — all called functions that
  weren't defined yet either. Fixed generally rather than one function
  at a time: the Open to Categories startup trigger now runs just
  before the main loop, after every function in the script has been
  defined. Confirmed live (a real tmux session, the previously-
  released binary) reproducing the exact blank-footer symptom, then
  confirming the fix. New `function-order-fixtures`
  test statically checks that no top-level codepath can reach a
  not-yet-defined function, so this class of bug can't come back
  unnoticed as new Actions rows get added later.

## [0.44.0] — 2026-08-28

### Changed

- **Reorganized the Actions menu (F4).** Four related changes in one
  batch:
  - Launch Preset removed from the menu — F9
    already runs it directly and sits in the footer on every screen
    Actions is reachable from.
  - Create Preset and Create Shortcut moved right after Categorize —
    closer in spirit to Hide/Favorite/Categorize than to a settings toggle.
  - Theme through Alt Keybinds now form one contiguous settings
    cluster, with Backup as the closing action.
  - F9's own preview pane is no longer gated behind
    F3/`DETAILS_VISIBLE` — it's simply always shown, same as F4's own
    pane, since a preset list is usually short and the point of
    glancing at one is seeing what's in it before launching. F3 is no
    longer offered in the F9 picker; it still works everywhere else
    (main list, F2).

## [0.43.0] — 2026-08-27

### Fixed

- **Renaming a category or preset to a name that still fuzzy-matches
  the old one silently did nothing** — e.g. renaming "Weathers" to
  "Weather." Root cause: `rename_category()`/
  `rename_preset()` read the typed name from fzf's `--print-query`
  output via `tail -n1`, but that output is *[typed query, then the
  matched row]* — and the picker's only row is the old name itself, so
  almost any edit that keeps a prefix of it (dropping the trailing
  "s", for instance) still matches that row, and `tail -n1` grabbed
  the stale match instead of what was typed. Reads `head -n1` now.
  Confirmed live with the exact reported case before and after.

### Added

- **A footer toggle: Fn keys only, or Fn plus their ⌥ alternatives.**
  The footer was inconsistent about this — All showed both, but F2
  (view picker) and F9 (presets) never did. Before this, whether a ⌥
  alias showed was decided purely by
  whether it happened to fit the terminal width — never a real choice,
  and F2/F9's own footer never even tried to show one. New **Actions →
  Alt Keybinds** (on by default): on tries to show each action's ⌥
  alias wherever it fits, same as before; off never shows one, on the
  main list, F2, or F9 alike. The F-keys themselves always work either
  way — this only changes what the footer prints.
- **A details pane in the Actions menu (F4), on by default**,
  describing what each toggle means. Unlike the shared Details
  toggle elsewhere (off by default, something you turn on), there's
  nothing to have deliberately hidden here yet — the whole point is
  explaining rows whose one-line label doesn't say what they actually
  do (Default Categories, Default Hidden, Sort, Alt Keybinds, and so
  on), so it just always shows.

## [0.42.3] — 2026-08-27

### Fixed

- **F3's category preview now respects Default Categories being off,
  and doesn't double-claim a manually-filed command.** A category
  showing a count of 0 could still list its bundled-default tools in
  the F3 preview — not actually a bug in the count itself: those were
  bundled defaults for a category Default Categories had been turned
  off for (Actions → Default Categories), and the preview, which had
  no idea that setting existed, still resurrected them. The preview's bundled-category scan now checks
  `CONFIG_DEFAULT_CATEGORIES` the same way `load_bundled_categories()`
  itself does, and additionally skips a command already filed by hand
  into some *other* real category, matching that function's
  `manually_categorized_commands` check too — otherwise a tool could
  appear to belong to two categories at once in the preview alone.
- **The F2/F9 pickers' own footer is now width-aware, same as the main
  list's.** Both had grown a static single-line
  footer past what fzf could safely render — F2 alone reached 6
  actions past nav/search, and confirmed live that even the tightest
  single-line rendering doesn't fit below roughly 95 columns, so fzf
  was truncating it mid-word. New `build_picker_footer()` mirrors
  `build_footer()`/`footer_actions()`'s own progressive-degradation
  idea: full gap, tighter gap, and — new, since neither existing rung
  was always enough here — wrapping the actions across two lines
  before ever letting fzf cut one off mid-word.

## [0.42.2] — 2026-08-27

### Fixed

- **Esc no longer undoes a Details choice made via Actions.**
  Turning Details on from F4 → Actions was meant as a
  standing "always on" choice (0.41.0), but the main list's own
  Esc-closes-the-pane-first behavior (0.31.0) couldn't tell that
  apart from a pane opened with a quick F3 press — so the very next
  Esc silently undid the choice. New `DETAILS_PINNED` flag tracks
  which of the two just turned the pane on: Actions → Details sets it
  to match the new state (a standing choice), all three F3 handlers
  (main list, F2, F9) always clear it (a peek). Esc's auto-close, and
  the `[Close]` footer hint that promises it, now only fire when
  `DETAILS_PINNED` is false — a pinned pane skips straight to
  whatever Esc would otherwise do. Verified live in both directions:
  pinned via Actions, one Esc left it alone and the next quit outright
  (nothing else to back out of); opened with F3 directly, one Esc
  still closed it exactly as before.

## [0.42.1] — 2026-08-27

### Fixed

- **F3's category preview (0.41.0) now excludes hidden entries, same
  as the category's own count.** A category with two hidden
  members showed "3" as its count but 5 tools in the preview — both
  numbers were individually correct by their own rules, but visibly
  disagreed with each other. The preview's hidden-status check is
  inlined (IGNORE_FILE, plus bundled-hidden via CACHE_FILE field 11
  unless SHOWN_FILE overrides it) rather than calling
  `load_hidden_commands()`, which isn't defined yet this early —
  same reasoning already documented for not calling it, just now
  actually replicating its combining rule instead of skipping it.
- **The F3/Details toggle is one shared state again, not two.**
  Shipped in 0.41.0 as two separate flags (`DETAILS_VISIBLE` for the
  main list, `PICKER_DETAILS_VISIBLE` for F2/F9) specifically so
  turning one on wouldn't silently turn the other on too — the
  opposite of the intended behavior: once on, it should stay on
  everywhere a details pane is available.
  `PICKER_DETAILS_VISIBLE` is gone; F2 and F9 now toggle and read the
  same `DETAILS_VISIBLE` the main list and Actions → Details already
  do, verified live across all three screens in one session.

## [0.42.0] — 2026-08-27

### Added

- **Uninstalling a favorited or categorized tool no longer leaves it
  behind forever.** Follow-up to the same batch as 0.41.0: a Favorites
  count showing "0" despite two genuine entries in the file read as a
  bug — both had been uninstalled since being favorited, and the
  count already correctly excluded them, but the stale lines just sat
  there forever with nothing to explain the gap. Asked what should
  happen (leave it, show the gap explicitly, or clean it up); answer
  was auto-clean. Since this launcher has no way to hook a live
  uninstall event, the real mechanism is `prune_stale_category_members()`,
  run once per real cache rebuild (`--refresh`, F5, or the periodic
  background one) rather than on every launch — the set of installed
  formulae has to be freshly confirmed for "no longer installed" to
  mean anything. Comments and blank lines in a category file pass
  through untouched; only an actual command line for something no
  longer installed is removed. Presets are deliberately left alone —
  a stale command there already fails gracefully at run time, and
  silently shrinking a saved pane layout felt like a different,
  more surprising kind of change than trimming a list.

## [0.41.0] — 2026-08-27

### Added

- **A "Details" toggle in Actions, mirroring F3.** Same
  `DETAILS_VISIBLE` flag F3 itself already flips, just also reachable
  — and its current state visible — from Actions, for anyone who
  reaches for the menu before remembering the direct key.
- **F9 (Launch Preset) now works from the view picker (F2) too.**
  F4 and F5 already worked there; F9 not doing the same read as an
  inconsistency once someone actually went looking for it.
- **F1/Help is now shown in the footer**, last (lowest priority, first
  dropped on a narrow terminal). It used to be deliberately left off
  everywhere on the theory that F1=help is close to universal
  knowledge — not finding it in practice is direct evidence that
  assumption doesn't hold for everyone.

### Fixed

- **The F3 category preview (0.39.0) now actually shows a bundled-only
  category's tools, instead of explaining why it won't.** Shows the
  union of a category's real file (if any) and every command whose
  cached default_category matches, minus anything explicitly excluded
  — the same membership the real F2 view itself shows when you open
  it. Deliberately doesn't filter out hidden commands the way the real
  view's own count does, on the theory that replicating three
  functions' worth of hidden-status logic here to stay in sync forever
  was a worse trade than an occasional preview slightly wider than
  what F2 lists.
  Caught a second, more fundamental bug while fixing this: the first
  draft read the cache's default_category column via a zsh `read`
  loop with placeholder variables for the fields in between, which
  silently collapses a genuinely empty field (field 6, "outdated")
  together with its neighboring tab and shifts every later field left
  by one — the exact reason `--internal-preview`'s own equivalent
  lookup already used `awk` instead of `read` for this, which the new
  code now does too.

## [0.40.0] — 2026-08-27

### Added

- **Sort by name or size.** The fourth of a batch of ideas, held back
  from the other three to ship on its own once it needed real parsing
  work.
  **F4 → Actions → Sort** toggles between `Name` (the cache's own
  alphabetical order, already free on every view) and `Size` (largest
  first — handy for "what's actually taking up space" without leaving
  for `ncdu`). Sizes are stored as display text (`"1.7MB"`, not a raw
  byte count), so the real work is `size_sort_key()`, parsing that
  back into a comparable number of bytes; `build_entries()` reuses the
  exact zero-padded sort-key mechanism Most Used/Recently Added
  already use, which Sort deliberately leaves alone — both already
  have a more meaningful order of their own. Persisted the same way
  as the other Actions toggles (`SORT=` in the config file); rebuilds
  the visible list immediately on toggle rather than waiting for the
  next incidental refresh, so the reorder is never mistaken for
  nothing having happened.

## [0.39.0] — 2026-08-27

### Added

Three related ideas shipped together.

- **A `*` after brew-launcher's own version, once a newer one is
  installable.** Reuses the exact outdated-formula snapshot that
  already powers the `*` marker on every other row — brew-launcher is
  just another installed formula to that mechanism, so
  `launcher_update_marker()` is a one-line hash lookup, shown on every
  screen's border via `screen_border_label()`. Same freshness caveat
  as every other `*` already has: reflects whatever Homebrew last
  knew locally, not a live check on every launch.
- **F3 details for the F2 (categories) and F9 (presets) pickers.**
  Reuses the exact same preview mechanism the main list's own details
  pane already uses, pointed at a category or preset file's contents
  instead of `brew info` — every command it holds, with its
  description; categories sorted alphabetically, presets kept in
  launch order. A built-in view (All, Hidden, Most Used, Recently
  Added) or a bundled-only category with no real file yet explains
  why there's nothing to preview instead of showing a blank pane.
- **Which presets a command belongs to, in its own F3 details pane.**
  The reverse lookup of the point above — a
  `Presets` line next to the existing `Categories` one, filled in at
  render time from `PRESETS_DIR` the same way `Categories` is filled
  in from `CATEGORIES_DIR`. Omitted when the command isn't in any.

## [0.38.0] — 2026-08-27

### Added

- **Rename categories and presets from the UI.** Both
  are just a named file (`~/.config/brew-launcher/categories/<name>`,
  `~/.config/brew-launcher/presets/<name>`), so renaming either is
  **Ctrl-R** in its picker (F2 for categories, F9 for presets) — type
  a new name over the prefilled current one, same fzf `--print-query`
  idiom `toggle_category()` already uses to accept a typed name — then
  a plain `mv`. Guards against the same things creating one already
  refuses (a name with "/" or a leading ".", one of the built-in view
  names) plus a new one renaming needs but creating never did:
  colliding with a name that already exists. A category that only
  exists via the [bundled defaults](#bundled-defaults), with no real
  file yet, needs one entry categorized into it with F8 first — there
  isn't a clean equivalent to deleting one of those (which just
  excludes every command it contributes) for renaming one. Renaming a
  preset with a session already running under its old name doesn't
  reach into that session — it keeps working under the old name until
  it ends.
- **Backup.** **F4 →
  Actions → Backup** writes `~/brew-launcher-backup.tar.gz` (always
  that path, overwritten every run) containing a Brewfile from `brew
  bundle dump` — every installed formula, cask and tap, including the
  tap this launcher itself comes from — plus a full copy of
  `~/.config/brew-launcher`, since `brew bundle` has no idea this
  launcher exists and can't capture categories, presets, hidden
  entries, favorites, or theme on its own. Restoring is left as a
  documented two-step manual process rather than a launcher action of
  its own — restoring only ever happens once per fresh machine, and
  it's inherently higher-stakes (it can overwrite current config) than
  creating a backup ever is.

## [0.37.1] — 2026-08-27

### Fixed

- **"Create shortcut" → "Create Shortcut"**. Spotted live: every other
  Actions row uses Title Case (Favorite, Categorize, Launch Preset,
  Create Preset, ...) — this was the one holdout, in the menu row
  itself and throughout the F1 help text.

## [0.37.0] — 2026-08-27

### Fixed

- **The 0.36.0 press-any-key pause didn't actually fix `fastfetch`.**
  The pause itself was working — the output
  was gone by the time it appeared. Root cause: fzf's own picker UI
  runs inside the alternate screen too (confirmed live — `--height=100%`
  still opens with a genuine `?1049h`; `--no-clear` only skips fzf's
  own erase-on-exit, it doesn't mean staying off the alternate
  screen). A one-shot CLI that never touches screen modes itself just
  inherits whatever's already active and ends up drawing onto that
  same alternate buffer — which the *after*-command printf (added
  earlier to recover a TUI that crashed mid-alternate-screen) then
  switched away from the instant the command finished, discarding
  output that had nowhere else to go. Confirmed with a real tmux pane
  and `pipe-pane` capturing the raw byte stream: fastfetch's output
  was genuinely being written in full, just onto a buffer that exact
  printf then hid.
- Fixed by also exiting alternate-screen mode *before* the command
  runs, not only after, in all three launch paths (current terminal,
  tmux, Ghostty). A plain one-shot CLI now lands on the real,
  persistent screen from the start; a TUI is still free to enter its
  own alternate screen fresh when it starts, and the existing *after*
  printf still recovers that if it crashes without exiting cleanly.
  Only `launch_in_current_terminal` was actually exposed to this (it
  reuses the picker's own pane) — `launch_in_tmux` and
  `launch_in_ghostty` always open a brand new window/tab that never
  inherited the picker's alternate screen in the first place, so the
  same printf there is a no-op kept for consistency across all three.
- `test/relaunch-fixtures.sh` now reproduces this directly: a real
  tmux pane with alternate-screen mode turned on before
  `launch_in_current_terminal` runs, checked for the command's output
  surviving before any key is sent. Verified this test actually
  catches the bug — reverted the *before* printf, confirmed it failed,
  restored it, confirmed it passed again.

## [0.36.0] — 2026-08-27

### Fixed

- **A one-shot CLI's output (`fastfetch`, `eza`, `jq`, ...) was getting
  wiped before it could be read.** The previous "relaunch the picker
  after a tool exits" fix (0.34.0) fired
  immediately once the command finished, so the picker's full-screen
  UI painted straight over the output. It looked exactly like the
  command had silently failed when it had actually run fine; a
  long-running TUI (`htop`, `newsboat`) wasn't affected the same way
  since you'd already seen everything before choosing to quit it.
  Fixed by pausing with **"Press any key to return to
  brew-launcher..."** right before the relaunch, in all three launch
  paths (current terminal, tmux, Ghostty) — a no-op with no real
  terminal attached (`read` returns immediately on EOF, so tests and
  `--preset` still fail fast rather than hang), and a real wait
  otherwise.
- `test/relaunch-fixtures.sh` now verifies the pause genuinely blocks
  using a real tmux pane rather than a raw Python `pty.fork()`, which
  gave a false failure here — `read -k` never returned even after a
  simulated keystroke, echoed by the pty's own line discipline but
  seemingly never delivered to zsh. Plain `tmux send-keys` against a
  real pane worked on the first try, so that's a gap in what a bare
  `pty.fork()` emulates (the same class of gap already on record in
  this project for fzf hanging on cursor-position queries against
  one), not a bug in `read -k` itself.

## [0.35.0] — 2026-08-27

### Changed

- **Detaching from a preset (or the preset ending) now brings the
  launcher back**, extending the previous "relaunch after quitting a
  tool" fix to presets. All three of `preset_show_session()`'s outcomes now relaunch the
  launcher once the tmux side of things ends, instead of leaving a
  dead pane or a bare shell behind.

### Fixed

- **A real bug this surfaced**: testing with a genuinely attached tmux
  client (not just a headless one) found that the "switch-client"
  path's claim of being recoverable — "the picker's own session is
  still alive, prefix+s switches back to it" — was wrong.
  switch-client's own process exits the instant it's done its job, and
  a pane whose foreground process exits is closed by tmux *by
  default*, so the picker's original pane (and, being the only one,
  its whole session) was actually being destroyed the moment
  switch-client succeeded. Relaunching the launcher in that same pane
  once switch-client returns fixes this properly — verified live with
  a real attached client that the session now survives and has a
  fresh, ready picker waiting once you switch back to it.
- **A second bug found while fixing the first**: chaining the relaunch
  with a bare `;` meant a *failed* attach-session/switch-client (no
  real terminal available — exactly what `--preset` looks like in a
  test or any non-interactive invocation) still ran straight into a
  brand new fzf session against that same broken stdin, hanging
  instead of failing fast. Changed to `&&`, so the relaunch only fires
  after a genuinely successful attach that later ended cleanly; a real
  failure still fails straight through, same as before this whole
  feature existed. `test/preset-fixtures.sh`'s SSH-simulated case now
  runs under an explicit timeout to guard against this exact hang
  coming back — an earlier version of that same test check reported
  PASS even with the bug deliberately reintroduced, because it
  inspected the hung process's children *after* killing its parent,
  by which point they'd already been reparented and were no longer
  visible to that check.

## [0.34.0] — 2026-08-27

### Changed

- **Quitting a launched tool now brings the picker back**, instead of
  always dropping to a plain shell — opening a new tab or window is
  already how you'd get a plain shell if you wanted one, so returning
  to the picker is the more useful default after quitting a TUI.
  All three single-tool launch paths — `current`, `tmux`, and
  Ghostty — now exec into the launcher itself (`$SCRIPT_PATH`) as the
  fallback once a tool exits, rather than a bare `zsh`. Presets are
  unchanged: each pane still falls to a plain shell, since a pane is
  one of several TUIs in a multi-tool session, not "using the
  launcher" the way a single-tool launch is. Desktop shortcuts
  (`.command`/`.desktop` files) are also unchanged, for the same
  reason in reverse — a shortcut is meant for direct access to one
  tool, not a detour through the picker.

  New `test/relaunch-fixtures.sh`: `launch_in_current_terminal()` is
  sourced and actually run (dependency-free — no tmux or Ghostty
  needed) against a fake stand-in launcher, confirming the exec chain
  really does relaunch; the tmux and Ghostty paths are covered as
  source-text assertions, since running those two end to end needs a
  real tmux session and a real Ghostty.app respectively.

## [0.33.0] — 2026-08-27

### Changed

- **`BREW_LAUNCHER_TERMINAL=auto` is now SSH-aware**, so a single-tool
  launch over SSH no longer hangs reaching for a Ghostty GUI window it
  has no display to open in — the same class of problem
  `preset_show_session()` already learned to avoid for presets, now
  the default for individual tools too. `auto` checks the standard
  `SSH_TTY`/`SSH_CONNECTION`/`SSH_CLIENT` trio first: over SSH and
  already inside a tmux session it picks `tmux`; over SSH otherwise,
  `current`. Local behavior (Ghostty on a Mac that has it, `current`
  everywhere else) is unchanged. The detection logic is shared with
  the preset code via a new `is_ssh_session()` helper rather than
  duplicated, and the decision itself is now a standalone
  `resolve_auto_terminal()` function with direct test coverage
  (`test/terminal-auto-fixtures.sh`) — this exact class of "auto
  reaches for a GUI it can't use" bug has now shown up twice, so it
  earns a real regression test rather than only living inline.

## [0.32.0] — 2026-08-27

### Added

- **Launching a preset opens its own window instead of always closing
  the one you launched it from.** A preset holding several TUIs at
  once deserves more than a corner of an existing tab, and a
  follow-up question confirmed the picker really was being replaced
  outright (`exec` never returns), not just backgrounded. New
  `preset_show_session()` picks one of three outcomes:
  - **Local Mac with Ghostty** — opens a genuinely separate Ghostty
    **window** (never a tab) attached to the session. The picker isn't
    touched at all.
  - **Over SSH (or no Ghostty), already inside a tmux session** —
    switches the client to the preset's session instead of the old
    unconditional takeover. Recoverable with prefix+s.
  - **Over SSH (or no Ghostty), not inside tmux** — same takeover as
    before (no GUI and no existing session to switch within leaves no
    other option), but now says so first instead of silently doing it.
  SSH is detected via the standard `SSH_TTY`/`SSH_CONNECTION`/
  `SSH_CLIENT` trio. The Ghostty path checks its own success rather
  than assuming it — confirmed live that it can genuinely fail
  ("Can't get focused terminal..."), in which case it falls through to
  the tmux paths above instead of silently claiming to have worked.
  `--preset <name>` from a terminal now explicitly exits either way,
  since a successful new-window launch no longer means "never
  returns" the way an exec always did.

## [0.31.0] — 2026-08-27

### Changed

- **The More menu is now the Actions menu**, and its border label names
  the row it's about to act on (e.g. "Actions on fastfetch") instead
  of a generic label. Someone used to a GUI right-click
  menu wouldn't necessarily know that pressing F4 acts on whatever's
  currently highlighted — "More" doesn't say that, the way a context
  menu opening already anchored to what you clicked would. Opened from
  the view picker (no single row to name) it still just says
  "Actions". Purely a rename/labeling change — every key, action, and
  behavior underneath is identical.

### Fixed

- **The footer's own width budget was quietly wrong** — off by 2
  characters, undercounting how much room fzf's border and padding
  actually take up. Harmless before now because the old "[More]" label
  happened to leave just enough slack to hide it; renaming it to the
  3-characters-wider "[Actions]" removed that slack and exposed it —
  the footer's F-key row could get truncated (missing the tail of
  "[Presets]") on a terminal that should have had room to spare.
  Measured the real overhead live by rendering the same footer text at
  a range of terminal widths rather than guessing, and corrected the
  budget to match — fixed for any future footer text change, not just
  this one.

## [0.30.2] — 2026-08-27

### Fixed

- **A preset bigger than ~4 tools could silently drop the rest** on a
  plain terminal. Root cause, found live by deliberately testing
  presets from 1 to 200 commands: tmux's default `split-window` just
  keeps halving whichever pane it's handed rather than filling the
  window grid-aware, so an 80x24 terminal ran out of room after only 4
  panes — the 5th onward failed with "no space for a new pane," and
  `run_preset()` never checked that call's exit status, so those tools
  vanished with no warning at all. Now retiles into a grid after every
  single pane, not just once at the end, which comfortably handles
  well over 100 panes on a plain terminal before hitting a true floor
  — and when it does hit one, a single summary warning ("no room for N
  tools...") reports it instead of failing silently.
- **A tool that crashed mid-TUI could leave its pane looking frozen or
  blank.** Found live while investigating: a curses-style tool that
  enters alternate-screen mode and then dies without restoring it (a
  common failure mode for an unhandled crash, not a bug in the tool
  necessarily) left tmux's own `#{alternate_on}` stuck at 1 even
  though a perfectly ordinary shell was running underneath — the
  visual result can be a pane that looks unresponsive until something
  else forces a redraw. Every "run the command, then fall through to a
  fresh shell" launch path (presets, the current-terminal and tmux
  backends, Ghostty, and both macOS/Linux shortcut file generators) now
  exits alternate-screen mode and shows the cursor again right before
  that fresh shell starts — a no-op if the tool already cleaned up
  after itself, a real fix if it didn't.
- **The More menu and Theme picker didn't mention you can type to
  search them**, despite both being fully searchable and both holding
  10 rows — every other list-like screen in the app already says
  "Type Search" in its footer. Added to both, matching the existing
  convention.

## [0.30.1] — 2026-08-27

### Fixed

- **Clicking `[Delete]` in the Launch Preset (F9) screen launched the
  preset instead of deleting it.** A footer click reports
  through a small side-channel file since it never matches `--expect`'s
  key list directly — `launch_preset()` was clearing that file right
  after fzf exited, before ever checking it, so the click was silently
  lost and fell through to whatever the empty default action was
  (launching). The check now runs before the file gets cleared, the
  same order the view picker's own (unaffected) `[Delete]` click
  already used. Verified live via simulated mouse clicks at the exact
  footer coordinates: `[Delete]` now opens the confirm screen,
  `[Launch]` still launches.

## [0.30.0] — 2026-08-27

### Added

- **Create Preset now shows launch order as a number, not just a dot.**
  Tab marks a tool and shows
  its position (`1`, `2`, `3`, ...); pressing Tab again on a marked
  tool unmarks it and renumbers everything after it down. Enter saves
  the preset in that exact order — previously the order always came
  from the underlying list's own (alphabetical-ish) sort, regardless of
  what order you actually pressed Tab in, since fzf's own `--multi`
  output preserves list order, not selection order. New
  `--internal-preset-tab` handler backs this: `create_preset()` no
  longer uses fzf's native `--multi`/`--marker` at all, keeping its own
  small ordered list on the side instead (one command per line, updated
  by a `transform` bind on every Tab press, reloading the list with
  updated number badges baked into the display text).

### Changed

- **Enter with nothing marked now shows an error** ("Mark at least one
  tool with Tab before saving a preset.") and reopens the same screen,
  instead of silently saving whatever the cursor happened to be
  sitting on as a one-tool preset — not really what presets are for,
  since you'd just launch that one tool directly.

## [0.29.1] — 2026-08-27

### Fixed

- **Launching a preset could look exactly like it did nothing.**
  A right-click revealed it was actually tmux's own context menu, meaning the preset
  had launched correctly all along. Root cause: a preset session that
  ends up with only one live pane (a one-tool preset, or one tool
  skipped because it wasn't found on PATH) is visually identical to a
  plain shell prompt, and there was nothing forcing tmux's status bar
  — the one thing that would actually say "you're in `blpreset-<name>`
  now" — to be visible, so it silently inherited whatever the user's
  own tmux config did with it. `run_preset()` now forces the status
  bar on for every preset session, same session-scoped approach
  already used for mouse mode.
- **"Not found on PATH" warnings were unreadable** — printed, then
  immediately overwritten the instant the function exec'd into tmux a
  few lines later. Now collected and printed together with a 2-second
  pause right before that exec, the last point they're actually able
  to stay on screen.

## [0.29.0] — 2026-08-26

### Added

- **Mouse mode is on by default in every preset's tmux session** —
  click a pane to focus it, drag a border to resize. Scoped to that
  session only (`tmux set-option -t <session> mouse on`, no `-g`), so
  it never changes mouse behavior anywhere else you use tmux.

### Fixed

- **Editing a preset while its tmux session was still running left the
  session unchanged** — a preset trimmed from 4 tools
  down to 3 still opened with 4 panes. Root cause: reattaching to an
  already-running preset session skipped rebuilding entirely, so it
  never noticed the file had changed. `run_preset()` now stashes a
  fingerprint of the command list on the session itself
  (`BL_PRESET_HASH`, via `tmux set-environment`) when it's built;
  the next launch compares the current file against that fingerprint
  and only reattaches if it still matches, killing and rebuilding the
  session otherwise. Re-running an unedited preset still reattaches to
  the exact same panes as before — verified live that the pane's PID
  doesn't change in that case.

## [0.28.0] — 2026-08-26

### Added

- **Delete a preset from the launcher.** F9 (Launch Preset) now accepts
  Ctrl-D on the highlighted preset as well as Enter — same key, same
  confirm-first pattern the view picker already uses to delete a
  category (Cancel listed first and selected by default, count of
  commands shown so the prompt is real information, nothing deleted
  without a second step). Previously the only way to remove a preset
  was `rm ~/.config/brew-launcher/presets/<name>` by hand.

## [0.27.0] — 2026-08-26

### Changed

- **F4 (More) and F5 (Refresh) now work from inside the view picker
  (F2) itself**, not just the main list. The view picker's own code
  comment called it "the main navigation hub," but it couldn't
  actually reach either. More opened from there now offers only the
  actions that don't need a highlighted row (Launch Preset, Theme, the
  three toggles, Create Preset) — Hide/Favorite/Categorize/Create
  shortcut are entry-scoped and stay main-list-only. New shared
  `open_more_menu()` (used by both call sites) and `refresh_cache_and_state()`
  (extracted from the old F5 handler) back this without duplicating either
  flow.
- **Esc from Theme (or any other loop-back More action) now returns to
  the More menu, not out to `All`.** Closing Theme used
  to dump you all the way out. Theme, Create Preset, and Launch Preset
  don't need a highlighted row either, so they're now handled inside
  `open_more_menu()`'s own loop, which reopens More after each one
  instead of falling through to whatever screen called it.
- **More menu reorganized** into three groups: entry-scoped actions
  (Hide, Favorite, Categorize) plus Launch Preset first; Theme and the
  three Default/Open-to-Categories toggles — "adjust something, then
  come back" — next; Create Preset and Create shortcut — "build
  something new" — last.

### Fixed

- **F5 from the view picker's very first appearance failed with
  `command not found: refresh_cache_and_state`** when Open to
  Categories is on, since that startup screen runs before the launcher
  reaches the point in the file where the function used to be defined.
  Moved the definition earlier, ahead of that startup call.

## [0.26.0] — 2026-08-26

### Changed

- **Every screen now shows the "Homebrew CLI vX" border label**, not
  just the main list. View, More, Theme, Categorize,
  Launch Preset, and the rest all showed a bare label like `View` or
  `More` with no version/branding — inconsistent, and more noticeable
  now that Open to Categories can make View the very first screen a
  launch shows. New shared `screen_border_label()` helper (same
  " Homebrew CLI vX · <label> " shape the main list already uses for a
  filtered view, just without the main list's disk-usage figures) now
  backs all 11 secondary fzf screens.
- **Esc now closes the details pane (F3) before doing anything else**.
  Pressing Esc while it was open used to fall straight
  through to Quit or Views, since F3 was a native fzf toggle-preview
  bind entirely invisible to this script — Esc had no way to know the
  pane was even open. F3/⌥D moved off that native bind and onto the
  same dispatch-and-redraw path every other toggle (F6/F7/F8) already
  uses, tracked by a new DETAILS_VISIBLE flag. Esc checks it first: if
  the pane is open, closes it and stays put; only steps back a view or
  quits once it's already closed. The footer says `[Close]` instead of
  `[Quit]`/`[Views]` while the pane is open, so the change in what Esc
  does is never a surprise. Also fixes a footer-click bug this same
  work surfaced: clicking `[Details]` still called the old native
  toggle directly, bypassing the new flag entirely — moved onto the
  same click → record → redraw path every other footer button uses.

## [0.25.2] — 2026-08-26

### Changed

- **The three More-menu switches (Default Categories, Default Hidden,
  Open to Categories) now flip with Space as well as Enter, and reopen
  the menu right after** instead of dropping back to the main list —
  pressing Enter to toggle a setting felt like leaving the screen the
  way Enter does on every other row, and having to
  press F4 again to touch a second setting was real friction for
  something meant to be flipped quickly, possibly more than one at a
  time. `pick_more_action()` gained `--bind 'space:accept'` (Space now
  confirms any row, same as Enter — the only real tradeoff being that
  Space can no longer be typed as a literal search character in this
  one short menu, which fuzzy-matching makes moot in practice). The F4
  dispatch itself now loops: a toggle flips in place and calls back
  into the same menu, anything else still exits normally exactly as
  before. The three standalone toggle handlers this replaced are gone
  — reaching them any other way was never possible, so keeping both
  would've been dead code.

## [0.25.1] — 2026-08-26

### Fixed

- **The view picker's "All" row now shows a count** — every other
  row had a number, "All" didn't. It was
  left out on the theory that fzf's own inline counter repeats it once
  you're actually in that view, but from the picker screen itself the
  missing number read as something broken rather than intentional.
  Also addresses a related point — "All"
  isn't literally every installed tool, it excludes `Hidden` the same
  way the real view does — by making that visible rather than changing
  the behavior: `All (50)` and `Hidden (63)` now sit on screen
  together and add up to the real total, instead of `All` silently
  meaning something narrower than its name implies with no visible
  cue. Renaming "All" itself was considered and declined — the
  underlying behavior is correct (it's the whole point of Hide: hidden
  things actually leave your default view) and the two visible counts
  now make the relationship clear without touching a name every
  existing user already knows.

## [0.25.0] — 2026-08-26

### Added

- **"Open to Categories"** (`More`, off by default; `OPEN_TO_CATEGORIES=on`
  in config). Opens straight to the view picker on launch instead of
  `All` — makes sense once your categories are actually populated
  (bundled, manual, or both), which the bundled-defaults feature makes
  true from a fresh install onward. Reuses `pick_view()` exactly as-is
  rather than a separate startup path, so typing to search, the
  per-category counts, and Esc falling back to `All` all come free and
  can't drift out of sync with the F2 screen itself. Off by default —
  unlike the two bundled-data switches, this changes the very first
  screen you see, so it stays opt-in rather than changing anyone's
  launch experience out from under them.

## [0.24.2] — 2026-08-26

### Fixed

- **The view picker's category counts could overcount**. Root cause
  was two-fold. A plain `grep -c` on a real
  category file counted blank/comment lines and entries that no
  longer exist or are hidden, and the bundled-category tally never
  checked hidden status at all — several bundled-hidden commands
  (`age-inspect`, `calcurse-caldav`/`-upgrade`/`-vdir`) share a
  formula with a bundled category (Security, Productivity), so those
  categories always overcounted by construction, on top of anything a
  user had separately hidden by hand. Extracted into a dedicated
  `compute_category_counts()` that mirrors exactly what the filtered
  view itself displays (known-installed, not hidden, real file parsed
  with the same blank/comment skipping `load_category_members()`
  already used) — verified against real data: Security's bundled
  tally dropped from a wrong 3 to a correct 1 once `age-inspect` and
  `age-plugin-batchpass` were excluded.

## [0.24.1] — 2026-08-26

### Fixed

- **A 2-pane preset now opens side by side instead of stacked.**
  `tmux select-layout tiled` grids panes by character-cell shape, not
  screen aspect ratio, so for exactly 2 panes it splits top/bottom even
  on a wide monitor (confirmed directly: two 200-column panes came out
  200x24 and 200x25, one above the other). Switched to
  `even-horizontal` specifically for the 2-pane case, which is the
  actual side-by-side split — the most common preset size benefits
  most from a widescreen layout. 3+ panes are unaffected; `tiled`'s
  grid behavior is still the right call once a single row or column
  stops making sense.

## [0.24.0] — 2026-08-26

### Added

- **Bundled default categories and hidden commands.** A curated,
  hand-reviewed dataset now ships with the launcher: a formula ->
  category mapping for ~140 well-known CLI/TUI tools across 18
  categories, and a short list of commands that are genuinely just a
  multi-command formula's minor helper scripts (`age-inspect`,
  `calcurse-upgrade`, `chkfont`, `figlist`, `showfigfonts`, `podboat`,
  and a few others — each reviewed individually against what it
  actually does, not filtered by a generic naming rule; a blanket
  heuristic here was already considered and rejected once before, see
  CONTRIBUTING.md). Both apply automatically on every cache rebuild to
  anything not already categorized/hidden by hand, so a fresh install
  already looks organized. Controlled by the two switches added in
  0.23.0 (`More → Default Categories` / `Default Hidden`), which were
  genuinely no-ops until this data existed to turn on or off.
  Read straight from two new cache fields (CACHE_FORMAT_VERSION 8→9),
  computed at rebuild time regardless of the on/off setting so
  toggling either takes effect immediately, no rebuild required.
- A category that's entirely bundled (no real category file behind it
  yet) shows up in the view picker like any other and takes a normal
  F8 press — pressing it again on a bundled-only membership writes to
  a new `category-exclude` file rather than a redundant real line,
  since there's no real line to remove. F6 on a bundled-hidden command
  works the same way via a new `shown` file. Your own F6/F8 choice on
  any individual entry always overrides the bundled default regardless
  of the global switch, exactly as promised when the switches shipped.
- The F3 details pane now shows a bundled category too, marked
  `(default)`, when nothing's filed by hand — same place the pane
  already names manually-assigned categories.

### Fixed

- A genuinely empty tab-separated cache field silently swallowed the
  tab next to it under zsh's `read` — `IFS=$'\t'` still applies the
  "collapse runs of IFS whitespace" rule tab itself qualifies for, the
  same behavior that collapses runs of spaces, so an empty field
  shifted every field after it left by one. Every existing field
  happened to always be non-empty in practice, so this had never
  surfaced before the new (usually-empty) default_category field
  exposed it. Fixed by never emitting an empty field — a `-`
  placeholder stands in for "no bundled category" instead.

## [0.23.0] — 2026-08-26

### Changed

- **Presets/Create Preset are visible again even without tmux**,
  reversing 0.21.0's hiding. Hiding them solved "don't offer what can
  only fail," but created a worse problem: someone who never had tmux
  installed had no way to discover Presets existed at all short of
  reading the README. Now both stay in the footer, More menu, and F1
  Help at all times; the More menu's hint column reads "needs tmux"
  in place of the usual keybind so the requirement is visible without
  pressing anything, and selecting either still explains the exact
  install command rather than silently failing.

### Added

- **Two new More-menu switches, Default Categories and Default
  Hidden** (`DEFAULT_CATEGORIES` / `DEFAULT_HIDDEN` in
  `~/.config/brew-launcher/config`, each `on`/`off`, default `on`).
  Reserved for a curated, bundled set of category and pre-hidden-
  command defaults shipping separately — flipping either is a no-op
  until that data exists, but the on/off mechanism (and its escape
  hatch for someone who wants a blank slate from the start) needed to
  be settled first. A user's own F3/F8 choice on any individual entry
  will always override the bundled data regardless of this setting.

## [0.22.0] — 2026-08-26

### Added

- **The border now shows disk usage** on the `All` view: how much space
  Homebrew's own installs are using, and how much is still free on the
  volume. Free space is checked live every launch (a single `df`, cheap
  enough not to matter). Homebrew's own usage needs a real `du` walk of
  the Cellar — measured at ~0.28s against a real ~3GB install, a cost
  this project's "instant startup" bar doesn't take on lightly — so
  it's cached and only recomputed when the cache itself rebuilds, since
  a local install/uninstall is the only thing that actually changes it.
  Hidden on filtered views to leave room for the view's own name.

## [0.21.0] — 2026-08-26

### Changed

- **F9/Presets and Create Preset now hide themselves if tmux isn't
  installed**, instead of being offered and then failing partway
  through — pressing F9 used to open a preset list (or "Create Preset"
  used to let you build one) that could only ever error the moment you
  actually tried to use it. Same "don't offer what can only fail"
  reasoning Create Shortcut already followed on unsupported platforms,
  now applied here too. The direct F9/⌥P keypress still works as a
  fallback and explains what's missing, in case muscle memory reaches
  for it anyway. `--preset` from a terminal is unaffected — typing that
  flag already implies you know what it needs.

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
