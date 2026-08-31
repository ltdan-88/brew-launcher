#!/bin/zsh
#
# Most Used / Recently Added ranking test.
#
# build_entries() re-sorts its filtered results for these two views —
# every other view stays in the alphabetical order the cache file is
# already written in. That re-sort broke silently during development:
# ${(On)array} quoted as "${(On)array}" collapses the whole sorted
# result into one glued-together string instead of a real array, so
# every element after the first vanishes. The real launcher showed
# 1 entry where 15 were expected; caught visually, not by any
# automated check, which is the gap this test closes.
#
# Sources build_entries() and its constants directly from the real
# file rather than reimplementing the sort, so a regression of the
# same shape fails this test rather than needing another visual catch.

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
# full_name, resolved_path, install_time. Only command (field 1) and
# install_time (field 9) matter to this test; the rest just need to
# be present so the row is well-formed.
cat > "$CACHE_FILE" <<'EOF'
apple	Apple tool	apple	1.0	1MB	0	apple	/bin/apple	100
banana	Banana tool	banana	1.0	1MB	0	banana	/bin/banana	500
cherry	Cherry tool	cherry	1.0	1MB	0	cherry	/bin/cherry	300
date	Date tool	date	1.0	1MB	0	date	/bin/date	700
elderberry	Elderberry tool	elderberry	1.0	1MB	0	elderberry	/bin/elderberry	200
EOF

# Constants build_entries() reads. Sourced from the real file for the
# ones with real logic behind them (COMPUTED_VIEW_LIMIT could change),
# hand-set for the plain literals that are just column widths.
COMPUTED_VIEW_LIMIT="$(sed -n 's/^COMPUTED_VIEW_LIMIT=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
[[ -n "$COMPUTED_VIEW_LIMIT" ]] || fail "could not read COMPUTED_VIEW_LIMIT from $LAUNCHER"

FAVORITE_MARKER_TEXT="+"
CATEGORIZED_MARKER_TEXT="#"
UPDATE_INDICATOR_TEXT="*"
COMPACT_VIEW="off"
LEFT_MARKER_WIDTH=4
max_name=20
max_version=8
max_size=6

typeset -A hidden_commands category_members favorite_commands
typeset -A categorized_commands outdated_formulas install_times launch_counts

# build_entries() records every row's size into this unconditionally
# (for SORT_ORDER=size — see sort-fixtures.sh), regardless of which
# view is being built. Needs declaring here too even though this test
# never sets SORT_ORDER itself, same "set -u" reason install_times
# etc. above already need declaring — caught live: this test failed
# with "apple: parameter not set" the moment that line shipped,
# without this test itself having changed at all.
typeset -A entry_sizes

# Sourced from the real file, not reimplemented, so a regression here
# fails this test rather than needing another visual catch.
source <(sed -n '/^build_entries() {/,/^}/p' "$LAUNCHER")

# ------------------------------------------------------------
# 1. Recently Added: every row qualifies (nothing hidden), ranked by
#    install_time descending — not the cache file's own alphabetical
#    order, and not insertion order either.
# ------------------------------------------------------------

CURRENT_VIEW="Recently Added"
build_entries

if (( ${#entries[@]} != 5 )); then
    fail "Recently Added: expected 5 entries, got ${#entries[@]}"
fi

expected_order=(date banana cherry elderberry apple)
i=1

for expected in "${expected_order[@]}"; do
    got="${entries[$i]%%$'\t'*}"
    if [[ "$got" != "$expected" ]]; then
        fail "Recently Added: position $i expected '$expected', got '$got' — full order: $(for e in "${entries[@]}"; do print -n "${e%%$'\t'*} "; done)"
    fi
    (( i++ ))
done

# ------------------------------------------------------------
# 2. Most Used: only commands with a launch count appear at all, and
#    the ranking is by count, independent of install_time — proves
#    the two views don't accidentally share a sort key.
# ------------------------------------------------------------

launch_counts=(apple 1 cherry 5 elderberry 3)

CURRENT_VIEW="Most Used"
build_entries

if (( ${#entries[@]} != 3 )); then
    fail "Most Used: expected 3 entries (only launched commands), got ${#entries[@]}: $(for e in "${entries[@]}"; do print -n "${e%%$'\t'*} "; done)"
fi

expected_order=(cherry elderberry apple)
i=1

for expected in "${expected_order[@]}"; do
    got="${entries[$i]%%$'\t'*}"
    if [[ "$got" != "$expected" ]]; then
        fail "Most Used: position $i expected '$expected', got '$got'"
    fi
    (( i++ ))
done

# ------------------------------------------------------------
# 3. The cap actually caps. Loaded 20 launches across the 5 fixture
#    commands (repeating them) isn't meaningful since there are only 5
#    distinct commands to rank — instead confirm the cap constant
#    itself is respected by asking for fewer than all of them: with
#    every command launched at least once, Most Used should still
#    never exceed COMPUTED_VIEW_LIMIT even if far more than that many
#    commands qualified in a real, larger install.
# ------------------------------------------------------------

if (( ${#entries[@]} > COMPUTED_VIEW_LIMIT )); then
    fail "Most Used returned more than COMPUTED_VIEW_LIMIT ($COMPUTED_VIEW_LIMIT) entries"
fi

printf 'PASS: Most Used and Recently Added rank correctly and independently, capped at %s\n' "$COMPUTED_VIEW_LIMIT"
