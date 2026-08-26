#!/usr/bin/env zsh
#
# --internal-preset-tab test — the handler behind Create Preset's
# numbered Tab marking. Exercises it directly, the same way a Tab
# press inside create_preset()'s fzf screen would (a fresh subprocess
# reading/writing the three PRESET_ORDER_* files it's handed via the
# environment), without needing a live fzf session to drive.

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

# Same 5-field shape build_entries() produces: command, display,
# formula, description, resolved_path. Only command and display
# matter here — display stands in for the real
# marker+name+version+size+description blob, and the badge gets
# prepended directly onto it.
cat > "$PRESET_ORDER_BASE_FILE" <<'EOF'
toolA	  toolA display	toolA	desc A	/bin/toolA
toolB	  toolB display	toolB	desc B	/bin/toolB
toolC	  toolC display	toolC	desc C	/bin/toolC
EOF
: > "$PRESET_ORDER_STATE_FILE"

# ------------------------------------------------------------
# 1. Marking builds the order up, one at a time.
# ------------------------------------------------------------

out="$("$LAUNCHER" --internal-preset-tab toolA)"
[[ "$out" == *"reload("* && "$out" == *"+down"* ]] ||
    fail "marking should print a reload+down transform action, got: $out"

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == "toolA" ]] || fail "expected state 'toolA', got: $state"

grep -q $'^toolA\t 1 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolA should be badged 1 after marking it first: $(cat "$PRESET_ORDER_LIST_FILE")"

"$LAUNCHER" --internal-preset-tab toolC >/dev/null

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolA\ntoolC' ]] ||
    fail "expected state 'toolA, toolC' in that order, got: $state"

grep -q $'^toolC\t 2 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolC should be badged 2 after marking it second: $(cat "$PRESET_ORDER_LIST_FILE")"

grep -q $'^toolB\t   ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolB should stay unbadged (blank), never marked: $(cat "$PRESET_ORDER_LIST_FILE")"

# ------------------------------------------------------------
# 2. Marking a third one, then unmarking the first, renumbers the
#    rest down rather than leaving a gap.
# ------------------------------------------------------------

"$LAUNCHER" --internal-preset-tab toolB >/dev/null

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolA\ntoolC\ntoolB' ]] ||
    fail "expected state 'toolA, toolC, toolB', got: $state"

"$LAUNCHER" --internal-preset-tab toolA >/dev/null

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolC\ntoolB' ]] ||
    fail "unmarking toolA should drop it from the state, got: $state"

grep -q $'^toolA\t   ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolA should be back to unbadged after unmarking: $(cat "$PRESET_ORDER_LIST_FILE")"

grep -q $'^toolC\t 1 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolC should renumber from 2 down to 1 once toolA is unmarked: $(cat "$PRESET_ORDER_LIST_FILE")"

grep -q $'^toolB\t 2 ' "$PRESET_ORDER_LIST_FILE" ||
    fail "toolB should stay 2 (only toolA's slot shifted): $(cat "$PRESET_ORDER_LIST_FILE")"

# ------------------------------------------------------------
# 3. An empty highlighted argument regenerates the list from the
#    current state without toggling anything or printing a reload —
#    the "just seed the initial screen" mode create_preset() uses once
#    up front, reusing this same code path instead of formatting the
#    blank badge a second time itself.
# ------------------------------------------------------------

out="$("$LAUNCHER" --internal-preset-tab "")"
[[ -z "$out" ]] || fail "an empty highlighted arg should print nothing, got: $out"

state="$(<"$PRESET_ORDER_STATE_FILE")"
[[ "$state" == $'toolC\ntoolB' ]] ||
    fail "an empty highlighted arg should not change the state, got: $state"

printf 'PASS: --internal-preset-tab marks in order, unmarking renumbers the rest down, and an empty arg only regenerates\n'
