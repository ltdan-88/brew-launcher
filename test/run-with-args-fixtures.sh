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

printf 'PASS: run_with_args() cancels cleanly on Esc (nothing launched, nothing logged, launch_counts untouched), builds a wrapper with exactly the typed arguments as separate words and launches that on Enter, launches the bare tool path directly (no wrapper) when nothing was typed, prefills from the current Launch Flags value as a starting point, logs every real run the same as an ordinary launch, and Actions/the main loop wire it end to end\n'
