#!/bin/zsh
#
# Run With Args — Actions -> Run With Args, raised live (from a
# summary of 1980s-launcher ideas): "Launch with Arguments...
# optionally prompt for arguments [before launching]."
#
# Deliberately separate from Launch Flags (a standing choice, always
# applied) — this is a one-off, forgotten immediately after. Prefilled
# with the current Launch Flags value as a convenience, but an empty
# answer here means "run it plain" (same as an ordinary Enter), not
# "clear the flags" the way it does in pick_launch_flags() — there's
# nothing stored to clear.
#
# run_with_args() calls fzf, so it's driven for real by stubbing fzf
# (a fake binary on PATH), same technique other interactive-but-
# scriptable pieces in this suite use. launch_in_current_terminal()
# itself is stubbed too, as a plain recorder rather than sourced for
# real — its own real exec chain would need a subshell (like
# update-all-fixtures.sh uses), but that would also hide every
# in-memory update this test cares about (launch_counts,
# last_launched_order): a subshell's changes to those never reach the
# parent once it exits. Recording what path it was actually asked to
# launch (checking the wrapper script's own content when one should
# exist) is both simpler and more precise than running a real exec
# chain just to prove the same thing indirectly.
#
# Sections 6-9 cover --internal-preview-usage, raised live: "would it
# be feasible to show what arguments are available?" On-demand only
# (F3/⌥D, never automatic) because this install list is full of games
# and animations that may not recognize --help and would otherwise
# flash on screen the moment the prompt opened. Invoked directly as a
# real subprocess of the actual binary (same style as
# actions-menu-fixtures.sh's own --internal-preview-action checks)
# rather than sourced, since it's a plain top-level CLI dispatch with
# no shared state to stub around.

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

FAKE_BIN="$TEST_HOME/fake-bin"
mkdir -p "$FAKE_BIN"

FAKE_TOOL="$TEST_HOME/fake-tool"
: > "$FAKE_TOOL"
chmod +x "$FAKE_TOOL"

CACHE_DIR="$TEST_HOME/cache"
CONFIG_DIR="$TEST_HOME/config"
LAUNCH_HISTORY_FILE="$CONFIG_DIR/launch-history"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

source <(sed -n '/^run_with_args() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^screen_border_label() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^launcher_update_marker() {/,/^}/p' "$LAUNCHER")

# Recorder, not the real launch_in_current_terminal() — see this
# file's own header comment for why.
LAUNCHED_PATH_FILE="$TEST_HOME/launched-path"
launch_in_current_terminal() {
    printf '%s' "$1" > "$LAUNCHED_PATH_FILE"
}

TERMINAL="current"
FZF_COLORS=""
FOOTER_CLICK_FILE="$TEST_HOME/footer-click"
SCRIPT_PATH="$LAUNCHER"
VERSION="test"
typeset -A outdated_formulas=()
LAST_LAUNCHED_COUNTER=0

# ------------------------------------------------------------
# 1. Esc: nothing launches, nothing logged.
# ------------------------------------------------------------

cat > "$FAKE_BIN/fzf" <<'EOF'
#!/bin/zsh
cat > /dev/null
printf '\nesc\n'
EOF
chmod +x "$FAKE_BIN/fzf"

typeset -A launch_flags=() launch_counts=() last_launched_order=()

PATH="$FAKE_BIN:$PATH" run_with_args faketool "$FAKE_TOOL"

[[ ! -f "$LAUNCHED_PATH_FILE" ]] || fail "Esc should not have launched anything, got path: $(cat "$LAUNCHED_PATH_FILE")"
[[ ! -f "$LAUNCH_HISTORY_FILE" ]] || fail "Esc should not have logged a launch"
[[ -z "${launch_counts[faketool]-}" ]] || fail "Esc should not have touched launch_counts"

# ------------------------------------------------------------
# 2. Enter with typed args: builds a wrapper that runs the tool with
#    exactly those args (as separate words, not one glued-together
#    string), launches *that*, and logs the run same as an ordinary
#    launch would.
# ------------------------------------------------------------

cat > "$FAKE_BIN/fzf" <<'EOF'
#!/bin/zsh
cat > /dev/null
printf '--tree --utf-force\nenter\n'
EOF
chmod +x "$FAKE_BIN/fzf"

