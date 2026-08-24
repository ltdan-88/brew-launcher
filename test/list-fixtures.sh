#!/bin/zsh
#
# --list fixture test: hidden-entry filtering and output shape.
#
# cache-roundtrip.sh exercises a real cache build, so it can only run
# where real Homebrew formulae exist — a bare CI runner skips it. This
# test writes the cache and state files directly instead of going
# through rebuild_cache(), so it never touches Homebrew and never
# skips: the state file's mtime alone satisfies the freshness check
# (see "Validate cache" in bin/brew-launcher), so no brew call happens
# at all.
#
# Covers what --list documents: hidden entries excluded, six
# tab-separated fields, and that command/formula/version/size/
# description survive the cache round trip unchanged.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

for dependency in brew fzf python3; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "SKIP: '$dependency' not available"
        exit 0
    fi
done

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export XDG_CACHE_HOME="$TEST_HOME/cache"
export XDG_CONFIG_HOME="$TEST_HOME/config"

CACHE_DIR="$XDG_CACHE_HOME/brew-launcher"
CONFIG_DIR="$XDG_CONFIG_HOME/brew-launcher"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR"

# The state file's format-version line must match the launcher's own
# constant exactly, or the cache is treated as stale and a real
# (network-dependent, formula-dependent) rebuild is attempted — which
# would defeat the entire point of a fixture test. Read it from the
# script rather than hardcoding it, so a future version bump can't
# silently make this test start skipping or failing for the wrong
# reason.
CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"

[[ -n "$CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

# entries columns: command, description, formula, version, size,
# outdated, full_name — see build_entries() in bin/brew-launcher.
# "hidden-tool" is the one this test expects --list to filter out.
cat > "$CACHE_DIR/entries" <<'EOF'
hidden-tool	A tool that should never appear	hidden-formula	1.0.0	1.2MB	0	hidden-formula
mole	Deep clean and optimize your Mac	mole	1.51.0	9.7MB	0	mole
tapped-tool	Comes from a third-party tap	tapped-tool	2.3.0	4MB	0	someuser/sometap/tapped-tool
EOF

# Line 1 = format version (must match); the rest is an arbitrary
# Homebrew-state snapshot — its content is never compared while the
# entry is fresh, only its presence and the file's mtime are.
{
    print -r -- "$CACHE_FORMAT_VERSION"
    print -r -- "fixture-state-snapshot"
} > "$CACHE_DIR/state"

print -r -- "hidden-tool" > "$CONFIG_DIR/ignore"

# Empty and fresh, so refresh_outdated_if_stale() treats it as valid
# and never shells out to a real `brew outdated` — that call is on its
# own separate TTL from the entries/state cache above, queries this
# machine's actual installed formulae regardless of the isolated XDG
# dirs, and made this test genuinely flaky (mole showed outdated_flag=1
# from the real Homebrew install on the machine this was first run on,
# not from anything this fixture seeded).
: > "$CACHE_DIR/outdated"

OUTPUT="$TEST_HOME/list-output.txt"

if ! "$LAUNCHER" --list > "$OUTPUT" 2>"$TEST_HOME/stderr.txt"; then
    printf -- '--- stdout ---\n' >&2
    cat "$OUTPUT" >&2
    printf -- '--- stderr ---\n' >&2
    cat "$TEST_HOME/stderr.txt" >&2
    fail "--list exited non-zero"
fi

# ------------------------------------------------------------
# 1. The hidden entry must not appear at all.
# ------------------------------------------------------------

if cut -f1 "$OUTPUT" | grep -qxF -- "hidden-tool"; then
    fail "hidden-tool appears in --list output despite being in the ignore file"
fi

# ------------------------------------------------------------
# 2. Every non-hidden entry must survive, exactly two of them.
# ------------------------------------------------------------

visible_count="$(grep -c '' "$OUTPUT")"

if [[ "$visible_count" != "2" ]]; then
    fail "expected 2 visible entries, got $visible_count"
fi

# ------------------------------------------------------------
# 3. --list documents six tab-separated fields on every row.
# ------------------------------------------------------------

bad_field_count="$(awk -F'\t' 'NF != 6 { c++ } END { print c+0 }' "$OUTPUT")"

if [[ "$bad_field_count" != "0" ]]; then
    fail "$bad_field_count row(s) did not have exactly 6 tab-separated fields"
fi

# ------------------------------------------------------------
# 4. Field values round-trip unchanged: command, formula, version,
#    size and description for a plain entry, and specifically that a
#    tap-qualified full_name doesn't leak into the formula column
#    (--list's second field is the short formula name, "formula",
#    not "full_name" — a real bug this would have caught: the
#    outdated-matching code has to check both, precisely because
#    they're allowed to differ).
# ------------------------------------------------------------

mole_row="$(grep '^mole	' "$OUTPUT")"
expected_mole=$'mole\tmole\t1.51.0\t9.7MB\t0\tDeep clean and optimize your Mac'

if [[ "$mole_row" != "$expected_mole" ]]; then
    fail "mole row round-tripped incorrectly: got [$mole_row]"
fi

tapped_formula_field="$(grep '^tapped-tool	' "$OUTPUT" | cut -f2)"

if [[ "$tapped_formula_field" != "tapped-tool" ]]; then
    fail "tapped-tool's formula field should be the short name 'tapped-tool', got [$tapped_formula_field]"
fi

printf 'PASS: hidden-entry filtering and 6-field shape verified against a fixture cache\n'
