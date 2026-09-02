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
#
# SSH_TTY (here and at every other real --preset invocation below,
# except the early argument-validation checks above, which return
# before ever building a session) forces preset_show_session()'s
# SSH-simulated branch — same reasoning step 8 further down already
# gives for its own use of it. Added after this exact line hung for
# real on a machine with Ghostty.app installed: run_preset() calls
# preset_show_session() once the panes are built (not just on a
# reattach), which without this attempts real Ghostty AppleScript
# automation — confirmed live to occasionally block for minutes,
# presumably on a permission negotiation nothing here can answer,
# rather than failing fast. None of what steps 4-7 actually check
# (pane count, reattach behavior, alternate-screen recovery) depends
# on which "show" path runs, so forcing this one is free.
SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset preset-fixtures-test </dev/null >/dev/null 2>&1

pane_count="$(tmux list-panes -t "$SESSION" 2>/dev/null | wc -l | tr -d ' ')"
[[ "$pane_count" == "2" ]] ||
    fail "expected 2 panes (the not-found command skipped, 2 cats split), got: $pane_count"

# Re-invoking the same preset while it's still running should reattach
# rather than spawn a duplicate session or re-split panes.
SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset preset-fixtures-test </dev/null >/dev/null 2>&1

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

SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset preset-fixtures-test </dev/null >/dev/null 2>&1

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

SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset preset-fixtures-big </dev/null >/dev/null 2>&1

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

SSH_TTY=/dev/fake TMUX= PATH="$BADTUI_BIN:$PATH" "$LAUNCHER" --preset preset-fixtures-badtui </dev/null >/dev/null 2>&1

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
# bug in the choice itself). Run with an explicit timeout, not just
# captured — this is the exact invocation shape that hung for real
# once preset_show_session() learned to relaunch the launcher on a
# clean detach: chaining that relaunch with a bare `;` meant a failed
# attach-session (no real terminal here, same as this test) still ran
# straight into a brand new fzf session against the same broken stdin,
# hanging instead of failing fast. && instead of ; fixed it — this
# guards against that exact regression coming back, not just the
# warning text.
notmux_output=""
notmux_timed_out_flag="$TEST_HOME/notmux-timed-out"
rm -f "$notmux_timed_out_flag"

SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset preset-fixtures-notmux </dev/null >"$TEST_HOME/notmux-output.txt" 2>&1 &
notmux_pid=$!

# The watcher records "still alive at 10s" (touches the flag file)
# BEFORE killing anything, not after — checking for surviving children
# post-kill doesn't work, since a killed parent's children are
# reparented (to PID 1) the instant it dies, no longer matching
# `pgrep -P $notmux_pid` at all by the time anything looks. Caught
# live: an earlier version of this test checked for children after the
# kill and reported PASS even with the bug deliberately reintroduced,
# because the real hang (an orphaned fzf, reparented once its actual
# parent — itself a live-relaunched instance of the launcher, not
# $notmux_pid directly — got killed) was already invisible to a
# parent-based check by the time it ran.
(
    sleep 10
    if kill -0 "$notmux_pid" 2>/dev/null; then
        touch "$notmux_timed_out_flag"
        pkill -9 -P "$notmux_pid" 2>/dev/null
        kill -9 "$notmux_pid" 2>/dev/null
    fi
) &
watcher_pid=$!

wait "$notmux_pid" 2>/dev/null
kill "$watcher_pid" 2>/dev/null
wait "$watcher_pid" 2>/dev/null

notmux_timed_out=false
[[ -f "$notmux_timed_out_flag" ]] && notmux_timed_out=true

notmux_output="$(<"$TEST_HOME/notmux-output.txt")"

[[ "$notmux_timed_out" == false ]] ||
    fail "launching a preset outside tmux with no real terminal should fail fast, not hang"

[[ "$notmux_output" == *"Not running inside tmux"* ]] ||
    fail "launching a preset outside tmux should warn before taking over the window, got: $notmux_output"

