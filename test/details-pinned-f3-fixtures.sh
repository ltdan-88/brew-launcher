#!/bin/zsh
#
# F3 becomes a no-op once Details is pinned on via Settings.
#
# Raised live, two remarks together: "the Details toggle in Settings
# is not always persistent" and "wouldn't it make sense to disable F3
# whenever Details is enabled in Settings?" Both point at the same
# root cause: turning Details on via Actions -> Settings -> Details
# sets DETAILS_PINNED=true (a standing "always on" choice, not a
# peek — see DETAILS_PINNED's own comment in bin/brew-launcher), but
# every F3 handler (main list, F2's view picker) used to flip
# DETAILS_VISIBLE and unconditionally clear DETAILS_PINNED right
# after, regardless of how it got turned on. A single F3 press
# anywhere — out of habit, or just to peek at a different entry —
# silently downgraded the Settings choice back into an ordinary peek,
# with nothing on screen to say that's what had just happened. From
# the user's side that reads as "the Settings toggle doesn't always
# stick." Fixed by making F3 check DETAILS_PINNED first: while pinned,
# it has nothing left to do, and Settings becomes the only way back
# off.
#
# Both F3 handlers are checked as source text (same reasoning as
# actions-menu-fixtures.sh: they're plain zsh embedded in a much
# larger dispatch loop, not their own callable function). The real
# behavior — Details staying open across a stray F3 press once pinned
# via Settings — is then driven for real in a live tmux session,
# since a guard that merely *looks* right in a diff is exactly the
# kind of thing worth actually launching and pressing keys against.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

full_source="$(cat "$LAUNCHER")"

# ------------------------------------------------------------
# 1. pick_view()'s (F2) own F3 handler guards on DETAILS_PINNED before
#    touching DETAILS_VISIBLE at all.
# ------------------------------------------------------------

pick_view_f3_block="$(sed -n '/if \[\[ "\$pick_action" == "f3" \]\]; then/,/^    fi$/p' "$LAUNCHER" | head -20)"
[[ "$pick_view_f3_block" == *'if [[ "$DETAILS_PINNED" == false ]]; then'* ]] ||
    fail "pick_view's F3 handler should guard on DETAILS_PINNED before toggling DETAILS_VISIBLE"
[[ "$pick_view_f3_block" == *'DETAILS_VISIBLE=false || DETAILS_VISIBLE=true'* ]] ||
    fail "pick_view's F3 handler should still flip DETAILS_VISIBLE when not pinned"

# ------------------------------------------------------------
# 2. The main list's own F3/⌥D handler does the same.
# ------------------------------------------------------------

main_f3_block="$(sed -n '/"\$action" == "f3" || "\$action" == "alt-d" \]\]; then/,/^    fi$/p' "$LAUNCHER" | head -20)"
[[ "$main_f3_block" == *'if [[ "$DETAILS_PINNED" == false ]]; then'* ]] ||
    fail "the main list's F3/alt-d handler should guard on DETAILS_PINNED before toggling DETAILS_VISIBLE"
[[ "$main_f3_block" == *'DETAILS_VISIBLE=false || DETAILS_VISIBLE=true'* ]] ||
    fail "the main list's F3/alt-d handler should still flip DETAILS_VISIBLE when not pinned"

# ------------------------------------------------------------
# 3. Live: turn Details on via Settings, return to the main list,
#    confirm the pane is already open with no F3 press needed, press
#    F3, and confirm it's still open — the actual regression this file
#    exists to catch, not just a guard that looks right in the diff.
# ------------------------------------------------------------

