#!/bin/zsh
#
# --diagnose fixture test.
#
# --diagnose is deliberately handled before the hard "brew/fzf/python3
# required" exit (see the comment above it in bin/brew-launcher) so it
# can still run — and explain what's missing — when one of those isn't
# installed. That's the one behavior a plain "run it against the real
# machine" smoke test can't cover, since the real machine always has
# all three, so this test simulates a missing dependency via a
# restricted PATH rather than skipping the case entirely.
#
# Also covers: exits 0 (not 1) against a totally fresh, empty
# XDG_CONFIG_HOME/XDG_CACHE_HOME (missing config/cache is a [warn], not
# a [FAIL] — nothing has gone wrong on a first run), and reports the
# real cache format version + entry count against a fixture cache.

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

# ------------------------------------------------------------
# Case 1: fresh environment, nothing created yet.
# ------------------------------------------------------------

FRESH_XDG_CONFIG="$TEST_HOME/fresh-config"
FRESH_XDG_CACHE="$TEST_HOME/fresh-cache"

fresh_output="$(XDG_CONFIG_HOME="$FRESH_XDG_CONFIG" XDG_CACHE_HOME="$FRESH_XDG_CACHE" \
    "$LAUNCHER" --diagnose 2>&1)"
fresh_status=$?

(( fresh_status == 0 )) || fail "fresh environment: expected exit 0, got $fresh_status
$fresh_output"

echo "$fresh_output" | grep -q 'not created yet' ||
    fail "fresh environment: expected a 'not created yet' line for missing config/cache
$fresh_output"

echo "$fresh_output" | grep -q '\[FAIL\]' &&
    fail "fresh environment: a missing config/cache dir should be [warn], not [FAIL]
$fresh_output"

# ------------------------------------------------------------
# Case 2: real cache/config present, matching format version.
# ------------------------------------------------------------

REAL_XDG_CONFIG="$TEST_HOME/real-config"
REAL_XDG_CACHE="$TEST_HOME/real-cache"
CACHE_DIR="$REAL_XDG_CACHE/brew-launcher"
CONFIG_DIR="$REAL_XDG_CONFIG/brew-launcher"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR/categories" "$CONFIG_DIR/presets"

CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
[[ -n "$CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

printf '%s\nsome-state-line\n' "$CACHE_FORMAT_VERSION" > "$CACHE_DIR/state"
printf 'btop\tresource monitor\tbtop\t1.0\t5M\tfalse\tbtop\t/opt/homebrew/bin/btop\t0\n' > "$CACHE_DIR/entries"
: > "$CONFIG_DIR/categories/Favorites"

real_output="$(XDG_CONFIG_HOME="$REAL_XDG_CONFIG" XDG_CACHE_HOME="$REAL_XDG_CACHE" \
    "$LAUNCHER" --diagnose 2>&1)"
real_status=$?

(( real_status == 0 )) || fail "populated environment: expected exit 0, got $real_status
$real_output"

echo "$real_output" | grep -q "cache format v$CACHE_FORMAT_VERSION (current)" ||
    fail "populated environment: expected current cache format line
$real_output"

echo "$real_output" | grep -q '1 cached entries' ||
    fail "populated environment: expected entry count of 1
$real_output"

echo "$real_output" | grep -q '1 categories, 0 presets' ||
    fail "populated environment: expected category/preset counts
$real_output"

# ------------------------------------------------------------
# Case 3: stale cache format version is a [warn], not a [FAIL].
# ------------------------------------------------------------

printf '%s\nsome-state-line\n' "$(( CACHE_FORMAT_VERSION - 1 ))" > "$CACHE_DIR/state"

stale_output="$(XDG_CONFIG_HOME="$REAL_XDG_CONFIG" XDG_CACHE_HOME="$REAL_XDG_CACHE" \
    "$LAUNCHER" --diagnose 2>&1)"
stale_status=$?

(( stale_status == 0 )) || fail "stale cache format: expected exit 0, got $stale_status
$stale_output"

echo "$stale_output" | grep -q 'will rebuild on next launch' ||
    fail "stale cache format: expected a rebuild-on-next-launch warning
$stale_output"

# ------------------------------------------------------------
# Case 4: a genuinely missing required dependency is a [FAIL], and
# drives a nonzero exit. Simulated via a restricted PATH containing
# fzf and python3 but not brew, rather than touching the real machine.
# ------------------------------------------------------------

FAKE_BIN="$TEST_HOME/fake-bin"
mkdir -p "$FAKE_BIN"
ln -s "$(command -v fzf)" "$FAKE_BIN/fzf"
ln -s "$(command -v python3)" "$FAKE_BIN/python3"

missing_output="$(PATH="$FAKE_BIN:/usr/bin:/bin" \
    XDG_CONFIG_HOME="$FRESH_XDG_CONFIG" XDG_CACHE_HOME="$FRESH_XDG_CACHE" \
    "$LAUNCHER" --diagnose 2>&1)"
missing_status=$?

(( missing_status == 1 )) || fail "missing brew: expected exit 1, got $missing_status
$missing_output"

echo "$missing_output" | grep -q '\[FAIL\] brew — not found' ||
    fail "missing brew: expected a [FAIL] line naming brew
$missing_output"

echo "$missing_output" | grep -q 'problem(s) found' ||
    fail "missing brew: expected a problem-count summary line
$missing_output"

echo "PASS: --diagnose exits 0 with only warnings on a fresh install, reports real cache format/entry/category/preset counts against a populated one, treats a stale cache format as a warning (not a failure), and correctly reports [FAIL] + exit 1 for a genuinely missing required dependency"
