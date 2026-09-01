#!/bin/zsh
#
# Launch History — Actions -> Launch History: see what's been recorded
# and clear it.
#
# LAUNCH_HISTORY_FILE is appended to on every launch and is what Most
# Used / Recently Launched are tallied from, but until this there was
# no way to look at it or clear it from inside the app — deleting the
# file by hand was the only option, which made both of those views
# effectively unmanageable.
#
# show_launch_history() calls fzf, so the screen itself is a
# source-text assertion (same reasoning rename-fixtures.sh gives). The
# parts that actually touch data — the tally it renders, and clearing
# plus the reload afterward — are run for real against a fixture
# history file, since those are what could silently lose or misreport
# someone's data.

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
mkdir -p "$CONFIG_DIR"
LAUNCH_HISTORY_FILE="$CONFIG_DIR/launch-history"

full_source="$(cat "$LAUNCHER")"

# ------------------------------------------------------------
# 1. The tally itself, run for real: load_launch_counts() is what the
#    viewer renders from, so the counts it produces are the counts
#    shown. Sourced and run against a fixture file with a known,
#    deliberately uneven distribution.
# ------------------------------------------------------------

typeset -A launch_counts last_launched_order
LAST_LAUNCHED_COUNTER=0

source <(sed -n '/^load_launch_counts() {/,/^}/p' "$LAUNCHER")

printf '%s\n' btop fastfetch btop glow btop fastfetch > "$LAUNCH_HISTORY_FILE"

load_launch_counts

(( launch_counts[btop] == 3 )) ||
    fail "btop should be tallied 3 times, got ${launch_counts[btop]-unset}"
(( launch_counts[fastfetch] == 2 )) ||
    fail "fastfetch should be tallied 2 times, got ${launch_counts[fastfetch]-unset}"
(( launch_counts[glow] == 1 )) ||
    fail "glow should be tallied 1 time, got ${launch_counts[glow]-unset}"