tmux kill-session -t "$NOTMUX_SESSION" 2>/dev/null

# ------------------------------------------------------------
# 9. Detaching from the Ghostty branch's window: raised live — a real,
#    named preset relaunches the picker into its new window on detach
#    on purpose (the payoff for detaching rather than quitting: the
#    session stays alive, reattachable later via F9, and you get the
#    picker back to do something else meanwhile in that same window).
#    An ad-hoc "Selection" session (mark rows, hit Enter) has no F9
#    entry to come back to, so the same relaunch just left it running
#    invisibly in the background with no way back to it, plus a second
#    live picker in the new window — exactly the redundant-instance
#    clutter already fixed for single-tool Ghostty launches. Detaching
#    from an ad-hoc session should instead kill it and let the window
#    close on its own, same as a plain tool launch.
#
#    Can't drive the Ghostty branch itself without a real Ghostty.app
#    (is_ssh_session forces it off for the section above, on purpose),
#    so this checks run_preset() passes its adhoc-ness through to both
#    of its preset_show_session() call sites, and that the AppleScript
#    source text's two branches do the right thing: the named branch
#    still relaunches unchanged; the ad-hoc branch kills the session
#    and does NOT reference launcherPath/exec into it at all.
# ------------------------------------------------------------

run_preset_body="$(sed -n '/^run_preset() {/,/^}/p' "$LAUNCHER")"
run_preset_calls="$(printf '%s\n' "$run_preset_body" | grep 'preset_show_session "\$preset_session"')"

[[ "$(printf '%s\n' "$run_preset_calls" | wc -l | tr -d ' ')" == "2" ]] ||
    fail "expected exactly 2 preset_show_session call sites in run_preset(), got: $run_preset_calls"

while IFS= read -r call_line; do
    [[ "$call_line" == *'"$preset_adhoc"'* ]] ||
        fail "run_preset() should pass \$preset_adhoc through to preset_show_session(), got: $call_line"
done <<< "$run_preset_calls"

preset_show_body="$(sed -n '/^preset_show_session() {/,/^}/p' "$LAUNCHER")"
# Comments stripped first — one of them explains the ad-hoc branch in
# prose that itself contains the word "else", which would otherwise
# fool a plain-text search for the AppleScript "else" keyword below.
preset_show_code="$(printf '%s\n' "$preset_show_body" | grep -v '^[[:space:]]*--')"
adhoc_branch="$(printf '%s\n' "$preset_show_code" | awk '/if isAdhoc is "true" then/,/else/')"
named_branch="$(printf '%s\n' "$preset_show_code" | awk '/^        else$/,/end if/')"

[[ "$adhoc_branch" == *'tmux kill-session -t \"$1\"'* ]] ||
    fail "the ad-hoc Ghostty branch should kill its own session once attach-session returns, instead of leaving it running with no way back to it"
[[ "$adhoc_branch" != *'launcherPath'* ]] ||
    fail "the ad-hoc Ghostty branch should not reference launcherPath at all — there's nothing to relaunch into, the window should just close"
[[ "$adhoc_branch" != *'exec \"$2\"'* ]] ||
    fail "the ad-hoc Ghostty branch should not exec back into the launcher — that would recreate the exact redundant-instance problem this exists to fix"

[[ "$named_branch" == *'&& exec \"$2\"'* ]] ||
    fail "a real named preset should still relaunch the picker into its new window on detach, unchanged — that persistence is the point of a named, F9-reattachable preset"

printf 'PASS: missing name / unknown preset / no-commands preset all rejected, tmux session gets the right pane count even well past the old ~4-pane ceiling, re-invoking reattaches instead of duplicating, mouse mode and the status bar are forced on, editing a running preset rebuilds instead of staying stale, a tool that dies mid-alternate-screen does not leave the pane stuck there, launching a preset outside tmux warns before taking over the window and fails fast rather than hanging when there is no real terminal to relaunch into, and detaching from an ad-hoc Ghostty-window session kills it and lets the window close instead of relaunching a redundant second picker\n'
