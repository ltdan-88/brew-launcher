#!/bin/zsh
#
# Header click — clicking the NAME or SIZE column header in the main
# list toggles Sort the same way Actions -> Sort already does, without
# needing to open a menu for it. Confirmed feasible via fzf's own
# click-header event before building this; confirmed live afterward
# that --delimiter=$'\t' (needed for the list's own real/display
# split) makes fzf stop splitting the header into words the way it
# does for click-footer, reporting the whole header line as one "word"
# instead — FZF_CLICK_HEADER_COLUMN still works in that situation, so
# --internal-header-click does its own column math against the exact
# FZF_HEADER string instead of relying on FZF_CLICK_HEADER_WORD.
#
# --internal-header-click needs no cache, no fzf, and no real entries
# — it's pure string/column arithmetic against whatever FZF_HEADER and
# FZF_CLICK_HEADER_COLUMN say, so it's invoked directly on the real
# binary rather than only checked as source text. run_fzf()'s own bind
# wiring and the main loop's dispatch are still source-text checks,
# same reasoning rename-fixtures.sh gives for the pickers themselves.

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

CACHE_DIR="$TEST_HOME/cache"
mkdir -p "$CACHE_DIR"
HEADER_CLICK_FILE="$TEST_HOME/header-click"

# Same layout build_fzf_header() itself produces — a leading
# LEFT_MARKER_WIDTH-wide blank field, then NAME/VERSION/SIZE padded to
# fixed widths, then DESCRIPTION unpadded at the end.
FULL_HEADER="$(printf '%-4s%-10s%-10s%-8s%s' '' NAME VERSION SIZE DESCRIPTION)"

# Same shape, minus the marker field and the VERSION/SIZE columns —
# what build_fzf_header() produces when COMPACT_VIEW=on.
COMPACT_HEADER="$(printf '%-10s%s' NAME DESCRIPTION)"

click() {
    local header="$1" column="$2"
    rm -f "$HEADER_CLICK_FILE"
    FZF_HEADER="$header" FZF_CLICK_HEADER_COLUMN="$column" \
        CACHE_DIR="$CACHE_DIR" HEADER_CLICK_FILE="$HEADER_CLICK_FILE" \
        "$LAUNCHER" --internal-header-click
}

# ------------------------------------------------------------
# 1. Clicking inside "NAME" (columns 5-8) accepts and records NAME.
# ------------------------------------------------------------

output="$(click "$FULL_HEADER" 6)"
[[ "$output" == "accept" ]] || fail "clicking NAME should print accept, got: $output"
[[ -f "$HEADER_CLICK_FILE" ]] || fail "clicking NAME should write HEADER_CLICK_FILE"
[[ "$(cat "$HEADER_CLICK_FILE")" == "NAME" ]] ||
    fail "HEADER_CLICK_FILE should contain NAME, got: $(cat "$HEADER_CLICK_FILE")"

# ------------------------------------------------------------
# 2. Clicking inside "SIZE" (columns 25-28) accepts and records SIZE.
# ------------------------------------------------------------

output="$(click "$FULL_HEADER" 26)"
[[ "$output" == "accept" ]] || fail "clicking SIZE should print accept, got: $output"
[[ "$(cat "$HEADER_CLICK_FILE")" == "SIZE" ]] ||
    fail "HEADER_CLICK_FILE should contain SIZE, got: $(cat "$HEADER_CLICK_FILE")"

# ------------------------------------------------------------
# 3. Clicking inside "VERSION" (columns 15-21) is ignored — there's no
#    third sort order to switch to.
# ------------------------------------------------------------

output="$(click "$FULL_HEADER" 17)"
[[ "$output" == "ignore" ]] || fail "clicking VERSION should print ignore, got: $output"
[[ ! -f "$HEADER_CLICK_FILE" ]] || fail "clicking VERSION should not write HEADER_CLICK_FILE"

# ------------------------------------------------------------
# 4. Clicking blank space (the marker column before NAME) and
#    clicking DESCRIPTION are both ignored too.
# ------------------------------------------------------------