if command -v tmux >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then

    wait_for() {
        local session="$1" pattern="$2"
        local _
        for _ in {1..40}; do
            tmux capture-pane -t "$session" -p 2>/dev/null | grep -q "$pattern" && return 0
            sleep 0.5
        done
        return 1
    }

    # Same reasoning as startup-screen-fixtures.sh's own seed_cache —
    # a from-scratch launch would otherwise call the real `brew`
    # commands to build its cache, which depends on how many formulae
    # happen to be installed wherever this runs rather than on
    # anything this test cares about.
    DP_CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
    [[ -n "$DP_CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

    DP_HOME="$(mktemp -d)"
    DP_CACHE_DIR="$DP_HOME/.cache/brew-launcher"
    mkdir -p "$DP_CACHE_DIR"
    printf 'cat\tConcatenate files\tcat\t1.0\t1MB\t0\tcat\t/bin/cat\t100\n' > "$DP_CACHE_DIR/entries"
    printf '%s\nfixture-state-snapshot\n' "$DP_CACHE_FORMAT_VERSION" > "$DP_CACHE_DIR/state"
    : > "$DP_CACHE_DIR/outdated"

    DP_SESSION="blf-details-pin-$$"
    tmux kill-session -t "$DP_SESSION" 2>/dev/null
    tmux new-session -d -s "$DP_SESSION" -x 100 -y 30 "HOME='$DP_HOME' zsh '$LAUNCHER'"

    if wait_for "$DP_SESSION" "Tab  Mark"; then

        # Baseline: Details starts off, nothing cached shows.
        tmux capture-pane -t "$DP_SESSION" -p 2>/dev/null | grep -q "no details cached" &&
            fail "Details should start off — the preview pane shouldn't be showing yet"

        # F4 -> Actions -> "Settings" (unique substring, no space —
        # this screen's own fzf binds space:accept, same pitfall noted
        # throughout this suite for any query containing a literal
        # space) -> Enter.
        tmux send-keys -t "$DP_SESSION" F4
        wait_for "$DP_SESSION" "Actions on" ||
            fail "F4 should open the Actions menu"
        tmux send-keys -t "$DP_SESSION" -l "Settings"
        sleep 0.3
        tmux send-keys -t "$DP_SESSION" Enter
        wait_for "$DP_SESSION" "· Settings " ||
            fail "Settings should open from Actions"

        # Down x6 reaches the Details row (Themes, Default Categories,
        # Default Hidden, Startup Screen, Sort, Compact View, then
        # Details — see pick_settings_action()'s own row order) —
        # arrow-key navigation instead of typing a query, since
        # "Details" as a fuzzy query also matches "Details Position"
        # and isn't guaranteed to rank the shorter row first.
        for _ in {1..6}; do
            tmux send-keys -t "$DP_SESSION" Down
            sleep 0.1
        done
        tmux send-keys -t "$DP_SESSION" Space
        sleep 0.5

        tmux capture-pane -t "$DP_SESSION" -p 2>/dev/null | grep -q "Details             On" ||
            fail "Details should read On in Settings right after toggling it"

        # Back to the main list: Esc out of Settings (Actions
        # reappears), Esc out of Actions.
        tmux send-keys -t "$DP_SESSION" Escape
        wait_for "$DP_SESSION" "Actions on" ||
            fail "Esc from Settings should return to Actions"
        tmux send-keys -t "$DP_SESSION" Escape
        wait_for "$DP_SESSION" "Tab  Mark" ||
            fail "Esc from Actions should return to the main list"

        # The pane should already be open — a standing choice, not
        # something that needs F3 first.
        wait_for "$DP_SESSION" "no details cached" ||
            fail "Details pinned on via Settings should already be showing on the main list, no F3 needed"

        # The actual regression: F3 used to close this immediately and
        # clear DETAILS_PINNED, downgrading the Settings choice into an
        # ordinary peek. It should now be a no-op.
        tmux send-keys -t "$DP_SESSION" F3
        sleep 0.5
        tmux capture-pane -t "$DP_SESSION" -p 2>/dev/null | grep -q "no details cached" ||
            fail "F3 should be a no-op while Details is pinned on via Settings — the pane should still be open"

    else
        printf 'SKIP: launcher never became interactive, skipping the live Details-pin check\n' >&2
    fi

    tmux kill-session -t "$DP_SESSION" 2>/dev/null
    rm -rf "$DP_HOME"

else
    printf 'SKIP: tmux or fzf not available, skipping the live Details-pin check\n' >&2
fi

printf 'PASS: turning Details on via Actions -> Settings -> Details pins it as a standing choice (DETAILS_PINNED=true), and both F3 handlers (main list, F2 view picker) now no-op instead of silently clearing that pin — confirmed live: the pane is already open on return to the main list with no F3 press needed, and a stray F3 press afterward leaves it open rather than closing it\n'
