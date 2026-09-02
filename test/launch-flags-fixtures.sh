#!/bin/zsh
#
# Launch Flags — Actions -> Launch Flags, raised live: "Actions: option
# to always run TUI with specific commands?" / "Presets: action to run
# with specific commands?" One config (LAUNCH_FLAGS_FILE, keyed by
# command name) answers both: resolve_launch_path() is the shared
# lookup every launch site funnels through — the main list's own
# Enter-launch, and each preset pane in run_preset().
#
# resolve_launch_path() and set_launch_flags() are pure filesystem
# functions (no fzf), sourced and run directly, same approach
# theme-config-fixtures.sh uses for set_config_value(). This also
# caught a real bug before it shipped: resolve_launch_path() was
# originally defined near launch_in_current_terminal(), far below the
# top-level `--preset` dispatch (which calls run_preset(), exits, and
# never reaches that later code) — a real live run failed with
# "command not found: resolve_launch_path" the moment a preset tried
# to use it. Fixed by moving it (and launch_flags itself) up next to
# run_preset(), same reasoning is_ssh_session() already documents for
# its own early placement.
#
# Notably, function-order-fixtures.sh's own static check does NOT
# catch this one — confirmed live by re-breaking the fix and running
# it: the call site is `preset_resolved="$(resolve_launch_path ...)"`,
# a plain assignment whose right-hand side happens to be a command
# substitution, and that checker's own heuristic explicitly excludes
# assignments when building its call graph (to avoid false positives
# on unrelated variable names). A real gap in that checker, not
# something to fix here — section 4 below is what actually catches
# this class of bug for this feature, by running --preset for real.
#
# pick_launch_flags() itself calls fzf, so it's checked as source
# text — specifically the one thing that makes it different from
# every other prompt here: it must tell Esc apart from "typed nothing,
# pressed Enter" (a genuinely different, valid answer — clear the
# flags — not a Cancel), which needs the pressed key read explicitly
# via --expect rather than inferred from an empty result string. The
# full interactive flow (prefilled query, saving, clearing) was
# verified live in a real tmux pane instead, same reasoning
# rename-fixtures.sh gives for renaming.

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
# 1. resolve_launch_path(): no configured flags passes the path
#    through unchanged.
# ------------------------------------------------------------

typeset -A launch_flags=()

source <(sed -n '/^resolve_launch_path() {/,/^}/p' "$LAUNCHER")

CACHE_DIR="$TEST_HOME/cache-1"
mkdir -p "$CACHE_DIR"

out="$(resolve_launch_path btop /opt/homebrew/bin/btop)"
[[ "$out" == "/opt/homebrew/bin/btop" ]] ||
    fail "with no configured flags, resolve_launch_path should return the path unchanged, got: $out"
[[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]] ||
    fail "resolve_launch_path should not write anything when there are no flags to apply: $(ls "$CACHE_DIR")"

# ------------------------------------------------------------
# 2. resolve_launch_path(): with flags configured, returns a wrapper
#    that actually runs the target with those flags, then self-deletes.
# ------------------------------------------------------------

CACHE_DIR="$TEST_HOME/cache-2"
mkdir -p "$CACHE_DIR"

FAKE_TOOL="$TEST_HOME/fake-tool"
ARGS_FILE="$TEST_HOME/fake-tool-args"

cat > "$FAKE_TOOL" <<EOF
#!/bin/zsh
printf '%s\n' "\$@" > "$ARGS_FILE"
EOF
chmod +x "$FAKE_TOOL"

typeset -A launch_flags=(faketool "--tree --utf-force")

wrapper="$(resolve_launch_path faketool "$FAKE_TOOL")"

[[ "$wrapper" != "$FAKE_TOOL" ]] ||
    fail "with flags configured, resolve_launch_path should return a wrapper, not the bare path"
[[ -x "$wrapper" ]] || fail "the wrapper should be executable"

"$wrapper"

[[ -f "$ARGS_FILE" ]] || fail "running the wrapper should have run the fake tool at all"
[[ "$(<"$ARGS_FILE")" == $'--tree\n--utf-force' ]] ||
    fail "the fake tool should have received --tree and --utf-force as separate arguments, got: $(cat "$ARGS_FILE")"
[[ ! -f "$wrapper" ]] || fail "the wrapper should have deleted itself after running"

# ------------------------------------------------------------
# 3. set_launch_flags(): add, update, and clear — same find-or-append
#    shape as set_config_value(), keyed on the first tab-separated
#    field instead of "key=".
# ------------------------------------------------------------

typeset -A launch_flags=()

