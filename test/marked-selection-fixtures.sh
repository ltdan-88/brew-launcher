#!/bin/zsh
#
# Mark-first multi-select — Tab marks rows on the main list itself
# (fzf's own --multi), and every action then acts on the marked set,
# falling back to the highlighted row when nothing is marked.
#
# This replaced three separate "... Multiple" Actions rows, each of
# which opened its own near-identical Tab-to-mark screen. Marking is
# context now, not a mode entered per action.
#
# The parsing this depends on is worth testing directly rather than
# only as source text: with --multi and --expect both on, fzf returns
# the pressed key on line 1 and then EVERY selected row after it, so
# the main loop's split has to keep working for one row (the
# overwhelmingly common case, unchanged behavior) and for several.
# That split is extracted and run for real below; the wiring around it
# is source-text, same reasoning rename-fixtures.sh gives for the
# pickers themselves.

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
# 1. The main list enables --multi, so Tab marks at all. Without
#    this the whole feature is inert — and the '●' marker that was
#    already set would stay invisible, as it was before.
# ------------------------------------------------------------

run_fzf_block="$(sed -n '/^run_fzf() {/,/^}/p' "$LAUNCHER")"
[[ -n "$run_fzf_block" ]] || fail "run_fzf() not found"

# Comment lines stripped before checking: run_fzf's own comment
# explains --multi at length, so a plain substring search passes even
# with the actual option deleted. Caught by deliberately removing the
# option and watching this assertion still go green.
run_fzf_code="$(printf '%s\n' "$run_fzf_block" | grep -v '^[[:space:]]*#')"
[[ "$run_fzf_code" == *'--multi'* ]] ||
    fail "run_fzf should enable --multi so Tab marks rows on the main list"
[[ "$run_fzf_block" == *"--marker='●'"* ]] ||
    fail "run_fzf should set a marker glyph for marked rows"

# ------------------------------------------------------------
# 2. The key/selection split itself, run for real against the exact
#    shape fzf produces. One selected row must behave identically to
#    how it always did (that's the untouched common path), and several
#    must all come through.
# ------------------------------------------------------------

# The real slicing logic, lifted straight out of the launcher rather
# than reimplemented here — an earlier version of this test wrote its
# own copy, which meant a deliberate off-by-one in the launcher (:1 ->
# :2, dropping the first marked row) sailed straight through green.
# Extracted and eval'd instead, so it genuinely exercises the shipped
# code.
marked_slice="$(sed -n '/^    marked_entries=/,/^    done$/p' "$LAUNCHER")"
[[ -n "$marked_slice" ]] || fail "could not extract the marked-set slicing block from the main loop"

parse_marked() {
    local fzf_result="$1"
    local -a result_lines marked_entries marked_commands
    local marked_line

    result_lines=("${(@f)fzf_result}")

    eval "$marked_slice"

    printf '%s|%s\n' "${result_lines[1]}" "${(j:,:)marked_commands}"
}

single="enter"$'\n'"btop"$'\t'"btop"$'\t'"btop"$'\t'"Resource monitor"
got="$(parse_marked "$single")"
[[ "$got" == "enter|btop" ]] ||
    fail "one selected row should parse to key=enter and exactly one command, got: $got"

several="f7"$'\n'"btop"$'\t'"btop"$'\t'"btop"$'\t'"desc"$'\n'"yazi"$'\t'"yazi"$'\t'"yazi"$'\t'"desc"$'\n'"glow"$'\t'"glow"$'\t'"glow"$'\t'"desc"
got="$(parse_marked "$several")"
[[ "$got" == "f7|btop,yazi,glow" ]] ||
    fail "three marked rows should all parse through, in order, got: $got"

# An F-key with several marked keeps the key on line 1 — the marked
# set must not swallow it, or every action would misdispatch.
[[ "${got%%|*}" == "f7" ]] ||
    fail "the pressed key must survive parsing when several rows are marked"

# ------------------------------------------------------------
# 3. Hide/Favorite/Categorize branch on the marked count: more than
#    one goes to the batch function, one or none takes the original
#    single-entry path completely untouched.
# ------------------------------------------------------------

