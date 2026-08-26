#!/bin/zsh
#
# Cache round-trip smoke test.
#
# Guards the highest-risk area of the launcher: writing the cache in
# Python and reading it back in zsh. A v0.4.0 bug lived here — the
# writer emitted no trailing newline, and `while read` silently skips
# a final line without one, so the alphabetically last tool was
# invisible everywhere in the app with no error of any kind.
#
# `--list` is the test surface because it exercises the real cache
# build and the real read loop, then exits without ever starting fzf,
# so it needs no TTY.
#
# Runs against whatever Homebrew formulae exist on the machine. If
# there are none (a bare CI runner), it skips rather than failing —
# an empty environment can't say anything useful about round-tripping.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

if [[ ! -x "$LAUNCHER" ]]; then
    fail "launcher not found or not executable: $LAUNCHER"
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "SKIP: brew not available"
    exit 0
fi

if [[ -z "$(brew leaves --installed-on-request 2>/dev/null)" ]]; then
    echo "SKIP: no user-installed Homebrew formulae to build a cache from"
    exit 0
fi

# Isolated XDG dirs so the test neither reads nor clobbers real
# user data — in particular it must not see a real ignore file,
# which would legitimately hide entries and confuse the assertions.
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

export XDG_CACHE_HOME="$TEST_HOME/cache"
export XDG_CONFIG_HOME="$TEST_HOME/config"

OUTPUT="$TEST_HOME/list-output.txt"

# Diagnostics capture both streams: the launcher reports startup
# errors (missing dependencies, unbuildable cache) on stdout via echo,
# not stderr, so capturing stderr alone reports a bare failure with no
# explanation.
if ! "$LAUNCHER" --list > "$OUTPUT" 2>"$TEST_HOME/stderr.txt"; then
    printf -- '--- stdout ---\n' >&2
    cat "$OUTPUT" >&2
    printf -- '--- stderr ---\n' >&2
    cat "$TEST_HOME/stderr.txt" >&2
    fail "--list exited non-zero"
fi

CACHE_FILE="$XDG_CACHE_HOME/brew-launcher/entries"

[[ -s "$CACHE_FILE" ]] || fail "--list did not build a cache at $CACHE_FILE"

# ------------------------------------------------------------
# 1. The cache must be newline-terminated.
# ------------------------------------------------------------

if [[ "$(tail -c 1 "$CACHE_FILE" | xxd -p)" != "0a" ]]; then
    fail "cache file does not end with a newline — the last entry will be silently dropped by every read loop"
fi

# ------------------------------------------------------------
# 2. Every cached entry must survive the round trip, minus whatever
#    the bundled default-hidden list (see "Bundled defaults")
#    legitimately excludes.
#
# No ignore file exists in this isolated config, so IGNORE_FILE
# contributes nothing here — but the bundled hidden list applies
# regardless of user config, so counts only match after subtracting
# field 11 (default_hidden) rows, not exactly.
# ------------------------------------------------------------

cache_count="$(grep -c '' "$CACHE_FILE")"
list_count="$(grep -c '' "$OUTPUT")"
bundled_hidden_count="$(awk -F'\t' '$11 == "1" { c++ } END { print c+0 }' "$CACHE_FILE")"
expected_count=$(( cache_count - bundled_hidden_count ))

if [[ "$expected_count" != "$list_count" ]]; then
    fail "cache has $cache_count entries ($bundled_hidden_count bundled-hidden) but --list emitted $list_count, expected $expected_count"
fi

# ------------------------------------------------------------
# 3. The last entry specifically — the one the original bug ate.
#
# Skips backward past any bundled-hidden row (field 11 == "1") —
# those are legitimately absent from --list regardless of this bug,
# so the real regression check needs the last row that's actually
# supposed to appear.
# ------------------------------------------------------------

last_cached="$(awk -F'\t' '$11 != "1" { line = $1 } END { print line }' "$CACHE_FILE")"

if [[ -z "$last_cached" ]]; then
    echo "SKIP: every cached entry is bundled-hidden, nothing to check here"
elif ! cut -f1 "$OUTPUT" | grep -qxF -- "$last_cached"; then
    fail "last cache entry '$last_cached' is missing from --list output"
fi

# ------------------------------------------------------------
# 4. Field shape: --list documents six tab-separated fields.
# ------------------------------------------------------------

bad_field_count="$(awk -F'\t' 'NF != 6 { c++ } END { print c+0 }' "$OUTPUT")"

if [[ "$bad_field_count" != "0" ]]; then
    fail "$bad_field_count --list row(s) did not have exactly 6 tab-separated fields"
fi

printf 'PASS: %s entries round-tripped intact (last: %s)\n' "$cache_count" "$last_cached"
