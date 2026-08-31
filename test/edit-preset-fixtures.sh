#!/bin/zsh
#
# Edit Preset — F9's Ctrl-E, for rearranging (or adding/removing tools
# in) a preset you already created.
#
# Raised live: "option to rearrange TUIs in existing presets." Before
# this, the only way to change order was Create Preset again with the
# same name — always starting blank, so every tool had to be re-marked
# from scratch. edit_preset() reuses the exact same --internal-preset-
# tab mechanism (already covered end to end by preset-order-
# fixtures.sh) but seeds PRESET_ORDER_STATE_FILE from the preset file's
# *current* members/order instead of starting empty — that seeding
# step, and the "same file, no name prompt" save, are the genuinely new
# behavior this file covers. --internal-preset-tab itself is a plain
# CLI subcommand with no fzf involved, so the seed-then-reorder
# sequence is driven for real, the same technique preset-order-
# fixtures.sh uses. edit_preset()'s own fzf loop and launch_preset()'s
# Ctrl-E wiring are source-text assertions, same reasoning as
# rename-fixtures.sh — the full interactive flow was verified live in a
# real tmux pane instead (seeded badges, unmark-then-remark actually
# moving a tool to the end, and the resulting file on disk).

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

export PRESET_ORDER_BASE_FILE="$TEST_HOME/base"
export PRESET_ORDER_LIST_FILE="$TEST_HOME/list"
export PRESET_ORDER_STATE_FILE="$TEST_HOME/state"

# Same 5-field shape build_entries() produces — see preset-order-
# fixtures.sh's own fixture for why only command/display matter here.
cat > "$PRESET_ORDER_BASE_FILE" <<'EOF'
toolA	  toolA display	toolA	desc A	/bin/toolA
toolB	  toolB display	toolB	desc B	/bin/toolB
toolC	  toolC display	toolC	desc C	/bin/toolC
EOF

# ------------------------------------------------------------
# 1. Seeding: a preset file already has toolB, toolC (in that order).
#    edit_preset() writes exactly that into PRESET_ORDER_STATE_FILE,
#    then calls --internal-preset-tab "" to seed the badges from it —
#    unlike create_preset(), which starts this file empty.
# ------------------------------------------------------------

printf 'toolB\ntoolC\n' > "$PRESET_ORDER_STATE_FILE"

out="$("$LAUNCHER" --internal-preset-tab "")"
[[ -z "$out" ]] || fail "seeding (empty highlighted arg) should print nothing, got: $out"

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolB\ntoolC' ]] ||
    fail "seeding should not have changed the state, got: $state"

grep -q $'^toolB\t 1 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolB should already be badged 1 on the seeded screen: $(cat "$PRESET_ORDER_LIST_FILE")"
grep -q $'^toolC\t 2 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolC should already be badged 2 on the seeded screen: $(cat "$PRESET_ORDER_LIST_FILE")"
grep -q $'^toolA\t   ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolA (not in the preset) should stay unbadged: $(cat "$PRESET_ORDER_LIST_FILE")"

# ------------------------------------------------------------
# 2. Reordering: unmark-then-remark toolB moves it to the end — the
#    same "Tab again to move it" interaction the header text promises.
# ------------------------------------------------------------

"$LAUNCHER" --internal-preset-tab toolB >/dev/null   # unmark
"$LAUNCHER" --internal-preset-tab toolB >/dev/null   # remark -> end

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolC\ntoolB' ]] ||
    fail "unmark-then-remark toolB should move it after toolC, got: $state"

grep -q $'^toolC\t 1 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolC should now be badged 1: $(cat "$PRESET_ORDER_LIST_FILE")"
grep -q $'^toolB\t 2 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolB should now be badged 2 (moved to the end): $(cat "$PRESET_ORDER_LIST_FILE")"

# ------------------------------------------------------------
# 3. Adding a tool: marking toolA (not originally in the preset) with
#    the seeded state already in place appends it after what's there.
# ------------------------------------------------------------

"$LAUNCHER" --internal-preset-tab toolA >/dev/null

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolC\ntoolB\ntoolA' ]] ||
    fail "marking toolA should append it after the seeded members, got: $state"

# ------------------------------------------------------------
# 4. edit_preset() itself — source text, same reasoning as
#    create_preset()'s own coverage (it calls fzf directly).
# ------------------------------------------------------------

edit_preset_block="$(sed -n '/^edit_preset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$edit_preset_block" ]] || fail "edit_preset() not found"

[[ "$edit_preset_block" == *'TMUX_AVAILABLE" == false'* ]] ||
    fail "edit_preset should gate on TMUX_AVAILABLE, same as create_preset"

# Seeds from the preset FILE's own members, not an empty state.
[[ "$edit_preset_block" == *'existing_members+=("$line")'* ]] ||
    fail "edit_preset should read the preset file's existing members"
[[ "$edit_preset_block" == *'existing_members[@]}" > "$PRESET_ORDER_STATE_FILE"'* ]] ||
    fail "edit_preset should seed PRESET_ORDER_STATE_FILE from the preset's existing members"

# Builds its base list from "All", not whatever $entries/CURRENT_VIEW
# already were — see this function's own comment for why that differs
# from create_preset() on purpose — and restores both afterward.
[[ "$edit_preset_block" == *'CURRENT_VIEW="All"'* ]] ||
    fail "edit_preset should build its own tool list from All, not the caller's current view"
[[ "$edit_preset_block" == *'CURRENT_VIEW="$saved_view"'* && "$edit_preset_block" == *'entries=("${saved_entries[@]}")'* ]] ||
    fail "edit_preset should restore the caller's CURRENT_VIEW and \$entries before returning"

# No naming step — writes straight back to the same file, unlike
# create_preset()'s type-or-pick-a-name screen.
[[ "$edit_preset_block" != *'--print-query'* ]] ||
    fail "edit_preset should not prompt for a name — it edits the preset it was handed, in place"
[[ "$edit_preset_block" == *'> "$preset_file"'* ]] ||
    fail "edit_preset should write back to the same preset file"

# ------------------------------------------------------------
# 5. launch_preset() wiring: Ctrl-E is offered, expected, clickable,
#    and dispatches to edit_preset before redrawing the preset list.
# ------------------------------------------------------------

launch_preset_block="$(sed -n '/^launch_preset() {/,/^}/p' "$LAUNCHER")"
[[ -n "$launch_preset_block" ]] || fail "launch_preset() not found"

[[ "$launch_preset_block" == *'--expect=enter,ctrl-d,ctrl-r,ctrl-e'* ]] ||
    fail "launch_preset's fzf --expect should include ctrl-e"
[[ "$launch_preset_block" == *'Ctrl-E'*'[Edit]'* ]] ||
    fail "launch_preset's footer should offer Ctrl-E [Edit]"
[[ "$launch_preset_block" == *"'[Edit]'|Edit) pick_action=\"ctrl-e\""* ]] ||
    fail "launch_preset's click-word mapping should recognize an [Edit] click"
[[ "$launch_preset_block" == *'edit_preset "$preset_name"'* ]] ||
    fail "launch_preset should dispatch ctrl-e to edit_preset"

printf 'PASS: --internal-preset-tab correctly seeds badges from an existing preset'"'"'s members/order (not blank, unlike Create Preset), unmark-then-remark reorders as promised, marking a tool not originally in the preset appends it, edit_preset() builds its own All-based tool list (restoring the caller'"'"'s view/entries) and saves straight back to the same file with no name prompt, and launch_preset wires Ctrl-E end to end\n'