for bulk_fn in bulk_hide bulk_favorite bulk_categorize; do
    [[ "$full_source" == *"$bulk_fn \"\${marked_commands[@]}\""* ]] ||
        fail "the main loop should hand the marked commands to $bulk_fn"
done

[[ "$full_source" == *'(( ${#marked_commands[@]} > 1 ))'* ]] ||
    fail "the main loop should branch on the marked count, not on marks merely existing"

# The single-entry toggles must still be reachable — a batch is one
# direction for everything marked, but one row still toggles.
[[ "$full_source" == *'toggle_favorite "$command"'* ]] ||
    fail "the single-entry F7 path should still toggle, not add"

# ------------------------------------------------------------
# 4. Enter with several marked launches them together through
#    run_preset()'s own pane machinery, and records every one of them
#    as launched so Most Used / Recently Launched still notice.
# ------------------------------------------------------------

[[ "$full_source" == *'run_preset "Selection" "${marked_commands[@]}"'* ]] ||
    fail "Enter with several marked should launch them via run_preset's ad-hoc path"
[[ "$full_source" == *'log_launch_batch "${marked_commands[@]}"'* ]] ||
    fail "a multi-launch should log every marked command, not just one"

log_batch_block="$(sed -n '/^log_launch_batch() {/,/^}/p' "$LAUNCHER")"
[[ -n "$log_batch_block" ]] || fail "log_launch_batch() not found"
[[ "$log_batch_block" == *'LAUNCH_HISTORY_FILE'* && "$log_batch_block" == *'launch_counts'* ]] ||
    fail "log_launch_batch should update both the history file and the in-memory launch counts"

# ------------------------------------------------------------
# 5. run_preset()'s ad-hoc mode: commands passed as arguments skip the
#    file entirely, but everything after that is the same code path a
#    real preset takes — that reuse is the whole point.
# ------------------------------------------------------------

run_preset_block="$(sed -n '/^run_preset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$run_preset_block" ]] || fail "run_preset() not found"
[[ "$run_preset_block" == *'preset_adhoc=true'* ]] ||
    fail "run_preset should detect the ad-hoc (commands-as-arguments) mode"
[[ "$run_preset_block" == *'if [[ "$preset_adhoc" == false ]]; then'* ]] ||
    fail "run_preset should skip the preset-file read entirely in ad-hoc mode"
[[ "$run_preset_block" == *'tmux split-window'* ]] ||
    fail "run_preset should still be the single place that builds panes — ad-hoc must not duplicate it"

# tmux is required for a multi-launch exactly as it is for a preset,
# and says so in terms that fit what was actually attempted.
[[ "$run_preset_block" == *'tmux is required to launch several tools at once'* ]] ||
    fail "a multi-launch without tmux should explain itself in its own terms, not as a preset error"

# ------------------------------------------------------------
# 6. Create Preset is seeded by the marks rather than replaced by
#    them — its ordered picker still exists, because a preset's launch
#    order matters and marks carry no order.
# ------------------------------------------------------------

create_preset_block="$(sed -n '/^create_preset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$create_preset_block" ]] || fail "create_preset() not found"
[[ "$create_preset_block" == *'--internal-preset-tab'* ]] ||
    fail "create_preset should still use its own ordered-badge picker — marks have no order"
[[ "$create_preset_block" == *'for seed_command in "${marked_commands[@]}"'* ]] ||
    fail "create_preset should seed its picker from whatever was already marked"

# ------------------------------------------------------------
# 7. Every entry-scoped action either uses the marked set or says it
#    isn't. Marks visibly set while an action silently acts on one row
#    reads as a bug even when each half is individually reasonable.
# ------------------------------------------------------------

# Update: one brew run across every marked formula that's outdated.
[[ "$full_source" == *'update_marked "${marked_formulas[@]}"'* ]] ||
    fail "Update should act on the marked formulae when several are marked"

# Create Shortcut: one file per marked entry.
[[ "$full_source" == *'create_shortcut "${marked_commands[$marked_index]}" "${marked_formulas[$marked_index]}"'* ]] ||
    fail "Create Shortcut should make one shortcut per marked entry"

# marked_formulas has to stay index-aligned with marked_commands, or
# Create Shortcut pairs a command with the wrong formula.
[[ "$full_source" == *'marked_formulas+=("${marked_rest%%$'"'"'\t'"'"'*}")'* ]] ||
    fail "marked_formulas should be built alongside marked_commands, index-aligned"