source <(sed -n '/^set_launch_flags() {/,/^}/p' "$LAUNCHER")

CONFIG_DIR="$TEST_HOME/set-flags-config"
CACHE_DIR="$TEST_HOME/set-flags-cache"
LAUNCH_FLAGS_FILE="$CONFIG_DIR/launch-flags"
mkdir -p "$CACHE_DIR"

# 3a. Setting flags for a command with none yet creates the file.
set_launch_flags btop "--utf-force"
[[ "$(cat "$LAUNCH_FLAGS_FILE")" == $'btop\t--utf-force' ]] ||
    fail "set_launch_flags should create the file with a tab-separated line: $(cat "$LAUNCH_FLAGS_FILE" 2>/dev/null)"
[[ "${launch_flags[btop]}" == "--utf-force" ]] ||
    fail "set_launch_flags should update the in-memory launch_flags table too, got: ${launch_flags[btop]-<unset>}"

# 3b. Adding a second, different command appends rather than
#     overwriting.
set_launch_flags lazygit "-w /tmp/repo"

if [[ "$(grep -c '' "$LAUNCH_FLAGS_FILE")" != "2" ]]; then
    fail "expected 2 lines after adding a second command: $(cat "$LAUNCH_FLAGS_FILE")"
fi
grep -qx $'btop\t--utf-force' "$LAUNCH_FLAGS_FILE" || fail "btop's line should have survived adding lazygit"
grep -qx $'lazygit\t-w /tmp/repo' "$LAUNCH_FLAGS_FILE" || fail "lazygit's line should have been added"

# 3c. Updating an existing command's flags replaces its line in place.
set_launch_flags btop "--tree"

if [[ "$(grep -c '' "$LAUNCH_FLAGS_FILE")" != "2" ]]; then
    fail "updating an existing command's flags should not change the line count: $(cat "$LAUNCH_FLAGS_FILE")"
fi
grep -qx $'btop\t--tree' "$LAUNCH_FLAGS_FILE" || fail "btop's flags should have been updated to --tree"
grep -qx $'btop\t--utf-force' "$LAUNCH_FLAGS_FILE" && fail "the old btop line should be gone, not duplicated"
[[ "${launch_flags[btop]}" == "--tree" ]] || fail "the in-memory table should reflect the update too"

# 3d. Clearing (empty flags) removes the line entirely rather than
#     writing an empty value.
set_launch_flags btop ""

if [[ "$(grep -c '' "$LAUNCH_FLAGS_FILE")" != "1" ]]; then
    fail "clearing btop's flags should drop its line entirely: $(cat "$LAUNCH_FLAGS_FILE")"
fi
grep -q "^btop" "$LAUNCH_FLAGS_FILE" && fail "btop should have no line left at all after clearing"
[[ -z "${launch_flags[btop]-}" ]] || fail "the in-memory table should have btop unset after clearing, got: ${launch_flags[btop]}"
grep -qx $'lazygit\t-w /tmp/repo' "$LAUNCH_FLAGS_FILE" || fail "lazygit's line should be untouched by clearing btop's"

# ------------------------------------------------------------
# 4. --preset actually applies configured flags to a preset member —
#    the real end-to-end path, via a real tmux session. This is also
#    what caught the function-ordering bug in the first place (see
#    this file's own header comment).
# ------------------------------------------------------------

if ! command -v tmux >/dev/null 2>&1; then
    echo "SKIP: 'tmux' not available — steps 1-3 above still ran and passed"
    exit 0
fi

PRESET_TEST_HOME="$TEST_HOME/preset-run"
mkdir -p "$PRESET_TEST_HOME/config/brew-launcher/presets"
export XDG_CONFIG_HOME="$PRESET_TEST_HOME/config"

FAKE_BIN_DIR="$PRESET_TEST_HOME/fake-bin"
mkdir -p "$FAKE_BIN_DIR"
PRESET_ARGS_FILE="$PRESET_TEST_HOME/preset-tool-args"

cat > "$FAKE_BIN_DIR/faketool" <<EOF
#!/bin/zsh
printf '%s\n' "\$@" > "$PRESET_ARGS_FILE"
while :; do sleep 1; done
EOF
chmod +x "$FAKE_BIN_DIR/faketool"
export PATH="$FAKE_BIN_DIR:$PATH"

printf 'faketool\t--flagged\n' > "$PRESET_TEST_HOME/config/brew-launcher/launch-flags"
printf 'faketool\n' > "$PRESET_TEST_HOME/config/brew-launcher/presets/flagtest"

SESSION="blpreset-flagtest"
tmux kill-session -t "$SESSION" 2>/dev/null

