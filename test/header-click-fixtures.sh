#!/bin/zsh
#
# Header click — clicking the NAME or SIZE column header in the main
# list sorts by it directly, the same SORT_ORDER Actions -> Sort
# already offers, without needing to open a menu for it. Clicking the
# column that's already active flips its direction instead of doing
# nothing, spreadsheet-style — see build_fzf_header()'s own sort
# arrow, shown right on whichever label is currently active.
#
# Confirmed feasible via fzf's own click-header event before building
# this; confirmed live afterward that --delimiter=$'\t' (needed for
# the list's own real/display split) makes fzf stop splitting the
# header into words the way it does for click-footer, reporting the
# whole header line as one "word" instead — FZF_CLICK_HEADER_COLUMN
# still works in that situation, so --internal-header-click does its
# own column math against the exact FZF_HEADER string instead of
# relying on FZF_CLICK_HEADER_WORD.
#
# --internal-header-click needs no cache, no fzf, and no real entries
# — it's pure string/column arithmetic against whatever FZF_HEADER and
# FZF_CLICK_HEADER_COLUMN say, so it's invoked directly on the real
# binary rather than only checked as source text. run_fzf()'s own bind
# wiring is a source-text check, same reasoning rename-fixtures.sh
# gives for the pickers themselves; the main loop's own direction-
# cycling dispatch is extracted and eval'd directly instead (see
# section 6 below), since its behavior has enough real states (four
# sort values, six transitions between them) to be worth actually
# running rather than only pattern-matching its source text.

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
# 6. The sort arrow itself: build_fzf_header() sourced and run
#    directly (no fzf/cache needed — pure string building) against
#    each of the four SORT_ORDER values, confirming the right label
#    gets the right arrow and the other one stays bare. Compact View
#    with a size-based sort active has no SIZE column to attach an
#    arrow to at all — silently omitted, not guessed at.
# ------------------------------------------------------------

FAVORITE_MARKER_TEXT="+"
CATEGORIZED_MARKER_TEXT="#"
LEFT_MARKER_WIDTH=4
max_name=20
max_version=10
max_size=10

source <(sed -n '/^build_fzf_header() {/,/^}/p' "$LAUNCHER")

COMPACT_VIEW="off"

SORT_ORDER="name"
build_fzf_header
[[ "$FZF_HEADER" == *'NAME ↑'* ]] || fail "SORT_ORDER=name should show NAME ↑, got: $FZF_HEADER"
[[ "$FZF_HEADER" == *'SIZE'* && "$FZF_HEADER" != *'SIZE ↑'* && "$FZF_HEADER" != *'SIZE ↓'* ]] ||
    fail "SORT_ORDER=name should leave SIZE bare, got: $FZF_HEADER"

SORT_ORDER="name-desc"
build_fzf_header
[[ "$FZF_HEADER" == *'NAME ↓'* ]] || fail "SORT_ORDER=name-desc should show NAME ↓, got: $FZF_HEADER"

SORT_ORDER="size"
build_fzf_header
[[ "$FZF_HEADER" == *'SIZE ↓'* ]] || fail "SORT_ORDER=size should show SIZE ↓, got: $FZF_HEADER"
[[ "$FZF_HEADER" == *'NAME'* && "$FZF_HEADER" != *'NAME ↑'* && "$FZF_HEADER" != *'NAME ↓'* ]] ||
    fail "SORT_ORDER=size should leave NAME bare, got: $FZF_HEADER"

SORT_ORDER="size-asc"
build_fzf_header
[[ "$FZF_HEADER" == *'SIZE ↑'* ]] || fail "SORT_ORDER=size-asc should show SIZE ↑, got: $FZF_HEADER"

# A size-based sort with no SIZE column to show it on — Compact View
# drops that column entirely, so the arrow has nowhere to attach and
# should be silently absent rather than guessed onto NAME instead.
COMPACT_VIEW="on"
SORT_ORDER="size"
build_fzf_header
[[ "$FZF_HEADER" != *'↓'* && "$FZF_HEADER" != *'↑'* ]] ||
    fail "Compact View with a size-based sort should show no arrow at all, got: $FZF_HEADER"
COMPACT_VIEW="off"