# The two that deliberately don't use marks must say so rather than
# staying silent about it.
for scoped_fn in pick_launch_flags run_with_args; do
    fn_block="$(sed -n "/^${scoped_fn}() {/,/^}/p" "$LAUNCHER")"
    [[ "$fn_block" == *'marked_count'* ]] ||
        fail "$scoped_fn should know how many rows were marked so it can say it's acting on one"
    [[ "$fn_block" == *'(( marked_count > 1 ))'* ]] ||
        fail "$scoped_fn should only mention marks when several actually are marked"
done

# ------------------------------------------------------------
# 8. update_marked() run for real: only the outdated marked formulae
#    are upgraded, and — the part that actually bit — each arrives as
#    its OWN argument.
#
#    Quoting inline in the heredoc looked equivalent and wasn't: the
#    heredoc flattens the array before (q) runs, escaping the
#    separators too, so brew received one mangled argument. Caught by
#    generating the script and running it against a brew that prints
#    its own argv, which is what this reproduces.
# ------------------------------------------------------------

UM_HOME="$(mktemp -d)"
mkdir -p "$UM_HOME/bin" "$UM_HOME/cache"
printf '#!/bin/zsh\nfor a in "$@"; do print -r -- "ARG:[$a]"; done\n' > "$UM_HOME/bin/brew"
chmod +x "$UM_HOME/bin/brew"

CACHE_DIR="$UM_HOME/cache"
TERMINAL="current"
typeset -A outdated_formulas=(btop 1.4 "weird name" 2.0 glow 3.0)
LAUNCHED_SCRIPT=""
launch_in_current_terminal() { LAUNCHED_SCRIPT="$1"; }

source <(sed -n '/^update_marked() {/,/^}/p' "$LAUNCHER")

# fastfetch is marked but NOT outdated — it must be filtered out.
update_marked btop fastfetch "weird name" >/dev/null 2>&1

[[ -n "$LAUNCHED_SCRIPT" && -f "$LAUNCHED_SCRIPT" ]] ||
    fail "update_marked should have built and launched an upgrade script"

um_args="$(PATH="$UM_HOME/bin:$PATH" zsh "$LAUNCHED_SCRIPT" 2>/dev/null | grep '^ARG:')"

[[ "$um_args" == *'ARG:[btop]'* ]] ||
    fail "btop should be passed to brew as its own argument, got: $um_args"
[[ "$um_args" == *'ARG:[weird name]'* ]] ||
    fail "a formula containing a space must survive as ONE argument, not be split or merged — got: $um_args"
[[ "$um_args" != *'ARG:[btop weird name]'* ]] ||
    fail "formulae were collapsed into a single argument — the heredoc quoting bug is back: $um_args"
[[ "$um_args" != *fastfetch* ]] ||
    fail "a marked but already-up-to-date formula should be filtered out, got: $um_args"

# Nothing outdated among the marked set: no script, no brew run.
LAUNCHED_SCRIPT=""
update_marked fastfetch >/dev/null 2>&1
[[ -z "$LAUNCHED_SCRIPT" ]] ||
    fail "update_marked should launch nothing when none of the marked formulae are outdated"

rm -rf "$UM_HOME"

# ------------------------------------------------------------
# 10. Live footer feedback while marking — raised live: pressing Tab
#     gave zero on-screen feedback beyond the small marker dot on the
#     row itself, so someone marking a row out of curiosity had no way
#     to discover what happens next without already knowing to check
#     F4. build_footer() now takes a marked_count and, once it's above
#     zero, replaces the normal nav line with one that says how many
#     are marked and spells out what Enter now does — updated live,
#     inside a still-open fzf session, via explicit tab/shift-tab
#     binds that chain fzf's own toggle+down/toggle+up onto
#     transform-footer(...), which re-invokes this script as
#     --internal-marked-footer using fzf's own $FZF_SELECT_COUNT.
#
#     Can't run this end to end here — footer_actions()/build_footer()
#     use a `${(l:...)}` construct that reports "parameter not set"
#     under `set -u` even though it works fine unsourced (same
#     footgun compact-view-fixtures.sh and actions-menu-fixtures.sh
#     already worked around the same way) — so this is source text,
#     confirmed working live instead via a real fzf session in tmux:
#     marking two rows showed "2 marked" immediately, no lag, at every
#     footer width tier, and unmarking back to zero correctly restored
#     the plain "Tab Mark" footer.
# ------------------------------------------------------------

