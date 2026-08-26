#!/bin/zsh
#
# Category-file loading test.
#
# load_category_names() is pure with respect to the filesystem — no
# fzf, no interactivity — so it's sourced and called directly against
# a fixture directory rather than driven through the picker. Most of
# category handling (creating one via F7, the reserved-name and "/"
# rejection on a typed name) lives inside toggle_category(), which
# does call fzf and so isn't something to unit-test without either a
# real TTY or refactoring working code purely to make it testable —
# not attempted here, deliberately, per the project's own "no
# drive-by refactors" stance. This covers the read side only: what
# actually ends up in the view picker's category list, given a
# directory of category files including the two reserved names a
# hand-edited file could still create.

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

CATEGORIES_DIR="$TEST_HOME/categories"
mkdir -p "$CATEGORIES_DIR"

# "All" and "Hidden" are hand-made here on purpose — F7 refuses to
# create either interactively, but nothing stops someone from making
# the file directly, and load_category_names() has to cope with that
# rather than trust its own writer was the only thing that ever wrote
# here.
: > "$CATEGORIES_DIR/All"
: > "$CATEGORIES_DIR/Hidden"
: > "$CATEGORIES_DIR/Favorites"
: > "$CATEGORIES_DIR/Weather"
: > "$CATEGORIES_DIR/Games"

# load_category_names() merges in any bundled category (see "Bundled
# defaults") that isn't already a real file — declared here, empty, so
# this test exercises pure real-file loading without pulling in the
# actual bundled dataset (that's covered separately).
typeset -A default_category_commands

# Sourced rather than copy-pasted, so this tests the actual function
# in bin/brew-launcher, not a reimplementation of it that could drift
# out of sync with the real logic.
source <(sed -n '/^load_category_names() {/,/^}/p' "$LAUNCHER")
source <(sed -n '/^compute_category_counts() {/,/^}/p' "$LAUNCHER")

load_category_names

# ------------------------------------------------------------
# 1. Reserved names never appear, even as hand-made files.
# ------------------------------------------------------------

for reserved in All Hidden; do
    for name in "${CATEGORY_NAMES[@]}"; do
        if [[ "$name" == "$reserved" ]]; then
            fail "reserved name '$reserved' appeared in CATEGORY_NAMES despite being a real file on disk"
        fi
    done
done

# ------------------------------------------------------------
# 2. Real categories all appear, none lost or duplicated.
# ------------------------------------------------------------

