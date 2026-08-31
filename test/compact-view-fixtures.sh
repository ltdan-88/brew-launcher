#!/bin/zsh
#
# Compact View (Actions -> Settings -> Compact View).
#
# Raised live: "detailed vs clean view" — clarified to mean the main
# list's own VERSION/SIZE columns specifically. build_entries() is
# sourced and actually run against a fixture cache, same technique
# sort-fixtures.sh already uses for SORT_ORDER=size — the real work
# here is confirming the VERSION/SIZE text is genuinely absent from
# the built display string when Compact View is on, not just blank or
# reordered. The column-header construction (FZF_HEADER) and the
# Settings row/dispatch are checked as source text: the former is a
# top-level computed constant, not a function, and the latter calls
# fzf.

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

CACHE_FILE="$TEST_HOME/entries"

# Fields: command, description, formula, version, size, outdated,
# full_name, resolved_path, install_time.
cat > "$CACHE_FILE" <<'EOF'
btop	Resource monitor	btop	1.4.7	1.5MB	0	btop	/bin/btop	100
EOF

COMPUTED_VIEW_LIMIT="$(sed -n 's/^COMPUTED_VIEW_LIMIT=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
[[ -n "$COMPUTED_VIEW_LIMIT" ]] || fail "could not read COMPUTED_VIEW_LIMIT from $LAUNCHER"

FAVORITE_MARKER_TEXT="+"
CATEGORIZED_MARKER_TEXT="#"
UPDATE_INDICATOR_TEXT="*"
LEFT_MARKER_WIDTH=4
max_name=20
max_version=8
max_size=6

typeset -A hidden_commands category_members favorite_commands
typeset -A categorized_commands outdated_formulas install_times launch_counts
typeset -A entry_sizes

source <(sed -n '/^build_entries() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. COMPACT_VIEW=off (default): the display string carries the
#    version and size, same as before this setting existed.
# ------------------------------------------------------------

CURRENT_VIEW="All"
COMPACT_VIEW="off"
build_entries

(( ${#entries[@]} == 1 )) || fail "expected 1 fixture entry, got ${#entries[@]}"

display="${entries[1]#*$'\t'}"
display="${display%%$'\t'*}"

echo "$display" | grep -q "1.4.7" ||
    fail "COMPACT_VIEW=off should show the version in the display string, got: $display"
echo "$display" | grep -q "1.5MB" ||
    fail "COMPACT_VIEW=off should show the size in the display string, got: $display"
echo "$display" | grep -q "Resource monitor" ||
    fail "the description should always show regardless of Compact View, got: $display"

# ------------------------------------------------------------
# 2. COMPACT_VIEW=on: the version and size are gone entirely, not
#    just blank — leaving the marker, name, and description.
# ------------------------------------------------------------

COMPACT_VIEW="on"
build_entries

display="${entries[1]#*$'\t'}"
display="${display%%$'\t'*}"

echo "$display" | grep -q "1.4.7" &&
    fail "COMPACT_VIEW=on should not show the version at all, got: $display"
echo "$display" | grep -q "1.5MB" &&
    fail "COMPACT_VIEW=on should not show the size at all, got: $display"
echo "$display" | grep -q "btop" ||
    fail "the name should still show in Compact View, got: $display"
echo "$display" | grep -q "Resource monitor" ||
    fail "the description should still show in Compact View, got: $display"

# ------------------------------------------------------------
# 3. Column header (FZF_HEADER): drops VERSION/SIZE when compact,
#    same as the row data itself. A top-level computed constant, not
#    a function, so checked as source text rather than sourced.
# ------------------------------------------------------------

header_block="$(sed -n '/^# Column header$/,/^fi$/p' "$LAUNCHER")"
[[ -n "$header_block" ]] || fail "column header block not found"

[[ "$header_block" == *'COMPACT_VIEW" == on'* ]] ||
    fail "the column header should branch on COMPACT_VIEW, same as build_entries()"
[[ "$header_block" == *'"NAME" \'*'"DESCRIPTION"'* ]] ||
    fail "the compact branch should still print NAME and DESCRIPTION"

# ------------------------------------------------------------
# 4. Wiring: Settings offers Compact View, and toggling it rebuilds
#    the list right away (same as Sort) rather than waiting for the
#    next incidental redraw.
# ------------------------------------------------------------

settings_action_block="$(sed -n '/^pick_settings_action() {/,/^}/p' "$LAUNCHER")"
open_settings_block="$(sed -n '/^open_settings_menu() {/,/^}/p' "$LAUNCHER")"

[[ "$settings_action_block" == *'rows+=("toggle_compact_view"'* ]] ||
    fail "pick_settings_action should offer a toggle_compact_view row"

toggle_block="$(printf '%s\n' "$open_settings_block" | sed -n '/toggle_compact_view)/,/;;/p')"
[[ "$toggle_block" == *'set_config_value COMPACT_VIEW'* ]] ||
    fail "toggling Compact View should persist via set_config_value, got: $toggle_block"
[[ "$toggle_block" == *"new_value='on'"* && "$toggle_block" == *"new_value='off'"* ]] ||
    fail "toggle_compact_view should cycle between 'on' and 'off', got: $toggle_block"
[[ "$toggle_block" == *'build_entries'* ]] ||
    fail "toggling Compact View should rebuild entries right away, same as Sort"

# Caught live before this line existed: build_entries() alone updates
# the row data, but FZF_HEADER is a separate computed value — without
# also recomputing it here, the column header kept advertising
# VERSION/SIZE right above rows that no longer had them.
[[ "$toggle_block" == *'build_fzf_header'* ]] ||
    fail "toggling Compact View should also rebuild the column header (build_fzf_header), not just the row data — otherwise it keeps showing VERSION/SIZE column names over rows that no longer have them"

printf 'PASS: build_entries() drops the version/size text entirely from the display string when Compact View is on (keeping the marker, name, and description), the column header branches the same way, and Settings -> Compact View toggles + persists it with an immediate rebuild of both the rows and the column header\n'
