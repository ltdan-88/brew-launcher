#!/bin/zsh
#
# "Launch a tool, quit it, land back in the launcher" test — raised
# live: quitting a tool used to always drop you into a plain shell,
# same as if you'd typed the command yourself. Someone who wants a
# plain shell can already open a new tab for that; the more useful
# default for a *launcher* is reappearing once the tool's done.
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
# direct source-text assertions instead — confirming they still exec
# into $SCRIPT_PATH rather than a plain shell, without needing either
# dependency present on the runner.

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
    SCRIPT_PATH="$FAKE_LAUNCHER"
    launch_in_current_terminal /usr/bin/true
) >/dev/null 2>&1

[[ -f "$MARKER_FILE" ]] ||
    fail "launch_in_current_terminal should exec into \$SCRIPT_PATH once the tool exits, but the fake launcher never ran"

[[ "$(<"$MARKER_FILE")" == "RELAUNCHED" ]] ||
    fail "marker file had unexpected content: $(<"$MARKER_FILE")"

# ------------------------------------------------------------
# 2. launch_in_tmux() and launch_in_ghostty(): can't run these end to
#    end without a real tmux session / Ghostty.app, so this asserts
#    directly on the source text instead — both should still exec into
#    $SCRIPT_PATH (quoted per each context's own convention) rather
#    than a plain `exec zsh`, the thing this whole fix replaced.
# ------------------------------------------------------------

tmux_line="$(sed -n '/^launch_in_tmux() {/,/^}/p' "$LAUNCHER")"
[[ "$tmux_line" == *'exec \"\$2\"'* ]] ||
    fail "launch_in_tmux should exec into \"\$2\" (SCRIPT_PATH) after the tool exits"
[[ "$tmux_line" == *'${(q)SCRIPT_PATH}'* ]] ||
    fail "launch_in_tmux should pass SCRIPT_PATH as the second quoted argument"

ghostty_block="$(sed -n '/^launch_in_ghostty() {/,/^}/p' "$LAUNCHER")"
[[ "$ghostty_block" == *'exec \"$2\"'* ]] ||
    fail "launch_in_ghostty should exec into \"\$2\" (launcherPath) after the tool exits"
[[ "$ghostty_block" == *'quoted form of launcherPath'* ]] ||
    fail "launch_in_ghostty should pass SCRIPT_PATH through as launcherPath"

printf 'PASS: quitting a launched tool relaunches the launcher instead of dropping to a plain shell, in all three launch paths\n'
