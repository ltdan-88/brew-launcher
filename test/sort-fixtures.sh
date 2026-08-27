#!/bin/zsh
#
# SORT_ORDER=size test (Actions → Sort).
#
# Raised live: "would an option for sorting by name or size make
# sense?" Name is just the cache's own alphabetical order, already
# free on every view — the real work is size_sort_key() (parsing a
# display string like "1.7MB" back into a comparable number of bytes)
# and build_entries()'s reuse of the same zero-padded sort-key
# mechanism computed-view-fixtures.sh already covers for Most Used/
# Recently Added. Same technique here: build_entries() sourced and
# actually run against a fixture cache, not reimplemented.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

source <(sed -n '/^size_sort_key() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. size_sort_key(): real units parsed correctly, larger units sort
#    ahead of smaller ones as bytes, unrecognized input sorts as 0
#    rather than erroring.
# ------------------------------------------------------------

[[ "$(size_sort_key "1KB")" == "1024" ]] ||
    fail "1KB should be 1024 bytes, got $(size_sort_key "1KB")"

[[ "$(size_sort_key "1MB")" == "1048576" ]] ||
    fail "1MB should be 1048576 bytes, got $(size_sort_key "1MB")"

(( $(size_sort_key "1.6GB") > $(size_sort_key "999MB") )) ||
    fail "1.6GB should sort ahead of 999MB"

(( $(size_sort_key "27.3MB") > $(size_sort_key "410.8KB") )) ||
    fail "27.3MB should sort ahead of 410.8KB"

[[ "$(size_sort_key "-")" == "0" ]] ||
    fail "an unparseable size (\"-\") should sort as 0, got $(size_sort_key "-")"

[[ "$(size_sort_key "")" == "0" ]] ||
    fail "an empty size should sort as 0, got $(size_sort_key "")"

# ------------------------------------------------------------
# 2. build_entries(): SORT_ORDER=size reorders "All" largest-first,
#    without capping it the way Most Used/Recently Added are capped.
# ------------------------------------------------------------

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

CACHE_FILE="$TEST_HOME/entries"

# Fields: command, description, formula, version, size, outdated,
# full_name, resolved_path, install_time.
cat > "$CACHE_FILE" <<'EOF'
apple	Apple tool	apple	1.0	1MB	0	apple	/bin/apple	100
banana	Banana tool	banana	1.0	500KB	0	banana	/bin/banana	500
cherry	Cherry tool	cherry	1.0	2.5GB	0	cherry	/bin/cherry	300
date	Date tool	date	1.0	10MB	0	date	/bin/date	700
elderberry	Elderberry tool	elderberry	1.0	1KB	0	elderberry	/bin/elderberry	200
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

CURRENT_VIEW="All"
SORT_ORDER="size"
build_entries

if (( ${#entries[@]} != 5 )); then
    fail "SORT_ORDER=size on All: expected all 5 fixture entries, got ${#entries[@]} — sorting by size should reorder, not filter"
fi

expected_order=(cherry date apple banana elderberry)
i=1

for expected in "${expected_order[@]}"; do
    got="${entries[$i]%%$'\t'*}"
    if [[ "$got" != "$expected" ]]; then
        fail "SORT_ORDER=size: position $i expected '$expected', got '$got' — full order: $(for e in "${entries[@]}"; do print -n "${e%%$'\t'*} "; done)"
    fi
    (( i++ ))
done

# ------------------------------------------------------------
# 3. SORT_ORDER=name (the default): plain alphabetical, exactly what
#    the cache file's own order already is — the toggle genuinely does
#    nothing extra in this state, not just "sorts the same way anyway."
# ------------------------------------------------------------

SORT_ORDER="name"
build_entries

expected_order=(apple banana cherry date elderberry)
i=1

for expected in "${expected_order[@]}"; do
    got="${entries[$i]%%$'\t'*}"
    if [[ "$got" != "$expected" ]]; then
        fail "SORT_ORDER=name: position $i expected '$expected', got '$got'"
    fi
    (( i++ ))
done

# ------------------------------------------------------------
# 4. SORT_ORDER=size doesn't leak into Most Used/Recently Added — they
#    keep their own meaningful order regardless.
# ------------------------------------------------------------

SORT_ORDER="size"
CURRENT_VIEW="Recently Added"
build_entries

expected_order=(date banana cherry elderberry apple)
i=1

for expected in "${expected_order[@]}"; do
    got="${entries[$i]%%$'\t'*}"
    if [[ "$got" != "$expected" ]]; then
        fail "SORT_ORDER=size should not affect Recently Added: position $i expected '$expected' (by install_time), got '$got'"
    fi
    (( i++ ))
done

printf 'PASS: size_sort_key() parses display sizes into bytes correctly, SORT_ORDER=size reorders All/categories largest-first without capping them, and leaves Most Used/Recently Added untouched\n'