PATH="$FAKE_BIN:$PATH" run_with_args faketool "$FAKE_TOOL"

[[ -f "$LAUNCHED_PATH_FILE" ]] || fail "confirmed args should have launched something"
launched_path="$(<"$LAUNCHED_PATH_FILE")"
[[ "$launched_path" != "$FAKE_TOOL" ]] ||
    fail "with args typed, run_with_args should launch a wrapper, not the bare tool path"
[[ -x "$launched_path" ]] || fail "the wrapper should be executable"
grep -qF -- "${(q)FAKE_TOOL} --tree --utf-force" "$launched_path" ||
    fail "the wrapper should run the tool with exactly those two arguments, got: $(cat "$launched_path")"

grep -qx "faketool" "$LAUNCH_HISTORY_FILE" ||
    fail "a one-off run should still be logged to launch history, same as an ordinary launch"
[[ "${launch_counts[faketool]-}" == "1" ]] ||
    fail "launch_counts should have been incremented, got: ${launch_counts[faketool]-<unset>}"
[[ -n "${last_launched_order[faketool]-}" ]] ||
    fail "last_launched_order should have been set (Recently Launched should notice this run)"

# ------------------------------------------------------------
# 3. Enter with nothing typed: runs the tool plain (launches the bare
#    resolved path directly, no wrapper at all) — not "clear" the way
#    it is in pick_launch_flags().
# ------------------------------------------------------------

rm -f "$LAUNCHED_PATH_FILE"

cat > "$FAKE_BIN/fzf" <<'EOF'
#!/bin/zsh
cat > /dev/null
printf '\nenter\n'
EOF
chmod +x "$FAKE_BIN/fzf"

PATH="$FAKE_BIN:$PATH" run_with_args faketool "$FAKE_TOOL"

[[ -f "$LAUNCHED_PATH_FILE" ]] || fail "an empty-but-confirmed answer should still launch the tool"
[[ "$(<"$LAUNCHED_PATH_FILE")" == "$FAKE_TOOL" ]] ||
    fail "an empty answer should launch the bare tool path directly, no wrapper, got: $(cat "$LAUNCHED_PATH_FILE")"

# ------------------------------------------------------------
# 4. Prefilled with the current Launch Flags value, as a starting
#    point — not the same setting, just a convenient default.
# ------------------------------------------------------------

typeset -A launch_flags=(faketool "--already-configured")
QUERY_CAPTURE="$TEST_HOME/query-capture"

cat > "$FAKE_BIN/fzf" <<EOF
#!/bin/zsh
cat > /dev/null
for arg in "\$@"; do
    [[ "\$arg" == --query=* ]] && printf '%s\n' "\${arg#--query=}" > "$QUERY_CAPTURE"
done
printf '\nesc\n'
EOF
chmod +x "$FAKE_BIN/fzf"

PATH="$FAKE_BIN:$PATH" run_with_args faketool "$FAKE_TOOL"

[[ -f "$QUERY_CAPTURE" ]] || fail "the fzf invocation should have passed --query at all"
[[ "$(<"$QUERY_CAPTURE")" == "--already-configured" ]] ||
    fail "should prefill with the current Launch Flags value, got: $(cat "$QUERY_CAPTURE")"

# ------------------------------------------------------------
# 5. Wiring: Actions offers Run With Args (entry-scoped, right after
#    Launch Flags), and the main loop dispatches it with a real
#    resolved path, same fallback lookup Enter itself uses.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
has_entry_block="$(printf '%s\n' "$more_action_block" | sed -n '/if \[\[ "\$has_entry" == true \]\]; then/,/^    fi$/p')"

[[ "$has_entry_block" == *'rows+=("run_with_args"'* ]] ||
    fail "pick_more_action should offer a run_with_args row inside the has_entry-gated block"

full_source="$(cat "$LAUNCHER")"
[[ "$full_source" == *'"$action" == "run_with_args"'* && "$full_source" == *'run_with_args "$command" "$command_path"'* ]] ||
    fail "the main loop should dispatch run_with_args to run_with_args() with the real command and a resolved path"

