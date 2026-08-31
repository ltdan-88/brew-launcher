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

# ------------------------------------------------------------
# 6. Real functional test of the fix raised live: "I tried editing a
#    preset and noticed that some TUIs that aren't listed anymore
#    still show up, break the numbering logic, but are not
#    selectable." Two distinct causes, both covered here:
#
#      - A HIDDEN (F6) but still-installed member used to be excluded
#        from edit_preset()'s own "All" base list the same way it's
#        excluded from the real All view, since build_entries() always
#        excludes hidden entries there — even though the member is
#        still perfectly real. edit_preset() now clears
#        hidden_commands for that one build.
#      - A genuinely uninstalled member has no row to build at all —
#        dropped from the seeded state instead, with a printed note,
#        rather than left in to eat a badge slot invisibly.
#
# fzf itself is stubbed (a fake binary on PATH) rather than driven for
# real — it just captures what edit_preset() built (the seeded state
# file, and whatever's piped to fzf as the rendered list) and reports
# Esc, so edit_preset() cancels cleanly with no interaction needed.
# This is the one thing the earlier source-text-only coverage above
# couldn't have caught: the actual runtime content of what gets seeded
# and rendered, not just that the right lines of code exist.
# ------------------------------------------------------------

EDIT_TEST_HOME="$(mktemp -d)"

export XDG_CACHE_HOME="$EDIT_TEST_HOME/cache"
export XDG_CONFIG_HOME="$EDIT_TEST_HOME/config"
CACHE_DIR="$XDG_CACHE_HOME/brew-launcher"
CONFIG_DIR="$XDG_CONFIG_HOME/brew-launcher"
PRESETS_DIR="$CONFIG_DIR/presets"
mkdir -p "$CACHE_DIR" "$PRESETS_DIR"

CACHE_FILE="$CACHE_DIR/entries"
cat > "$CACHE_FILE" <<'EOF'
visibletool	Visible tool	visibletool	1.0	1MB	0	visibletool	/bin/visibletool	100
hiddentool	Hidden tool	hiddentool	1.0	1MB	0	hiddentool	/bin/hiddentool	200
EOF

CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
{
    print -r -- "$CACHE_FORMAT_VERSION"
    print -r -- "fixture-state-snapshot"
} > "$CACHE_DIR/state"
: > "$CACHE_DIR/outdated"

printf 'visibletool\nhiddentool\nno-longer-installed-tool\n' > "$PRESETS_DIR/mixedpreset"

FAKE_BIN="$EDIT_TEST_HOME/fake-bin"
mkdir -p "$FAKE_BIN"
CAPTURED_LIST="$EDIT_TEST_HOME/captured-list"
CAPTURED_STATE="$EDIT_TEST_HOME/captured-state"

cat > "$FAKE_BIN/fzf" <<EOF
#!/bin/zsh
cat > "$CAPTURED_LIST"
cp "\$PRESET_ORDER_STATE_FILE" "$CAPTURED_STATE" 2>/dev/null || : > "$CAPTURED_STATE"
printf 'esc\n'
EOF
chmod +x "$FAKE_BIN/fzf"

# edit_preset() is only reachable through the interactive Actions menu
# — sourced and called directly here instead, with the same fixture
# globals build_entries() needs (same technique compact-view-fixtures.sh
# and sort-fixtures.sh already use).
FAVORITE_MARKER_TEXT="+"
CATEGORIZED_MARKER_TEXT="#"
UPDATE_INDICATOR_TEXT="*"
COMPACT_VIEW="off"
LEFT_MARKER_WIDTH=4
max_name=20
max_version=8
max_size=6
COMPUTED_VIEW_LIMIT="$(sed -n 's/^COMPUTED_VIEW_LIMIT=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
[[ -n "$COMPUTED_VIEW_LIMIT" ]] || fail "could not read COMPUTED_VIEW_LIMIT from $LAUNCHER"

typeset -A category_members favorite_commands categorized_commands
typeset -A outdated_formulas install_times launch_counts entry_sizes
typeset -A hidden_commands=(hiddentool 1)

CURRENT_VIEW="All"
entries=()

source <(sed -n '/^build_entries() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^edit_preset() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^screen_border_label() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^launcher_update_marker() {/,/^}/p' "$LAUNCHER")

SCRIPT_PATH="$LAUNCHER"
TMUX_AVAILABLE=true
FOOTER_CLICK_FILE="$EDIT_TEST_HOME/footer-click"
VERSION="test"
FZF_COLORS=""

note_output="$(PATH="$FAKE_BIN:$PATH" edit_preset mixedpreset 2>&1)"

echo "$note_output" | grep -q "no-longer-installed-tool" ||
    fail "should have printed a note naming the genuinely-uninstalled member, got: $note_output"
echo "$note_output" | grep -q "1 command" ||
    fail "should have said exactly 1 command was dropped, got: $note_output"

[[ -f "$CAPTURED_LIST" ]] || fail "edit_preset should have reached the fzf call at all"

grep -qE $'^visibletool\t 1 ' "$CAPTURED_LIST" ||
    fail "visibletool should be badged 1, got: $(cat "$CAPTURED_LIST")"
grep -qE $'^hiddentool\t 2 ' "$CAPTURED_LIST" ||
    fail "hiddentool (still installed, just hidden from the main list) should be badged 2 — not missing, and not skipping a number — got: $(cat "$CAPTURED_LIST")"
grep -q "no-longer-installed-tool" "$CAPTURED_LIST" &&
    fail "the genuinely uninstalled member has no row to show at all and should not appear in the rendered list: $(cat "$CAPTURED_LIST")"

[[ "$(<"$CAPTURED_STATE")" == $'visibletool\nhiddentool' ]] ||
    fail "the seeded state should keep visibletool and hiddentool, in order, dropping only the uninstalled one, got: $(cat "$CAPTURED_STATE")"

# ------------------------------------------------------------
# 7. Every member stale: the empty-array guard. Caught live before it
#    existed: `printf '%s\n' "${empty[@]}"` still writes one blank
#    line, which --internal-preset-tab reads back as one real
#    (empty-string) entry — silently eating badge #1 the exact same
#    way an unfiltered stale member would have.
# ------------------------------------------------------------

printf 'gone-tool-one\ngone-tool-two\n' > "$PRESETS_DIR/allstale"
rm -f "$CAPTURED_LIST" "$CAPTURED_STATE"

PATH="$FAKE_BIN:$PATH" edit_preset allstale >/dev/null 2>&1

[[ -f "$CAPTURED_STATE" ]] || fail "edit_preset should still reach fzf even when every member is stale"
[[ ! -s "$CAPTURED_STATE" ]] ||
    fail "the seeded state should be genuinely empty (0 bytes), not a single blank line, when every member is stale — got $(wc -c < "$CAPTURED_STATE") byte(s): $(cat -A "$CAPTURED_STATE" 2>/dev/null || od -c "$CAPTURED_STATE")"

rm -rf "$EDIT_TEST_HOME"

printf 'PASS: --internal-preset-tab correctly seeds badges from an existing preset'"'"'s members/order (not blank, unlike Create Preset), unmark-then-remark reorders as promised, marking a tool not originally in the preset appends it, edit_preset() builds its own All-based tool list (restoring the caller'"'"'s view/entries) and saves straight back to the same file with no name prompt, launch_preset wires Ctrl-E end to end, a hidden-but-installed member is included and correctly badged (not excluded the way All itself excludes it), a genuinely uninstalled member is dropped with a printed note instead of silently breaking the badge sequence, and seeding an entirely-stale preset leaves a genuinely empty state file rather than one phantom blank-line entry\n'