# ------------------------------------------------------------
# 7. Direction cycling: the main loop's own dispatch block, extracted
#    and eval'd inside a throwaway one-iteration loop (so its own
#    "continue" is harmless) with every side-effecting call stubbed
#    out — same reasoning update-tool-fixtures.sh gives for stubbing
#    launch_in_current_terminal() rather than re-deriving its own
#    logic here. Real behavior, not just source-text pattern-matching:
#    clicking the already-active column flips direction; clicking the
#    other one switches to it at that column's own default direction
#    (name ascending, size descending — unchanged from before
#    direction existed at all).
# ------------------------------------------------------------

header_click_block="$(sed -n '/if \[\[ -f "\$HEADER_CLICK_FILE" \]\]; then/,/^    fi$/p' "$LAUNCHER")"
[[ -n "$header_click_block" ]] ||
    fail "could not extract the HEADER_CLICK_FILE dispatch block from the main loop"

CONFIG_CALLS_FILE="$TEST_HOME/config-calls"

set_config_value() { printf '%s\n' "$2" >> "$CONFIG_CALLS_FILE"; }
build_fzf_header() { :; }
build_entries() { :; }
find_entry_position() { :; }

run_click_dispatch() {
    local HEADER_CLICK_FILE="$1"
    local SORT_ORDER="$2"
    local selection=$'fake-command\tfake-display\tfake-formula'
    local clicked_header new_sort_order restore_position
    for _ in 1; do
        eval "$header_click_block"
    done
    printf '%s' "$SORT_ORDER"
}

click_header_file() {
    local word="$1" f="$TEST_HOME/click-$RANDOM"
    printf '%s\n' "$word" > "$f"
    printf '%s' "$f"
}

: > "$CONFIG_CALLS_FILE"

result="$(run_click_dispatch "$(click_header_file NAME)" "name")"
[[ "$result" == "name-desc" ]] ||
    fail "clicking NAME while already sorted name (ascending) should flip to name-desc, got: $result"

result="$(run_click_dispatch "$(click_header_file NAME)" "name-desc")"
[[ "$result" == "name" ]] ||
    fail "clicking NAME while already sorted name-desc should flip back to name, got: $result"

result="$(run_click_dispatch "$(click_header_file NAME)" "size")"
[[ "$result" == "name" ]] ||
    fail "clicking NAME while sorted by size should switch to name's own default (ascending), got: $result"

result="$(run_click_dispatch "$(click_header_file SIZE)" "size")"
[[ "$result" == "size-asc" ]] ||
    fail "clicking SIZE while already sorted size (descending) should flip to size-asc, got: $result"

result="$(run_click_dispatch "$(click_header_file SIZE)" "size-asc")"
[[ "$result" == "size" ]] ||
    fail "clicking SIZE while already sorted size-asc should flip back to size, got: $result"

result="$(run_click_dispatch "$(click_header_file SIZE)" "name")"
[[ "$result" == "size" ]] ||
    fail "clicking SIZE while sorted by name should switch to size's own default (descending), got: $result"

grep -qx "name-desc" "$CONFIG_CALLS_FILE" ||
    fail "a header click's new sort order should be persisted via set_config_value, same as Actions -> Sort"

# ------------------------------------------------------------
# 8. Wiring: run_fzf() binds click-header and clears the side-channel
#    file first, and FZF_HEADER is exported so the click handler's own
#    fresh subprocess can see it.
# ------------------------------------------------------------

run_fzf_block="$(sed -n '/^run_fzf() {/,/^}/p' "$LAUNCHER")"
[[ "$run_fzf_block" == *'rm -f "$HEADER_CLICK_FILE"'* ]] ||
    fail "run_fzf() should clear HEADER_CLICK_FILE before every call"
[[ "$run_fzf_block" == *'click-header:transform:$SCRIPT_PATH --internal-header-click'* ]] ||
    fail "run_fzf() should bind click-header to --internal-header-click"

full_source="$(cat "$LAUNCHER")"
[[ "$full_source" == *'export FZF_HEADER'* ]] ||
    fail "FZF_HEADER should be exported so --internal-header-click's subprocess can read it"

printf 'PASS: clicking NAME or SIZE in the main list column header accepts and records which one, VERSION/blank-space/DESCRIPTION clicks are ignored, Compact View correctly has no clickable SIZE column, clicking the already-active column flips its direction while clicking the other switches to its own default direction, and run_fzf() wires the click through correctly\n'
