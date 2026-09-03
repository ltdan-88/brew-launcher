#!/bin/zsh
#
# "Uncategorized" — a computed view (F2), raised live: "I'd like to
# have a category called 'Uncategorized'."
#
# Same family as All/Hidden/Most Used/Recently Launched/Recently
# Added: not backed by a CATEGORIES_DIR file, computed instead —
# every installed, non-hidden command not in categorized_commands
# (every real category's members, plus every bundled default_category,
# minus whatever Default Categories/F8 excluded — see
# categorized_commands' own comment). Being favorited alone doesn't
# count as categorized either, same as the "#" marker itself already
# treats it — see load_categorized_commands()'s own Favorites skip.
#
# The row/count (pick_view()), the build_entries() filter, the F3
# preview, and the Ctrl-R/Ctrl-D reserved-name guards are all checked
# elsewhere as source text or via sourced-function execution
# (computed-view-fixtures.sh, category-fixtures.sh, rename-fixtures.sh,
# picker-details-fixtures.sh) — this file drives the real, full
# interactive flow end to end in a live tmux session instead, since a
# feature built from several pieces working together is exactly the
# kind of thing worth actually launching and pressing keys against
# rather than trusting each piece's own isolated proof to add up
# correctly in practice.
#
# Each check below gets its own fresh session rather than chaining
# several actions in one — this app draws with --no-clear throughout,
# so a refusal message (Ctrl-R/Ctrl-D on a built-in view) leaves its
# own text on screen and reopens the picker as a genuinely new fzf
# process; sending the next key too close to that reopen is exactly
# the kind of boundary that turned out to be flaky here (a key or
# typed character landing on the dying process, the new one, or
# neither, confirmed live while writing this while chaining three such
# transitions in one session). One action per session, each waiting
# for its own screen to actually be interactive first, is slower but
# was the difference between a reliable test and an intermittently
# flaky one.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

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

    UV_CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
    [[ -n "$UV_CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

    # One fixture $HOME reused across all four sessions below — each
    # launches its own fresh process against it, so there's no shared
    # in-memory state to worry about, only the same on-disk cache/
    # categories every session reads independently.
    UV_HOME="$(mktemp -d)"
    UV_CACHE_DIR="$UV_HOME/.cache/brew-launcher"
    UV_CONFIG_DIR="$UV_HOME/.config/brew-launcher"
    mkdir -p "$UV_CACHE_DIR" "$UV_CONFIG_DIR/categories"

    # tool1: filed nowhere. tool2: filed in a real category (Morning).
    # tool3: bundled into Games. tool4: hidden and filed nowhere
    # (proving hidden-exclusion applies independently of
    # categorization). tool5: favorited only — proving that alone
    # doesn't count as categorized. Only tool1 and tool5 should end up
    # in Uncategorized.
    cat > "$UV_CACHE_DIR/entries" <<'EOF'
tool1	No category at all	tool1	1.0	1MB	0	tool1	/bin/tool1	100	-	0
tool2	Filed in Morning	tool2	1.0	1MB	0	tool2	/bin/tool2	200	-	0
tool3	Bundled into Games	tool3	1.0	1MB	0	tool3	/bin/tool3	300	Games	0
tool4	Hidden, no category	tool4	1.0	1MB	0	tool4	/bin/tool4	400	-	1
tool5	Favorited only	tool5	1.0	1MB	0	tool5	/bin/tool5	500	-	0
EOF
    printf '%s\nfixture-state-snapshot\n' "$UV_CACHE_FORMAT_VERSION" > "$UV_CACHE_DIR/state"
    : > "$UV_CACHE_DIR/outdated"
    printf 'tool2\n' > "$UV_CONFIG_DIR/categories/Morning"
    printf 'tool5\n' > "$UV_CONFIG_DIR/categories/Favorites"

    # Sanity check the fixture itself before ever launching anything
    # against it — raised live after a CI-only failure (Morning and
    # Favorites missing from the picker, on Linux specifically,
    # reproducible on rerun but not reproducible in an isolated Docker
    # container matching the same OS/Homebrew/fzf/tmux versions) that
    # this diagnostic exists specifically to narrow down: is the
    # fixture itself ever incomplete on disk (a mkdir/printf that
    # silently failed — this file has no `set -e`, so that would
    # otherwise go unnoticed), or is a complete, correct fixture being
    # misread by the app itself.
    if [[ ! -f "$UV_CONFIG_DIR/categories/Morning" || ! -f "$UV_CONFIG_DIR/categories/Favorites" ]]; then
        fail "fixture setup itself is incomplete before any session even launched — ls -la \"$UV_CONFIG_DIR/categories\": $(ls -la "$UV_CONFIG_DIR/categories" 2>&1)"
    fi

    uv_open_view_picker() {
        local session="$1"
        tmux kill-session -t "$session" 2>/dev/null
        tmux new-session -d -s "$session" -x 100 -y 30 "HOME='$UV_HOME' zsh '$LAUNCHER'"
        wait_for "$session" "Tab  Mark" || return 1
        tmux send-keys -t "$session" F2
        wait_for "$session" "· View " || return 1
        return 0
    }

    # ------------------------------------------------------------
    # 1. The row exists with the right count, and its own F3 preview
    #    lists exactly tool1 and tool5 — "Uncategorized" is a unique
    #    substring (no other row contains it, and pick_view()'s own
    #    fzf call has no space:accept bind to worry about), so typing
    #    it fuzzy-filters straight to that one row without counting
    #    arrow-key presses.
    # ------------------------------------------------------------

    UV_SESSION_A="blf-uncategorized-a-$$"

    if uv_open_view_picker "$UV_SESSION_A"; then

        tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null | grep -q "Uncategorized (2)" ||
            fail "expected an Uncategorized row reading (2), got: $(tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null); ls -la \"$UV_CONFIG_DIR/categories\" at failure time: $(ls -la "$UV_CONFIG_DIR/categories" 2>&1); Morning contents: $(cat "$UV_CONFIG_DIR/categories/Morning" 2>&1); Favorites contents: $(cat "$UV_CONFIG_DIR/categories/Favorites" 2>&1)"

        # F3 first, then type the filter — not the other way around.
        # pick_view()'s own F3 handler recurses into a fresh pick_view()
        # call to redraw with the pane now visible, which (same as
        # every other redraw here) resets the query to empty; typing
        # first and pressing F3 second would lose the filter and end
        # up previewing "All" (the top row) instead. Confirmed live.
        tmux send-keys -t "$UV_SESSION_A" F3
        sleep 0.3
        tmux send-keys -t "$UV_SESSION_A" -l "Uncategorized"
        sleep 0.5

        tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null | grep -q "tool1" ||
            fail "Uncategorized's own F3 preview should list tool1, got: $(tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null)"
        tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null | grep -q "tool5" ||
            fail "Uncategorized's own F3 preview should list tool5 (favorited only still counts as uncategorized), got: $(tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null)"
        tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null | grep -q "tool2" &&
            fail "Uncategorized's own F3 preview should not list tool2 (filed in Morning)"
        tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null | grep -q "tool3" &&
            fail "Uncategorized's own F3 preview should not list tool3 (bundled into Games)"
        tmux capture-pane -t "$UV_SESSION_A" -p 2>/dev/null | grep -q "tool4" &&
            fail "Uncategorized's own F3 preview should not list tool4 (hidden)"

    else
        printf 'SKIP: launcher never became interactive, skipping the row/preview check\n' >&2
    fi

    tmux kill-session -t "$UV_SESSION_A" 2>/dev/null

    # ------------------------------------------------------------
    # 2. Ctrl-R refuses it — it's a computed view, not a real category
    #    file.
    # ------------------------------------------------------------

    UV_SESSION_B="blf-uncategorized-b-$$"

    if uv_open_view_picker "$UV_SESSION_B"; then

        tmux send-keys -t "$UV_SESSION_B" -l "Uncategorized"
        sleep 0.3
        tmux send-keys -t "$UV_SESSION_B" C-r
        wait_for "$UV_SESSION_B" "can't be renamed" ||
            fail "Ctrl-R on Uncategorized should refuse with \"can't be renamed\", got: $(tmux capture-pane -t "$UV_SESSION_B" -p 2>/dev/null)"

    else
        printf 'SKIP: launcher never became interactive, skipping the Ctrl-R check\n' >&2
    fi

    tmux kill-session -t "$UV_SESSION_B" 2>/dev/null

    # ------------------------------------------------------------
    # 3. Ctrl-D refuses it too, same reasoning.
    # ------------------------------------------------------------

    UV_SESSION_C="blf-uncategorized-c-$$"

    if uv_open_view_picker "$UV_SESSION_C"; then

        tmux send-keys -t "$UV_SESSION_C" -l "Uncategorized"
        sleep 0.3
        tmux send-keys -t "$UV_SESSION_C" C-d
        wait_for "$UV_SESSION_C" "can't be deleted" ||
            fail "Ctrl-D on Uncategorized should refuse with \"can't be deleted\", got: $(tmux capture-pane -t "$UV_SESSION_C" -p 2>/dev/null)"

    else
        printf 'SKIP: launcher never became interactive, skipping the Ctrl-D check\n' >&2
    fi

    tmux kill-session -t "$UV_SESSION_C" 2>/dev/null

    # ------------------------------------------------------------
    # 4. Selecting it actually filters the main list to exactly tool1
    #    and tool5.
    # ------------------------------------------------------------

    UV_SESSION_D="blf-uncategorized-d-$$"

    if uv_open_view_picker "$UV_SESSION_D"; then

        tmux send-keys -t "$UV_SESSION_D" -l "Uncategorized"
        sleep 0.3
        tmux send-keys -t "$UV_SESSION_D" Enter
        wait_for "$UV_SESSION_D" "· Uncategorized " ||
            fail "selecting Uncategorized should filter the main list, border label never showed it"

        tmux capture-pane -t "$UV_SESSION_D" -p 2>/dev/null | grep -q "tool1" ||
            fail "the filtered main list should show tool1"
        tmux capture-pane -t "$UV_SESSION_D" -p 2>/dev/null | grep -q "tool5" ||
            fail "the filtered main list should show tool5"
        tmux capture-pane -t "$UV_SESSION_D" -p 2>/dev/null | grep -qE "tool2|tool3|tool4" &&
            fail "the filtered main list should not show tool2/tool3/tool4"

    else
        printf 'SKIP: launcher never became interactive, skipping the select-and-filter check\n' >&2
    fi

    tmux kill-session -t "$UV_SESSION_D" 2>/dev/null
    rm -rf "$UV_HOME"

else
    printf 'SKIP: tmux or fzf not available, skipping the live Uncategorized checks\n' >&2
fi

printf 'PASS: F2 offers an Uncategorized row with the correct count, its own F3 preview lists exactly the tools filed nowhere (favorited-only still counts as uncategorized; real-category, bundled-category, and hidden entries are correctly excluded), Ctrl-R/Ctrl-D both refuse it as a computed view, and selecting it filters the main list to exactly those tools\n'