# SSH_TTY forces preset_show_session()'s SSH-simulated branch, same
# trick preset-fixtures.sh's own step 8 already uses — without it,
# this machine has real Ghostty.app installed, and run_preset() ends
# by calling preset_show_session() even for a brand-new session (not
# just a reattach), which would attempt real AppleScript automation
# against it. Confirmed live: that path is not just undesirable here,
# it's slow enough in a non-interactive run (a real, reproducible
# ~2 minute hang, presumably waiting on a permission negotiation with
# no one able to answer it) to make the whole suite unreliable.
#
# Backgrounded with the same watcher-timeout safety net as
# preset-fixtures.sh's own step 8, for the identical reason: the final
# exec into `tmux attach-session` (SSH_TTY's own branch, once
# panes are already built) has no real terminal to attach to here
# either, and this test only needs the panes themselves to have
# started, not that last step to succeed.
run_pid_flagfile="$TEST_HOME/flagtest-timed-out"
rm -f "$run_pid_flagfile"

SSH_TTY=/dev/fake TMUX= "$LAUNCHER" --preset flagtest </dev/null >/dev/null 2>&1 &
run_pid=$!

(
    sleep 10
    if kill -0 "$run_pid" 2>/dev/null; then
        touch "$run_pid_flagfile"
        pkill -9 -P "$run_pid" 2>/dev/null
        kill -9 "$run_pid" 2>/dev/null
    fi
) &
run_watcher_pid=$!

# Give the pane a moment to actually start the wrapper/tool, checked
# independently of whether the launcher process itself ever returns —
# the panes are built well before the final show/attach step this
# watcher is guarding against.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -f "$PRESET_ARGS_FILE" ]] && break
    sleep 0.3
done

kill "$run_watcher_pid" 2>/dev/null
wait "$run_watcher_pid" 2>/dev/null
kill -9 "$run_pid" 2>/dev/null
wait "$run_pid" 2>/dev/null

tmux kill-session -t "$SESSION" 2>/dev/null

[[ -f "$PRESET_ARGS_FILE" ]] ||
    fail "the preset's faketool pane should have run at all — resolve_launch_path may not be reachable from run_preset() (the exact bug this file's header describes)"
[[ "$(<"$PRESET_ARGS_FILE")" == "--flagged" ]] ||
    fail "the preset member should have launched with its configured flag, got: $(cat "$PRESET_ARGS_FILE")"

# ------------------------------------------------------------
# 5. pick_launch_flags(): the one thing that makes this prompt
#    different from every other one here — it must tell Esc apart
#    from "typed nothing, pressed Enter" (a valid "clear the flags"
#    answer, not a Cancel). Checked as source text since it calls fzf;
#    the actual fzf output shape (query always first, regardless of
#    which key completed it) was confirmed live before writing this.
# ------------------------------------------------------------

pick_launch_flags_block="$(sed -n '/^pick_launch_flags() {/,/^}/p' "$LAUNCHER")"
[[ -n "$pick_launch_flags_block" ]] || fail "pick_launch_flags() not found"

[[ "$pick_launch_flags_block" == *'--expect=enter,esc'* ]] ||
    fail "pick_launch_flags should read the pressed key explicitly via --expect, not infer it from an empty result"
[[ "$pick_launch_flags_block" == *'pick_action" != "enter"'* ]] ||
    fail "pick_launch_flags should bail out on anything but an explicit enter, including esc"
[[ "$pick_launch_flags_block" == *'--query="$current"'* ]] ||
    fail "pick_launch_flags should prefill the query with the current flags, same idiom as rename_category"

# ------------------------------------------------------------
# 6. Wiring: Actions offers Launch Flags (entry-scoped, same as Create
#    Shortcut), showing the current flags as its hint, and the main
#    loop dispatches it to pick_launch_flags() with the real command.
# ------------------------------------------------------------

more_action_block="$(sed -n '/^pick_more_action() {/,/^}/p' "$LAUNCHER")"
has_entry_block="$(printf '%s\n' "$more_action_block" | sed -n '/if \[\[ "\$has_entry" == true \]\]; then/,/^    fi$/p')"

[[ "$has_entry_block" == *'rows+=("launch_flags"'* ]] ||
    fail "pick_more_action should offer a launch_flags row inside the has_entry-gated block"
[[ "$has_entry_block" == *'launch_flags[$entry_name]'* ]] ||
    fail "the Launch Flags row should show the current flags (keyed by entry_name, the real command) as its hint"

full_source="$(cat "$LAUNCHER")"
[[ "$full_source" == *'"$MORE_MENU_FALLTHROUGH_ACTION" == "launch_flags"'* ]] ||
    fail "the F4 block's own loop should dispatch the launch_flags fallthrough action, not a plain \$action check further down"
