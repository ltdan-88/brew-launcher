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

printf 'PASS: the main list marks rows via fzf --multi, the key/selection split handles one row identically to before and several correctly (keeping the pressed key intact), Hide/Favorite/Categorize branch on the marked count rather than on marks merely existing, Enter with several marked launches them through run_preset'"'"'s existing pane machinery and logs every one, and Create Preset is seeded by marks rather than replaced by them\n'
