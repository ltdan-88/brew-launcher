#!/bin/zsh
#
# What happens after you quit a launched tool differs by launch path
# on purpose, and this pins down which does what.
#
# launch_in_current_terminal() relaunches the picker: quitting a tool
# used to always drop you into a plain shell there, same as if you'd
# typed the command yourself, and the more useful default for a
# *launcher* is reappearing once the tool's done. This is the one path
# where relaunching doesn't create a second, redundant live instance —
# it replaces the very session that was already running the picker
# before the tool launched, so there is no "elsewhere" to be redundant
# with.
#
# launch_in_tmux() and launch_in_ghostty() close the window/tab
# outright instead, on purpose too, and for the opposite reason: both
# open a brand-new window/tab for one tool while the picker you
# actually launched it from keeps running, untouched, in whichever
# window/tab you started from, so there's never anything to return to
# there. A first attempt (v0.62.0) fell back to a plain shell instead
# of relaunching, which fixed the redundant-launcher problem but left
# an empty window needing a manual "exit" to close — not what the very
# first version of this feature actually did before a one-shot CLI's
# fast exit turned out to close the window before there was any chance
# to read its output. The real fix keeps that original closing
# behavior (tmux does it on its own once nothing's left running in the
# window; Ghostty the same way, since it can't be told to close a tab
# directly — checked live, no "close" command in its AppleScript
# dictionary) and keeps the keypress pause too, so a fast command's
# output survives on screen until a key is pressed, then the
# window/tab closes exactly the same way a long-running TUI's does.
#
# launch_in_current_terminal() is dependency-free (no tmux, no
# Ghostty) and does an actual exec chain worth running for real:
# sourced directly and called in a subshell (so its final exec doesn't
# take out this test script), pointed at a fake "launcher" in place of
# the real one via $SCRIPT_PATH, and checked for a marker that fake
# script leaves behind once the real one's relaunch line reaches it.
#
# launch_in_tmux() and launch_in_ghostty() need a real tmux session /
# a real Ghostty.app to run end to end, so those two are covered as
# direct source-text assertions instead — confirming neither relaunches
# the picker nor falls to a plain shell, and that the keypress pause
# is still there to protect a one-shot CLI's output, without needing
# either dependency present on the runner. The actual close-on-exit
# behavior this relies on was confirmed live in tmux separately (real
# tool, real new window, quit, keypress, window gone) — not something
# a source-text check alone could prove.
#
# launch_in_ghostty() and preset_show_session() also both get checked
# for going through a window's "selected tab" before asking for
# "focused terminal", rather than asking a window for that property
# directly — Ghostty's own scripting dictionary source (checked
# directly: macos/Ghostty.sdef) never gives `window` a "focused
# terminal" property at all, only `tab` does, so asking a window for it
# was quietly resolving through some undefined fallback instead of a
# real, window-scoped lookup (see section 3 below). Same dependency
# limitation as above: source-text only, no real Ghostty.app on the
# runner.

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
# 1. launch_in_current_terminal(): quitting the tool should exec into
#    $SCRIPT_PATH, not a plain shell.
# ------------------------------------------------------------

FAKE_LAUNCHER="$TEST_HOME/fake-launcher"
MARKER_FILE="$TEST_HOME/marker"

cat > "$FAKE_LAUNCHER" <<EOF
#!/bin/zsh
printf 'RELAUNCHED\n' > "$MARKER_FILE"
EOF
chmod +x "$FAKE_LAUNCHER"

source <(sed -n '/^launch_in_current_terminal() {/,/^}/p' "$LAUNCHER")

(
    # The real script always exports this near the top, before any
    # function can run — sourcing just the one function skips that, so
    # it needs setting here too (a harmless nonexistent path is fine,
    # the function only ever `rm -f`s it). Caught live: this passed
    # locally only because an earlier real run in this same shell had
    # left FOOTER_CLICK_FILE set in the environment already — CI, with
    # a clean one, failed on `set -u` the moment the sourced function
    # referenced it, before ever reaching the exec chain this test is
    # actually about.
    FOOTER_CLICK_FILE="$TEST_HOME/footer-click"
    SCRIPT_PATH="$FAKE_LAUNCHER"
    launch_in_current_terminal /usr/bin/true
) >/dev/null 2>&1