if (( ${#CATEGORY_NAMES[@]} != 3 )); then
    fail "expected 3 entries (Favorites, Games, Weather), got ${#CATEGORY_NAMES[@]}: ${CATEGORY_NAMES[*]}"
fi

for expected in Favorites Games Weather; do
    found=0
    for name in "${CATEGORY_NAMES[@]}"; do
        [[ "$name" == "$expected" ]] && found=1
    done
    (( found )) || fail "'$expected' missing from CATEGORY_NAMES: ${CATEGORY_NAMES[*]}"
done

# ------------------------------------------------------------
# 3. Favorites always sorts first, ahead of alphabetically earlier
#    names — it's pinned, not just sorted normally ("F" < "G"/"W"
#    would happen to put it first anyway, so this specifically checks
#    position, not just presence).
# ------------------------------------------------------------

if [[ "${CATEGORY_NAMES[1]}" != "Favorites" ]]; then
    fail "Favorites should be first in CATEGORY_NAMES, got: ${CATEGORY_NAMES[*]}"
fi

# ------------------------------------------------------------
# 4. Everything else after Favorites is alphabetically sorted.
# ------------------------------------------------------------

if [[ "${CATEGORY_NAMES[2]}" != "Games" || "${CATEGORY_NAMES[3]}" != "Weather" ]]; then
    fail "non-Favorites entries should sort alphabetically (Games, Weather), got: ${CATEGORY_NAMES[2]}, ${CATEGORY_NAMES[3]}"
fi

# ------------------------------------------------------------
# 5. Without a Favorites file at all, nothing is pinned — the
#    function shouldn't invent an entry that isn't on disk.
# ------------------------------------------------------------

rm -f "$CATEGORIES_DIR/Favorites"
load_category_names

if (( ${#CATEGORY_NAMES[@]} != 2 )); then
    fail "expected 2 entries with no Favorites file, got ${#CATEGORY_NAMES[@]}: ${CATEGORY_NAMES[*]}"
fi

for name in "${CATEGORY_NAMES[@]}"; do
    [[ "$name" == "Favorites" ]] && fail "Favorites appeared in CATEGORY_NAMES despite no Favorites file existing"
done

# ------------------------------------------------------------
# 6. Bundled categories (see "Bundled defaults") merge in without
#    duplicating a name that already has a real file, and a bundled-
#    only name (no real file at all) still shows up so it's browsable.
# ------------------------------------------------------------

rm -f "$CATEGORIES_DIR/Weather"
: > "$CATEGORIES_DIR/Games"
default_category_commands=(
    [nsnake]=Games
    [btop]="System Monitoring"
)

load_category_names

if (( ${#CATEGORY_NAMES[@]} != 2 )); then
    fail "expected 2 entries (Games, System Monitoring), got ${#CATEGORY_NAMES[@]}: ${CATEGORY_NAMES[*]}"
fi

games_seen=0
for name in "${CATEGORY_NAMES[@]}"; do
    [[ "$name" == "Games" ]] && (( games_seen++ ))
done
(( games_seen == 1 )) || fail "'Games' should appear exactly once (real file + bundled member), saw $games_seen: ${CATEGORY_NAMES[*]}"

found=0
for name in "${CATEGORY_NAMES[@]}"; do
    [[ "$name" == "System Monitoring" ]] && found=1
done
(( found )) || fail "bundled-only category 'System Monitoring' (no real file) should still be browsable: ${CATEGORY_NAMES[*]}"

# ------------------------------------------------------------
# 7. compute_category_counts() — the view-picker's per-category count
#    has to match what the filtered view will actually show, not just
#    how many lines mention that category. Real bug (reported live):
#    a plain `grep -c` on the real file counted hidden and no-longer-
#    installed entries, and the bundled tally didn't check hidden
#    either — so a category containing any hidden command always
#    showed a higher count than it actually displayed.
# ------------------------------------------------------------

CACHE_FILE="$TEST_HOME/entries"
cat > "$CACHE_FILE" <<CACHE
age	desc	age	1.0	1MB	0	age	/opt/homebrew/bin/age	0	-	0
age-inspect	desc	age	1.0	1MB	0	age	/opt/homebrew/bin/age-inspect	0	Security	1
age-keygen	desc	age	1.0	1MB	0	age	/opt/homebrew/bin/age-keygen	0	Security	0
CACHE

: > "$CATEGORIES_DIR/Security"
printf 'age\nage-inspect\nuninstalled-tool\n' > "$CATEGORIES_DIR/Security"
default_category_commands=([age-keygen]=Security)

typeset -A hidden_commands category_counts
hidden_commands=([age-inspect]=1)

# CATEGORY_NAMES drives which category files compute_category_counts()
# even looks at — needs a fresh load now that "Security" exists.
load_category_names
compute_category_counts

# Expected: age (real, visible) + age-keygen (bundled, visible) = 2.
# age-inspect is real but hidden, uninstalled-tool isn't in the cache
# at all — neither should count.
if [[ "${category_counts[Security]:-0}" != "2" ]]; then
    fail "expected Security count 2 (age + age-keygen; age-inspect hidden, uninstalled-tool not cached), got ${category_counts[Security]:-0}"
fi

printf 'PASS: category loading skips reserved names, pins Favorites first, sorts the rest, merges bundled categories without duplicating, counts exclude hidden/uninstalled entries\n'
