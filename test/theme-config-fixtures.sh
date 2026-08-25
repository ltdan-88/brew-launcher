#!/bin/zsh
#
# Theme and config-file test.
#
# Covers: every named theme is accepted, an unknown one is rejected
# (matching the fail-fast convention BREW_LAUNCHER_TERMINAL already
# has), the config file's persisted TERMINAL/THEME are picked up with
# no env var set, and an env var still wins over the config file when
# both are present.
#
# Uses the same fixture-cache trick as list-fixtures.sh (a state file
# whose mtime alone satisfies the freshness check) so this runs
# without needing any real installed formulae, and never calls brew.

set -u

SCRIPT_DIR="${0:A:h}"
LAUNCHER="$SCRIPT_DIR/../bin/brew-launcher"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -x "$LAUNCHER" ]] || fail "launcher not found or not executable: $LAUNCHER"

for dependency in fzf python3; do
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

CACHE_FORMAT_VERSION="$(sed -n 's/^CACHE_FORMAT_VERSION=\([0-9]*\)/\1/p' "$LAUNCHER" | head -1)"
[[ -n "$CACHE_FORMAT_VERSION" ]] || fail "could not read CACHE_FORMAT_VERSION from $LAUNCHER"

cat > "$CACHE_DIR/entries" <<'EOF'
btop	Resource monitor	btop	1.4.7	1.5MB	0	btop	/usr/bin/btop	100
EOF

{
    print -r -- "$CACHE_FORMAT_VERSION"
    print -r -- "fixture-state-snapshot"
} > "$CACHE_DIR/state"

: > "$CACHE_DIR/outdated"

# ------------------------------------------------------------
# 1. Every documented theme name is accepted.
# ------------------------------------------------------------

for theme in catppuccin gruvbox tokyonight nord dracula; do
    if ! BREW_LAUNCHER_THEME="$theme" "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
        cat "$TEST_HOME/stderr.txt" >&2
        fail "theme '$theme' was rejected, but it's supposed to be valid"
    fi
done

# ------------------------------------------------------------
# 2. An unrecognized theme name is rejected, matching how
#    BREW_LAUNCHER_TERMINAL already fails on an invalid value —
#    silently falling back would hide a typo instead of surfacing it.
# ------------------------------------------------------------

# The launcher's own startup-error convention is to print to stdout,
# not stderr (see cache-roundtrip.sh's own note on this) — captured
# accordingly rather than assuming stderr the way most CLIs would.
if BREW_LAUNCHER_THEME="not-a-real-theme" "$LAUNCHER" --list >"$TEST_HOME/stdout.txt" 2>&1; then
    fail "an unrecognized theme name should have been rejected"
fi

grep -q "unknown theme" "$TEST_HOME/stdout.txt" ||
    fail "rejection message should explain what went wrong: $(cat "$TEST_HOME/stdout.txt")"

# ------------------------------------------------------------
# 3. The config file's persisted THEME/TERMINAL are used when no env
#    var overrides them.
# ------------------------------------------------------------

cat > "$CONFIG_DIR/config" <<'EOF'
# a comment, and blank lines below, should both be harmless
THEME=nord
TERMINAL=current
EOF

if ! "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
    cat "$TEST_HOME/stderr.txt" >&2
    fail "a valid config-file theme should not be rejected"
fi

# ------------------------------------------------------------
# 4. An env var still overrides the config file — same precedence
#    BREW_LAUNCHER_TERMINAL already had before this file existed.
# ------------------------------------------------------------

if BREW_LAUNCHER_THEME="not-a-real-theme" "$LAUNCHER" --list >/dev/null 2>"$TEST_HOME/stderr.txt"; then
    fail "the env var should override the config file's valid theme with an invalid one and fail"
fi

# ------------------------------------------------------------
# 5. set_config_value() — the function the in-app Theme picker uses
#    to write the config file. Pure with respect to the filesystem
#    (no fzf), so sourced and called directly, same approach as
#    hide_entry()/unhide_entry() in ignore-fixtures.sh.
# ------------------------------------------------------------

CONFIG_DIR="$TEST_HOME/set-config-dir"
CONFIG_FILE="$CONFIG_DIR/config"
CACHE_DIR="$TEST_HOME/set-config-cache"
mkdir -p "$CACHE_DIR"

source <(sed -n '/^set_config_value() {/,/^}/p' "$LAUNCHER")

# 5a. Writing into a config file that doesn't exist yet creates it.
set_config_value THEME nord
[[ "$(cat "$CONFIG_FILE")" == "THEME=nord" ]] ||
    fail "set_config_value should create the config file with the new line: $(cat "$CONFIG_FILE" 2>/dev/null)"

# 5b. Adding a second, different key appends rather than overwriting.
set_config_value TERMINAL current

if [[ "$(grep -c '' "$CONFIG_FILE")" != "2" ]]; then
    fail "expected 2 lines after adding a second key, got: $(cat "$CONFIG_FILE")"
fi
grep -qx "THEME=nord" "$CONFIG_FILE" || fail "THEME=nord should have survived adding TERMINAL"
grep -qx "TERMINAL=current" "$CONFIG_FILE" || fail "TERMINAL=current should have been added"

# 5c. Updating an existing key replaces its line in place — a hand-
#     written comment elsewhere in the file must survive untouched.
printf '# a note I wrote by hand\n' >> "$CONFIG_FILE"
set_config_value THEME dracula

if [[ "$(grep -c '' "$CONFIG_FILE")" != "3" ]]; then
    fail "updating an existing key should not change the line count: $(cat "$CONFIG_FILE")"
fi
grep -qx "THEME=dracula" "$CONFIG_FILE" || fail "THEME should have been updated to dracula"
grep -qx "THEME=nord" "$CONFIG_FILE" && fail "the old THEME=nord line should be gone, not duplicated"
grep -qx "# a note I wrote by hand" "$CONFIG_FILE" || fail "a hand-written comment should survive an update to a different concern"
grep -qx "TERMINAL=current" "$CONFIG_FILE" || fail "TERMINAL=current should still be there, untouched by a THEME update"

printf 'PASS: all named themes accepted, unknown theme rejected, config file honored, env var still wins, set_config_value writes/updates correctly\n'
