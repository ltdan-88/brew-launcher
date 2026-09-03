#!/bin/zsh
#
# Hide / unhide (ignore file) test.
#
# hide_entry(), unhide_entry() and load_hidden_commands() are all
# pure with respect to the filesystem — no fzf, no interactivity —
# so they're sourced directly and called against a fixture directory,
# the same approach as category-fixtures.sh.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

CONFIG_DIR="$TEST_HOME/config"
CACHE_DIR="$TEST_HOME/cache"
CACHE_FILE="$CACHE_DIR/entries"
IGNORE_FILE="$CONFIG_DIR/ignore"
SHOWN_FILE="$CONFIG_DIR/shown"
CONFIG_DEFAULT_HIDDEN=""
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

# No cache file at all in this fixture — load_bundled_hidden_commands()
# (called by load_hidden_commands() below) treats a missing CACHE_FILE
# as "nothing bundled-hidden," so this test exercises IGNORE_FILE
# behavior in isolation, same as before the bundled list existed.
#
# load_hidden_commands() assumes these are already declared as
# associative arrays by the real script (see its own `typeset -A`
# lines) rather than declaring them itself — matched here for the
# same reason.
typeset -A hidden_commands bundled_hidden_commands shown_commands

# Sourced from the real file, not reimplemented, so this tests the
# actual code rather than a copy that could drift out of sync.
source <(sed -n '/^load_bundled_hidden_commands() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^load_shown_commands() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^load_hidden_commands() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^remove_line_from_file() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^hide_entry() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^unhide_entry() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. Hiding writes the command to the ignore file.
# ------------------------------------------------------------

hide_entry "btop"

[[ -f "$IGNORE_FILE" ]] || fail "hide_entry did not create the ignore file"
grep -qxF "btop" "$IGNORE_FILE" || fail "btop missing from ignore file after hide_entry"

# ------------------------------------------------------------
# 2. Hiding the same command twice doesn't duplicate the line.
# ------------------------------------------------------------

hide_entry "btop"

btop_count="$(grep -cxF "btop" "$IGNORE_FILE")"
[[ "$btop_count" == "1" ]] || fail "expected exactly 1 'btop' line after hiding it twice, got $btop_count"

# ------------------------------------------------------------
# 3. load_hidden_commands sees what's actually in the file.
# ------------------------------------------------------------

hide_entry "mc"
load_hidden_commands

[[ -n "${hidden_commands[btop]-}" ]] || fail "btop should be reported hidden by load_hidden_commands"
[[ -n "${hidden_commands[mc]-}" ]] || fail "mc should be reported hidden by load_hidden_commands"
[[ -z "${hidden_commands[yazi]-}" ]] || fail "yazi was never hidden but load_hidden_commands reports it hidden"

# ------------------------------------------------------------
# 4. Blank lines and "#" comment lines in a hand-edited ignore file
#    are skipped, not treated as commands to hide — the ignore file
#    is documented as plain-text and hand-editable, so a comment or
#    stray blank line is a real scenario, not a hypothetical one.
# ------------------------------------------------------------

printf '\n# a comment explaining why\nyazi\n   \n' >> "$IGNORE_FILE"
load_hidden_commands

[[ -n "${hidden_commands[yazi]-}" ]] || fail "yazi (added after a comment/blank line) should be hidden"
[[ -z "${hidden_commands[' a comment explaining why']-}" ]] || fail "a '#' comment line should never become a hidden-command key"

# ------------------------------------------------------------
# 5. unhide_entry removes exactly the target command's line, and
#    nothing else — checked by confirming a sibling entry survives.
# ------------------------------------------------------------

unhide_entry "mc"
load_hidden_commands

[[ -z "${hidden_commands[mc]-}" ]] || fail "mc should no longer be hidden after unhide_entry"
[[ -n "${hidden_commands[btop]-}" ]] || fail "btop should still be hidden — unhide_entry removed more than just mc"
[[ -n "${hidden_commands[yazi]-}" ]] || fail "yazi should still be hidden — unhide_entry removed more than just mc"

# ------------------------------------------------------------
# 6. unhide_entry on a command that was never hidden, or with no
#    ignore file at all, doesn't error.
# ------------------------------------------------------------

unhide_entry "never-hidden-tool" || fail "unhide_entry should not fail on a command that was never hidden"

rm -f "$IGNORE_FILE"
unhide_entry "btop" || fail "unhide_entry should not fail when the ignore file doesn't exist at all"

# ------------------------------------------------------------
# 7. Bundled-hidden commands (see "Bundled defaults") are hidden
#    without ever touching IGNORE_FILE, and F6 overrides them via
#    SHOWN_FILE instead — reversing that override, rather than adding
#    a redundant IGNORE_FILE line, is what hiding it again should do.
# ------------------------------------------------------------

rm -f "$IGNORE_FILE" "$SHOWN_FILE"

# load_hidden_commands() recomputes bundled_hidden_commands from
# CACHE_FILE every time it runs (see its own comment on why), so a
# direct array assignment here would just be overwritten — a real
# fixture cache line is what actually exercises that path. Field 11
# is default_hidden; the rest don't matter for this test.
printf 'age-inspect\tdesc\tage\t1.0\t1MB\t0\tage\t/opt/homebrew/bin/age-inspect\t0\t-\t1\n' > "$CACHE_FILE"

load_hidden_commands

[[ -n "${hidden_commands[age-inspect]-}" ]] || fail "bundled-hidden command should be hidden with no ignore file involved"

unhide_entry "age-inspect"
load_hidden_commands

[[ -z "${hidden_commands[age-inspect]-}" ]] || fail "unhide_entry should override a bundled-hidden command via SHOWN_FILE"
[[ ! -f "$IGNORE_FILE" ]] || fail "unhide_entry should not have written IGNORE_FILE for a bundled-hidden command"
grep -qxF "age-inspect" "$SHOWN_FILE" || fail "age-inspect should be recorded in SHOWN_FILE after unhide_entry"

hide_entry "age-inspect"
load_hidden_commands

[[ -n "${hidden_commands[age-inspect]-}" ]] || fail "hide_entry should re-hide age-inspect by reverting the SHOWN_FILE override"
grep -qxF "age-inspect" "$SHOWN_FILE" 2>/dev/null && fail "hide_entry should have removed age-inspect from SHOWN_FILE, not left it there"
[[ ! -f "$IGNORE_FILE" ]] || fail "hide_entry should not add a redundant IGNORE_FILE line for an already bundled-hidden command"

# ------------------------------------------------------------
# 7b. A bundled-hidden command still registers even when an earlier
#     field is genuinely empty — raised live via a wrong "All" count.
#     load_bundled_hidden_commands() used to read the cache with a
#     zsh `read` loop and placeholder variables for the fields in
#     between field 1 and field 11 (default_hidden); `IFS=$'\t' read`
#     treats a run of consecutive tabs the same way it treats a run of
#     ordinary whitespace — as a single separator — so a genuinely
#     empty field doesn't consume a placeholder of its own, leaving
#     the read one token short by the time it reaches the last
#     variable. Two fields a real formula's cache row can actually
#     have empty (unlike field 10, default_category, which was
#     already given a non-empty "-" placeholder for this exact
#     reason): description (a formula with no `desc` — see
#     cache_writer.py's own `.get("desc", "")`) and size (no entry in
#     `brew info --sizes` for it — `.get(name, "")`). Either one used
#     to make raw_default_hidden come back empty regardless of what
#     field 11 actually held, so the command silently never counted
#     as hidden anywhere (a category/All/Hidden count, or the F3
#     preview above, all disagreeing with reality). Fixed by reading
#     field 11 with awk instead, same as --internal-preview-category's
#     own equivalent lookup already does.
# ------------------------------------------------------------

rm -f "$IGNORE_FILE" "$SHOWN_FILE"

printf 'empty-desc\t\tempty-desc\t1.0\t1MB\t0\tempty-desc\t/opt/homebrew/bin/empty-desc\t100\t-\t1\n' > "$CACHE_FILE"
load_hidden_commands
[[ -n "${hidden_commands[empty-desc]-}" ]] ||
    fail "a bundled-hidden command with an empty description should still be hidden"

printf 'empty-size\tSome tool\tempty-size\t1.0\t\t0\tempty-size\t/opt/homebrew/bin/empty-size\t100\t-\t1\n' > "$CACHE_FILE"
load_hidden_commands
[[ -n "${hidden_commands[empty-size]-}" ]] ||
    fail "a bundled-hidden command with an empty size should still be hidden"

printf 'PASS: hide/unhide round-trips correctly, comments and blank lines are skipped, unhide is surgical, bundled-hidden overrides work via SHOWN_FILE, and a bundled-hidden command with an empty description or size still registers as hidden\n'