# ------------------------------------------------------------
# 6. --internal-preview-usage: a tool that actually supports --help
#    gets its output shown, and fast (nowhere near the timeout).
# ------------------------------------------------------------

HELPFUL_TOOL="$TEST_HOME/helpful-tool"
cat > "$HELPFUL_TOOL" <<'EOF'
#!/bin/zsh
printf 'USAGE: helpful-tool [--flag]\n'
EOF
chmod +x "$HELPFUL_TOOL"

usage_output="$("$LAUNCHER" --internal-preview-usage "$HELPFUL_TOOL" 2>&1)"
[[ "$usage_output" == *'USAGE: helpful-tool'* ]] ||
    fail "--internal-preview-usage should show a tool's own --help output, got: $usage_output"

# ------------------------------------------------------------
# 7. A tool that ignores --help and hangs (the real risk this install
#    list carries — games/animations that launch straight into their
#    own full-screen mode instead of printing usage and exiting) gets
#    killed quickly rather than hanging the preview pane. No
#    `timeout`/`gtimeout` on stock macOS, so this has to actually
#    measure wall time, not just check the output.
# ------------------------------------------------------------

HANGING_TOOL="$TEST_HOME/hanging-tool"
cat > "$HANGING_TOOL" <<'EOF'
#!/bin/zsh
sleep 30
EOF
chmod +x "$HANGING_TOOL"

start_time=$SECONDS
usage_output="$("$LAUNCHER" --internal-preview-usage "$HANGING_TOOL" 2>&1)"
elapsed=$(( SECONDS - start_time ))

(( elapsed <= 5 )) ||
    fail "a tool that ignores --help and hangs should be killed quickly, took ${elapsed}s"
[[ "$usage_output" == *'No usage information available'* ]] ||
    fail "a killed/hung tool should fall back to a plain message, got: $usage_output"

sleep 1
if pgrep -f "$HANGING_TOOL" >/dev/null 2>&1; then
    fail "the hanging tool should have been killed, not left running"
fi

# ------------------------------------------------------------
# 8. A missing or non-executable path — same fallback message, no
#    crash. (edit_preset()'s own stale-member handling already proves
#    this codebase treats "installed at cache time, gone now" as a
#    normal case, not an error; this is the same idea for a path.)
# ------------------------------------------------------------

usage_output="$("$LAUNCHER" --internal-preview-usage "$TEST_HOME/does-not-exist" 2>&1)"
[[ "$usage_output" == *'No usage information available'* ]] ||
    fail "a missing path should fall back to a plain message, got: $usage_output"

usage_output="$("$LAUNCHER" --internal-preview-usage "" 2>&1)"
[[ "$usage_output" == *'No usage information available'* ]] ||
    fail "an empty path should fall back to a plain message, got: $usage_output"

# ------------------------------------------------------------
# 9. Wiring: run_with_args()'s own fzf call wires the preview up as
#    hidden-until-asked (F3/⌥D toggles it), not automatic.
# ------------------------------------------------------------

run_with_args_block="$(sed -n '/^run_with_args() {/,/^}/p' "$LAUNCHER")"

[[ "$run_with_args_block" == *'--internal-preview-usage'* ]] ||
    fail "run_with_args() should wire its fzf call to --internal-preview-usage"
[[ "$run_with_args_block" == *'preview-window='*'hidden'* ]] ||
    fail "run_with_args()'s preview should start hidden — on demand, not automatic"
[[ "$run_with_args_block" == *'f3,alt-d:toggle-preview'* ]] ||
    fail "run_with_args() should bind F3/⌥D to toggle-preview"

printf 'PASS: run_with_args() cancels cleanly on Esc (nothing launched, nothing logged, launch_counts untouched), builds a wrapper with exactly the typed arguments as separate words and launches that on Enter, launches the bare tool path directly (no wrapper) when nothing was typed, prefills from the current Launch Flags value as a starting point, logs every real run the same as an ordinary launch, Actions/the main loop wire it end to end, and its F3/⌥D usage preview shows a real --help, kills a tool that ignores it and hangs instead of blocking, falls back cleanly for a missing path, and stays hidden until asked\n'
