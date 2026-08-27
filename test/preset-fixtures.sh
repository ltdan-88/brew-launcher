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

# ------------------------------------------------------------
# 6. A preset bigger than tmux's default split behavior can handle
#    without help. Found live: on a plain 80x24 terminal, splitting
#    kept halving whichever pane it was given rather than filling the
#    window grid-aware, so only 4 of 6 (and later, only 4 of 12) panes
#    ever got created — split-window failed silently on the rest ("no
#    space for a new pane"), with nothing telling the user tools had
#    been dropped. run_preset() now retiles into a grid after every
#    split, not just once at the end, so the window is always as full
#    as it can be before the next one is attempted. 12 comfortably
#    exceeds the old ~4-pane ceiling this bug had on a plain 80x24
#    session — this is the regression check for that ceiling coming
#    back, not a claim about a maximum panes count.
# ------------------------------------------------------------

BIG_SESSION="blpreset-preset-fixtures-big"
tmux kill-session -t "$BIG_SESSION" 2>/dev/null

for _ in $(seq 1 12); do printf 'cat\n'; done > "$PRESETS_DIR/preset-fixtures-big"

"$LAUNCHER" --preset preset-fixtures-big </dev/null >/dev/null 2>&1

big_pane_count="$(tmux list-panes -t "$BIG_SESSION" 2>/dev/null | wc -l | tr -d ' ')"
[[ "$big_pane_count" == "12" ]] ||
    fail "a 12-command preset should get 12 panes on a plain terminal, got: $big_pane_count"

tmux kill-session -t "$BIG_SESSION" 2>/dev/null

# ------------------------------------------------------------
# 7. A tool that enters alternate-screen mode and then dies without
#    restoring it (a real, common failure mode for a curses-based tool
#    that crashes instead of exiting cleanly) shouldn't leave the pane
#    stuck thinking it's still in alternate-screen mode once the
#    fallback shell takes over — found live via tmux's own
#    #{alternate_on}, confirmed still 1 even though a perfectly
#    ordinary, responsive shell was running underneath.
# ------------------------------------------------------------

BADTUI_SESSION="blpreset-preset-fixtures-badtui"
tmux kill-session -t "$BADTUI_SESSION" 2>/dev/null

BADTUI_BIN="$TEST_HOME/bin"
mkdir -p "$BADTUI_BIN"
cat > "$BADTUI_BIN/badtui" <<'EOF'
#!/bin/sh
printf '\033[?1049h\033[?25l\033[2J'
printf 'this is the "crashed" alternate screen'
exit 1
EOF
chmod +x "$BADTUI_BIN/badtui"

cat > "$PRESETS_DIR/preset-fixtures-badtui" <<'EOF'
badtui
EOF

PATH="$BADTUI_BIN:$PATH" "$LAUNCHER" --preset preset-fixtures-badtui </dev/null >/dev/null 2>&1

alternate_on="$(tmux display-message -p -t "$BADTUI_SESSION" '#{alternate_on}' 2>/dev/null)"
[[ "$alternate_on" == "0" ]] ||
    fail "pane should have exited alternate-screen mode after the tool died without doing so, got alternate_on=$alternate_on"

tmux kill-session -t "$BADTUI_SESSION" 2>/dev/null

# ------------------------------------------------------------
# 8. preset_show_session()'s three-way branch: SSH-simulated (the
#    standard SSH_TTY/SSH_CONNECTION/SSH_CLIENT env-var trio) skips
#    the local-GUI-window path entirely regardless of what's actually
#    installed on this machine, same as a real SSH session would.
#    Doesn't attempt the switch-client/attach-session step itself for
#    the same reason noted at the top of this file — no real attached
#    client to hand off to — but the *choice* of which one it takes,
#    and the warning printed before the unrecoverable one, are both
#    fully verifiable without one.
# ------------------------------------------------------------

NOTMUX_SESSION="blpreset-preset-fixtures-notmux"
tmux kill-session -t "$NOTMUX_SESSION" 2>/dev/null

cat > "$PRESETS_DIR/preset-fixtures-notmux" <<'EOF'
cat
EOF

# Not inside tmux: should warn before taking over, then attempt
# attach-session (fails here for the environment reason above, not a
# bug in the choice itself).
notmux_output="$(SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset preset-fixtures-notmux </dev/null 2>&1)"

[[ "$notmux_output" == *"Not running inside tmux"* ]] ||
    fail "launching a preset outside tmux should warn before taking over the window, got: $notmux_output"

tmux kill-session -t "$NOTMUX_SESSION" 2>/dev/null

printf 'PASS: missing name / unknown preset / no-commands preset all rejected, tmux session gets the right pane count even well past the old ~4-pane ceiling, re-invoking reattaches instead of duplicating, mouse mode and the status bar are forced on, editing a running preset rebuilds instead of staying stale, a tool that dies mid-alternate-screen does not leave the pane stuck there, launching a preset outside tmux warns before taking over the window\n'