[[ -f "$MARKER_FILE" ]] ||
    fail "launch_in_current_terminal should exec into \$SCRIPT_PATH once the tool exits, but the fake launcher never ran"

[[ "$(<"$MARKER_FILE")" == "RELAUNCHED" ]] ||
    fail "marker file had unexpected content: $(<"$MARKER_FILE")"

# ------------------------------------------------------------
# 1b. The "press any key" pause: raised live — a one-shot CLI
#     (fastfetch, eza, jq, ...) prints and exits in under a second, and
#     without a pause the relaunch above landed so fast the picker's
#     full-screen UI painted over that output before there was any
#     real chance to read it. Looked exactly like the command had
#     silently failed, when it had actually run fine.
#
# Two things to prove: the pause is genuinely there waiting on a
# keypress (checked live below via a real pty — the run above with no
# tty doesn't exercise this, since `read` returns immediately on EOF
# rather than blocking, which is also exactly why the run above never
# hangs in CI), and it doesn't turn a headless run (no tty at all,
# same as CI or --preset) into a hang.
# ------------------------------------------------------------

MARKER_FILE_2="$TEST_HOME/marker2"
cat > "$FAKE_LAUNCHER" <<EOF
#!/bin/zsh
printf 'RELAUNCHED\n' > "$MARKER_FILE_2"
EOF

pause_timed_out_flag="$TEST_HOME/pause-timed-out"
rm -f "$pause_timed_out_flag" "$MARKER_FILE_2"

(
    FOOTER_CLICK_FILE="$TEST_HOME/footer-click-2"
    SCRIPT_PATH="$FAKE_LAUNCHER"
    launch_in_current_terminal /usr/bin/true
) </dev/null >/dev/null 2>&1 &
headless_pid=$!

(
    sleep 5
    if kill -0 "$headless_pid" 2>/dev/null; then
        touch "$pause_timed_out_flag"
        kill -9 "$headless_pid" 2>/dev/null
    fi
) &
watcher_pid=$!

wait "$headless_pid" 2>/dev/null
kill "$watcher_pid" 2>/dev/null
wait "$watcher_pid" 2>/dev/null

[[ -f "$pause_timed_out_flag" ]] &&
    fail "launch_in_current_terminal's press-any-key pause should return immediately on EOF (no tty), not hang"

[[ -f "$MARKER_FILE_2" ]] ||
    fail "launch_in_current_terminal should still relaunch after the pause once \`read\` hits EOF"

# Now with a real pty, the pause should actually hold until a key
# arrives, rather than falling straight through. A plain subshell (as
# used above) has no controlling tty at all, so it never really
# exercises the wait, only the EOF fallback.
#
# tmux provides that real pty rather than a raw python pty.fork(),
# which was tried first here and gave a false failure: `read -k`
# never returned even after `send`-ing a keystroke, echoed by the
# kernel's own line discipline but seemingly never delivered to zsh.
# Re-run as plain `tmux send-keys` against a real tmux pane instead
# (below) and it worked first try — so that was a gap in what a raw
# pty.fork() emulates, the same class of gap already on record in this
# project for fzf hanging on cursor-position queries against one, not
# a bug in `read -k` itself. tmux is what real usage actually goes
# through for this launch path anyway, so it's the more honest test.
if command -v tmux >/dev/null 2>&1; then
    MARKER_FILE_3="$TEST_HOME/marker3"
    cat > "$FAKE_LAUNCHER" <<EOF
#!/bin/zsh
printf 'RELAUNCHED\n' > "$MARKER_FILE_3"
EOF
    rm -f "$MARKER_FILE_3"

    TMUX_SCRIPT="$TEST_HOME/tmux-script.zsh"
    cat > "$TMUX_SCRIPT" <<EOF