(( ${#launch_counts} == 3 )) ||
    fail "three distinct tools should be tallied, got ${#launch_counts}"

# ------------------------------------------------------------
# 2. Clearing removes the file AND resets the in-memory tables the
#    two views read. Leaving stale counts in memory would keep showing
#    a Most Used built from a file that no longer exists — the exact
#    failure worth guarding, since nothing on screen would say so.
# ------------------------------------------------------------

rm -f "$LAUNCH_HISTORY_FILE"
load_launch_counts

(( ${#launch_counts} == 0 )) ||
    fail "clearing the history should empty the in-memory tally, got ${#launch_counts} entries still counted"
(( LAST_LAUNCHED_COUNTER == 0 )) ||
    fail "clearing the history should reset the Recently Launched counter, got $LAST_LAUNCHED_COUNTER"

history_block="$(sed -n '/^show_launch_history() {/,/^}/p' "$LAUNCHER")"
[[ -n "$history_block" ]] || fail "show_launch_history() not found"

# Comments stripped before checking for calls: this function's own
# doc comment names load_launch_counts, so a plain substring search
# stays green even with the actual call deleted. Caught by removing
# the call and watching this assertion pass anyway.
history_code="$(printf '%s\n' "$history_block" | grep -v '^[[:space:]]*#')"

[[ "$history_code" == *'rm -f "$LAUNCH_HISTORY_FILE"'* ]] ||
    fail "show_launch_history should remove the history file when clearing"
[[ "$history_code" == *'load_launch_counts'* ]] ||
    fail "show_launch_history should reload the tally after clearing, not leave stale counts in memory"
[[ "$history_code" == *'build_entries'* ]] ||
    fail "show_launch_history should rebuild the entries after clearing, so Most Used/Recently Launched update immediately"

# ------------------------------------------------------------
# 3. Clearing is confirmed first, Cancel-first — it destroys data and
#    can't be undone, so the safe choice must be the highlighted one,
#    same convention confirm_quit()/confirm_delete_category() use.
# ------------------------------------------------------------

confirm_block="$(sed -n '/^confirm_clear_history() {/,/^}/p' "$LAUNCHER")"
[[ -n "$confirm_block" ]] || fail "confirm_clear_history() not found"
[[ "$history_block" == *'confirm_clear_history'* ]] ||
    fail "show_launch_history should confirm before clearing"

# "Cancel" must be printed before the destructive choice, so it's the
# row already highlighted when the screen opens.
confirm_choices="$(printf '%s\n' "$confirm_block" | grep -o "printf '%s\\\\n' \"Cancel\" \"Clear all")"
[[ -n "$confirm_choices" ]] ||
    fail "confirm_clear_history should list Cancel first, ahead of the clear option"

# Esc must not clear: only an explicit match on the destructive label
# counts as consent.
[[ "$confirm_block" == *'[[ "$answer" == "Clear all $total launches" ]]'* ]] ||
    fail "confirm_clear_history should only succeed on an exact match of the clear choice, so Esc/empty cancels"

# ------------------------------------------------------------
# 4. An empty history says so rather than opening a blank screen, and
#    doesn't offer to clear something that isn't there.
# ------------------------------------------------------------

[[ "$history_block" == *'No launches recorded yet.'* ]] ||
    fail "an empty history should explain itself rather than opening an empty list"
[[ "$history_block" == *'(( history_total == 0 ))'* ]] ||
    fail "show_launch_history should bail out early when nothing is recorded"

# ------------------------------------------------------------
# 5. Wiring: an Actions row that shows how much is recorded before
#    it's opened, dispatched to the viewer, and grouped with Backup
#    (not gated on has_entry — neither concerns any single row).
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
open_menu_block="$(sed -n '/^open_more_menu() {/,/^}/p' "$LAUNCHER")"

[[ "$more_action_block" == *'rows+=("launch_history"'* ]] ||
    fail "pick_more_action should offer a Launch History row"
[[ "$open_menu_block" == *'launch_history)'* && "$open_menu_block" == *'show_launch_history'* ]] ||
    fail "open_more_menu should dispatch launch_history to show_launch_history"

# Outside the has_entry-gated block, same as Backup: it isn't about
# whichever row happens to be highlighted.
has_entry_block="$(printf '%s\n' "$more_action_block" | sed -n '/if \[\[ "\$has_entry" == true \]\]; then/,/^    fi$/p')"
[[ "$has_entry_block" != *'rows+=("launch_history"'* ]] ||
    fail "the Launch History row should not be gated on has_entry — it concerns no single entry, same as Backup"

# ...and the row's own line must not carry a has_entry condition
# either. Sitting outside the gated block isn't sufficient on its own:
# a one-line "[[ \$has_entry == true ]] &&" prefix would gate it just
# as effectively while still passing the position check above.
history_row_line="$(printf '%s\n' "$more_action_block" | grep 'rows+=("launch_history"')"
[[ "$history_row_line" != *'has_entry'* ]] ||
    fail "the Launch History row line should not condition itself on has_entry either, got: $history_row_line"

# The row's own preview explains what clearing costs.
preview_action_block="$(sed -n '/--internal-preview-action/,/^fi$/p' "$LAUNCHER")"
history_preview="$(printf '%s\n' "$preview_action_block" | sed -n '/^        launch_history)$/,/^            ;;$/p')"
[[ -n "$history_preview" ]] ||
    fail "the Launch History row should have its own details-pane preview"
[[ "$history_preview" == *'Most Used'* ]] ||
    fail "the preview should say what clearing actually affects"

printf 'PASS: load_launch_counts() tallies a fixture history correctly and empties both in-memory tables once the file is gone, show_launch_history() removes the file and reloads/rebuilds rather than leaving stale counts on screen, clearing is Cancel-first and only proceeds on an exact match (so Esc cancels), an empty history explains itself instead of opening blank, and the Actions row is wired up ungated with a count hint and its own preview\n'
