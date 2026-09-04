#!/bin/zsh
#
# Update — Actions -> Update, raised live: "would it make sense to
# have the option to update individual TUIs?" Update All's own
# per-entry sibling: `brew upgrade <formula>` instead of a bare `brew
# upgrade`, through the same self-deleting-wrapper/three-way
# launch-path trick update_all() already uses.
#
# No confirmation prompt, unlike Update All — confirmed live via
# AskUserQuestion before building this: scoped to one formula rather
# than everything outdated, it's a smaller, quicker action, instant
# like Hide/Favorite rather than something worth pausing on.
#
# launch_in_current_terminal() is stubbed as a plain recorder rather
# than sourced for real, same technique run-with-args-fixtures.sh
# uses and for the same reason — its own real exec chain would need a
# subshell, which would hide the thing this test actually cares about
# (what path it was asked to launch).

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

CACHE_DIR="$TEST_HOME/cache"
mkdir -p "$CACHE_DIR"

# update_tool() checks $BACKEND now (pacman needs root to upgrade
# anything, unlike brew, so it refuses early with a plain message
# instead of trying) — real launches always have this set by the time
# any function runs; this isolated function-body test needs it set by
# hand.
BACKEND="homebrew"

source <(sed -n '/^update_tool() {/,/^}/p' "$LAUNCHER")

# Recorder, not the real launch_in_current_terminal() — see this
# file's own header comment for why.
LAUNCHED_PATH_FILE="$TEST_HOME/launched-path"
launch_in_current_terminal() {
    printf '%s' "$1" > "$LAUNCHED_PATH_FILE"
}

TERMINAL="current"

# ------------------------------------------------------------
# 1. Already up to date: nothing launches, a plain message instead.
# ------------------------------------------------------------

typeset -A outdated_formulas=()

output="$(update_tool fastfetch fastfetch 2>&1)"
exit_status=$?

[[ ! -f "$LAUNCHED_PATH_FILE" ]] ||
    fail "already-up-to-date should not have launched anything, got: $(cat "$LAUNCHED_PATH_FILE")"
[[ "$output" == *"fastfetch is already up to date."* ]] ||
    fail "should say the command is already up to date, got: $output"
(( exit_status != 0 )) ||
    fail "already-up-to-date should return non-zero"

# ------------------------------------------------------------
# 2. Outdated: builds a wrapper running `brew upgrade <formula>` —
#    the formula, not the command, since brew upgrade doesn't know
#    command names (midnight-commander's own command is `mc`).
# ------------------------------------------------------------

typeset -A outdated_formulas=(midnight-commander "4.8.33")

update_tool mc midnight-commander >/dev/null 2>&1

[[ -f "$LAUNCHED_PATH_FILE" ]] ||
    fail "an outdated formula should have launched something"
launched_path="$(<"$LAUNCHED_PATH_FILE")"
[[ -x "$launched_path" ]] || fail "the launched path should be an executable wrapper"
grep -qF -- "brew upgrade midnight-commander" "$launched_path" ||
    fail "the wrapper should run brew upgrade against the formula name, got: $(cat "$launched_path")"

# ------------------------------------------------------------
# 3. Wiring: Actions offers Update (entry-scoped, right after Run
#    With Args, hint showing the new version when outdated), and the
#    main loop dispatches it to update_tool() with the real command
#    and formula.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
has_entry_block="$(printf '%s\n' "$more_action_block" | sed -n '/if \[\[ "\$has_entry" == true \]\]; then/,/^    fi$/p')"

[[ "$has_entry_block" == *'rows+=("update_tool"'* ]] ||
    fail "pick_more_action should offer an update_tool row inside the has_entry-gated block"
[[ "$has_entry_block" == *'outdated_formulas[$entry_formula]'* ]] ||
    fail "the Update row's hint should read outdated_formulas[], keyed by formula not command"

full_source="$(cat "$LAUNCHER")"
[[ "$full_source" == *'"$action" == "update_tool"'* && "$full_source" == *'update_tool "$command" "$formula"'* ]] ||
    fail "the main loop should dispatch update_tool to update_tool() with the real command and formula"

printf 'PASS: update_tool() runs brew upgrade for just the highlighted formula (already-up-to-date says so and launches nothing; outdated builds a wrapper targeting the formula name, not the command), and Actions/the main loop wire it end to end\n'