FOOTER_CLICK_FILE="$TEST_HOME/footer-click-3"
SCRIPT_PATH="$FAKE_LAUNCHER"
source <(sed -n '/^launch_in_current_terminal() {/,/^}/p' "$LAUNCHER")
launch_in_current_terminal /usr/bin/true
EOF

    TMUX_SESSION="brew-launcher-relaunch-test-$$"
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null

    tmux new-session -d -s "$TMUX_SESSION" -x 80 -y 24 "zsh '$TMUX_SCRIPT'"
    sleep 1.5

    still_waiting=true
    [[ -f "$MARKER_FILE_3" ]] && still_waiting=false

    tmux send-keys -t "$TMUX_SESSION" x
    sleep 1.5

    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null

    [[ "$still_waiting" == true ]] ||
        fail "launch_in_current_terminal should still be waiting on the press-any-key pause 1.5s in (before a key arrives)"

    [[ -f "$MARKER_FILE_3" ]] ||
        fail "launch_in_current_terminal should relaunch once a key arrives at the pause, but the fake launcher never ran"
else
    printf 'SKIP: tmux not found, skipping the real-pty press-any-key check\n' >&2
fi

# ------------------------------------------------------------
# 1c. A one-shot CLI's output must survive being run while the picker's
#     own alternate-screen mode is still active — the real bug behind
#     "fastfetch still quickly exits" even after the pause above
#     landed. fzf's own `--height=100%` still opens a genuine
#     alternate screen (confirmed live with a bare fzf under
#     pipe-pane: `--no-clear` only skips its erase-on-exit, it doesn't
#     avoid the alternate screen). A one-shot CLI that never touches
#     screen modes itself just inherits that, and the *after* printf
#     that exits alternate-screen mode — added for a different reason,
#     recovering a TUI that crashed mid-alternate-screen — was
#     switching straight back out of it once the command finished,
#     taking output with it that had nowhere else to go. Confirmed
#     live with a real tmux pane and pipe-pane capturing the raw byte
#     stream: fastfetch's output was genuinely being written in full,
#     just onto a buffer that exact printf then hid before there was
#     any chance to see it — the press-any-key prompt above was
#     working exactly as designed, but by the time it appeared the
#     output was already gone.
#
# Reproduced here the same way: a real tmux pane, alternate-screen
# mode turned on directly (standing in for the picker having done it)
# before launch_in_current_terminal ever runs, then capture-pane
# checked for the command's marker output once it's done — before any
# key is sent, so this is checking the same instant the bug showed up
# in, not after a redraw might have papered over it.
# ------------------------------------------------------------

if command -v tmux >/dev/null 2>&1; then
    MARKER_FILE_4="$TEST_HOME/marker4"
    cat > "$FAKE_LAUNCHER" <<EOF
#!/bin/zsh
printf 'RELAUNCHED\n' > "$MARKER_FILE_4"
EOF
    rm -f "$MARKER_FILE_4"

    ALT_SCREEN_COMMAND="$TEST_HOME/alt-screen-command"
    cat > "$ALT_SCREEN_COMMAND" <<'EOF'
#!/bin/zsh
printf 'ONE_SHOT_OUTPUT_MARKER\n'
EOF
    chmod +x "$ALT_SCREEN_COMMAND"

    TMUX_SCRIPT_2="$TEST_HOME/tmux-script-2.zsh"
    cat > "$TMUX_SCRIPT_2" <<EOF
printf '\033[?1049h'
FOOTER_CLICK_FILE="$TEST_HOME/footer-click-4"
SCRIPT_PATH="$FAKE_LAUNCHER"
source <(sed -n '/^launch_in_current_terminal() {/,/^}/p' "$LAUNCHER")
launch_in_current_terminal "$ALT_SCREEN_COMMAND"
EOF

    TMUX_SESSION_2="brew-launcher-relaunch-test-altscreen-$$"
    tmux kill-session -t "$TMUX_SESSION_2" 2>/dev/null

    tmux new-session -d -s "$TMUX_SESSION_2" -x 80 -y 24 "zsh '$TMUX_SCRIPT_2'"
    sleep 1.5

    pane_content="$(tmux capture-pane -t "$TMUX_SESSION_2" -p -S -100)"
    tmux send-keys -t "$TMUX_SESSION_2" x
    sleep 1

    tmux kill-session -t "$TMUX_SESSION_2" 2>/dev/null

    [[ "$pane_content" == *"ONE_SHOT_OUTPUT_MARKER"* ]] ||
        fail "a one-shot command's output should survive being run while the picker's alternate-screen mode is still active, not get switched away from before the press-any-key pause; got: $pane_content"