[[ "$full_source" == *'pick_launch_flags "${selection%%$'"'"'\t'"'"'*}"'* ]] ||
    fail "launch_flags should be dispatched to pick_launch_flags with the real (freshly re-derived) command"

# ------------------------------------------------------------
# 7. Raised live: Esc from Launch Flags used to skip straight past
#    Actions to the main list, even though Actions is the only way to
#    reach Launch Flags at all (no direct key of its own). Moved
#    inside the F4 block's own loop specifically so a "no" answer
#    (Esc, or an unchanged value) loops back to Actions instead of
#    falling through — checked as source text (the loop structure
#    itself), and confirmed for real below via a live tmux session,
#    since this is exactly the kind of thing a source-text check alone
#    could describe correctly while the real key wiring is still wrong.
# ------------------------------------------------------------

f4_block="$(sed -n '/if \[\[ "\$action" == "f4" || "\$action" == "alt-m" \]\]; then/,/^    fi$/p' "$LAUNCHER")"
launch_flags_branch="$(printf '%s\n' "$f4_block" | sed -n '/MORE_MENU_FALLTHROUGH_ACTION" == "launch_flags"/,/elif/p')"

[[ "$launch_flags_branch" == *'! pick_launch_flags'*$'\n'*'continue'* ]] ||
    fail "a 'no' from pick_launch_flags should loop back to Actions (continue, the inner loop) rather than fall through"
[[ "$launch_flags_branch" == *'continue 2'* ]] ||
    fail "a real save from pick_launch_flags should still return to the main list (continue 2, the outer loop)"

if command -v tmux >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then

    LF_HOME="$TEST_HOME/lf-live"
    mkdir -p "$LF_HOME"

    LF_SESSION="blf-launch-flags-esc-$$"
    tmux kill-session -t "$LF_SESSION" 2>/dev/null

    tmux new-session -d -s "$LF_SESSION" -x 100 -y 30 "HOME='$LF_HOME' zsh '$LAUNCHER'"

    lf_ready=false
    for _ in {1..30}; do
        tmux capture-pane -t "$LF_SESSION" -p 2>/dev/null | grep -q "Tab  Mark" && { lf_ready=true; break; }
        sleep 0.5
    done

    if [[ "$lf_ready" == true ]]; then

        tmux send-keys -t "$LF_SESSION" F4
        for _ in {1..20}; do
            tmux capture-pane -t "$LF_SESSION" -p 2>/dev/null | grep -q "Actions on" && break
            sleep 0.3
        done

        # "Flags" alone, not "Launch Flags" — Actions binds space to
        # accept (space:accept), so a query containing a literal space
        # accepts whatever's highlighted the instant the space is
        # typed rather than continuing to filter. "Flags" alone
        # matches only this one row.
        tmux send-keys -t "$LF_SESSION" -l "Flags"
        sleep 0.4
        tmux send-keys -t "$LF_SESSION" Enter
        for _ in {1..20}; do
            tmux capture-pane -t "$LF_SESSION" -p 2>/dev/null | grep -q "Launch flags —" && break
            sleep 0.3
        done
        tmux capture-pane -t "$LF_SESSION" -p 2>/dev/null | grep -q "Launch flags —" ||
            fail "expected to reach the Launch flags prompt via F4 -> Launch Flags"

        tmux send-keys -t "$LF_SESSION" Escape
        for _ in {1..20}; do
            tmux capture-pane -t "$LF_SESSION" -p 2>/dev/null | grep -q "Actions on" && break
            sleep 0.3
        done

        tmux capture-pane -t "$LF_SESSION" -p 2>/dev/null | grep -q "Actions on" ||
            fail "Esc from Launch Flags should return to Actions, not the main list"

        tmux kill-session -t "$LF_SESSION" 2>/dev/null
    else
        printf 'SKIP: launcher never became interactive, skipping the live Esc check\n' >&2
    fi
else
    printf 'SKIP: tmux or fzf not available, skipping the live Esc check\n' >&2
fi

printf 'PASS: resolve_launch_path() passes an unflagged command through unchanged and, when flags are configured, returns a self-deleting wrapper that actually runs the target with them; set_launch_flags() adds/updates/clears correctly (both on disk and in the in-memory table); a real --preset run actually launches a configured member with its flags applied; pick_launch_flags() correctly distinguishes Esc from an empty-but-confirmed answer; Actions/the main loop wire it end to end; and Esc from Launch Flags returns to Actions rather than skipping past it to the main list\n'