build_footer_block="$(sed -n '/^build_footer() {/,/^}/p' "$LAUNCHER")"

[[ "$build_footer_block" == *'marked_count="${2:-0}"'* ]] ||
    fail "build_footer should accept a marked_count parameter, defaulting to 0"
[[ "$build_footer_block" == *'marked_count > 0'* ]] ||
    fail "build_footer should branch on whether anything is marked"
[[ "$build_footer_block" == *'Launch $marked_count marked'* ]] ||
    fail "build_footer's marked-state nav line should say how many are marked and that Enter launches them"
[[ "$build_footer_block" == *'Launch $marked_count]'* ]] ||
    fail "build_footer's narrower marked-state nav_short should still show the count"

run_fzf_full_block="$(sed -n '/^run_fzf() {/,/^}/p' "$LAUNCHER")"

[[ "$run_fzf_full_block" == *'local esc_hint="$5"'* ]] ||
    fail "run_fzf should accept esc_hint as a 5th parameter, needed by the live-marking footer bind"
[[ "$run_fzf_full_block" == *'tab:toggle+down+transform-footer('* ]] ||
    fail "run_fzf should bind tab to fzf's own toggle+down default plus a live footer update, not silently drop the transform"
[[ "$run_fzf_full_block" == *'shift-tab:toggle+up+transform-footer('* ]] ||
    fail "run_fzf should bind shift-tab to fzf's own toggle+up default plus a live footer update, not silently drop the transform"
[[ "$run_fzf_full_block" == *'--internal-marked-footer'* ]] ||
    fail "run_fzf's tab/shift-tab binds should invoke --internal-marked-footer"

# Raised live: right-click already marks a row by default (fzf's own
# behavior whenever --multi is on), completely undocumented until a
# user found it themselves — nothing on screen ever prompted anyone to
# try it. That makes the live footer feedback more important here than
# for Tab, not less: a text hint in an already-packed footer wouldn't
# reach someone who never went looking for one, but reacting the
# instant they actually try right-clicking will. No "+down"/"+up" —
# unlike Tab/Shift-Tab, a click already lands on the row clicked.
[[ "$run_fzf_full_block" == *'right-click:toggle+transform-footer('* ]] ||
    fail "run_fzf should bind right-click to fzf's own toggle default plus a live footer update, same reasoning as tab/shift-tab above"

run_fzf_call_site="$(grep -A6 'run_fzf \\$' "$LAUNCHER")"

[[ "$run_fzf_call_site" == *'"$restore_position" \'*$'\n''            "$esc_hint"'* ]] ||
    fail "the main loop's run_fzf call should pass \$esc_hint through as the 5th argument, right after \$restore_position, got: $run_fzf_call_site"

internal_marked_footer_block="$(sed -n '/if \[\[ "\$1" == "--internal-marked-footer" \]\]; then/,/^fi/p' "$LAUNCHER")"

[[ -n "$internal_marked_footer_block" ]] ||
    fail "--internal-marked-footer dispatch not found"
[[ "$internal_marked_footer_block" == *'build_footer "$2" "${FZF_SELECT_COUNT:-0}"'* ]] ||
    fail "--internal-marked-footer should call build_footer with esc_hint and fzf's own \$FZF_SELECT_COUNT"

printf 'PASS: the main list marks rows via fzf --multi, the key/selection split handles one row identically to before and several correctly (keeping the pressed key intact), Hide/Favorite/Categorize branch on the marked count rather than on marks merely existing, Enter with several marked launches them through run_preset'"'"'s existing pane machinery and logs every one, Create Preset is seeded by marks rather than replaced by them, Update and Create Shortcut both act on the marked set (Update as a single brew run, with each formula passed as its own argument and already-current ones filtered out), Launch Flags/Run With Args say they are acting on one row when several are marked, and the footer updates live the instant something is marked (via Tab/Shift-Tab or right-click alike) instead of staying silent until an action is taken\n'