else
    printf 'SKIP: tmux not found, skipping the alternate-screen survival check\n' >&2
fi

# ------------------------------------------------------------
# 2. launch_in_tmux() and launch_in_ghostty(): can't run these end to
#    end without a real tmux session / Ghostty.app, so this asserts
#    directly on the source text instead — both should drop to a
#    plain `exec zsh` now, NOT relaunch $SCRIPT_PATH/launcherPath.
#    Comments are stripped before checking: both functions' own
#    comments mention $SCRIPT_PATH and "exec" while explaining why
#    they DON'T do that any more, which a plain substring search can't
#    tell apart from the code actually doing it.
# ------------------------------------------------------------

tmux_block="$(sed -n '/^launch_in_tmux() {/,/^}/p' "$LAUNCHER")"
tmux_code="$(printf '%s\n' "$tmux_block" | grep -v '^[[:space:]]*#')"

[[ "$tmux_code" != *'SCRIPT_PATH'* ]] ||
    fail "launch_in_tmux should no longer reference SCRIPT_PATH at all — it closes the window now, it doesn't relaunch into it"
# Exactly one "exec zsh" — the outer wrapper that runs the command in
# the first place. A second occurrence would mean a fallback shell got
# reintroduced at the end, which is exactly what used to leave the
# window open needing a manual "exit".
[[ "$(grep -o 'exec zsh' <<<"$tmux_code" | wc -l | tr -d ' ')" == "1" ]] ||
    fail "launch_in_tmux should exec into a plain zsh exactly once (the wrapper itself), not fall through to a second one at the end"
[[ "$tmux_code" == *'read -k 1 -s'* ]] ||
    fail "launch_in_tmux should still pause on a keypress — without it, a fast one-shot command's output would be lost the instant the window closes"
[[ "$tmux_code" == *'Press any key to close this window'* ]] ||
    fail "launch_in_tmux's pause should say it's about to close the window, not the old \"return to brew-launcher\" wording"
[[ "$(grep -o '1049l' <<<"$tmux_code" | wc -l | tr -d ' ')" == "1" ]] ||
    fail "launch_in_tmux should exit alternate-screen mode once, after the command — the 'before' exit only ever mattered for reusing the current pane, which a new window never does"

ghostty_block="$(sed -n '/^launch_in_ghostty() {/,/^}/p' "$LAUNCHER")"
ghostty_code="$(printf '%s\n' "$ghostty_block" | grep -v '^[[:space:]]*--')"

[[ "$ghostty_code" != *'launcherPath'* ]] ||
    fail "launch_in_ghostty should no longer reference launcherPath at all — it closes the tab now, it doesn't relaunch into it"
# Same reasoning as launch_in_tmux above.
[[ "$(grep -o 'exec zsh' <<<"$ghostty_code" | wc -l | tr -d ' ')" == "1" ]] ||
    fail "launch_in_ghostty should exec into a plain zsh exactly once (the wrapper itself), not fall through to a second one at the end"
[[ "$ghostty_code" == *'read -k 1 -s'* ]] ||
    fail "launch_in_ghostty should still pause on a keypress — without it, a fast one-shot command's output would be lost the instant the tab closes"
[[ "$ghostty_code" == *'Press any key to close this tab'* ]] ||
    fail "launch_in_ghostty's pause should say it's about to close the tab, not the old \"return to brew-launcher\" wording"