output="$(click "$FULL_HEADER" 2)"
[[ "$output" == "ignore" ]] || fail "clicking the blank marker column should print ignore, got: $output"

output="$(click "$FULL_HEADER" 40)"
[[ "$output" == "ignore" ]] || fail "clicking DESCRIPTION should print ignore, got: $output"

# ------------------------------------------------------------
# 5. Compact View's header has no SIZE column at all — a click where
#    SIZE would otherwise be is ignored, not mismatched onto whatever
#    text happens to sit there instead (DESCRIPTION, in this shape).
#    NAME still works exactly the same.
# ------------------------------------------------------------

output="$(click "$COMPACT_HEADER" 26)"
[[ "$output" == "ignore" ]] ||
    fail "Compact View has no SIZE column — a click there should print ignore, got: $output"

# Specifically targets the boundary a missing "SIZE not found" guard
# would get wrong: with no real "SIZE" substring to find, a naive
# %%SIZE* strip returns the whole string unchanged, so an unguarded
# version would compute a phantom "SIZE" range starting right where
# the real header text ends — one column past its actual length.
output="$(click "$COMPACT_HEADER" $(( ${#COMPACT_HEADER} + 1 )) )"
[[ "$output" == "ignore" ]] ||
    fail "clicking just past Compact View's header should not land on a phantom SIZE range, got: $output"

output="$(click "$COMPACT_HEADER" 2)"
[[ "$output" == "accept" ]] || fail "clicking NAME in Compact View should print accept, got: $output"
[[ "$(cat "$HEADER_CLICK_FILE")" == "NAME" ]] ||
    fail "Compact View's HEADER_CLICK_FILE should contain NAME, got: $(cat "$HEADER_CLICK_FILE")"

# ------------------------------------------------------------
# 6. Wiring: run_fzf() binds click-header and clears the side-channel
#    file first, FZF_HEADER is exported so the click handler's own
#    fresh subprocess can see it, and the main loop reads
#    HEADER_CLICK_FILE and maps NAME/SIZE onto the exact same
#    SORT_ORDER/set_config_value plumbing Actions -> Sort uses,
#    rebuilding the list before looping back.
# ------------------------------------------------------------

run_fzf_block="$(sed -n '/^run_fzf() {/,/^}/p' "$LAUNCHER")"
[[ "$run_fzf_block" == *'rm -f "$HEADER_CLICK_FILE"'* ]] ||
    fail "run_fzf() should clear HEADER_CLICK_FILE before every call"
[[ "$run_fzf_block" == *'click-header:transform:$SCRIPT_PATH --internal-header-click'* ]] ||
    fail "run_fzf() should bind click-header to --internal-header-click"

full_source="$(cat "$LAUNCHER")"
[[ "$full_source" == *'export FZF_HEADER'* ]] ||
    fail "FZF_HEADER should be exported so --internal-header-click's subprocess can read it"

[[ "$full_source" == *'if [[ -f "$HEADER_CLICK_FILE" ]]; then'* ]] ||
    fail "the main loop should check HEADER_CLICK_FILE after fzf exits"
[[ "$full_source" == *'NAME) new_sort_order='"'"'name'"'"' ;;'* ]] ||
    fail "the main loop should map a NAME header click onto SORT_ORDER=name"
[[ "$full_source" == *'SIZE) new_sort_order='"'"'size'"'"' ;;'* ]] ||
    fail "the main loop should map a SIZE header click onto SORT_ORDER=size"
[[ "$full_source" == *'set_config_value SORT "$new_sort_order"'* ]] ||
    fail "a header click should persist the new sort order via set_config_value, same as Actions -> Sort"

printf 'PASS: clicking NAME or SIZE in the main list column header accepts and records which one, VERSION/blank-space/DESCRIPTION clicks are ignored, Compact View correctly has no clickable SIZE column, and run_fzf()/the main loop wire the click through to the same SORT_ORDER/set_config_value plumbing Actions -> Sort already uses\n'
