#!/bin/zsh
#
# Duplicate command-name handling test.
#
# The dedup logic lives inline inside lib/brew-launcher/cache_writer.py
# (it needs real `brew info --json` output to reach naturally), so it
# can't be sourced as a standalone function the way load_category_names()
# or hide_entry() can. Instead the exact block is extracted from that
# file with sed and spliced after a fixture `entries` list, so this
# still tests the real code — not a hand-copied reimplementation that
# could quietly drift out of sync.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"
CACHE_WRITER_PY="$SCRIPT_DIR/../lib/brew-launcher/cache_writer.py"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"
[[ -f "$CACHE_WRITER_PY" ]] || fail "cache writer not found: $CACHE_WRITER_PY"

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

DEDUP_BLOCK="$TEST_HOME/dedup_block.py"

sed -n '/^seen = set()$/,/^# Write cache\.$/p' "$CACHE_WRITER_PY" |
    sed '$d;$d' \
    > "$DEDUP_BLOCK"

[[ -s "$DEDUP_BLOCK" ]] || fail "could not extract the dedup block from $CACHE_WRITER_PY — its markers may have changed"

TEST_SCRIPT="$TEST_HOME/test.py"

cat > "$TEST_SCRIPT" <<'PY'
import sys

# Fields: command, description, formula, version, size, outdated_flag,
# full_name — see build_entries() / the cache-writer in bin/brew-launcher.
#
# "mc" is deliberately provided by two different formulae, one of them
# tap-qualified, to also exercise the exact real-world case that
# caused it (midnight-commander's mc vs. an unrelated tap also
# providing an "mc" command).
#
# sorted(entries, key=str.lower) sorts on the WHOLE tab-joined string,
# not just the formula name — both rows start with "mc\t", so the tie
# is actually broken by the description (the next field), not the
# formula. "A terminal file manager" is picked to sort before "Some
# other tool" on purpose, so which one "wins" here is deliberate and
# readable, not an accident of description text nobody chose.
entries = [
    "mc\tA terminal file manager\tmidnight-commander\t4.8.33\t8.2MB\t0\tmidnight-commander",
    "mc\tSome other tool\tother-mc-tool\t1.0.0\t1MB\t0\tsomeone/tap/other-mc-tool",
    "btop\tResource monitor\tbtop\t1.4.7\t1.5MB\t0\tbtop",
]

exec(open(sys.argv[1]).read())

print("UNIQUE_COUNT", len(unique))
print("DUPLICATE_COUNT", len(duplicates))
for e in unique:
    print("UNIQUE_ROW", e.split("\t")[0], e.split("\t")[2])
for cmd, formula in duplicates:
    print("DUPLICATE_ROW", cmd, formula)
PY

OUTPUT="$(python3 "$TEST_SCRIPT" "$DEDUP_BLOCK" 2>"$TEST_HOME/stderr.txt")"

if [[ -z "$OUTPUT" ]]; then
    printf -- '--- stderr ---\n' >&2
    cat "$TEST_HOME/stderr.txt" >&2
    fail "dedup block produced no output — see stderr above"
fi

# ------------------------------------------------------------
# 1. Exactly one "mc" survives, one "btop" survives — 2 unique rows.
# ------------------------------------------------------------

unique_count="$(print -r -- "$OUTPUT" | grep -c '^UNIQUE_COUNT ')"
unique_value="$(print -r -- "$OUTPUT" | awk '/^UNIQUE_COUNT/ {print $2}')"

[[ "$unique_value" == "2" ]] || fail "expected 2 unique entries, got $unique_value"

# ------------------------------------------------------------
# 2. Exactly one duplicate recorded (the second "mc").
# ------------------------------------------------------------

duplicate_value="$(print -r -- "$OUTPUT" | awk '/^DUPLICATE_COUNT/ {print $2}')"

[[ "$duplicate_value" == "1" ]] || fail "expected 1 duplicate, got $duplicate_value"

# ------------------------------------------------------------
# 3. The FIRST match by sort order is the one kept, not just
#    whichever happened to be appended first in the fixture list
#    above (both orders are tried implicitly since the fixture
#    doesn't rely on list order — sorted() re-sorts it regardless).
# ------------------------------------------------------------

kept_formula="$(print -r -- "$OUTPUT" | awk '/^UNIQUE_ROW mc / {print $3}')"

[[ "$kept_formula" == "midnight-commander" ]] || fail "expected midnight-commander to be the kept 'mc' entry, got $kept_formula"

# ------------------------------------------------------------
# 4. The one dropped is recorded with its OWN formula name, not the
#    kept one's — this is what makes the stderr note ("also provided
#    by X") actually useful instead of misleading.
# ------------------------------------------------------------

dropped_formula="$(print -r -- "$OUTPUT" | awk '/^DUPLICATE_ROW mc / {print $3}')"

[[ "$dropped_formula" == "other-mc-tool" ]] || fail "expected the dropped duplicate to be attributed to other-mc-tool, got $dropped_formula"

# ------------------------------------------------------------
# 5. btop, with no collision, survives untouched.
# ------------------------------------------------------------

print -r -- "$OUTPUT" | grep -qx 'UNIQUE_ROW btop btop' ||
    fail "btop (no duplicate) should survive as its own unique entry"

printf 'PASS: duplicate command names are deduplicated, first sorted match kept, both formulae reported\n'
