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
IGNORE_FILE="$CONFIG_DIR/ignore"
mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

# load_hidden_commands() assumes this is already declared as an
# associative array by the real script (see its own `typeset -A
# hidden_commands` line) rather than declaring it itself — matched
# here for the same reason.
typeset -A hidden_commands

# Sourced from the real file, not reimplemented, so this tests the
# actual code rather than a copy that could drift out of sync.
source <(sed -n '/^load_hidden_commands() {/,/^}/p' "$LAUNCHER")
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

printf 'PASS: hide/unhide round-trips correctly, comments and blank lines are skipped, unhide is surgical\n'
