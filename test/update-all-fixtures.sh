#!/bin/zsh
#
# Update All — Actions -> Update All, raised live: "Action to launch
# TUI update or update all TUIs with command?"
#
# update_all() itself calls confirm_update_all() (fzf) and one of the
# three launch_in_* functions — driven for real here by stubbing
# confirm_update_all() as a call-counter (same technique
# bulk-cancel-and-quit-confirm-fixtures.sh uses for pick_multiple_
# entries()) and running the real launch_in_current_terminal() in a
# subshell, same reasoning relaunch-fixtures.sh gives for why that one
# specifically is safe to run for real (no tmux/Ghostty dependency, and
# its own exec never escapes the subshell). A fake `brew` on PATH
# stands in for the real one — this test must never touch the real
# Homebrew install. confirm_update_all()'s own Cancel-first convention
# is checked as source text, same reasoning as confirm_quit's own
# coverage in bulk-cancel-and-quit-confirm-fixtures.sh.

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

# ------------------------------------------------------------
# 1. Nothing outdated: returns without ever prompting or touching brew.
# ------------------------------------------------------------

typeset -A outdated_formulas=()

source <(sed -n '/^update_all() {/,/^}/p' "$LAUNCHER")

confirm_update_all() {
    fail "confirm_update_all should not be called when nothing is outdated"
}

CACHE_DIR="$TEST_HOME/cache-empty"
mkdir -p "$CACHE_DIR"

output="$(update_all 2>&1)"
exit_code=$?

(( exit_code == 1 )) || fail "update_all should return 1 when nothing is outdated, got $exit_code"
echo "$output" | grep -qi "already up to date" ||
    fail "update_all should say everything's already up to date, got: $output"

[[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]] ||
    fail "update_all should not have left anything in CACHE_DIR when it never ran: $(ls "$CACHE_DIR")"

unfunction confirm_update_all

# ------------------------------------------------------------
# 2. Outdated formulae, but Cancel: no brew call, no leftover script.
# ------------------------------------------------------------

typeset -A outdated_formulas=(toolA "2.0" toolB "3.0")

CACHE_DIR="$TEST_HOME/cache-cancel"
mkdir -p "$CACHE_DIR"

FAKE_BIN="$TEST_HOME/fake-bin"
mkdir -p "$FAKE_BIN"
BREW_CALLS_FILE="$TEST_HOME/brew-calls"
: > "$BREW_CALLS_FILE"

cat > "$FAKE_BIN/brew" <<EOF
#!/bin/sh
echo "\$@" >> "$BREW_CALLS_FILE"
exit 0
EOF
chmod +x "$FAKE_BIN/brew"
export PATH="$FAKE_BIN:$PATH"

confirm_update_all() {
    [[ "$1" == "2" ]] || fail "confirm_update_all should be called with the real outdated count (2), got: $1"
    return 1
}

TERMINAL="current"
output="$(update_all 2>&1)"
exit_code=$?

(( exit_code == 1 )) || fail "update_all should return 1 when the confirm is declined, got $exit_code"
[[ ! -s "$BREW_CALLS_FILE" ]] ||
    fail "brew should never have been called after declining the confirm, got: $(cat "$BREW_CALLS_FILE")"
[[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]] ||
    fail "no temp script should be left behind after declining the confirm: $(ls "$CACHE_DIR")"

unfunction confirm_update_all

# ------------------------------------------------------------
# 3. Outdated formulae, confirmed: runs the real launch_in_current_
#    terminal() (in a subshell, so its exec can't take out this test —
#    same technique relaunch-fixtures.sh uses), which should run the
#    generated script: call the fake brew with "upgrade", then relaunch
#    bare into the fake launcher (not forced into any special flag —
#    see update_all()'s own comment for why a plain relaunch is
#    correct here, not a bug), and clean up after itself.
# ------------------------------------------------------------

: > "$BREW_CALLS_FILE"
CACHE_DIR="$TEST_HOME/cache-confirmed"
mkdir -p "$CACHE_DIR"

FAKE_LAUNCHER="$TEST_HOME/fake-launcher"
MARKER_FILE="$TEST_HOME/relaunch-marker"

cat > "$FAKE_LAUNCHER" <<EOF
#!/bin/zsh
printf '%s\n' "\$@" > "$MARKER_FILE"
EOF
chmod +x "$FAKE_LAUNCHER"

source <(sed -n '/^launch_in_current_terminal() {/,/^}/p' "$LAUNCHER")

confirm_update_all() { return 0; }

(
    FOOTER_CLICK_FILE="$TEST_HOME/footer-click"
    SCRIPT_PATH="$FAKE_LAUNCHER"
    TERMINAL="current"
    update_all
) </dev/null >/dev/null 2>&1

[[ -s "$BREW_CALLS_FILE" ]] ||
    fail "the generated script should have called the (fake) brew at all"
grep -qx "upgrade" "$BREW_CALLS_FILE" ||
    fail "the generated script should call brew with exactly 'upgrade', got: $(cat "$BREW_CALLS_FILE")"

[[ -f "$MARKER_FILE" ]] ||
    fail "launch_in_current_terminal's own relaunch tail should still reach \$SCRIPT_PATH once brew upgrade finishes"
[[ -z "$(<"$MARKER_FILE")" ]] ||
    fail "the relaunch should be bare, same as any other tool, got args: $(cat "$MARKER_FILE")"

[[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]] ||
    fail "the temp script should have deleted itself once it finished running: $(ls "$CACHE_DIR")"

unfunction confirm_update_all

# ------------------------------------------------------------
# 4. confirm_update_all() itself: Cancel-first, same convention as
#    confirm_quit()/confirm_delete_category().
# ------------------------------------------------------------

confirm_update_all_block="$(sed -n '/^confirm_update_all() {/,/^}/p' "$LAUNCHER")"
[[ -n "$confirm_update_all_block" ]] || fail "confirm_update_all() not found"

[[ "$confirm_update_all_block" == *'"Cancel" "Update all $count $noun"'* ]] ||
    fail "confirm_update_all should list Cancel first, same safe-default convention as confirm_quit/confirm_relaunch"

# ------------------------------------------------------------
# 5. Wiring: pick_more_action() offers Update All (not gated on
#    has_entry, same as Refresh right above it), showing the real
#    outdated count; open_more_menu() dispatches it.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
open_menu_block="$(sed -n '/^open_more_menu() {/,/^}/p' "$LAUNCHER")"
has_entry_block="$(printf '%s\n' "$more_action_block" | sed -n '/if \[\[ "\$has_entry" == true \]\]; then/,/^    fi$/p')"

[[ "$more_action_block" == *'rows+=("update_all"'* ]] ||
    fail "pick_more_action should offer an update_all row"
[[ "$has_entry_block" != *'rows+=("update_all"'* ]] ||
    fail "update_all's row should sit outside the has_entry-gated block, same as Refresh"
[[ "$more_action_block" == *'${#outdated_formulas}'* ]] ||
    fail "pick_more_action's Update All row should show the real outdated count"

[[ "$open_menu_block" == *$'\n            update_all)'* && "$open_menu_block" == *'update_all'*';'* ]] ||
    fail "open_more_menu should dispatch update_all"

printf 'PASS: update_all() short-circuits with nothing outdated, never calls brew when the confirm is declined, and — when confirmed — runs a self-deleting script that calls brew upgrade then relaunches bare, same as any other tool (verified via a fake brew and a fake launcher, both run for real); confirm_update_all() is Cancel-first; Actions offers Update All outside the has_entry-gated block with the real outdated count\n'