[[ "$(grep -o '1049l' <<<"$ghostty_code" | wc -l | tr -d ' ')" == "1" ]] ||
    fail "launch_in_ghostty should exit alternate-screen mode once, after the command — see launch_in_tmux's own comment for why"

# osascript itself should only be handed the one argument it still
# needs — a stray second one left over from the old relaunch path
# would silently do nothing, but it'd be a sign the revert was only
# half done.
osascript_call="$(printf '%s\n' "$ghostty_block" | grep -m1 'osascript -')"
[[ "$osascript_call" == *'osascript - "$command_path" <<'* ]] ||
    fail "launch_in_ghostty should call osascript with just \$command_path now, got: $osascript_call"

# ------------------------------------------------------------
# 3. The window-vs-tab "focused terminal" bug: raised live — marking
#    several TUIs and hitting Enter could open a genuinely new Ghostty
#    window with nothing but a bare shell in it, while the actual
#    session ended up attached in a tab on the already-open launcher
#    window instead. Not a caught AppleScript error (ruled out live —
#    no "Could not open a new Ghostty window" fallback message
#    appeared, meaning osascript itself reported success) and not the
#    system-wide "prefer tabs" preference (also ruled out live). A first
#    attempt added a `delay 0.3` on the theory that window-server focus
#    just hadn't caught up yet — that didn't fix it, and changed the
#    symptom (the fallback message started firing), which is what
#    prompted actually reading Ghostty's own scripting dictionary
#    source (macos/Ghostty.sdef) instead of guessing further.
#
#    That source settles it: `window` never has a "focused terminal"
#    property at all — only `tab` does. `focused terminal of newWindow`
#    was never a real, window-scoped lookup; it was quietly resolving
#    through some undefined fallback the whole time; no delay could
#    have fixed a wrong property path. The fix goes through the
#    window's own "selected tab" first (a freshly created window always
#    has exactly one, so this is never ambiguous) before asking that
#    tab for its "focused terminal", which really does exist on `tab`
#    and is guaranteed synchronous — checked directly in the app's
#    Swift source too (ScriptWindow.selectedTab / ScriptTab.
#    focusedTerminal), neither depends on anything that needs time to
#    settle. launch_in_ghostty()'s new-tab branch never had this bug —
#    "new tab" already returns a `tab` object directly — so it's
#    checked here too, as a control, to confirm nothing changed there.
#    None of this can be proven behaviorally without a real Ghostty.app
#    on the runner, so it's a source-text position check, same as the
#    rest of this section.
# ------------------------------------------------------------

[[ "$(printf '%s\n' "$ghostty_block" | grep -A1 'set newWindow to new window' | tail -1 | tr -d '[:space:]')" == "setnewTabtoselectedtabofnewWindow" ]] ||
    fail "launch_in_ghostty's new-window branch should go through the window's own selected tab before asking for a focused terminal, since window has no such property of its own"
[[ "$(printf '%s\n' "$ghostty_block" | grep -A1 'set newTab to new tab in front window' | tail -1 | tr -d '[:space:]')" == "setnewTerminaltofocusedterminalofnewTab" ]] ||
    fail "launch_in_ghostty's new-tab branch should still ask its (already correctly typed) tab directly for a focused terminal, unchanged"

preset_show_block="$(sed -n '/^preset_show_session() {/,/^}/p' "$LAUNCHER")"
[[ "$(printf '%s\n' "$preset_show_block" | grep -A1 'set newWindow to new window' | tail -1 | tr -d '[:space:]')" == "setnewTabtoselectedtabofnewWindow" ]] ||
    fail "preset_show_session's Ghostty path should go through the window's own selected tab before asking for a focused terminal, since window has no such property of its own"

printf 'PASS: launch_in_current_terminal() still relaunches the picker (the one path where that is not redundant), while launch_in_tmux() and launch_in_ghostty() both let the window/tab close on its own after a keypress pause, instead of relaunching into it or falling back to a plain shell that would need a manual exit; launch_in_ghostty() and preset_show_session() both reach a newly created window'\''s terminal through its selected tab rather than a nonexistent "focused terminal of window" property\n'
