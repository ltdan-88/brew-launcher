#!/bin/zsh
#
# Presets (--preset <name>) test.
#
# Covers the CLI/parsing surface that doesn't need a live tmux session
# (missing name, unknown preset, an all-comments/blank preset file, and
# that comments/blank lines are actually skipped rather than treated
# as commands) on every runner, plus real tmux session behavior when
# tmux is available: the right number of panes gets created, and
# re-invoking the same preset while it's still running reattaches
# instead of spawning a duplicate session.
#
# Doesn't attempt to test the final attach-session/switch-client step
# itself — that needs a real attached terminal client, which no CI
# runner has. Session creation, pane count and reattach-dedup are the
# parts that are actually meaningful to verify without one.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

for dependency in fzf python3; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "SKIP: '$dependency' not available"
        exit 0
    fi
done

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export XDG_CONFIG_HOME="$TEST_HOME/config"
PRESETS_DIR="$XDG_CONFIG_HOME/brew-launcher/presets"
mkdir -p "$PRESETS_DIR"

# ------------------------------------------------------------
# 1. --preset with no name is rejected.
# ------------------------------------------------------------

if "$LAUNCHER" --preset >"$TEST_HOME/stdout.txt" 2>&1; then
    fail "--preset with no name should have been rejected"
fi
grep -qi "requires a name" "$TEST_HOME/stdout.txt" ||
    fail "rejection message should explain what went wrong: $(cat "$TEST_HOME/stdout.txt")"

# ------------------------------------------------------------
# 2. A preset name with no matching file is rejected.
# ------------------------------------------------------------

if "$LAUNCHER" --preset does-not-exist >"$TEST_HOME/stdout.txt" 2>&1; then
    fail "a nonexistent preset should have been rejected"
fi
grep -qi "not found" "$TEST_HOME/stdout.txt" ||
    fail "rejection message should say the preset wasn't found: $(cat "$TEST_HOME/stdout.txt")"

# ------------------------------------------------------------
# 3. A preset file with only comments/blank lines is rejected —
#    same "no real commands in here" check as an empty file.
# ------------------------------------------------------------

cat > "$PRESETS_DIR/empty" <<'EOF'
# just a comment

EOF

if "$LAUNCHER" --preset empty >"$TEST_HOME/stdout.txt" 2>&1; then
    fail "a preset with no real commands should have been rejected"
fi
grep -qi "no commands" "$TEST_HOME/stdout.txt" ||
    fail "rejection message should say there are no commands: $(cat "$TEST_HOME/stdout.txt")"

# ------------------------------------------------------------
# 4. Real tmux behavior — skipped if tmux isn't installed, same
#    pattern as the other dependency skips above.
# ------------------------------------------------------------

if ! command -v tmux >/dev/null 2>&1; then
    echo "SKIP: 'tmux' not available — steps 1-3 above still ran and passed"
    exit 0
fi

SESSION="blpreset-preset-fixtures-test"
tmux kill-session -t "$SESSION" 2>/dev/null

cat > "$PRESETS_DIR/preset-fixtures-test" <<'EOF'
# a comment, and a not-found command, should both be harmless
this-command-does-not-exist-anywhere
cat
cat
EOF

# `cat` with no arguments just blocks reading stdin — a real,
# harmless, long-running-enough process for pane-content purposes,
# already relied on elsewhere in this project's own tmux testing.
"$LAUNCHER" --preset preset-fixtures-test </dev/null >/dev/null 2>&1

pane_count="$(tmux list-panes -t "$SESSION" 2>/dev/null | wc -l | tr -d ' ')"
[[ "$pane_count" == "2" ]] ||
    fail "expected 2 panes (the not-found command skipped, 2 cats split), got: $pane_count"

# Re-invoking the same preset while it's still running should reattach
# rather than spawn a duplicate session or re-split panes.
"$LAUNCHER" --preset preset-fixtures-test </dev/null >/dev/null 2>&1

pane_count_after="$(tmux list-panes -t "$SESSION" 2>/dev/null | wc -l | tr -d ' ')"
[[ "$pane_count_after" == "2" ]] ||
    fail "re-invoking a running preset should not change pane count, got: $pane_count_after"

session_count="$(tmux list-sessions 2>/dev/null | grep -c '^blpreset-preset-fixtures-test:')"
[[ "$session_count" == "1" ]] ||
    fail "re-invoking a running preset should not spawn a second session, got: $session_count"

mouse_option="$(tmux show-options -t "$SESSION" mouse 2>/dev/null)"
[[ "$mouse_option" == "mouse on" ]] ||
    fail "preset session should have mouse mode on, got: $mouse_option"

# Forced on regardless of the user's own tmux config — otherwise a
# preset that only ends up with one live pane (like this fixture, one
# command skipped) is visually identical to a plain shell prompt, with
# nothing on screen saying a preset launched at all.
status_option="$(tmux show-options -t "$SESSION" status 2>/dev/null)"
[[ "$status_option" == "status on" ]] ||
    fail "preset session should have the status bar forced on, got: $status_option"

# ------------------------------------------------------------
# 5. Editing the preset file while its session is still running
#    should rebuild with the new pane count on the next invocation,
#    not reattach to the stale session from before the edit.
# ------------------------------------------------------------

cat > "$PRESETS_DIR/preset-fixtures-test" <<'EOF'
cat
EOF

"$LAUNCHER" --preset preset-fixtures-test </dev/null >/dev/null 2>&1

pane_count_edited="$(tmux list-panes -t "$SESSION" 2>/dev/null | wc -l | tr -d ' ')"
[[ "$pane_count_edited" == "1" ]] ||
    fail "editing a running preset down to 1 command should rebuild with 1 pane, got: $pane_count_edited"

session_count_edited="$(tmux list-sessions 2>/dev/null | grep -c '^blpreset-preset-fixtures-test:')"
[[ "$session_count_edited" == "1" ]] ||
    fail "rebuilding an edited preset should still leave exactly one session, got: $session_count_edited"

tmux kill-session -t "$SESSION" 2>/dev/null

printf 'PASS: missing name / unknown preset / no-commands preset all rejected, tmux session gets the right pane count, re-invoking reattaches instead of duplicating, mouse mode and the status bar are forced on, editing a running preset rebuilds instead of staying stale\n'
